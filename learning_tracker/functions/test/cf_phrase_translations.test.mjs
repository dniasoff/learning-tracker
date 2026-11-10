import assert from 'node:assert/strict';
import { afterEach, beforeEach, describe, test } from 'node:test';
import {
  call,
  clearFirestore,
  db,
  expectHttpsError,
  fns,
  PARENT,
  parentAuth,
} from './_cf_helpers.mjs';
import {
  phraseTranslationCacheId,
  resetPhraseTranslationTestDependencies,
  setPhraseTranslationTestDependencies,
} from '../lib/phrase_translations.js';

const REF = 'Genesis 1:1';
const LANG = 'es';
const SOURCE = 'בְּרֵאשִׁית בָּרָא אֱלֹהִים';
const PHRASES = [
  { source: 'בְּרֵאשִׁית', translation: 'En el principio' },
  { source: 'בָּרָא', translation: 'creó' },
  { source: 'אֱלֹהִים', translation: 'Dios' },
];

function toolResponse(phrases) {
  return { content: [{ type: 'tool_use', input: { phrases } }] };
}

async function clearTranslationData() {
  await clearFirestore();
  await Promise.all([
    db.recursiveDelete(db.collection('phrase_translations')),
    db.recursiveDelete(db.collection('phrase_translation_rate_limits')),
  ]);
}

function installMocks({
  source = SOURCE,
  responses = [toolResponse(PHRASES)],
  anthroError,
  fetchError,
  fetchNever = false,
  sefariaTimeoutMs = 10_000,
} = {}) {
  let fetchCalls = 0;
  let anthropicCalls = 0;
  let requestOptions;
  let clientOptions;
  let abortSignal;
  setPhraseTranslationTestDependencies({
    readApiKey: () => 'unit-test-key',
    sefariaTimeoutMs,
    anthropicTimeoutMs: 45_000,
    fetchSefaria: async (url, init) => {
      fetchCalls++;
      assert.match(String(url), /api\/texts\/Genesis%201%3A1\?context=0/);
      abortSignal = init.signal;
      if (fetchError) throw fetchError;
      if (fetchNever) return new Promise(() => {});
      return new Response(JSON.stringify({ he: source }), {
        status: 200,
        headers: { 'content-type': 'application/json' },
      });
    },
    createAnthropic: (options) => {
      clientOptions = options;
      return {
        messages: {
          create: async (request, options) => {
            anthropicCalls++;
            requestOptions = { request, options };
            if (anthroError) throw anthroError;
            return responses[Math.min(anthropicCalls - 1, responses.length - 1)];
          },
        },
      };
    },
  });
  return {
    get fetchCalls() { return fetchCalls; },
    get anthropicCalls() { return anthropicCalls; },
    get requestOptions() { return requestOptions; },
    get clientOptions() { return clientOptions; },
    get abortSignal() { return abortSignal; },
  };
}

function invoke(data = { sefariaRef: REF, targetLanguage: LANG }, auth = parentAuth) {
  return call(fns.translatePhrases, data, auth);
}

beforeEach(clearTranslationData);
afterEach(resetPhraseTranslationTestDependencies);

describe('translatePhrases callable', () => {
  test('rejects unauthenticated callers', async () => {
    installMocks();
    await expectHttpsError(invoke(undefined, null), 'unauthenticated');
  });

  test('validates empty and oversized refs, language tags, and segment indexes', async () => {
    installMocks();
    await expectHttpsError(invoke({ sefariaRef: '', targetLanguage: LANG }), 'invalid-argument');
    await expectHttpsError(invoke({ sefariaRef: 'x'.repeat(201), targetLanguage: LANG }), 'invalid-argument');
    await expectHttpsError(invoke({ sefariaRef: REF, targetLanguage: 'not a language' }), 'invalid-argument');
    await expectHttpsError(invoke({ sefariaRef: REF, targetLanguage: LANG, segmentIndex: 500 }), 'invalid-argument');
  });

  test('rejects an oversized passage returned by the mocked Sefaria endpoint', async () => {
    const mocks = installMocks({ source: 'א'.repeat(12_001) });
    await expectHttpsError(invoke(), 'invalid-argument');
    assert.equal(mocks.fetchCalls, 1);
    assert.equal(mocks.anthropicCalls, 0);
  });

  test('looks up Hebrew through mocked Sefaria fetch and passes the default model to mocked Anthropic', async () => {
    delete process.env.PHRASE_TRANSLATION_MODEL;
    const mocks = installMocks();
    const result = await invoke();
    assert.deepEqual(result.phrases, PHRASES);
    assert.equal(mocks.fetchCalls, 1);
    assert.equal(mocks.anthropicCalls, 1);
    assert.equal(mocks.requestOptions.request.model, 'claude-sonnet-5-5');
    assert.equal(mocks.clientOptions.timeout, 45_000);
    assert.equal(mocks.clientOptions.maxRetries, 1);
    assert.equal(mocks.requestOptions.options.timeout, 45_000);
    assert.equal(mocks.requestOptions.options.maxRetries, 1);
  });

  test('model parameter overrides the default without code changes', async () => {
    process.env.PHRASE_TRANSLATION_MODEL = 'claude-sonnet-test-override';
    const mocks = installMocks();
    await invoke();
    assert.equal(mocks.requestOptions.request.model, 'claude-sonnet-test-override');
    delete process.env.PHRASE_TRANSLATION_MODEL;
  });

  test('a cached result skips Sefaria, Anthropic, and the daily rate-limit transaction', async () => {
    const mocks = installMocks();
    const cacheId = phraseTranslationCacheId(REF, undefined, LANG);
    await db.collection('phrase_translations').doc(cacheId).set({ phrases: PHRASES });
    const result = await invoke();
    assert.deepEqual(result, { phrases: PHRASES, cached: true });
    assert.equal(mocks.fetchCalls, 0);
    assert.equal(mocks.anthropicCalls, 0);
    const day = new Date().toISOString().slice(0, 10);
    const rate = await db.collection('phrase_translation_rate_limits').doc(`${PARENT}_${day}`).get();
    assert.equal(rate.exists, false);
  });

  test('a miss stores the translation in the shared Firestore cache and reserves one daily slot', async () => {
    const mocks = installMocks();
    const result = await invoke();
    assert.deepEqual(result, { phrases: PHRASES, cached: false });
    const cacheId = phraseTranslationCacheId(REF, undefined, LANG);
    assert.deepEqual((await db.collection('phrase_translations').doc(cacheId).get()).get('phrases'), PHRASES);
    const day = new Date().toISOString().slice(0, 10);
    assert.equal((await db.collection('phrase_translation_rate_limits').doc(`${PARENT}_${day}`).get()).get('count'), 1);
    assert.equal(mocks.fetchCalls, 1);
    assert.equal(mocks.anthropicCalls, 1);
  });

  test('transaction rejects a caller who reached the daily new-translation limit', async () => {
    const mocks = installMocks();
    const day = new Date().toISOString().slice(0, 10);
    await db.collection('phrase_translation_rate_limits').doc(`${PARENT}_${day}`).set({ count: 20, day });
    await expectHttpsError(invoke(), 'resource-exhausted');
    assert.equal(mocks.anthropicCalls, 0);
  });

  test('retries invalid phrase coverage once, then rejects without caching', async () => {
    const incomplete = toolResponse(PHRASES.slice(0, 2));
    const mocks = installMocks({ responses: [incomplete, incomplete] });
    await expectHttpsError(invoke(), 'internal');
    assert.equal(mocks.anthropicCalls, 2);
    const cacheId = phraseTranslationCacheId(REF, undefined, LANG);
    assert.equal((await db.collection('phrase_translations').doc(cacheId).get()).exists, false);
  });

  test('maps Anthropic SDK timeout to a sanitized unavailable error', async () => {
    const timeoutError = new Error('private request details');
    timeoutError.name = 'APIConnectionTimeoutError';
    const mocks = installMocks({ anthroError: timeoutError });
    await expectHttpsError(invoke(), 'unavailable');
    assert.equal(mocks.anthropicCalls, 1);
  });

  test('aborts a Sefaria lookup at its deadline and reports unavailable', async () => {
    const mocks = installMocks({ fetchNever: true, sefariaTimeoutMs: 10 });
    await expectHttpsError(invoke(), 'unavailable');
    assert.equal(mocks.fetchCalls, 1);
    assert.equal(mocks.abortSignal.aborted, true);
    assert.equal(mocks.anthropicCalls, 0);
  });
});

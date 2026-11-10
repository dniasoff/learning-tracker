import assert from 'node:assert/strict';
import { describe, test } from 'node:test';
import { createPhrases, validPhrases } from '../lib/phrase_translations.js';

describe('phrase translation response validation', () => {
  const source = 'בְּרֵאשִׁית בָּרָא אֱלֹהִים';
  const complete = [
    { source: 'בְּרֵאשִׁית', translation: 'In the beginning' },
    { source: 'בָּרָא', translation: 'created' },
    { source: 'אֱלֹהִים', translation: 'God' },
  ];

  test('accepts exact ordered phrases covering the complete source', () => {
    assert.equal(validPhrases(source, complete), true);
  });

  test('rejects missing, reordered, or invented source phrases', () => {
    assert.equal(validPhrases(source, complete.slice(0, 2)), false);
    assert.equal(validPhrases(source, [...complete].reverse()), false);
    assert.equal(validPhrases(source, [{ ...complete[0], source: 'לא קיים' }, ...complete.slice(1)]), false);
  });

  test('retries a mocked Anthropic response once when coverage is incomplete', async () => {
    const mockedAnthropicCreate = async (attempt) => attempt === 0 ? complete.slice(0, 2) : complete;
    const result = await createPhrases(source, mockedAnthropicCreate);
    assert.deepEqual(result, complete);
  });

  test('rejects after two invalid mocked Anthropic responses', async () => {
    let calls = 0;
    await assert.rejects(createPhrases(source, async () => {
      calls++;
      return complete.slice(0, 2);
    }));
    assert.equal(calls, 2);
  });
});

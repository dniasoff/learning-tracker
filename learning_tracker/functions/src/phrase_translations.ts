import { createHash } from "node:crypto";
import Anthropic from "@anthropic-ai/sdk";
import { defineSecret, defineString } from "firebase-functions/params";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { db, CALL_OPTS } from "./shared";

export const ANTHROPIC_API_KEY = defineSecret("ANTHROPIC_API_KEY");
const MODEL_ID = defineString("PHRASE_TRANSLATION_MODEL", { default: "claude-sonnet-5-5" });
const PROMPT_VERSION = "phrase-v1";
const MAX_REF_LENGTH = 200;
const MAX_SOURCE_LENGTH = 12_000;
const MAX_TRANSLATIONS_PER_DAY = 20;
const LANGUAGE_TAG = /^[a-z]{2,3}(?:-[A-Z]{2})?$/;

export type Phrase = { source: string; translation: string };

function normalized(text: string): string {
  return text.normalize("NFD").replace(/[\p{P}\p{S}\s\p{M}]/gu, "").toLocaleLowerCase();
}

export function validPhrases(source: string, phrases: unknown): phrases is Phrase[] {
  if (!Array.isArray(phrases) || phrases.length === 0) return false;
  let cursor = 0;
  const sources: string[] = [];
  for (const phrase of phrases) {
    if (!phrase || typeof phrase.source !== "string" || typeof phrase.translation !== "string" ||
      !phrase.source.trim() || !phrase.translation.trim()) return false;
    const index = source.indexOf(phrase.source, cursor);
    if (index < cursor) return false;
    cursor = index + phrase.source.length;
    sources.push(phrase.source);
  }
  return normalized(sources.join("")) === normalized(source);
}

export async function createPhrases(
  source: string,
  create: (attempt: number) => Promise<unknown>,
): Promise<Phrase[]> {
  for (let attempt = 0; attempt < 2; attempt++) {
    const result = await create(attempt);
    if (validPhrases(source, result)) return result;
  }
  throw new HttpsError("internal", "Could not create a complete phrase translation");
}

function flattenText(value: unknown): string[] {
  if (typeof value === "string") return [value];
  if (!Array.isArray(value)) return [];
  return value.flatMap(flattenText);
}

async function fetchSegment(ref: string, segmentIndex?: number): Promise<string> {
  let response: Response;
  try {
    response = await fetch(`https://www.sefaria.org/api/texts/${encodeURIComponent(ref)}?context=0`);
  } catch {
    throw new HttpsError("unavailable", "Text source is unavailable");
  }
  if (!response.ok) throw new HttpsError("not-found", "Sefaria text not found");
  const payload = await response.json() as { he?: unknown };
  const segments = flattenText(payload.he).filter((part) => part.trim().length > 0);
  const source = segmentIndex === undefined
    ? segments.join("\n")
    : segments[segmentIndex];
  if (!source) throw new HttpsError("not-found", "Hebrew text segment not found");
  if (source.length > MAX_SOURCE_LENGTH) throw new HttpsError("invalid-argument", "Text segment is too long");
  return source;
}

function cacheId(ref: string, segmentIndex: number | undefined, lang: string): string {
  return createHash("sha256").update(`${ref}|${segmentIndex ?? "all"}|${lang}|${PROMPT_VERSION}`).digest("hex");
}

async function reserveDailyTranslation(uid: string): Promise<void> {
  const day = new Date().toISOString().slice(0, 10);
  const rateRef = db.collection("phrase_translation_rate_limits").doc(`${uid}_${day}`);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(rateRef);
    const count = snapshot.get("count") ?? 0;
    if (count >= MAX_TRANSLATIONS_PER_DAY) {
      throw new HttpsError("resource-exhausted", "Daily phrase translation limit reached");
    }
    transaction.set(rateRef, { count: count + 1, day }, { merge: true });
  });
}

export const translatePhrases = onCall({ ...CALL_OPTS, secrets: [ANTHROPIC_API_KEY] }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Must be signed in");
  const data = (request.data ?? {}) as Record<string, unknown>;
  if (Object.keys(data).some((key) => !["sefariaRef", "segmentIndex", "targetLanguage"].includes(key))) {
    throw new HttpsError("invalid-argument", "Unexpected request field");
  }
  const { sefariaRef, segmentIndex, targetLanguage } = data;
  if (typeof sefariaRef !== "string" || !sefariaRef.trim() || sefariaRef.length > MAX_REF_LENGTH) {
    throw new HttpsError("invalid-argument", "sefariaRef must be a valid Sefaria reference");
  }
  if (segmentIndex !== undefined && (!Number.isInteger(segmentIndex) || (segmentIndex as number) < 0 || (segmentIndex as number) > 499)) {
    throw new HttpsError("invalid-argument", "segmentIndex must be an integer from 0 to 499");
  }
  if (typeof targetLanguage !== "string" || !LANGUAGE_TAG.test(targetLanguage)) {
    throw new HttpsError("invalid-argument", "targetLanguage must be a valid ISO language code");
  }

  const index = segmentIndex as number | undefined;
  const id = cacheId(sefariaRef, index, targetLanguage);
  const cacheRef = db.collection("phrase_translations").doc(id);
  const cached = await cacheRef.get();
  if (cached.exists) return { phrases: cached.get("phrases"), cached: true };

  const source = await fetchSegment(sefariaRef, index);
  await reserveDailyTranslation(uid);
  const client = new Anthropic({ apiKey: ANTHROPIC_API_KEY.value() });
  const phrases = await createPhrases(source, async () => {
    const response = await client.messages.create({
      model: MODEL_ID.value(),
      max_tokens: 8192,
      system: "Translate Torah study text faithfully. Keep source phrases exact and in order, covering all source text. Return only the requested structured tool input.",
      messages: [{ role: "user", content: `Split this Hebrew or Aramaic passage into short meaningful phrases, following its clauses, and translate each into language code ${targetLanguage}. Preserve the complete source exactly across ordered phrases. Passage:\n${source}` }],
      tools: [{
        name: "phrase_translation",
        description: "Return an ordered full-coverage phrase translation.",
        input_schema: {
          type: "object",
          properties: {
            phrases: {
              type: "array",
              items: {
                type: "object",
                properties: { source: { type: "string" }, translation: { type: "string" } },
                required: ["source", "translation"],
                additionalProperties: false,
              },
            },
          },
          required: ["phrases"],
          additionalProperties: false,
        },
      }],
      tool_choice: { type: "tool", name: "phrase_translation" },
    });
    const tool = response.content.find((block) => block.type === "tool_use");
    if (!tool || tool.type !== "tool_use") return null;
    return (tool.input as { phrases?: unknown }).phrases;
  });
  try {
    await cacheRef.create({ sefaria_ref: sefariaRef, segment_index: index ?? null, target_language: targetLanguage, prompt_version: PROMPT_VERSION, phrases, created_at: new Date() });
  } catch (error) {
    const racedCache = await cacheRef.get();
    if (racedCache.exists) return { phrases: racedCache.get("phrases"), cached: true };
    throw error;
  }
  return { phrases, cached: false };
});

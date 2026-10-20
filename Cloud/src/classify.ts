export const CLEF_MODEL = "@cf/cloudflare/clef";
const CLEF_TIMEOUT_MS = 15_000;
const CLEF_CONCURRENCY = 6;
const CONTENT_ROLES = ["content", "lead_in", "heading", "caption"];

const MOST_BLOCKS = 400;
const LONGEST_BLOCK = 4000;
const MOST_CHARACTERS = 60_000;
const MOST_CANDIDATES = 120;

const graphemes = new Intl.Segmenter(undefined, { granularity: "grapheme" });

export interface Classification {
  blocks: string[];
  candidates: number[];
}

export interface Verdict {
  probabilities: number[];
  tokens: number;
}

export function parseClassification(body: unknown): Classification | string {
  if (typeof body !== "object" || body === null) return "body must be an object";
  const { title, site, blocks, candidates } = body as { [key: string]: unknown };
  if (title !== undefined && typeof title !== "string") return "title must be a string";
  if (site !== undefined && typeof site !== "string") return "site must be a string";
  if (!Array.isArray(blocks) || blocks.length === 0 || blocks.length > MOST_BLOCKS) return `blocks must hold 1 to ${MOST_BLOCKS} entries`;
  if (!blocks.every((block) => typeof block === "string")) return "each block must be a string";
  const lengths = blocks.map(characters);
  if (lengths.some((length) => length > LONGEST_BLOCK)) return `each block must be under ${LONGEST_BLOCK} characters`;
  if (lengths.reduce((total, length) => total + length, 0) > MOST_CHARACTERS) return `blocks must total under ${MOST_CHARACTERS} characters`;
  if (!Array.isArray(candidates) || candidates.length === 0 || candidates.length > MOST_CANDIDATES) return `candidates must hold 1 to ${MOST_CANDIDATES} entries`;
  if (!candidates.every((index) => Number.isSafeInteger(index) && index >= 0 && index < blocks.length)) return "candidates must be indexes into blocks";
  if (new Set(candidates).size !== candidates.length) return "candidates must not repeat";
  return { blocks, candidates };
}

function characters(text: string): number {
  let count = 0;
  for (const _ of graphemes.segment(text)) count += 1;
  return count;
}

function blockTokens(text: string): number {
  let ascii = 0;
  let wide = 0;
  for (const character of text) {
    if (character.charCodeAt(0) < 128) ascii += 1;
    else wide += 1;
  }
  return Math.ceil(ascii / 4 + wide * 1.1) + 400;
}

export function estimateTokens(classification: Classification): number {
  return classification.candidates.reduce((total, index) => total + blockTokens(classification.blocks[index]), 0);
}

export class ClefError extends Error {
  constructor(message: string, readonly tokens: number) {
    super(message);
  }
}

export function clefRequest(text: string): object {
  return {
    model: "clef",
    state: { text },
    questions: {
      role: {
        type: "choice",
        instructions: "What role does `text` play on this article page?",
        criteria: {
          content: "Article prose, a quote, or a list item that is part of the article's content.",
          lead_in: "A short line that introduces what follows, such as a quote, a list, or an excerpt, often ending with a colon.",
          heading: "A heading or subheading within the article body, including a product or section name.",
          caption: "A caption describing an image or video in the article.",
          credit: "A photo, image, or video credit naming a photographer, agency, or company.",
          promo: "A promotion, sponsorship, newsletter, subscription, app, follow, or share prompt.",
          navigation: "Links to related or other articles, tags, site navigation, or a comments prompt.",
          meta: "A byline, dateline, label such as PRESS RELEASE or UPDATE, a media download section, or a repeat of the whole article.",
        },
      },
    },
  };
}

async function askAbout(text: string, ai: Ai): Promise<{ probability: number; tokens: number }> {
  const body = (await ai.run(CLEF_MODEL, clefRequest(text) as Record<string, unknown>, { signal: AbortSignal.timeout(CLEF_TIMEOUT_MS) })) as {
    answers?: { role?: { probabilities?: { [role: string]: unknown } } };
    usage?: { input_tokens?: unknown; output_tokens?: unknown };
  };
  const roles = body.answers?.role?.probabilities;
  if (!roles || !CONTENT_ROLES.every((role) => typeof roles[role] === "number")) throw new Error("clef left a block unanswered");
  const probability = Math.min(1, Math.round(CONTENT_ROLES.reduce((total, role) => total + (roles[role] as number), 0) * 10_000) / 10_000);
  const input = body.usage?.input_tokens;
  const output = body.usage?.output_tokens;
  const tokens = typeof input === "number" ? input + (typeof output === "number" ? output : 0) : blockTokens(text);
  return { probability, tokens };
}

export async function askClef(classification: Classification, ai: Ai): Promise<Verdict> {
  const texts = classification.candidates.map((index) => classification.blocks[index]);
  const probabilities: number[] = [];
  let tokens = 0;
  let next = 0;
  let failure: Error | undefined;
  await Promise.all(Array.from({ length: Math.min(CLEF_CONCURRENCY, texts.length) }, async () => {
    while (!failure && next < texts.length) {
      const position = next++;
      try {
        const answer = await askAbout(texts[position], ai);
        probabilities[position] = answer.probability;
        tokens += answer.tokens;
      } catch (error) {
        failure ??= error as Error;
      }
    }
  }));
  if (failure) throw new ClefError(failure.message, tokens);
  return { probabilities, tokens };
}

export const JEV_URL = "https://api.typesafe.ai/v1/systemone";
export const JEV_MODEL = "jev-latest";
const JEV_TIMEOUT_MS = 15_000;
const JEV_CONCURRENCY = 6;

const MOST_BLOCKS = 400;
const LONGEST_BLOCK = 4000;
const MOST_CHARACTERS = 60_000;
const MOST_CANDIDATES = 120;
const LONGEST_TITLE = 500;
const LONGEST_SITE = 253;

export interface Classification {
  title: string;
  site: string;
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
  if (title !== undefined && (typeof title !== "string" || title.length > LONGEST_TITLE)) return `title must be under ${LONGEST_TITLE} characters`;
  if (site !== undefined && (typeof site !== "string" || site.length > LONGEST_SITE)) return "site must be a host name";
  if (!Array.isArray(blocks) || blocks.length === 0 || blocks.length > MOST_BLOCKS) return `blocks must hold 1 to ${MOST_BLOCKS} entries`;
  if (!blocks.every((block) => typeof block === "string" && block.length <= LONGEST_BLOCK)) return `each block must be a string under ${LONGEST_BLOCK} characters`;
  if (blocks.reduce((total, block) => total + block.length, 0) > MOST_CHARACTERS) return `blocks must total under ${MOST_CHARACTERS} characters`;
  if (!Array.isArray(candidates) || candidates.length === 0 || candidates.length > MOST_CANDIDATES) return `candidates must hold 1 to ${MOST_CANDIDATES} entries`;
  if (!candidates.every((index) => Number.isSafeInteger(index) && index >= 0 && index < blocks.length)) return "candidates must be indexes into blocks";
  if (new Set(candidates).size !== candidates.length) return "candidates must not repeat";
  return { title: (title as string | undefined) ?? "", site: (site as string | undefined) ?? "", blocks, candidates };
}

export function estimateTokens(classification: Classification): number {
  let ascii = 0;
  let wide = 0;
  for (const index of classification.candidates) {
    for (const character of classification.blocks[index]) {
      if (character.charCodeAt(0) < 128) ascii += 1;
      else wide += 1;
    }
  }
  return Math.ceil(ascii / 4) + wide + classification.candidates.length * 150;
}

export class JevError extends Error {
  constructor(message: string, readonly tokens: number) {
    super(message);
  }
}

export function jevRequest(text: string): object {
  return {
    model: JEV_MODEL,
    state: { text },
    questions: {
      meaningfulness_check: {
        type: "noul",
        instructions: "Is this a meaningful part of an article?",
        criteria: {
          true: "The text, Markdown, or HTML reflect a meaningful part of an article that is part of the article's content.",
          false: "The text, Markdown, or HTML do not contribute to the article contents, and/or are noise that is part of the article's UI.",
        },
      },
    },
  };
}

async function askAbout(text: string, apiKey: string): Promise<{ probability: number; tokens: number }> {
  const response = await fetch(JEV_URL, {
    method: "POST",
    headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
    body: JSON.stringify(jevRequest(text)),
    signal: AbortSignal.timeout(JEV_TIMEOUT_MS),
  });
  if (!response.ok) throw new Error(`jev returned ${response.status}`);
  const body = (await response.json()) as {
    answers?: { meaningfulness_check?: { noul?: unknown } };
    usage?: { input_tokens?: unknown; output_tokens?: unknown };
  };
  const probability = body.answers?.meaningfulness_check?.noul;
  if (typeof probability !== "number" || probability < 0 || probability > 1) throw new Error("jev left a block unanswered");
  const input = body.usage?.input_tokens;
  const output = body.usage?.output_tokens;
  const tokens = typeof input === "number" ? input + (typeof output === "number" ? output : 0) : Math.ceil(text.length / 4) + 150;
  return { probability, tokens };
}

export async function askJev(classification: Classification, apiKey: string): Promise<Verdict> {
  const texts = classification.candidates.map((index) => classification.blocks[index]);
  const probabilities: number[] = [];
  let tokens = 0;
  let next = 0;
  let failure: Error | undefined;
  await Promise.all(Array.from({ length: Math.min(JEV_CONCURRENCY, texts.length) }, async () => {
    while (!failure && next < texts.length) {
      const position = next++;
      try {
        const answer = await askAbout(texts[position], apiKey);
        probabilities[position] = answer.probability;
        tokens += answer.tokens;
      } catch (error) {
        failure ??= error as Error;
      }
    }
  }));
  if (failure) throw new JevError(failure.message, tokens);
  return { probabilities, tokens };
}

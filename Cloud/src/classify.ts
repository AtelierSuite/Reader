export const JEV_URL = "https://api.typesafe.ai/v1/systemone";
export const JEV_MODEL = "jev-latest";
const JEV_TIMEOUT_MS = 15_000;

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
  for (const block of [classification.title, ...classification.blocks]) {
    for (const character of block) {
      if (character.charCodeAt(0) < 128) ascii += 1;
      else wide += 1;
    }
  }
  return Math.ceil(ascii / 4) + wide + classification.candidates.length * 60 + 200;
}

function blockKey(index: number): string {
  return `b${index + 1}`;
}

export function jevRequest(classification: Classification): object {
  return {
    model: JEV_MODEL,
    state: {
      title: classification.title,
      site: classification.site,
      blocks: Object.fromEntries(classification.blocks.map((block, index) => [blockKey(index), block])),
    },
    questions: Object.fromEntries(classification.candidates.map((index) => [blockKey(index), {
      type: "noul",
      instructions: `Is \`blocks.${blockKey(index)}\` part of the main content of the article titled \`title\`?`,
      criteria: {
        true: "Body text, a heading, a quote, a list item, or a caption that belongs to the article itself",
        false: "Navigation, an advertisement, a promotion, a newsletter or subscription prompt, related or recommended links, a share or comment prompt, an author bio, a copyright or legal notice, or other site boilerplate",
      },
    }])),
  };
}

export async function askJev(classification: Classification, apiKey: string): Promise<Verdict> {
  const response = await fetch(JEV_URL, {
    method: "POST",
    headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
    body: JSON.stringify(jevRequest(classification)),
    signal: AbortSignal.timeout(JEV_TIMEOUT_MS),
  });
  if (!response.ok) throw new Error(`jev returned ${response.status}`);
  const body = (await response.json()) as {
    answers?: { [key: string]: { noul?: unknown } };
    usage?: { input_tokens?: unknown; output_tokens?: unknown };
  };
  const probabilities = classification.candidates.map((index) => {
    const value = body.answers?.[blockKey(index)]?.noul;
    if (typeof value !== "number" || value < 0 || value > 1) throw new Error("jev left a block unanswered");
    return value;
  });
  const input = body.usage?.input_tokens;
  const output = body.usage?.output_tokens;
  const tokens = typeof input === "number" ? input + (typeof output === "number" ? output : 0) : estimateTokens(classification);
  return { probabilities, tokens };
}

import type { Device } from "./device";

export interface Env {
  DEVICE: DurableObjectNamespace<Device>;
  APPLE_TEAM_ID: string;
  APP_BUNDLE_ID: string;
  APP_ATTEST_ENVIRONMENT: string;
  TOKENS_PER_MINUTE: string;
  CHALLENGE_SECRET?: string;
  JEV_API_KEY?: string;
  SKIP_APP_ATTEST?: string;
}

export function appId(env: Env): string | null {
  if (!env.APPLE_TEAM_ID || !env.APP_BUNDLE_ID) return null;
  return `${env.APPLE_TEAM_ID}.${env.APP_BUNDLE_ID}`;
}

export function limit(value: string): number | null {
  const parsed = Number(value);
  return value !== "" && Number.isSafeInteger(parsed) && parsed >= 0 ? parsed : null;
}

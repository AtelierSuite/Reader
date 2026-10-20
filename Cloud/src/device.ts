import { DurableObject } from "cloudflare:workers";
import { verifyAssertion } from "./attest";
import type { Env } from "./env";

export const WINDOW_MS = 60_000;

interface Spend {
  id: string;
  at: number;
  tokens: number;
}

export interface Reservation {
  allowed: boolean;
  id?: string;
  limit: number;
  remaining: number;
  retryAfter?: number;
}

export interface Allowance {
  limit: number;
  used: number;
  remaining: number;
}

export class Device extends DurableObject<Env> {
  private createLimits(): void {
    this.ctx.storage.sql.exec("CREATE TABLE IF NOT EXISTS limits (kind TEXT PRIMARY KEY, per_minute INTEGER)");
  }

  private limit(fallback: number): number {
    this.createLimits();
    const perMinute = this.ctx.storage.sql.exec("SELECT per_minute FROM limits WHERE kind = 'tokens'").toArray()[0]?.per_minute;
    return Number.isSafeInteger(perMinute) && (perMinute as number) >= 0 ? (perMinute as number) : fallback;
  }

  async register(point: Uint8Array): Promise<boolean> {
    if (await this.ctx.storage.get("point")) return false;
    await this.ctx.storage.put({ point, counter: 0 });
    this.createLimits();
    return true;
  }

  async authenticate(assertion: Uint8Array, clientData: Uint8Array, appId: string): Promise<boolean> {
    let passed = false;
    await this.ctx.blockConcurrencyWhile(async () => {
      const point = await this.ctx.storage.get<Uint8Array>("point");
      if (!point) return;
      const last = (await this.ctx.storage.get<number>("counter")) ?? 0;
      try {
        const counter = await verifyAssertion(assertion, clientData, point, appId, last);
        await this.ctx.storage.put("counter", counter);
        passed = true;
      } catch {
        passed = false;
      }
    });
    return passed;
  }

  private async spends(now: number): Promise<Spend[]> {
    const stored = (await this.ctx.storage.get<Spend[]>("spends")) ?? [];
    return stored.filter((spend) => spend.at > now - WINDOW_MS);
  }

  async reserve(tokens: number, fallback: number, now = Date.now()): Promise<Reservation> {
    const limit = this.limit(fallback);
    const spends = await this.spends(now);
    const used = spends.reduce((total, spend) => total + spend.tokens, 0);
    if (tokens > limit) return { allowed: false, limit, remaining: Math.max(0, limit - used) };
    if (used + tokens > limit) {
      let freed = 0;
      let retryAfter = 1;
      for (const spend of [...spends].sort((first, second) => first.at - second.at)) {
        freed += spend.tokens;
        if (used - freed + tokens <= limit) {
          retryAfter = Math.max(1, Math.ceil((spend.at + WINDOW_MS - now) / 1000));
          break;
        }
      }
      return { allowed: false, limit, remaining: Math.max(0, limit - used), retryAfter };
    }
    const id = crypto.randomUUID();
    await this.ctx.storage.put("spends", [...spends, { id, at: now, tokens }]);
    return { allowed: true, id, limit, remaining: limit - used - tokens };
  }

  async settle(id: string, tokens: number, fallback: number, now = Date.now()): Promise<number> {
    const spends = (await this.spends(now)).map((spend) => (spend.id === id ? { ...spend, tokens } : spend));
    await this.ctx.storage.put("spends", spends);
    const used = spends.reduce((total, spend) => total + spend.tokens, 0);
    return Math.max(0, this.limit(fallback) - used);
  }

  async release(id: string, now = Date.now()): Promise<void> {
    await this.ctx.storage.put("spends", (await this.spends(now)).filter((spend) => spend.id !== id));
  }

  async allowance(fallback: number, now = Date.now()): Promise<Allowance> {
    const limit = this.limit(fallback);
    const used = (await this.spends(now)).reduce((total, spend) => total + spend.tokens, 0);
    return { limit, used, remaining: Math.max(0, limit - used) };
  }
}

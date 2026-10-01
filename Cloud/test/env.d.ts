declare namespace Cloudflare {
  interface Env extends Omit<import("../src/env").Env, never> {}
}

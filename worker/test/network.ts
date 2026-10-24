import { setupNetwork } from "@msw/cloudflare";

export const network = setupNetwork();

// Any request without a handler fails, so no test can reach the real network.
network.configure({ onUnhandledFrame: "error" });

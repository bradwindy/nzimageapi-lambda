// Ports AuthorizedConsumerTests.

import { describe, expect, it } from "vitest";
import { authorizedConsumer } from "../src/api.ts";

const allowed = "site:AbC123,mobile:XyZ789";

describe("authorizedConsumer", () => {
	it("returns the consumer name for a matching secret", async () => {
		expect(await authorizedConsumer("AbC123", allowed)).toBe("site");
		expect(await authorizedConsumer("XyZ789", allowed)).toBe("mobile");
	});

	it("returns null for a non-matching secret", async () => {
		expect(await authorizedConsumer("wrong-secret", allowed)).toBeNull();
		expect(await authorizedConsumer("", allowed)).toBeNull();
	});

	it("returns null for an empty allowed list", async () => {
		expect(await authorizedConsumer("AbC123", "")).toBeNull();
	});

	it("skips a malformed entry without a colon", async () => {
		expect(await authorizedConsumer("malformed", "malformed,site:AbC123")).toBeNull();
		expect(await authorizedConsumer("AbC123", "malformed,site:AbC123")).toBe("site");
	});

	it("keeps everything after the first colon as the secret", async () => {
		expect(await authorizedConsumer("AbC:123", "site:AbC:123")).toBe("site");
	});

	it("matches a single-pair list", async () => {
		expect(await authorizedConsumer("solo-secret", "only:solo-secret")).toBe("only");
	});

	// Both sides are hashed to 32 bytes before the constant-time compare, so unequal lengths
	// must still resolve correctly (crypto.subtle.timingSafeEqual throws on unequal lengths).

	it("returns null when the presented value is shorter than the secret", async () => {
		expect(await authorizedConsumer("AbC12", allowed)).toBeNull();
	});

	it("returns null when the presented value is longer than the secret", async () => {
		expect(await authorizedConsumer("AbC1234", allowed)).toBeNull();
	});

	it("returns null when the secret is a prefix of the presented value", async () => {
		expect(await authorizedConsumer("AbC123XYZ", allowed)).toBeNull();
	});

	it("still resolves an exact match after the hash compare", async () => {
		expect(await authorizedConsumer("AbC123", allowed)).toBe("site");
	});
});

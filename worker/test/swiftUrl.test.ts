// Ports the slice(from:to:) half of StringExtensionsTests. The URL expectations were produced by
// running the same inputs through Foundation's URL on macOS.

import { describe, expect, it } from "vitest";
import {
	lastPathComponent,
	lastPathComponentWithoutExtension,
	pathComponents,
	pathExtension,
	slice,
	swiftURLString,
	urlHost,
} from "../src/swiftUrl.ts";

describe("swiftURLString", () => {
	it("matches URL(string:)?.absoluteString", () => {
		expect(swiftURLString("https://x.com/a b/Māori.jpg")).toBe("https://x.com/a%20b/M%C4%81ori.jpg");
		expect(swiftURLString("https://x.com/a%zz")).toBe("https://x.com/a%25zz");
		expect(swiftURLString("https://x.com/a%41")).toBe("https://x.com/a%41");
		expect(swiftURLString("https://x.com/a|b^c{d}")).toBe("https://x.com/a%7Cb%5Ec%7Bd%7D");
		expect(swiftURLString("https://x.com/[x]")).toBe("https://x.com/%5Bx%5D");
		expect(swiftURLString("foo")).toBe("foo");
		expect(swiftURLString("")).toBeNull();
	});
});

describe("URL components", () => {
	const url = "https://user@Host.example.com:8080/node/1%20a/images/My%20File.JPG?x=1";

	it("match Foundation's URL accessors", () => {
		expect(urlHost(url)).toBe("Host.example.com");
		expect(pathComponents(url)).toEqual(["node", "1 a", "images", "My File.JPG"]);
		expect(lastPathComponent(url)).toBe("My File.JPG");
		expect(pathExtension(url)).toBe("JPG");
		expect(lastPathComponentWithoutExtension(url)).toBe("My File");
		expect(lastPathComponent("https://x.com/")).toBe("/");
		expect(pathExtension("https://x.com/.hidden")).toBe("");
		expect(pathComponents("https://x.com/a//b/")).toEqual(["a", "b"]);
	});
});

describe("slice", () => {
	it("finds the substring between markers", () => {
		expect(slice("display/12345-600", "display/", "-600")).toBe("12345");
		expect(slice("prefix[BODY]suffix", "[", "]")).toBe("BODY");
	});

	it("returns undefined when the from marker is absent", () => {
		expect(slice("display/12345-600", "nope/", "-600")).toBeUndefined();
	});

	it("returns undefined when the to marker is absent", () => {
		expect(slice("display/12345-600", "display/", "-nope")).toBeUndefined();
	});

	it("only searches for the to marker after the from marker", () => {
		expect(slice("-600display/12345", "display/", "-600")).toBeUndefined();
	});

	it("returns an empty string for adjacent markers", () => {
		expect(slice("display/-600", "display/", "-600")).toBe("");
	});

	it("uses the first occurrence when markers repeat", () => {
		expect(slice("display/A-600display/B-600", "display/", "-600")).toBe("A");
	});
});

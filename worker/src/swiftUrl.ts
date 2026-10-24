// String and URL helpers that reproduce the Foundation behaviour the Swift Lambda relied on.
// URLs are kept as plain strings throughout (Swift's `URL.absoluteString` returns the input
// string), so WHATWG `new URL()` normalisation never changes what the API returns.

const URL_PATTERN = /^(?:([^:/?#]+):)?(?:\/\/([^/?#]*))?([^?#]*)/;
const SCHEME_AND_AUTHORITY = /^(?:[^:/?#]+:)?(?:\/\/[^/?#]*)?/;

const URL_ALLOWED = /^[A-Za-z0-9\-._~:/?#@!$&'()*+,;=]$/;
const HEX_PAIR = /^[0-9A-Fa-f]{2}$/;
const ASCII_ALPHANUMERIC = /^[A-Za-z0-9]$/;

const encoder = new TextEncoder();

function percentEncodeCharacter(character: string): string {
	let out = "";
	for (const byte of encoder.encode(character)) {
		out += `%${byte.toString(16).toUpperCase().padStart(2, "0")}`;
	}
	return out;
}

/**
 * `String.addingPercentEncoding(withAllowedCharacters:)`: UTF-8 bytes as uppercase `%XX`.
 * Foundation encodes every non-ASCII character whatever the set, so `isAllowed` only ever
 * sees ASCII.
 */
export function percentEncode(value: string, isAllowed: (character: string) => boolean): string {
	let out = "";
	for (const character of value) {
		out += character.charCodeAt(0) < 0x80 && isAllowed(character) ? character : percentEncodeCharacter(character);
	}
	return out;
}

/** `CharacterSet.alphanumerics`, as `addingPercentEncoding` applies it (ASCII only). */
export function isAlphanumeric(character: string): boolean {
	return ASCII_ALPHANUMERIC.test(character);
}

/** `CharacterSet.urlHostAllowed`. */
export function isURLHostAllowed(character: string): boolean {
	return ASCII_ALPHANUMERIC.test(character) || "!$&'()*+,-.:;=[]_~".includes(character);
}

/**
 * `URL(string:)?.absoluteString`. Foundation returns nil for an empty string and percent-encodes
 * characters that cannot appear in a URL (spaces, non-ASCII, `|`, a stray `%`, brackets outside
 * the host); every valid URL string comes back unchanged.
 */
export function swiftURLString(value: string): string | null {
	if (value.length === 0) return null;
	const prefixLength = SCHEME_AND_AUTHORITY.exec(value)?.[0].length ?? 0;
	let out = "";
	let index = 0;
	for (const character of value) {
		if (character === "%") {
			out += HEX_PAIR.test(value.slice(index + 1, index + 3)) ? "%" : "%25";
		} else if (URL_ALLOWED.test(character) || (index < prefixLength && (character === "[" || character === "]"))) {
			out += character;
		} else {
			out += percentEncodeCharacter(character);
		}
		index += character.length;
	}
	return out;
}

function decodeComponent(component: string): string {
	try {
		return decodeURIComponent(component);
	} catch {
		return component;
	}
}

/** `URL.scheme`. */
export function urlScheme(url: string): string | undefined {
	return URL_PATTERN.exec(url)?.[1];
}

/** `URL.host`: the authority without userinfo or port, percent-decoded. Empty counts as absent. */
export function urlHost(url: string): string | undefined {
	const authority = URL_PATTERN.exec(url)?.[2];
	if (authority === undefined) return undefined;
	const hostAndPort = authority.slice(authority.lastIndexOf("@") + 1);
	const host = hostAndPort.startsWith("[")
		? hostAndPort.slice(1, hostAndPort.indexOf("]"))
		: hostAndPort.replace(/:\d*$/, "");
	return host.length > 0 ? decodeComponent(host) : undefined;
}

function path(url: string): string {
	return URL_PATTERN.exec(url)?.[3] ?? "";
}

/** `URL.pathComponents` without the leading `"/"`, percent-decoded. */
export function pathComponents(url: string): string[] {
	return path(url)
		.split("/")
		.filter((component) => component.length > 0)
		.map(decodeComponent);
}

/** `URL.lastPathComponent`, percent-decoded: `"/"` for a root path, `""` for no path. */
export function lastPathComponent(url: string): string {
	return pathComponents(url).at(-1) ?? (path(url).length > 0 ? "/" : "");
}

/** `URL.pathExtension` of the last path component. */
export function pathExtension(url: string): string {
	const component = lastPathComponent(url);
	const dot = component.lastIndexOf(".");
	return dot <= 0 || dot === component.length - 1 ? "" : component.slice(dot + 1);
}

/** `URL.deletingPathExtension().lastPathComponent`. */
export function lastPathComponentWithoutExtension(url: string): string {
	const component = lastPathComponent(url);
	const extension = pathExtension(url);
	return extension.length > 0 ? component.slice(0, -(extension.length + 1)) : component;
}

/** `String.slice(from:to:)`: the text between the first `from` and the next `to` after it. */
export function slice(value: string, from: string, to: string): string | undefined {
	const start = value.indexOf(from);
	if (start < 0) return undefined;
	const contentStart = start + from.length;
	const end = value.indexOf(to, contentStart);
	return end < 0 ? undefined : value.slice(contentStart, end);
}

/** Swift `String.split(separator:)`, which drops empty pieces. */
export function splitNonEmpty(value: string, separator: string): string[] {
	return value.split(separator).filter((piece) => piece.length > 0);
}

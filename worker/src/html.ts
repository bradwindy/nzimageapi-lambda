// A regex stand-in for the one SwiftSoup query the Lambda made:
// `document.select("meta").first { $0.attr("property") == "og:image" }?.attr("content")`.
// A DOM parser would not fit the Free plan's 10 ms CPU budget on large landing pages.

// An unclosed comment, script or style runs to the end of the page (as in a browser), so one
// pass is linear even on malformed pages instead of rescanning the rest per opener.
const IGNORED_CONTENT = /<!--[\s\S]*?(?:-->|$)|<script\b[\s\S]*?(?:<\/script\s*>|$)|<style\b[\s\S]*?(?:<\/style\s*>|$)/gi;
const META_TAG = /<meta\b((?:[^>"']|"[^"]*"|'[^']*')*)>/gi;
const ATTRIBUTE = /([^\s"'>/=]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+)))?/g;

const NAMED_ENTITIES: Record<string, string> = {
	amp: "&",
	lt: "<",
	gt: ">",
	quot: '"',
	apos: "'",
	nbsp: " ",
};

export function decodeEntities(value: string): string {
	return value.replace(/&(#[0-9]+|#x[0-9a-f]+|[a-z]+);/gi, (entity, name: string) => {
		if (name.startsWith("#")) {
			const codePoint = name[1] === "x" || name[1] === "X" ? parseInt(name.slice(2), 16) : parseInt(name.slice(1), 10);
			return codePoint > 0 && codePoint <= 0x10ffff ? String.fromCodePoint(codePoint) : entity;
		}
		return NAMED_ENTITIES[name.toLowerCase()] ?? entity;
	});
}

function attributes(source: string): Map<string, string> {
	const result = new Map<string, string>();
	for (const match of source.matchAll(ATTRIBUTE)) {
		const name = match[1]!.toLowerCase();
		if (!result.has(name)) result.set(name, decodeEntities(match[2] ?? match[3] ?? match[4] ?? ""));
	}
	return result;
}

/**
 * The `content` of the first `<meta property="og:image">`, `""` when that tag has no content
 * (SwiftSoup's `attr` returns `""` for a missing attribute), or undefined when there is no such tag.
 */
export function ogImageContent(html: string): string | undefined {
	const markup = html.replace(IGNORED_CONTENT, "");
	for (const tag of markup.matchAll(META_TAG)) {
		const tagAttributes = attributes(tag[1]!);
		if (tagAttributes.get("property") === "og:image") return tagAttributes.get("content") ?? "";
	}
	return undefined;
}

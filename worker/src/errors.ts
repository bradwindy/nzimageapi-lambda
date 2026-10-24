/** The Swift `RichError`s: a `kind` plus a little context for the log line. */
export class ApiError extends Error {
	readonly kind: string;
	readonly data: Record<string, string>;

	constructor(kind: string, data: Record<string, string> = {}) {
		super(kind);
		this.name = "ApiError";
		this.kind = kind;
		this.data = data;
	}
}

/** `exclude` removed every collection, so there is nothing left to pick from. */
export class NoEligibleCollectionsError extends Error {
	constructor() {
		super("No eligible collections");
		this.name = "NoEligibleCollectionsError";
	}
}

/** A JSON body that Swift's `JSONDecoder` would have rejected. */
export class DecodingError extends Error {
	constructor(message: string) {
		super(message);
		this.name = "DecodingError";
	}
}

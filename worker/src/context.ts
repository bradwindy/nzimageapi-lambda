import { Http } from "./http.ts";

/** The bindings the API reads. Secrets may be unset in local dev, so all are optional here. */
export interface ApiEnv {
	DIGITALNZ_API_KEY?: string;
	API_CLIENT_SECRETS?: string;
	JP2_CONVERTER_URL?: string;
	CONVERTER_SIGNING_KEY?: string;
}

export type Logger = (message: string) => void;

/** Per-invocation state: one `Http` (and so one subrequest budget) per API request. */
export interface RequestContext {
	http: Http;
	env: ApiEnv;
	log: Logger;
}

export function createContext(env: ApiEnv, log: Logger = console.log): RequestContext {
	return { http: new Http(), env, log };
}

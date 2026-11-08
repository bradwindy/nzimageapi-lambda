const LOCAL_HOSTNAMES = new Set(['localhost', '127.0.0.1', '[::1]']);

/**
 * True for a request this app's own page made to its own local server. The Host check stops DNS
 * rebinding (the browser then calls it same-origin), and Sec-Fetch-Site / Origin stop other
 * pages the developer has open from reaching the API routes, which write files in the repo.
 */
export function isLocalSameOriginRequest(headers: Headers): boolean {
  const host = headers.get('host')?.toLowerCase();
  if (!host || !LOCAL_HOSTNAMES.has(host.replace(/:\d+$/, ''))) return false;

  const site = headers.get('sec-fetch-site');
  if (site !== null && site !== 'same-origin' && site !== 'none') return false;

  const origin = headers.get('origin');
  if (origin === null) return true;
  try {
    return new URL(origin).host === host;
  } catch {
    return false;
  }
}

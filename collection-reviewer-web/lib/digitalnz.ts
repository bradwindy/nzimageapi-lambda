export interface FacetEntry {
  name: string;
  count: number;
}

// Faithful port of CollectionLister/main.swift facets query.
// Returns all primary_collection facets for Images category (up to 350).
export async function fetchCollectionFacets(): Promise<FacetEntry[]> {
  const apiKey = process.env.DIGITALNZ_API_KEY;
  if (!apiKey) {
    throw new Error('DIGITALNZ_API_KEY environment variable is not set');
  }

  const params = new URLSearchParams({
    per_page: '0',
    'and[category][]': 'Images',
    facets: 'primary_collection',
    facets_per_page: '350',
  });

  const res = await fetch(
    `https://api.digitalnz.org/records.json?${params.toString()}`,
    {
      headers: { 'Authentication-Token': apiKey },
      cache: 'no-store',
    }
  );

  if (!res.ok) {
    throw new Error(`DigitalNZ API returned HTTP ${res.status}`);
  }

  const json = await res.json();

  if (Array.isArray(json.errors) && json.errors.length > 0) {
    throw new Error(`DigitalNZ API errors: ${(json.errors as string[]).join(', ')}`);
  }

  const facetDict = json?.search?.facets?.primary_collection as
    | Record<string, number>
    | undefined;

  if (!facetDict) {
    throw new Error('No facet data returned from DigitalNZ API');
  }

  return Object.entries(facetDict).map(([name, count]) => ({ name, count }));
}

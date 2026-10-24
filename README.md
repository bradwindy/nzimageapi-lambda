# NZ Image API

Returns random images from New Zealand archives, libraries and cultural institutions, through
the [DigitalNZ API](https://digitalnz.org/). It is a pure URL builder: each response points at
the highest-resolution copy of the image it can find.

It powers the slideshow at [nzimages.iolab.nz](https://nzimages.iolab.nz)
([nzimage-web](https://github.com/bradwindy/nzimage-web)).

## How it runs

| Part | Where | Code |
| --- | --- | --- |
| API | Cloudflare Worker `nzimages-api` on the Workers Free plan, `https://nzimages-api.iolab.nz` | [`worker/`](worker/) |
| JP2/TIFF converter | AWS Lambda (Python + Pillow) behind a signed Function URL | [`converter/`](converter/) |
| Converter kill switch | AWS Lambda that keeps the converter inside the free tier | [`guard/`](guard/) |
| Website | Cloudflare Worker `nzimages-web`, calls the API over a service binding | [nzimage-web](https://github.com/bradwindy/nzimage-web) |

Everything is meant to cost $0. The Workers Free plan returns errors instead of billing when a
limit is hit, and the converter's kill switch stops it before Lambda's always-free allowance
runs out. See [`docs/ACCESS-CONTROL.md`](docs/ACCESS-CONTROL.md) for the cost controls.

## API reference

Every request needs a consumer secret in the `secret` header (see [Access control](#access-control)).

### `GET /image`

A random image from a collection picked at random, weighted by how many images each collection
has.

```bash
curl -H "secret: YOUR_CONSUMER_SECRET" "https://nzimages-api.iolab.nz/image"
```

```json
{
  "id": 12345678,
  "title": "Historic photograph",
  "description": "Description of the image...",
  "display_collection": "Te Papa Collections Online",
  "thumbnail_url": "https://...",
  "large_thumbnail_url": "https://...",
  "landing_url": "https://..."
}
```

`large_thumbnail_url` is the image to show. For collections whose originals are JPEG 2000 or
TIFF (TAPUHI, War Art Online, Feilding Library, Manawatū Heritage) it is a signed converter URL
that returns a JPEG up to 4000 px. The first load of one can take several seconds.

Query parameters:

- `collection=<name>` picks that collection (URL-encoded name).
- `exclude=<name>,<name>` leaves those collections out of the random pick. Ignored when
  `collection` is set. Names containing a comma can't be excluded this way.

A `400` means no image could be found for the pick. Try again.

### `GET /collections`

The names of every collection the API picks from.

```bash
curl -H "secret: YOUR_CONSUMER_SECRET" "https://nzimages-api.iolab.nz/collections"
```

## Access control

There is no public path: each approved consumer gets its own secret, which can be revoked on its
own. A browser page or app binary can't keep a secret, so a consumer needs a small backend of its
own that holds it. The website doesn't use a secret at all: it is a Worker on the same Cloudflare
account and calls the API's `ImageApi` RPC entrypoint directly.

[`docs/ACCESS-CONTROL.md`](docs/ACCESS-CONTROL.md) covers the threat model, onboarding and
revoking consumers, the cost controls and the runbook.
[`docs/adr/0001-free-per-consumer-secrets.md`](docs/adr/0001-free-per-consumer-secrets.md)
records why static secrets were chosen over Amazon Cognito.

## Development

The API Worker:

```bash
cd worker
npm ci
cp .dev.vars.example .dev.vars   # DIGITALNZ_API_KEY, API_CLIENT_SECRETS, CONVERTER_SIGNING_KEY
npm run dev                      # http://127.0.0.1:8787
npm test
```

[`worker/README.md`](worker/README.md) has the details, including the two maintenance scripts:

- `npm run check-collections` requests an image from every collection, checks each image URL
  loads, and can compare against another deployment.
- `npm run count-collections` fetches live image counts for the weighting table.

The converter and kill switch:

```bash
cd converter && pip install -r requirements-dev.txt && pytest
cd guard && pip install -r requirements-dev.txt && pytest
```

The collection reviewer (`collection-reviewer-web/`) is a local Next.js tool for triaging
collections. `npm run dev` there starts the API Worker too, using `DIGITALNZ_API_KEY` from the
repo-root `.env` (see `.env.example`).

## Deployment

- **API Worker**: Workers Builds deploys `worker/` on every push to `main`. By hand:
  `cd worker && npx wrangler deploy`. Secrets are set with `npx wrangler secret put <NAME>`.
- **Converter stack**: GitHub Actions runs `sam build` and `sam deploy` on every push to `main`
  (`.github/workflows/ci-cd.yml`). [`.claude/rules/build-test-deploy.md`](.claude/rules/build-test-deploy.md)
  covers the parameters, the artefact bucket and deploying by hand.

## Collections

Images come from about 48 collections, weighted by size. Auckland Museum, Te Papa, Kura
Heritage, Canterbury Museum and TAPUHI are the largest. The full table is in
[`worker/src/collections.ts`](worker/src/collections.ts), and
[`Research/highres/`](Research/highres/) records how each collection's highest-resolution image
is found.

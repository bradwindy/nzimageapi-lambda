"""Master -> JPEG converter Lambda (behind a Function URL).

The NZ Image API Swift Lambda stays a pure URL builder. Some collections expose a
high-resolution preservation master that the browser can't display directly:

  - TAPUHI / NDHA: a JPEG 2000 (.jp2) FL stream
    (`...DeliveryManagerServlet?dps_pid=FL<n>&dps_func=stream`). JP2 is undecodable by
    ~98% of browsers and by every free keyless image proxy (weserv/cloudimg/etc.).
  - Feilding Library (Recollect): the original is a multi-megapixel TIFF reached via
    `feildingheritage.nz/item/<uuid>/files/<fileId>/download?variant=original`, which
    302-redirects to a short-lived presigned S3 URL. TIFF is also not browser-displayable
    and the files (~75 MB / ~25 MP) are too large for weserv (it 504s on them).

This function downloads that master (following redirects), decodes it with Pillow
(OpenJPEG for JP2, libtiff for TIFF), downscales to stay under the Function URL 6 MB
response cap, and returns a browser-displayable JPEG (base64, image/jpeg).

It is a generic master->JPEG proxy, host-allowlisted to a fixed set of trusted origins so
it can never be used as an open proxy / SSRF pivot. (A redirect issued by an allowlisted
origin — e.g. Feilding -> its own presigned S3 store — is followed transparently by
urlopen; only the entry host is checked, which is sufficient because the entry host is
trusted to choose its own asset store.)
"""

import base64
import hashlib
import hmac
import os
import time
from io import BytesIO
from urllib.parse import urlparse
from urllib.request import Request, urlopen

# --- configuration (env-overridable; defaults match the SAM template) ---------------
# Comma-separated allowlist; ALLOWED_HOST (singular) is still honoured for backward compat.
_HOSTS_RAW = os.environ.get("ALLOWED_HOSTS") or os.environ.get("ALLOWED_HOST", "ndhadeliver.natlib.govt.nz")
ALLOWED_HOSTS = frozenset(h.strip() for h in _HOSTS_RAW.split(",") if h.strip())
MAX_DIM = int(os.environ.get("MAX_DIM", "4000"))
# HMAC key shared with the Swift Lambda, which signs every converter URL it emits — required so
# this public, unauthenticated Function URL only accepts requests minted by our own Swift Lambda.
SIGNING_KEY = os.environ.get("CONVERTER_SIGNING_KEY", "")
# Finite decompression-bomb ceiling. The host allowlist alone doesn't bound decoded pixel count;
# this is high enough not to reject legitimate preservation masters (multi-hundred-MP TIFFs/JP2s
# are expected here) while still stopping a pathological multi-gigapixel bomb.
MAX_IMAGE_PIXELS = 500_000_000

# Browser UA: the NDHA FL `dps_func=stream` endpoint is stateless (no cookies needed); the
# Feilding download endpoint also serves anonymously for public-rights records.
USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
# Large masters (≈60 MB JP2, ≈75 MB TIFF) need headroom to download; stays well under the
# 60 s Lambda timeout once the (fast, same-region) S3/NDHA fetch completes.
DOWNLOAD_TIMEOUT = int(os.environ.get("DOWNLOAD_TIMEOUT", "35"))  # seconds
MAX_DOWNLOAD_BYTES = 110 * 1024 * 1024  # guard on the source download (masters ~60–80 MB)

# Keep the *base64* response body under the Function URL 6 MB cap. base64 inflates by
# ~4/3, so a ~4.0 MB JPEG -> ~5.4 MB base64, safely under 6 MB.
RAW_JPEG_BUDGET = 4_000_000


def download_image(url, max_bytes=MAX_DOWNLOAD_BYTES, timeout=DOWNLOAD_TIMEOUT):
    """Download the source image, enforcing a byte ceiling and timeout."""
    request = Request(url, headers={"User-Agent": USER_AGENT})
    with urlopen(request, timeout=timeout) as response:  # noqa: S310 (host is allowlisted)
        data = response.read(max_bytes + 1)
    if len(data) > max_bytes:
        raise ValueError(f"source exceeds {max_bytes} byte limit")
    if not data:
        raise ValueError("empty response from source")
    return data


def _encode_jpeg(image, dim, quality):
    """Downscale a copy so the long side <= dim (never upscales) and JPEG-encode it."""
    from PIL import Image

    work = image.copy()
    work.thumbnail((dim, dim), Image.Resampling.LANCZOS)
    buffer = BytesIO()
    work.save(buffer, format="JPEG", quality=quality, optimize=True)
    return buffer.getvalue()


def convert_to_jpeg(data, max_dim=MAX_DIM):
    """Decode arbitrary (incl. JP2 / TIFF) image bytes and return browser-displayable JPEG bytes.

    Grayscale ("L") is kept as-is (the canonical TAPUHI master is grayscale); RGB (the
    Feilding TIFF originals) passes through unchanged; palette / CMYK / etc. are converted
    to RGB. A small budget guard loop keeps the encoded JPEG under RAW_JPEG_BUDGET so the
    base64 body never exceeds the 6 MB Function URL cap.
    """
    from PIL import Image

    # Finite ceiling (not disabled outright): high enough to admit legitimate large
    # preservation masters, low enough to still reject a pathological decompression bomb.
    Image.MAX_IMAGE_PIXELS = MAX_IMAGE_PIXELS

    image = Image.open(BytesIO(data))

    # JPEG 2000 is wavelet-coded: OpenJPEG can discard high-resolution levels at decode time
    # (each discarded level halves the dimensions). Since the output is downscaled to max_dim
    # anyway, decode the smallest level whose long side is still >= max_dim rather than the full
    # master. This keeps a 100+ MP JP2 master fast and within the Lambda memory/timeout budget
    # (decoding the full raster of a ~60 MB JP2 otherwise times out).
    if image.format == "JPEG2000":
        longest = max(image.size)
        reduce_n = 0
        while (longest >> (reduce_n + 1)) >= max_dim and reduce_n < 8:
            reduce_n += 1
        if reduce_n:
            image.reduce = reduce_n

    image.load()

    if image.mode not in ("RGB", "L"):
        image = image.convert("RGB")

    candidate = None
    for dim, quality in ((max_dim, 85), (max_dim, 75), (3000, 75)):
        candidate = _encode_jpeg(image, dim, quality)
        if len(candidate) <= RAW_JPEG_BUDGET:
            return candidate
    return candidate  # best effort: smallest variant we produced


def _text_response(status, message):
    return {
        "statusCode": status,
        "headers": {"Content-Type": "text/plain; charset=utf-8"},
        "body": message,
    }


def lambda_handler(event, context):
    params = event.get("queryStringParameters") or {}
    source_url = params.get("url")
    if not source_url:
        return _text_response(400, "missing 'url' query parameter")

    if not SIGNING_KEY:
        return _text_response(500, "converter signing key not configured")

    # Verify before any host check / network access: only the Swift Lambda (which holds
    # SIGNING_KEY) can mint a valid signature, so an invalid one is rejected fast, before
    # spending a download/decode on a request nobody with the key actually asked for.
    supplied_sig = params.get("sig") or ""
    expected_sig = hmac.new(SIGNING_KEY.encode(), source_url.encode(), hashlib.sha256).hexdigest()
    if not hmac.compare_digest(expected_sig, supplied_sig):
        return _text_response(403, "invalid signature")

    host = urlparse(source_url).hostname
    if host not in ALLOWED_HOSTS:
        return _text_response(403, f"host not allowed: {host}")

    t0 = time.perf_counter()
    try:
        data = download_image(source_url)
    except Exception as error:  # noqa: BLE001 — surface a short reason, never crash
        return _text_response(502, f"download failed: {error}")
    t_download = time.perf_counter() - t0

    t1 = time.perf_counter()
    try:
        jpeg = convert_to_jpeg(data, MAX_DIM)
    except Exception as error:  # noqa: BLE001
        return _text_response(502, f"decode/convert failed: {error}")
    t_convert = time.perf_counter() - t1

    # Observability: download (NDHA -> Lambda) vs decode/encode split, plus byte sizes.
    print(
        f"timing download={t_download:.2f}s convert={t_convert:.2f}s "
        f"src={len(data)}B out={len(jpeg)}B"
    )

    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "image/jpeg",
            "Cache-Control": "public, max-age=31536000, immutable",
        },
        "isBase64Encoded": True,
        "body": base64.b64encode(jpeg).decode("ascii"),
    }

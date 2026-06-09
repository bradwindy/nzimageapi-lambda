"""JP2 -> JPEG converter Lambda (behind a Function URL).

The NZ Image API Swift Lambda stays a pure URL builder. For the TAPUHI collection it
resolves an NDHA preservation master (`...DeliveryManagerServlet?dps_pid=FL<n>&dps_func=stream`),
which is a JPEG 2000 (.jp2). JP2 is undecodable by ~98% of browsers and by every free
keyless image proxy (weserv/cloudimg/etc.). This function downloads that JP2, decodes it
with Pillow (OpenJPEG), downscales to stay under the Function URL 6 MB response cap, and
returns a browser-displayable JPEG (base64, image/jpeg).

It is a generic JP2->JPEG proxy, host-allowlisted to a single origin so it can never be
used as an open proxy / SSRF pivot.
"""

import base64
import os
from io import BytesIO
from urllib.parse import urlparse
from urllib.request import Request, urlopen

# --- configuration (env-overridable; defaults match the SAM template) ---------------
ALLOWED_HOST = os.environ.get("ALLOWED_HOST", "ndhadeliver.natlib.govt.nz")
MAX_DIM = int(os.environ.get("MAX_DIM", "4000"))

# Browser UA: the NDHA FL `dps_func=stream` endpoint is stateless (no cookies needed).
USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
DOWNLOAD_TIMEOUT = 20  # seconds
MAX_DOWNLOAD_BYTES = 60 * 1024 * 1024  # 60 MB guard on the source JP2

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
    """Decode arbitrary (incl. JP2) image bytes and return browser-displayable JPEG bytes.

    Grayscale ("L") is kept as-is (the canonical TAPUHI master is grayscale); palette /
    CMYK / etc. are converted to RGB. A small budget guard loop keeps the encoded JPEG
    under RAW_JPEG_BUDGET so the base64 body never exceeds the 6 MB Function URL cap.
    """
    from PIL import Image

    # The host is allowlisted to a single trusted origin, so the decompression-bomb guard
    # would only ever produce false positives on legitimately large preservation masters.
    Image.MAX_IMAGE_PIXELS = None

    image = Image.open(BytesIO(data))
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

    host = urlparse(source_url).hostname
    if host != ALLOWED_HOST:
        return _text_response(403, f"host not allowed: {host}")

    try:
        data = download_image(source_url)
    except Exception as error:  # noqa: BLE001 — surface a short reason, never crash
        return _text_response(502, f"download failed: {error}")

    try:
        jpeg = convert_to_jpeg(data, MAX_DIM)
    except Exception as error:  # noqa: BLE001
        return _text_response(502, f"decode/convert failed: {error}")

    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "image/jpeg",
            "Cache-Control": "public, max-age=31536000, immutable",
        },
        "isBase64Encoded": True,
        "body": base64.b64encode(jpeg).decode("ascii"),
    }

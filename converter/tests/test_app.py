"""Hermetic (offline) pytest suite for converter/app.py.

Every test here is deterministic and network-free: request-path tests build synthetic
API-Gateway-v2-style events and monkeypatch `app.download_image` / `app.urlopen` / module
globals instead of hitting real hosts; convert/encode tests use `PIL.Image.new` to build
synthetic in-memory images rather than downloading real masters. `converter/test_local.py`
(a manual smoke script against a live NDHA asset) is intentionally NOT run from here.

The JP2 `reduce_n` fast path in `convert_to_jpeg` needs an OpenJPEG-capable Pillow build and
a real JP2 file to exercise meaningfully, so it isn't covered here — it's exercised by the
existing live `converter/test_local.py` smoke script instead.
"""

import base64
import hashlib
import hmac
import sys
from io import BytesIO
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import app  # noqa: E402


# --- shared helpers ------------------------------------------------------------------


def _sig(key, url):
    return hmac.new(key.encode(), url.encode(), hashlib.sha256).hexdigest()


def _image_bytes(size=(50, 50), mode="RGB", color=(10, 20, 30), fmt="PNG"):
    from PIL import Image

    buf = BytesIO()
    Image.new(mode, size, color).save(buf, format=fmt)
    return buf.getvalue()


# --- B1: lambda_handler request-path tests --------------------------------------------


def test_missing_url_param_returns_400():
    result = app.lambda_handler({"queryStringParameters": {}}, None)
    assert result["statusCode"] == 400


def test_missing_query_string_parameters_key_returns_400():
    result = app.lambda_handler({}, None)
    assert result["statusCode"] == 400


def test_empty_signing_key_returns_500(monkeypatch):
    monkeypatch.setattr(app, "SIGNING_KEY", "")
    event = {"queryStringParameters": {"url": "https://ndhadeliver.natlib.govt.nz/x", "sig": "whatever"}}

    result = app.lambda_handler(event, None)

    assert result["statusCode"] == 500


def test_bad_signature_returns_403(monkeypatch):
    monkeypatch.setattr(app, "SIGNING_KEY", "test-signing-key")
    event = {
        "queryStringParameters": {
            "url": "https://ndhadeliver.natlib.govt.nz/x",
            "sig": "0" * 64,  # well-formed hex, but not the correct digest
        }
    }

    result = app.lambda_handler(event, None)

    assert result["statusCode"] == 403
    assert "invalid signature" in result["body"]


def test_valid_signature_but_disallowed_host_returns_403(monkeypatch):
    monkeypatch.setattr(app, "SIGNING_KEY", "test-signing-key")
    monkeypatch.setattr(app, "ALLOWED_HOSTS", frozenset({"ndhadeliver.natlib.govt.nz"}))
    url = "https://evil.example.com/x"
    event = {"queryStringParameters": {"url": url, "sig": _sig("test-signing-key", url)}}

    result = app.lambda_handler(event, None)

    assert result["statusCode"] == 403
    assert "host not allowed" in result["body"]


def test_valid_signature_and_allowed_host_but_download_fails_returns_502(monkeypatch):
    monkeypatch.setattr(app, "SIGNING_KEY", "test-signing-key")
    monkeypatch.setattr(app, "ALLOWED_HOSTS", frozenset({"ndhadeliver.natlib.govt.nz"}))
    url = "https://ndhadeliver.natlib.govt.nz/x"

    def _raise(*_args, **_kwargs):
        raise ValueError("boom")

    monkeypatch.setattr(app, "download_image", _raise)
    event = {"queryStringParameters": {"url": url, "sig": _sig("test-signing-key", url)}}

    result = app.lambda_handler(event, None)

    assert result["statusCode"] == 502
    assert "download failed" in result["body"]


def test_successful_request_returns_200_base64_jpeg(monkeypatch):
    # Verifies the full ordering (HMAC -> host allowlist -> download -> convert) and the
    # success response shape, using a synthetic PNG in place of a real network download.
    monkeypatch.setattr(app, "SIGNING_KEY", "test-signing-key")
    monkeypatch.setattr(app, "ALLOWED_HOSTS", frozenset({"ndhadeliver.natlib.govt.nz"}))
    url = "https://ndhadeliver.natlib.govt.nz/x"
    monkeypatch.setattr(app, "download_image", lambda *_a, **_kw: _image_bytes())
    event = {"queryStringParameters": {"url": url, "sig": _sig("test-signing-key", url)}}

    result = app.lambda_handler(event, None)

    assert result["statusCode"] == 200
    assert result["headers"]["Content-Type"] == "image/jpeg"
    assert result["isBase64Encoded"] is True
    assert "immutable" in result["headers"]["Cache-Control"]
    decoded = base64.b64decode(result["body"])
    assert decoded[:2] == b"\xff\xd8"  # JPEG SOI marker


# --- B2: convert_to_jpeg / _encode_jpeg -----------------------------------------------


def test_rgb_image_stays_rgb():
    from PIL import Image

    jpeg = app.convert_to_jpeg(_image_bytes(mode="RGB", color=(200, 100, 50)), max_dim=200)

    assert Image.open(BytesIO(jpeg)).mode == "RGB"


def test_grayscale_image_stays_grayscale():
    from PIL import Image

    jpeg = app.convert_to_jpeg(_image_bytes(mode="L", color=128), max_dim=200)

    assert Image.open(BytesIO(jpeg)).mode == "L"


def test_palette_image_normalizes_to_rgb():
    from PIL import Image

    img = Image.new("P", (50, 50))
    img.putpalette([i % 256 for i in range(768)])
    buf = BytesIO()
    img.save(buf, format="PNG")

    jpeg = app.convert_to_jpeg(buf.getvalue(), max_dim=200)

    assert Image.open(BytesIO(jpeg)).mode == "RGB"


def test_rgba_image_normalizes_to_rgb():
    from PIL import Image

    jpeg = app.convert_to_jpeg(_image_bytes(mode="RGBA", color=(10, 20, 30, 255)), max_dim=200)

    assert Image.open(BytesIO(jpeg)).mode == "RGB"


def test_cmyk_image_normalizes_to_rgb():
    from PIL import Image

    jpeg = app.convert_to_jpeg(_image_bytes(mode="CMYK", color=(10, 20, 30, 0), fmt="TIFF"), max_dim=200)

    assert Image.open(BytesIO(jpeg)).mode == "RGB"


def test_output_is_always_jpeg():
    jpeg = app.convert_to_jpeg(_image_bytes(), max_dim=200)

    assert jpeg[:2] == b"\xff\xd8"


def test_large_image_downscales_to_max_dim():
    from PIL import Image

    jpeg = app.convert_to_jpeg(_image_bytes(size=(6000, 4000), color=(120, 80, 40)), max_dim=500)

    assert max(Image.open(BytesIO(jpeg)).size) <= 500


def test_small_image_is_never_upscaled():
    from PIL import Image

    jpeg = app.convert_to_jpeg(_image_bytes(size=(100, 80)), max_dim=4000)

    assert Image.open(BytesIO(jpeg)).size == (100, 80)


def test_budget_loop_stops_at_first_variant_under_budget(monkeypatch):
    calls = []

    def fake_encode(_image, dim, quality):
        calls.append((dim, quality))
        # First attempt is oversized; the second (of three possible) fits the budget.
        size = app.RAW_JPEG_BUDGET + 100 if len(calls) == 1 else 10
        return b"\xff\xd8" + (b"x" * size)

    monkeypatch.setattr(app, "_encode_jpeg", fake_encode)

    result = app.convert_to_jpeg(_image_bytes(size=(10, 10)), max_dim=200)

    assert len(calls) == 2
    assert len(result) <= app.RAW_JPEG_BUDGET


def test_budget_loop_returns_best_effort_when_every_variant_exceeds_budget(monkeypatch):
    calls = []
    oversized = app.RAW_JPEG_BUDGET + 100

    def fake_encode(_image, dim, quality):
        calls.append((dim, quality))
        return b"\xff\xd8" + (b"x" * oversized)

    monkeypatch.setattr(app, "_encode_jpeg", fake_encode)

    result = app.convert_to_jpeg(_image_bytes(size=(10, 10)), max_dim=200)

    # All three (dim, quality) variants attempted: (max_dim, 85), (max_dim, 75), (3000, 75).
    assert len(calls) == 3
    assert len(result) == oversized + 2  # best-effort: the last (smallest-attempted) variant


def test_encode_jpeg_caps_dimension_at_max_dim():
    from PIL import Image

    img = Image.new("RGB", (2000, 1000), (10, 20, 30))

    encoded = app._encode_jpeg(img, dim=500, quality=80)

    assert max(Image.open(BytesIO(encoded)).size) <= 500


def test_encode_jpeg_never_upscales_small_image():
    from PIL import Image

    img = Image.new("RGB", (100, 80), (10, 20, 30))

    encoded = app._encode_jpeg(img, dim=4000, quality=80)

    assert Image.open(BytesIO(encoded)).size == (100, 80)


# --- B3: download_image / _text_response -----------------------------------------------


class _FakeURLResponse:
    def __init__(self, data):
        self._data = data

    def read(self, n):
        return self._data[:n]

    def __enter__(self):
        return self

    def __exit__(self, *_exc):
        return False


def test_download_image_raises_when_over_max_bytes(monkeypatch):
    monkeypatch.setattr(app, "urlopen", lambda _request, timeout=None: _FakeURLResponse(b"x" * 20))

    with pytest.raises(ValueError):
        app.download_image("https://example.com/x", max_bytes=10, timeout=5)


def test_download_image_raises_when_response_empty(monkeypatch):
    monkeypatch.setattr(app, "urlopen", lambda _request, timeout=None: _FakeURLResponse(b""))

    with pytest.raises(ValueError):
        app.download_image("https://example.com/x", max_bytes=10, timeout=5)


def test_download_image_returns_bytes_for_normal_response(monkeypatch):
    monkeypatch.setattr(app, "urlopen", lambda _request, timeout=None: _FakeURLResponse(b"hello"))

    result = app.download_image("https://example.com/x", max_bytes=100, timeout=5)

    assert result == b"hello"


def test_text_response_shape():
    assert app._text_response(403, "nope") == {
        "statusCode": 403,
        "headers": {"Content-Type": "text/plain; charset=utf-8"},
        "body": "nope",
    }

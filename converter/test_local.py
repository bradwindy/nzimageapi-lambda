#!/usr/bin/env python3
"""Local converter smoke test (no AWS).

Downloads a real TAPUHI FL JP2 preservation master and runs the exact same decode path
the Lambda uses, asserting the output is a multi-megapixel browser-displayable JPEG.

Canonical record from Research/highres/logs/025-tapuhi.md (live-verified 2026-06-07):
  FL stream -> image/jp2, 3737x2148 (8 MP), ~6 MB.
  Expected after conversion -> image/jpeg, 3737x2148 (<= 4000 long side; no downscale).

Run:  python converter/test_local.py
Exits non-zero on failure.
"""

import sys
from io import BytesIO

from app import convert_to_jpeg, download_image

FL_STREAM_URL = (
    "https://ndhadeliver.natlib.govt.nz/delivery/DeliveryManagerServlet"
    "?dps_pid=FL73782300&dps_func=stream"
)


def main():
    print(f"Downloading JP2 master: {FL_STREAM_URL}")
    data = download_image(FL_STREAM_URL)
    print(f"  downloaded {len(data):,} bytes")

    jpeg = convert_to_jpeg(data)

    from PIL import Image

    width, height = Image.open(BytesIO(jpeg)).size
    megapixels = (width * height) / 1_000_000
    print(f"  decoded JPEG: {width}x{height} ({megapixels:.1f} MP), {len(jpeg):,} bytes")

    assert jpeg[:2] == b"\xff\xd8", "output is not a JPEG (missing SOI marker)"
    assert width * height >= 1_000_000, f"expected multi-MP, got {width}x{height}"

    print("PASS")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:  # noqa: BLE001
        print(f"FAIL: {error}", file=sys.stderr)
        sys.exit(1)

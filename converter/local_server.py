"""Local stand-in for the converter's Lambda Function URL (no AWS, dev-only).

NOT part of the deployed image (the Dockerfile only copies app.py). This faithfully
simulates a Lambda Function URL so the real app.py handler can be exercised end-to-end
from the Swift Lambda without deploying:

  - GET /?url=<percent-encoded FL stream>  ->  build an API Gateway v2 event with the
    URL-*decoded* queryStringParameters (exactly what a Function URL passes the handler),
    call app.lambda_handler, return its response (base64-decoding the body when
    isBase64Encoded, like AWS does for binary responses).
  - HEAD is short-circuited to a fast 200 image/jpeg so CollectionTester's 10s HEAD probe
    never times out on the cold 6 MB download+decode; the subsequent ranged GET does the
    real conversion and returns actual JPEG bytes.

Usage:
    python -m venv .venv && .venv/bin/pip install 'Pillow==11.*'
    .venv/bin/python converter/local_server.py 8787 &
    export JP2_CONVERTER_URL=http://127.0.0.1:8787
    swift run CollectionTester "TAPUHI"
"""

import base64
import os
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qsl, urlparse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from app import lambda_handler  # noqa: E402

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8787


class Handler(BaseHTTPRequestHandler):
    def _invoke(self):
        parsed = urlparse(self.path)
        # parse_qsl URL-decodes values — mirrors Function URL queryStringParameters.
        qs = dict(parse_qsl(parsed.query, keep_blank_values=True))
        event = {
            "version": "2.0",
            "rawPath": parsed.path,
            "rawQueryString": parsed.query,
            "queryStringParameters": qs,
            "requestContext": {"http": {"method": "GET", "path": parsed.path}},
        }
        return lambda_handler(event, None)

    def do_HEAD(self):
        self.send_response(200)
        self.send_header("Content-Type", "image/jpeg")
        self.end_headers()

    def do_GET(self):
        resp = self._invoke()
        body = resp.get("body", "") or ""
        data = base64.b64decode(body) if resp.get("isBase64Encoded") else body.encode("utf-8")
        self.send_response(resp["statusCode"])
        for key, value in (resp.get("headers") or {}).items():
            self.send_header(key, value)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *args):  # quiet
        pass


if __name__ == "__main__":
    server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    print(f"converter listening on http://127.0.0.1:{PORT}", flush=True)
    server.serve_forever()

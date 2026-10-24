#!/bin/bash
#
# Smoke-tests the /image access-control model described in docs/ACCESS-CONTROL.md.
# Asserts: 200 with a valid secret, 401 with a missing/wrong secret, and (optionally,
# opt-in) 429 once the iolab.nz WAF rate-limiting rule (30 requests per 10 s per IP) trips.
#
# Usage:
#   API_URL="https://nzimages-api.iolab.nz" \
#   API_SECRET="your-consumer-secret" \
#   ./scripts/smoke-test-access-control.sh
#
#   # Also exercise the rate limit (fires 40 parallel /collections requests, which count
#   # toward the Free plan's daily Worker requests, so it's opt-in and NOT run by default):
#   ./scripts/smoke-test-access-control.sh --throttle

set -e

API_URL="${API_URL:?Set API_URL to the deployed API base URL, e.g. https://nzimages-api.iolab.nz}"
API_SECRET="${API_SECRET:?Set API_SECRET to a secret value from API_CLIENT_SECRETS}"
RUN_THROTTLE_TEST=false

for arg in "$@"; do
  if [ "$arg" = "--throttle" ]; then
    RUN_THROTTLE_TEST=true
  fi
done

pass_count=0
fail_count=0

assert_status() {
  local description="$1"
  local expected="$2"
  local actual="$3"
  if [ "$actual" = "$expected" ]; then
    echo "  PASS: $description (got $actual)"
    pass_count=$((pass_count + 1))
  else
    echo "  FAIL: $description (expected $expected, got $actual)"
    fail_count=$((fail_count + 1))
  fi
}

echo "== Access-control smoke test against: $API_URL/image =="

echo "-- Valid secret --"
status=$(curl -s -o /dev/null -w "%{http_code}" -H "secret: $API_SECRET" "$API_URL/image")
assert_status "correct secret returns 200" "200" "$status"

echo "-- Missing secret --"
status=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/image")
assert_status "no secret header returns 401" "401" "$status"

echo "-- Wrong secret --"
status=$(curl -s -o /dev/null -w "%{http_code}" -H "secret: definitely-not-a-real-secret" "$API_URL/image")
assert_status "incorrect secret returns 401" "401" "$status"

if [ "$RUN_THROTTLE_TEST" = true ]; then
  echo "-- Rate limit (WAF rule allows 30 requests per 10 s per IP; firing 40 in parallel) --"
  statuses=$(seq 1 40 | xargs -P 40 -I{} curl -s -o /dev/null -w "%{http_code}\n" -H "secret: $API_SECRET" "$API_URL/collections")
  if echo "$statuses" | grep -q '^429$'; then
    echo "  PASS: rate limit engaged (saw a 429 within 40 parallel requests)"
    pass_count=$((pass_count + 1))
  else
    echo "  FAIL: never saw a 429 within 40 parallel requests -- check the iolab.nz rate limiting rule"
    fail_count=$((fail_count + 1))
  fi
else
  echo "-- Rate limit test skipped (pass --throttle to run it; it deliberately fires 40 parallel requests) --"
fi

echo ""
echo "== $pass_count passed, $fail_count failed =="
[ "$fail_count" -eq 0 ]

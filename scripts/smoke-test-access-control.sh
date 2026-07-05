#!/bin/bash
#
# Smoke-tests the /image access-control model described in docs/ACCESS-CONTROL.md.
# Asserts: 200 with a valid secret, 401 with a missing/wrong secret, and (optionally,
# opt-in) 429 once the API Gateway stage throttle is exceeded.
#
# Usage:
#   API_URL="https://xxxx.execute-api.ap-southeast-2.amazonaws.com" \
#   API_SECRET="your-consumer-secret" \
#   ./scripts/smoke-test-access-control.sh
#
#   # Also exercise the throttle (fires ~20+ rapid requests -- costs real invocations,
#   # so it's opt-in and NOT run by default):
#   ./scripts/smoke-test-access-control.sh --throttle

set -e

API_URL="${API_URL:?Set API_URL to the deployed API base URL, e.g. https://xxxx.execute-api.ap-southeast-2.amazonaws.com}"
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
  echo "-- Throttle (default ThrottlingBurstLimit is 20; firing 30 rapid requests) --"
  saw_429=false
  for _ in $(seq 1 30); do
    status=$(curl -s -o /dev/null -w "%{http_code}" -H "secret: $API_SECRET" "$API_URL/image")
    if [ "$status" = "429" ]; then
      saw_429=true
      break
    fi
  done
  if [ "$saw_429" = true ]; then
    echo "  PASS: throttle engaged (saw a 429 within 30 rapid requests)"
    pass_count=$((pass_count + 1))
  else
    echo "  FAIL: never saw a 429 within 30 rapid requests -- check ThrottlingBurstLimit/ThrottlingRateLimit"
    fail_count=$((fail_count + 1))
  fi
else
  echo "-- Throttle test skipped (pass --throttle to run it; it deliberately fires 30 rapid requests) --"
fi

echo ""
echo "== $pass_count passed, $fail_count failed =="
[ "$fail_count" -eq 0 ]

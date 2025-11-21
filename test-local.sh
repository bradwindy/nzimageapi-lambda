#!/bin/bash

# Script to test the locally running NZ Image API Lambda
# Usage: ./test-local.sh [collection_name]
#
# Required environment variables:
#   DIGITALNZ_API_KEY - Your DigitalNZ API key
#
# Optional environment variables:
#   SECRET - Authentication secret (default: super_secret_secret)
#   PORT - Lambda server port (default: 7000)

COLLECTION=$1
SECRET=${SECRET:-super_secret_secret}
PORT=${PORT:-7000}

# Check if API key is set
if [ -z "$DIGITALNZ_API_KEY" ]; then
    echo "✗ Error: DIGITALNZ_API_KEY environment variable is not set"
    echo ""
    echo "Please set your DigitalNZ API key:"
    echo "  export DIGITALNZ_API_KEY=your_api_key_here"
    echo ""
    echo "Then ensure the lambda is running with the API key:"
    echo "  DIGITALNZ_API_KEY=your_api_key SECRET=super_secret_secret LOCAL_LAMBDA_SERVER_ENABLED=true ./.build/debug/NZImageApiLambda"
    exit 1
fi

# URL encode function (simple version for collection names)
urlencode() {
    local string="$1"
    local strlen=${#string}
    local encoded=""
    local pos c o

    for (( pos=0 ; pos<strlen ; pos++ )); do
        c=${string:$pos:1}
        case "$c" in
            [-_.~a-zA-Z0-9] ) o="${c}" ;;
            * ) printf -v o '%%%02x' "'$c"
        esac
        encoded+="${o}"
    done
    echo "${encoded}"
}

# Build the query string if collection is specified
if [ -n "$COLLECTION" ]; then
    RAW_QUERY_STRING="collection=$(urlencode "$COLLECTION")"
else
    RAW_QUERY_STRING=""
fi

RAW_PATH="/image"

echo "Testing NZ Image API Lambda..."
echo "Endpoint: http://127.0.0.1:$PORT/invoke"
if [ -n "$COLLECTION" ]; then
    echo "Collection: $COLLECTION"
else
    echo "Collection: Random"
fi
echo ""

# Build query string parameters JSON if collection is specified
if [ -n "$COLLECTION" ]; then
    QUERY_PARAMS="\"queryStringParameters\":{\"collection\":\"$COLLECTION\"},"
else
    QUERY_PARAMS=""
fi

# Make the request
RESPONSE=$(curl -s --header "Content-Type: application/json" \
    --request POST \
    --data "{
  \"routeKey\":\"GET /image\",
  \"version\":\"2.0\",
  \"rawPath\":\"$RAW_PATH\",
  $QUERY_PARAMS
  \"stageVariables\":{},
  \"requestContext\":{
    \"timeEpoch\":$(date +%s)000,
    \"domainPrefix\":\"image\",
    \"accountId\":\"0123456789\",
    \"stage\":\"\$default\",
    \"domainName\":\"image.test.com\",
    \"apiId\":\"pb5dg6g3rg\",
    \"requestId\":\"test-$(date +%s)\",
    \"http\":{
      \"path\":\"$RAW_PATH\",
      \"userAgent\":\"test-local-script\",
      \"method\":\"GET\",
      \"protocol\":\"HTTP/1.1\",
      \"sourceIp\":\"127.0.0.1\"
    },
    \"time\":\"$(date -u +"%d/%b/%Y:%H:%M:%S %z")\"
  },
  \"isBase64Encoded\":false,
  \"rawQueryString\":\"$RAW_QUERY_STRING\",
  \"headers\":{
    \"secret\": \"$SECRET\",
    \"host\":\"localhost:$PORT\",
    \"user-agent\":\"test-local-script\",
    \"content-length\":\"0\"
  }
}" \
    http://127.0.0.1:$PORT/invoke)

# Check if request was successful
if [ $? -ne 0 ]; then
    echo "✗ Error: Failed to connect to lambda. Is it running?"
    echo ""
    echo "Start it with:"
    echo "  SECRET=super_secret_secret LOCAL_LAMBDA_SERVER_ENABLED=true ./.build/debug/NZImageApiLambda"
    exit 1
fi

# Display the response
echo "Response:"
echo "$RESPONSE"
echo ""

# Try to extract status code (works with or without jq)
if command -v jq &> /dev/null; then
    STATUS_CODE=$(echo "$RESPONSE" | jq -r '.statusCode')

    if [ "$STATUS_CODE" = "200" ]; then
        echo "✓ Success! Image details:"
        echo ""
        BODY=$(echo "$RESPONSE" | jq -r '.body')
        echo "$BODY" | jq .
    else
        echo "✗ Request failed with status code: $STATUS_CODE"
    fi
else
    # Fallback without jq
    if echo "$RESPONSE" | grep -q '"statusCode":200'; then
        echo "✓ Success!"
    else
        echo "✗ Request may have failed (install jq for better output)"
    fi
fi

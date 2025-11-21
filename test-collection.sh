#!/bin/bash

# test-collection.sh
# Starts the local lambda server and fetches an image from a collection

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
COLLECTION=""
PORT=7000
HOST="127.0.0.1"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --port)
            PORT="$2"
            shift 2
            ;;
        --host)
            HOST="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [COLLECTION] [OPTIONS]"
            echo ""
            echo "Starts the local lambda server and fetches an image"
            echo ""
            echo "Arguments:"
            echo "  COLLECTION        Collection name (optional, random if not specified)"
            echo ""
            echo "Options:"
            echo "  --port <port>     Port to use (default: 7000)"
            echo "  --host <host>     Host to use (default: 127.0.0.1)"
            echo "  -h, --help        Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                              # Random collection"
            echo "  $0 \"Canterbury Museum\"         # Specific collection"
            echo "  $0 --port 9000                  # Random with custom port"
            exit 0
            ;;
        *)
            COLLECTION="$1"
            shift
            ;;
    esac
done

# Check if API key is set
if [ -z "$DIGITALNZ_API_KEY" ]; then
    echo -e "${RED}Error: DIGITALNZ_API_KEY environment variable not set${NC}"
    echo "Please set it with: export DIGITALNZ_API_KEY=your_api_key"
    exit 1
fi

# Check if port is available
if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${YELLOW}Warning: Port $PORT is already in use${NC}"
    echo "Attempting to kill existing process..."
    lsof -ti :$PORT | xargs kill -9 2>/dev/null || true
    sleep 1
fi

# Start the lambda server
echo -e "${GREEN}🚀 Starting local lambda server on port $PORT...${NC}"
SECRET=super_secret_secret LOCAL_LAMBDA_SERVER_ENABLED=true .build/debug/NZImageApiLambda > /tmp/lambda-server.log 2>&1 &
LAMBDA_PID=$!

# Function to cleanup on exit
cleanup() {
    echo ""
    echo -e "${GREEN}🧹 Shutting down lambda server...${NC}"
    kill $LAMBDA_PID 2>/dev/null || true
    wait $LAMBDA_PID 2>/dev/null || true
}

trap cleanup EXIT INT TERM

# Wait for server to be ready
echo "⏳ Waiting for server to start..."
MAX_RETRIES=30
RETRY_COUNT=0

# Test with a simple health check to /invoke
while ! curl -s -X POST http://$HOST:$PORT/invoke -d '{}' > /dev/null 2>&1; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo -e "${RED}❌ Server failed to start after ${MAX_RETRIES} seconds${NC}"
        echo "Check /tmp/lambda-server.log for details:"
        tail -20 /tmp/lambda-server.log
        exit 1
    fi
    sleep 1
done

echo -e "${GREEN}✅ Server is ready!${NC}"
echo ""

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
    QUERY_PARAMS="\"queryStringParameters\":{\"collection\":\"$COLLECTION\"},"
else
    RAW_QUERY_STRING=""
    QUERY_PARAMS=""
fi

RAW_PATH="/image"

# Make the request
echo "🔍 Making request..."
if [ -n "$COLLECTION" ]; then
    echo "📁 Collection: $COLLECTION"
else
    echo "🎲 Using random collection"
fi
echo ""

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
      \"userAgent\":\"test-collection-script\",
      \"method\":\"GET\",
      \"protocol\":\"HTTP/1.1\",
      \"sourceIp\":\"127.0.0.1\"
    },
    \"time\":\"$(date -u +"%d/%b/%Y:%H:%M:%S %z")\"
  },
  \"isBase64Encoded\":false,
  \"rawQueryString\":\"$RAW_QUERY_STRING\",
  \"headers\":{
    \"secret\": \"super_secret_secret\",
    \"host\":\"$HOST:$PORT\",
    \"user-agent\":\"test-collection-script\",
    \"content-length\":\"0\"
  }
}" \
    http://$HOST:$PORT/invoke)

# Check if request was successful
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Error: Failed to connect to lambda${NC}"
    exit 1
fi

# Try to extract status code (works with or without jq)
if command -v jq &> /dev/null; then
    STATUS_CODE=$(echo "$RESPONSE" | jq -r '.statusCode')

    if [ "$STATUS_CODE" = "200" ]; then
        echo -e "${GREEN}✅ Success!${NC}"
        echo ""
        BODY=$(echo "$RESPONSE" | jq -r '.body')
        echo "$BODY" | jq '.'
    else
        echo -e "${RED}✗ Request failed with status code: $STATUS_CODE${NC}"
        echo ""
        echo "Response:"
        echo "$RESPONSE" | jq '.'
        exit 1
    fi
else
    # Fallback without jq - just show the response
    if echo "$RESPONSE" | grep -q '"statusCode":200'; then
        echo -e "${GREEN}✅ Success!${NC}"
        echo ""
        echo "$RESPONSE"
    else
        echo -e "${RED}✗ Request may have failed${NC}"
        echo ""
        echo "$RESPONSE"
        exit 1
    fi
fi

# Cleanup happens automatically via trap

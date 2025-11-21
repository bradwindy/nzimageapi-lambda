#!/bin/bash

# test-collection.sh
# Wrapper script for CollectionTester

set -e

# Check if API key is set
if [ -z "$DIGITALNZ_API_KEY" ]; then
    echo "Error: DIGITALNZ_API_KEY environment variable not set"
    echo "Please set it with: export DIGITALNZ_API_KEY=your_api_key"
    exit 1
fi

# Build CollectionTester
echo "🔨 Building CollectionTester..."
swift build --product CollectionTester 2>&1 | grep -E "(Compiling|Linking|Build complete)" || true

# Run CollectionTester with the API key and forward all arguments
.build/debug/CollectionTester "$@"

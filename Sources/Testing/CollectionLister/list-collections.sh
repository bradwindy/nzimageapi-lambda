#!/bin/bash

# list-collections.sh
# Wrapper script for CollectionLister

set -e

# Check if API key is set
if [ -z "$DIGITALNZ_API_KEY" ]; then
    echo "Error: DIGITALNZ_API_KEY environment variable not set"
    echo "Please set it with: export DIGITALNZ_API_KEY=your_api_key"
    exit 1
fi

# Build CollectionLister
echo "🔨 Building CollectionLister..."
swift build --product CollectionLister 2>&1 | grep -E "(Compiling|Linking|Build complete)" || true

# Run CollectionLister with the API key
.build/debug/CollectionLister

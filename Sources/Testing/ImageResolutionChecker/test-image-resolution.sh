#!/bin/bash

# test-image-resolution.sh
# Wrapper script for ImageResolutionChecker

set -e

# Check if API key is set
if [ -z "$DIGITALNZ_API_KEY" ]; then
    echo "Error: DIGITALNZ_API_KEY environment variable not set"
    echo "Please set it with: export DIGITALNZ_API_KEY=your_api_key"
    exit 1
fi

# Build ImageResolutionChecker
echo "🔨 Building ImageResolutionChecker..."
swift build --product ImageResolutionChecker 2>&1 | grep -E "(Compiling|Linking|Build complete)" || true

# Run ImageResolutionChecker with the API key and forward all arguments
.build/debug/ImageResolutionChecker "$@"

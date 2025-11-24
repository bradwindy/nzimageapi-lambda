#!/bin/bash
set -e

# Check for API key
if [ -z "$DIGITALNZ_API_KEY" ]; then
    echo "Error: DIGITALNZ_API_KEY environment variable not set"
    echo "Export it with: export DIGITALNZ_API_KEY=your_api_key"
    exit 1
fi

# Build the Swift product
echo "Building CollectionReviewer..."
swift build --product CollectionReviewer 2>&1 | grep -E "(Compiling|Linking|Build complete)" || true

# Run the binary
.build/debug/CollectionReviewer "$@"

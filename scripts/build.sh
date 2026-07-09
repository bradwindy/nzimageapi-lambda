#!/bin/bash

set -e

# Clean previous build artifacts to avoid permission issues
echo "Cleaning previous build artifacts..."
rm -rf .build/checkouts .build/repositories .build/workspace-state.json

# Build using Docker
echo "Building Lambda for Amazon Linux 2023..."
docker run \
    --rm \
    --platform linux/arm64 \
    --volume "$(pwd)/:/src" \
    --workdir "/src/" \
    swift:6.3-amazonlinux2023 \
    /bin/bash -c "dnf -y install openssl-devel; swift build --product NZImageApiLambda -c release -Xswiftc -static-stdlib"

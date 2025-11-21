#!/bin/bash

set -e

# Clean previous build artifacts to avoid permission issues
echo "Cleaning previous build artifacts..."
rm -rf .build/checkouts .build/repositories .build/workspace-state.json

# Build using Docker
echo "Building Lambda for Amazon Linux 2..."
docker run \
    --rm \
    --volume "$(pwd)/:/src" \
    --workdir "/src/" \
    swift:6.0-amazonlinux2 \
    /bin/bash -c "yum -y update; yum -y install openssl openssl-devel -y; swift build --product NZImageApiLambda -c release -Xswiftc -static-stdlib"

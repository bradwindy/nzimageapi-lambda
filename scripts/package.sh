#!/bin/bash

set -eu

target=.build/lambda/NZImageApiLambda
rm -rf "$target"
mkdir -p "$target"
cp ".build/release/NZImageApiLambda" "$target/"
cd "$target"
upx NZImageApiLambda
ln -s "NZImageApiLambda" "bootstrap"
zip --symlinks lambda.zip *


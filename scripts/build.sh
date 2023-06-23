#!/bin/bash

docker run \
    --rm \
    --volume "$(pwd)/:/src" \
    --workdir "/src/" \
    swift:5.8.0-amazonlinux2 \
    /bin/bash -c "yum -y update; yum -y install openssl; yum -y install openssl-devel; swift build --product NZImageApiLambda -c release -Xswiftc -static-stdlib"

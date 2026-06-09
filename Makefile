# SAM custom-runtime build target for the Swift Lambda (provided.al2).
# `sam build` invokes `make build-NZImageApiFunction` with ARTIFACTS_DIR set; it then
# zips ARTIFACTS_DIR itself (no package.sh needed). scripts/build.sh cross-compiles a
# static arm64 Amazon Linux 2 binary in Docker (pinned --platform linux/arm64 to match
# Architectures: [arm64] in template.yaml).
build-NZImageApiFunction:
	./scripts/build.sh
	cp .build/release/NZImageApiLambda "$(ARTIFACTS_DIR)/bootstrap"
	# optional size reduction (uncomment if upx is installed on the build host):
	# upx "$(ARTIFACTS_DIR)/bootstrap"

# SAM `BuildMethod: makefile` target for the converter .zip (python3.13 on arm64).
# Installs Pillow's manylinux aarch64 wheel whatever the build host's OS or architecture, so a
# macOS build produces the same artefact as CI. Pillow 12+ only publishes manylinux_2_27/2_28
# tags; the manylinux2014 tag in AWS's packaging guide finds no wheel. Lambda's AL2023 runtime
# has glibc 2.34, which satisfies 2_28.
build-Jp2ConverterFunction:
	python3 -m pip install --quiet --no-compile --target "$(ARTIFACTS_DIR)" \
		--platform manylinux_2_28_aarch64 --implementation cp --python-version 3.13 \
		--only-binary=:all: -r requirements.txt
	cp app.py "$(ARTIFACTS_DIR)/"

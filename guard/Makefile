# SAM `BuildMethod: makefile` target for the guard .zip. It has no dependencies beyond the boto3
# bundled in the python3.13 runtime, so the build is a copy; using makefile (not SAM's
# python_pip builder) means `sam build` does not need python3.13 on the build host.
build-ConverterGuardFunction:
	cp app.py "$(ARTIFACTS_DIR)/"

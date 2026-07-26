FROM public.ecr.aws/lambda/python:3.15@sha256:f6aa405dd25ac6bd6a0720987f245e3de885c4dd287558fc118d897e7c189abd

# Pillow's manylinux wheel bundles libopenjp2. Install it, then HARD-ASSERT at build
# time that JPEG 2000 decode is actually enabled — if it is not, the build fails here
# (a deterministic guarantee, rather than discovering it at runtime).
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
RUN python -c "from PIL import features; assert features.check('jpg_2000'), 'OpenJPEG/JP2 NOT enabled in Pillow'"
RUN python -c "from PIL import features; assert features.check('libtiff'), 'libtiff NOT enabled in Pillow'"

COPY app.py ${LAMBDA_TASK_ROOT}/

CMD ["app.lambda_handler"]

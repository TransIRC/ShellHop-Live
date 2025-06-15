#!/bin/bash
set -euxo pipefail

IMAGE_NAME="shellhop-builder"
OUTPUT_DIR="$(pwd)"

# Build Docker image
docker build -t "$IMAGE_NAME" .

# Run container with output dir mounted
docker run --rm -it \
  -v "$OUTPUT_DIR":/work \
  "$IMAGE_NAME"

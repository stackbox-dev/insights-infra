#!/bin/bash

# Build script for custom Zeppelin image with embedded Flink 2.0
# Usage: ./build-zeppelin-image.sh [IMAGE_TAG]

set -e

# Configuration
PROJECT_ID="sbx-stag"
IMAGE_NAME="zeppelin-flink"
DEFAULT_TAG="2.0.0-zeppelin-0.12.0"
IMAGE_TAG="${1:-$DEFAULT_TAG}"
FULL_IMAGE_NAME="gcr.io/${PROJECT_ID}/${IMAGE_NAME}:${IMAGE_TAG}"

echo "Building custom Zeppelin image with embedded Flink 2.0..."
echo "Image: ${FULL_IMAGE_NAME}"
echo "======================================================"

# Build the Docker image
echo "Step 1: Building Docker image..."
docker build -f Dockerfile-zeppelin -t ${FULL_IMAGE_NAME} .

echo "Step 2: Testing the built image..."
# Quick test to ensure Flink is properly embedded
docker run --rm ${FULL_IMAGE_NAME} ls -la /opt/flink/lib/ | grep -E "(sql-client|table-planner)"

echo "Step 3: Pushing image to GCR..."
# Configure Docker for GCR if needed
if ! docker-credential-gcr configure-docker > /dev/null 2>&1; then
    echo "Configuring Docker for GCR..."
    gcloud auth configure-docker gcr.io
fi

# Push the image
docker push ${FULL_IMAGE_NAME}

echo "======================================================"
echo "✅ Custom Zeppelin image built and pushed successfully!"
echo "Image: ${FULL_IMAGE_NAME}"
echo ""
echo "To use this image in your deployment, update the image in 08-zeppelin.yaml:"
echo "  containers:"
echo "    - name: zeppelin"
echo "      image: ${FULL_IMAGE_NAME}"
echo ""
echo "And remove the init container since Flink is now embedded."
echo "======================================================"

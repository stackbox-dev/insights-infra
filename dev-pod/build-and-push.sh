#!/bin/bash
set -e

# Docker registry and image details
REGISTRY="asia-docker.pkg.dev"
PROJECT="sbx-ci-cd"
REPOSITORY="public"
IMAGE_NAME="dev-pod"
TAG="latest"
FULL_IMAGE="${REGISTRY}/${PROJECT}/${REPOSITORY}/${IMAGE_NAME}:${TAG}"

echo "Building Docker image: ${FULL_IMAGE}"

# Build the Docker image for AMD64 architecture
docker build --platform linux/amd64 -t ${FULL_IMAGE} -f Dockerfile .

echo "Pushing Docker image to registry..."

# Configure docker to use gcloud credentials (if not already configured)
gcloud auth configure-docker ${REGISTRY} --quiet

# Push the image
docker push ${FULL_IMAGE}

echo "Successfully pushed: ${FULL_IMAGE}"
echo ""
echo "To deploy to Kubernetes, run:"
echo "kubectl apply -f gcp.yaml"
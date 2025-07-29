#!/bin/bash

# Build and push custom Flink image with all necessary libraries
# This script builds a custom Flink image with Kafka, Avro, and GCP libraries pre-installed

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
IMAGE_REGISTRY="asia-docker.pkg.dev/sbx-ci-cd/public"
IMAGE_NAME="flink"
IMAGE_TAG="latest"
FULL_IMAGE_NAME="${IMAGE_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

print_status "Building custom Flink image with pre-installed libraries..."
print_status "Target image: ${FULL_IMAGE_NAME}"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

# Build the image
print_status "Building Docker image for linux/amd64 platform..."
docker build --platform linux/amd64 -t "${FULL_IMAGE_NAME}" -f ../docker/Dockerfile ../docker/

if [ $? -ne 0 ]; then
    print_error "Docker build failed!"
    exit 1
fi

print_status "Docker image built successfully!"

# Verify the image contents
print_status "Verifying image contents..."
docker run --rm "${FULL_IMAGE_NAME}" ls -la /opt/flink/lib/ | grep -E "(kafka|avro|google)" || {
    print_warning "Could not verify all libraries in the image"
}

# Push the image to the registry
print_status "Pushing image to registry..."
docker push "${FULL_IMAGE_NAME}"

if [ $? -ne 0 ]; then
    print_error "Docker push failed! Make sure you're authenticated to the registry."
    print_status "You can authenticate using: gcloud auth configure-docker asia-docker.pkg.dev"
    exit 1
fi

print_status "Image pushed successfully!"
print_status "Image is available at: ${FULL_IMAGE_NAME}"

# Clean up local build cache (optional)
read -p "Do you want to clean up the local Docker build cache? [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Cleaning up Docker build cache..."
    docker system prune -f
    print_status "Docker build cache cleaned up."
fi

print_status "Build and push completed successfully!"
print_status ""
print_status "Next steps:"
print_status "1. Update your Kubernetes manifests to use: ${FULL_IMAGE_NAME}"
print_status "2. Remove init containers and postStart hooks from your manifests"
print_status "3. Redeploy your Flink cluster and SQL Gateway"

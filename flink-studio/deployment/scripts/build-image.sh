#!/bin/bash

# Build and push custom Flink image with all necessary libraries
# This script builds a custom Flink image with Kafka, Avro, and GCP libraries pre-installed
#
# Usage:
#   ./build-image.sh [TAG]
#
# Examples:
#   ./build-image.sh                 # Build with 'latest' tag
#   ./build-image.sh v1.0.0         # Build with 'v1.0.0' tag
#   ./build-image.sh $(date +%Y%m%d) # Build with date tag

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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="${SCRIPT_DIR}/../docker"
IMAGE_REGISTRY="asia-docker.pkg.dev/sbx-ci-cd/public"
IMAGE_NAME="flink"

# Allow custom tag from command line argument
if [[ -n "$1" ]]; then
    IMAGE_TAG="$1"
else
    IMAGE_TAG="latest"
fi

FULL_IMAGE_NAME="${IMAGE_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

print_status "Building custom Flink image with pre-installed libraries..."
print_status "Target image: ${FULL_IMAGE_NAME}"
print_status "Docker context: ${DOCKER_DIR}"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

# Verify required files exist
if [[ ! -f "${DOCKER_DIR}/Dockerfile" ]]; then
    print_error "Dockerfile not found at ${DOCKER_DIR}/Dockerfile"
    exit 1
fi

if [[ ! -f "${DOCKER_DIR}/prepare-image.sh" ]]; then
    print_error "prepare-image.sh not found at ${DOCKER_DIR}/prepare-image.sh"
    exit 1
fi

if [[ ! -f "${DOCKER_DIR}/dependency-versions.json" ]]; then
    print_error "dependency-versions.json not found at ${DOCKER_DIR}/dependency-versions.json"
    exit 1
fi

print_status "All required files found. Starting build..."

# Build the image
print_status "Building Docker image for linux/amd64 platform..."
print_status "Docker build output will be displayed below..."
echo "----------------------------------------"

cd "${DOCKER_DIR}"

# Build with no-cache to see all stages and --progress=plain for better visibility
docker build --platform linux/amd64 --progress=plain --no-cache -t "${FULL_IMAGE_NAME}" .

# Check if build succeeded
if [ $? -ne 0 ]; then
    echo "----------------------------------------"
    print_error "Docker build failed!"
    print_error "Check the build output above for errors."
    print_error "Common issues:"
    print_error "  - Network connectivity issues"
    print_error "  - Missing dependencies in dependency-versions.json"
    print_error "  - Permission issues with prepare-image.sh"
    exit 1
fi

echo "----------------------------------------"
print_status "Docker image built successfully!"
cd - > /dev/null  # Return to original directory

# Verify the image contents
print_status "Verifying image contents..."
print_status "Checking installed libraries..."
docker run --rm "${FULL_IMAGE_NAME}" ls -la /opt/flink/lib/ | head -10

print_status "Checking for key dependencies..."
if docker run --rm "${FULL_IMAGE_NAME}" ls /opt/flink/lib/ | grep -q "kafka"; then
    print_status "✓ Kafka libraries found"
else
    print_warning "⚠ Kafka libraries not found"
fi

if docker run --rm "${FULL_IMAGE_NAME}" ls /opt/flink/lib/ | grep -q "avro"; then
    print_status "✓ Avro libraries found"
else
    print_warning "⚠ Avro libraries not found"
fi

if docker run --rm "${FULL_IMAGE_NAME}" ls /opt/flink/lib/ | grep -q "google"; then
    print_status "✓ Google libraries found"
else
    print_warning "⚠ Google libraries not found"
fi

# Show total library count
total_libs=$(docker run --rm "${FULL_IMAGE_NAME}" ls -1 /opt/flink/lib/ | wc -l)
print_status "Total libraries installed: ${total_libs}"

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

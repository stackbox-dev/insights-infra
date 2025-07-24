#!/bin/bash

# Build and push Flink GCS-enabled Docker image for GCP
# This script builds a custom Flink image with GCS support

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

# Image configuration
IMAGE_NAME="asia-docker.pkg.dev/sbx-ci-cd/private/flink-gke:2.0.0-scala_2.12-java21"
DOCKERFILE_PATH="."

print_status "Building Flink GCS-enabled Docker image..."
print_status "Image: $IMAGE_NAME"
print_status ""

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed or not in PATH"
    exit 1
fi

# Check if we're in the correct directory
if [ ! -f "Dockerfile" ]; then
    print_error "Dockerfile not found in current directory. Make sure you're in the gcp folder."
    exit 1
fi

# Build the image
print_status "Building Docker image..."
docker build --platform linux/amd64 -t "$IMAGE_NAME" "$DOCKERFILE_PATH"

if [ $? -eq 0 ]; then
    print_status "Docker image built successfully: $IMAGE_NAME"
else
    print_error "Failed to build Docker image"
    exit 1
fi

# Push the image
print_status "Pushing Docker image to registry..."
docker push "$IMAGE_NAME"

if [ $? -eq 0 ]; then
    print_status "Docker image pushed successfully: $IMAGE_NAME"
    print_status ""
    print_status "Image is now ready for deployment!"
else
    print_error "Failed to push Docker image"
    exit 1
fi

print_status ""
print_status "=== Build Summary ==="
print_status "Image: $IMAGE_NAME"
print_status "Registry: asia-docker.pkg.dev/sbx-ci-cd/private"
print_status "Status: Ready for deployment"
print_status ""
print_status "=== GCP Authentication Features ==="
print_status "✓ GCS Connector with service account key support"
print_status "✓ Google Cloud client libraries for authentication"
print_status "✓ GCP authentication verification script included"
print_status "✓ Configured for service account JSON key authentication"
print_status ""
print_status "To verify GCP authentication after deployment:"
print_status "kubectl exec -it deployment/flink-session-cluster -n flink-studio -- /opt/flink/bin/verify-gcp-auth.sh"

#!/bin/bash

# Build and push Azure-enabled Flink image

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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
REGISTRY="sbxstag.azurecr.io"
IMAGE_NAME="flink-aks"
TAG="2.0.0-scala_2.12-azure"
FULL_IMAGE="${REGISTRY}/${IMAGE_NAME}:${TAG}"

print_status "Building Azure-enabled Flink image: ${FULL_IMAGE}"

# Build the image
docker build -t "${FULL_IMAGE}" .

if [ $? -eq 0 ]; then
    print_status "Image built successfully: ${FULL_IMAGE}"
    
    print_status "Pushing image to registry..."
    docker push "${FULL_IMAGE}"
    
    if [ $? -eq 0 ]; then
        print_status "Image pushed successfully!"
        print_status "You can now deploy the Flink platform with: ../deploy.sh"
    else
        print_error "Failed to push image. Make sure you're logged in to Azure Container Registry:"
        print_error "az acr login --name sbxstag"
        exit 1
    fi
else
    print_error "Failed to build image"
    exit 1
fi

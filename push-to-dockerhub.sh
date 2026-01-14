#!/bin/bash
# ============================================
# Push PayFlow Images to Docker Hub
# ============================================
# Usage: ./push-to-dockerhub.sh <your-dockerhub-username>
# Example: ./push-to-dockerhub.sh johndoe

set -e

# Check if username provided
if [ -z "$1" ]; then
  echo "❌ Error: Docker Hub username required"
  echo "Usage: $0 <your-dockerhub-username>"
  echo "Example: $0 johndoe"
  exit 1
fi

DOCKERHUB_USERNAME="$1"
echo "🚀 Pushing PayFlow images to Docker Hub as: $DOCKERHUB_USERNAME"
echo ""

# List of images to push
IMAGES=(
  "payflow/api-gateway:latest"
  "payflow/auth-service:latest"
  "payflow/wallet-service:latest"
  "payflow/transaction-service:latest"
  "payflow/notification-service:latest"
  "payflow/frontend:latest"
)

# Tag and push each image
for IMAGE in "${IMAGES[@]}"; do
  # Extract image name without payflow/ prefix
  IMAGE_NAME=$(echo "$IMAGE" | sed 's|payflow/||')
  
  # New tag with Docker Hub username
  NEW_TAG="${DOCKERHUB_USERNAME}/${IMAGE_NAME}"
  
  echo "📦 Tagging: $IMAGE -> $NEW_TAG"
  docker tag "$IMAGE" "$NEW_TAG"
  
  echo "⬆️  Pushing: $NEW_TAG"
  docker push "$NEW_TAG"
  
  echo "✅ Successfully pushed: $NEW_TAG"
  echo ""
done

echo "🎉 All images pushed to Docker Hub!"
echo ""
echo "Your images are now available at:"
for IMAGE in "${IMAGES[@]}"; do
  IMAGE_NAME=$(echo "$IMAGE" | sed 's|payflow/||')
  echo "  - docker.io/${DOCKERHUB_USERNAME}/${IMAGE_NAME}:latest"
done


#!/usr/bin/env bash
set -euo pipefail

REGISTRY="${REGISTRY:-zlooezlo}"
BACKEND_IMAGE="$REGISTRY/k8s-homework-backend"
FRONTEND_IMAGE="$REGISTRY/k8s-homework-frontend"

docker build ./backend \
  --build-arg APP_VERSION=v1 \
  --build-arg RELEASE_MESSAGE="initial release" \
  -t "$BACKEND_IMAGE:v1"

docker build ./backend \
  --build-arg APP_VERSION=v2 \
  --build-arg RELEASE_MESSAGE="rolling update completed" \
  -t "$BACKEND_IMAGE:v2"

docker build ./frontend \
  -t "$FRONTEND_IMAGE:v1"

docker push "$BACKEND_IMAGE:v1"
docker push "$BACKEND_IMAGE:v2"
docker push "$FRONTEND_IMAGE:v1"

echo "Built and pushed:"
echo "  $BACKEND_IMAGE:v1"
echo "  $BACKEND_IMAGE:v2"
echo "  $FRONTEND_IMAGE:v1"

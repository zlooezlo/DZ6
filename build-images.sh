#!/usr/bin/env bash
set -euo pipefail

: "${REGISTRY:?Set REGISTRY, for example REGISTRY=registry.example.com/student}"
IMAGE="$REGISTRY/k8s-homework-backend"

docker build ./backend \
  --build-arg APP_VERSION=v1 \
  --build-arg RELEASE_MESSAGE="initial release" \
  -t "$IMAGE:v1"

docker build ./backend \
  --build-arg APP_VERSION=v2 \
  --build-arg RELEASE_MESSAGE="rolling update completed" \
  -t "$IMAGE:v2"

docker push "$IMAGE:v1"
docker push "$IMAGE:v2"

echo "Built and pushed:"
echo "  $IMAGE:v1"
echo "  $IMAGE:v2"

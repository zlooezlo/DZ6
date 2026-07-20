#!/usr/bin/env bash

set -Eeuo pipefail

REGISTRY="${REGISTRY:-zlooezlo}"
PUSH="${PUSH:-false}"

BACKEND_IMAGE="${REGISTRY}/k8s-homework-backend:v3-tls"
FRONTEND_IMAGE="${REGISTRY}/k8s-homework-frontend:v2-tls"

echo "=== Сборка backend TLS ==="

docker build \
  --pull \
  --build-arg APP_VERSION=v3-tls \
  --build-arg RELEASE_MESSAGE='end-to-end TLS release' \
  --tag "$BACKEND_IMAGE" \
  backend

echo
echo "=== Сборка frontend TLS ==="

docker build \
  --pull \
  --tag "$FRONTEND_IMAGE" \
  frontend

echo
echo "=== Проверка непривилегированных пользователей ==="

docker run \
  --rm \
  --entrypoint id \
  "$BACKEND_IMAGE"

docker run \
  --rm \
  --entrypoint id \
  "$FRONTEND_IMAGE"

if test "$PUSH" = "true"; then
  echo
  echo "=== Публикация образов ==="

  docker push "$BACKEND_IMAGE"
  docker push "$FRONTEND_IMAGE"
else
  echo
  echo "INFO: публикация пропущена"
  echo "Для публикации выполните:"
  echo "PUSH=true ./build-images.sh"
fi

echo
echo "PASS: финальные TLS-образы собраны"

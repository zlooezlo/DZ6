#!/usr/bin/env bash
set -Eeuo pipefail

NODE_IP=${NODE_IP:-192.168.56.12}
HTTPS_PORT=${HTTPS_PORT:-30443}
HTTP_PORT=${HTTP_PORT:-30080}
CA_FILE=${CA_FILE:?Укажите CA_FILE, например CA_FILE=./dz6-ca.crt}

echo "=== Проверка внешнего HTTPS ==="
curl --fail --silent --show-error \
  --cacert "${CA_FILE}" \
  --resolve "dz6.local:${HTTPS_PORT}:${NODE_IP}" \
  "https://dz6.local:${HTTPS_PORT}/" \
  | grep 'Kubernetes Homework'

curl --fail --silent --show-error \
  --cacert "${CA_FILE}" \
  --resolve "dz6.local:${HTTPS_PORT}:${NODE_IP}" \
  --request POST \
  "https://dz6.local:${HTTPS_PORT}/api/visits"
echo

echo "=== Проверка TLS backend -> PostgreSQL ==="
curl --fail --silent --show-error \
  --cacert "${CA_FILE}" \
  --resolve "dz6.local:${HTTPS_PORT}:${NODE_IP}" \
  "https://dz6.local:${HTTPS_PORT}/api/db-tls"
echo

echo "=== Проверка отсутствия внешнего HTTP ==="
if curl --silent --show-error --max-time 3 \
  "http://${NODE_IP}:${HTTP_PORT}/" >/dev/null 2>&1; then
  echo "ERROR: HTTP ${HTTP_PORT}/TCP всё ещё доступен" >&2
  exit 1
fi

echo "PASS: внешний HTTP недоступен, HTTPS и TLS к PostgreSQL работают"

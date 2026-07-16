#!/usr/bin/env bash
set -Eeuo pipefail

CHART_VERSION=${CHART_VERSION:-41.0.2}
NAMESPACE=${NAMESPACE:-traefik}
VALUES_FILE=${VALUES_FILE:-infra/traefik-values.yaml}

if [[ ! -f ${VALUES_FILE} ]]; then
  echo "Не найден ${VALUES_FILE}" >&2
  exit 1
fi

helm repo add traefik https://traefik.github.io/charts \
  --force-update
helm repo update traefik

helm upgrade --install traefik traefik/traefik \
  --version "${CHART_VERSION}" \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  --values "${VALUES_FILE}" \
  --wait \
  --timeout 10m

helm list --namespace "${NAMESPACE}"
kubectl get deployment,pod,service \
  --namespace "${NAMESPACE}" \
  --output wide

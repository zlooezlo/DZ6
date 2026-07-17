#!/usr/bin/env bash
set -Eeuo pipefail

test "$(hostname)" = "kube1" || {
  echo "Сценарий необходимо запускать на kube1" >&2
  exit 1
}

MANIFEST_DIR=${MANIFEST_DIR:-"${HOME}"}
TRAEFIK_VALUES=${TRAEFIK_VALUES:-"${HOME}/traefik-values.yaml"}

for secret in dz6-external-tls dz6-ca frontend-tls backend-tls postgres-tls; do
  kubectl get secret "${secret}" --namespace homework >/dev/null
done

kubectl apply --dry-run=server \
  -f "${MANIFEST_DIR}/postgres-tls-config.yaml" \
  -f "${MANIFEST_DIR}/postgres-statefulset.yaml" \
  -f "${MANIFEST_DIR}/backend-configmap.yaml" \
  -f "${MANIFEST_DIR}/backend-service.yaml" \
  -f "${MANIFEST_DIR}/backend-deployment.yaml" \
  -f "${MANIFEST_DIR}/frontend-service.yaml" \
  -f "${MANIFEST_DIR}/frontend-deployment.yaml" \
  -f "${MANIFEST_DIR}/frontend-servers-transport.yaml" \
  -f "${MANIFEST_DIR}/frontend-ingress.yaml" \
  -f "${MANIFEST_DIR}/network-policies.yaml"

kubectl apply \
  -f "${MANIFEST_DIR}/postgres-tls-config.yaml" \
  -f "${MANIFEST_DIR}/postgres-statefulset.yaml" \
  -f "${MANIFEST_DIR}/backend-configmap.yaml" \
  -f "${MANIFEST_DIR}/backend-service.yaml" \
  -f "${MANIFEST_DIR}/backend-deployment.yaml" \
  -f "${MANIFEST_DIR}/frontend-service.yaml" \
  -f "${MANIFEST_DIR}/frontend-deployment.yaml" \
  -f "${MANIFEST_DIR}/frontend-servers-transport.yaml" \
  -f "${MANIFEST_DIR}/frontend-ingress.yaml" \
  -f "${MANIFEST_DIR}/network-policies.yaml"

helm repo add traefik https://traefik.github.io/charts \
  --force-update
helm repo update traefik

helm upgrade --install traefik traefik/traefik \
  --version 41.0.2 \
  --namespace traefik \
  --create-namespace \
  --values "${TRAEFIK_VALUES}" \
  --wait \
  --timeout 10m

kubectl rollout status statefulset/postgres \
  --namespace homework \
  --timeout=300s
kubectl rollout status deployment/backend \
  --namespace homework \
  --timeout=300s
kubectl rollout status deployment/frontend \
  --namespace homework \
  --timeout=300s

kubectl get deployment,statefulset,pod,service,ingress \
  --namespace homework \
  --output wide
kubectl get service traefik \
  --namespace traefik

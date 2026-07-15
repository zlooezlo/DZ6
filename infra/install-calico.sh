#!/usr/bin/env bash
set -Eeuo pipefail

CALICO_VERSION="v3.32.1"
MANIFEST="$(mktemp)"
trap 'rm -f "$MANIFEST"' EXIT

command -v kubectl >/dev/null
command -v curl >/dev/null

echo "Installing Calico ${CALICO_VERSION}"
curl -fsSL \
  "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml" \
  -o "$MANIFEST"

kubectl apply -f "$MANIFEST"

# All VirtualBox guests have the same NAT address. Reuse the Kubernetes
# InternalIP so Calico routes node-to-node traffic over the Host-only network.
kubectl set env daemonset/calico-node -n kube-system \
  IP_AUTODETECTION_METHOD=kubernetes-internal-ip

kubectl rollout status daemonset/calico-node -n kube-system --timeout=300s
kubectl rollout status deployment/calico-kube-controllers -n kube-system \
  --timeout=300s

kubectl get nodes -o wide
kubectl get pods -A -o wide

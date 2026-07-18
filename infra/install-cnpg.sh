#!/usr/bin/env bash
set -Eeuo pipefail

CNPG_VERSION="${CNPG_VERSION:-1.30.0}"
MANIFEST_URL="https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.30/releases/cnpg-${CNPG_VERSION}.yaml"
EXPECTED_SHA256="f8bede43fe4ee0d478c2355b204a36876b2ae4faac60f2a9452280b293da3b88"

TMP_MANIFEST=$(mktemp)
trap 'rm -f "$TMP_MANIFEST"' EXIT

curl --fail --silent --show-error --location \
  "$MANIFEST_URL" \
  --output "$TMP_MANIFEST"

ACTUAL_SHA256=$(sha256sum "$TMP_MANIFEST" | awk '{print $1}')

if [[ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]]; then
  printf 'ERROR: SHA256 CNPG manifest does not match\n' >&2
  printf 'expected=%s\nactual=%s\n' "$EXPECTED_SHA256" "$ACTUAL_SHA256" >&2
  exit 1
fi

kubectl apply --server-side --field-manager=dz6-cnpg-installer \
  --filename "$TMP_MANIFEST"

kubectl rollout status deployment/cnpg-controller-manager \
  --namespace cnpg-system \
  --timeout=300s

kubectl wait --for=condition=Established \
  crd/clusters.postgresql.cnpg.io \
  --timeout=180s

kubectl get deployment,pod --namespace cnpg-system --output=wide
printf 'PASS: CloudNativePG %s installed\n' "$CNPG_VERSION"

#!/usr/bin/env bash

set -Eeuo pipefail
set +x

test "$(hostname)" = "kube1" || {
  echo "STOP: сценарий необходимо выполнять на kube1"
  exit 1
}

VAULT_NAMESPACE="${VAULT_NAMESPACE:-vault}"
VAULT_POD="${VAULT_POD:-vault-0}"
APP_NAMESPACE="${APP_NAMESPACE:-homework}"
INIT_FILE="${INIT_FILE:-$HOME/vault-init.json}"

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPOSITORY_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
RBAC_FILE="${RBAC_FILE:-$REPOSITORY_DIR/k8s/vault-auth-rbac.yaml}"

test -s "$RBAC_FILE" || {
  echo "STOP: отсутствует $RBAC_FILE"
  exit 1
}

test -s "$INIT_FILE" || {
  echo "STOP: отсутствует $INIT_FILE"
  exit 1
}

test "$(stat -c '%a' "$INIT_FILE")" = "600" || {
  echo "STOP: файл $INIT_FILE должен иметь права 0600"
  exit 1
}

echo "=== Применение ServiceAccount и TokenReview RBAC ==="

kubectl apply \
  -f "$RBAC_FILE"

kubectl exec \
  -n "$VAULT_NAMESPACE" \
  "$VAULT_POD" -- \
  env \
    VAULT_ADDR=https://127.0.0.1:8200 \
    VAULT_SKIP_VERIFY=true \
    vault status \
  >/dev/null

ROOT_TOKEN=$(python3 -c '
import json
import sys

with open(sys.argv[1], encoding="utf-8") as file:
    data = json.load(file)

token = data.get("root_token")

if not token:
    raise SystemExit("STOP: root_token не найден")

print(token)
' "$INIT_FILE")

printf '%s' "$ROOT_TOKEN" \
  | kubectl exec \
      -i \
      -n "$VAULT_NAMESPACE" \
      "$VAULT_POD" -- \
      sh -c '
        umask 077
        cat > /tmp/dz6-root-token
        chmod 0600 /tmp/dz6-root-token
      '

unset ROOT_TOKEN

cleanup_token() {
  kubectl exec \
    -n "$VAULT_NAMESPACE" \
    "$VAULT_POD" -- \
    rm -f /tmp/dz6-root-token \
    >/dev/null 2>&1 || true
}

trap cleanup_token EXIT

echo
echo "=== Настройка Vault ==="

kubectl exec \
  -i \
  -n "$VAULT_NAMESPACE" \
  "$VAULT_POD" -- \
  sh -ceu '
    export VAULT_ADDR=https://127.0.0.1:8200
    export VAULT_SKIP_VERIFY=true
    export VAULT_TOKEN
    VAULT_TOKEN=$(cat /tmp/dz6-root-token)

    if vault secrets list -format=json | grep -q "\"dz6/\""; then
      echo "INFO: KV v2 mount dz6 уже существует"
    else
      vault secrets enable \
        -path=dz6 \
        -version=2 \
        kv

      echo "PASS: KV v2 mount dz6 создан"
    fi

    if vault auth list -format=json | grep -q "\"kubernetes/\""; then
      echo "INFO: Kubernetes Auth уже включён"
    else
      vault auth enable kubernetes
      echo "PASS: Kubernetes Auth включён"
    fi

    vault write \
      auth/kubernetes/config \
      token_reviewer_jwt="" \
      kubernetes_ca_cert="" \
      kubernetes_host=https://kubernetes.default.svc:443 \
      disable_local_ca_jwt=false \
      disable_iss_validation=true \
      >/dev/null

    echo "PASS: Kubernetes Auth настроен"

    vault policy write homework-db-read - <<POLICY
path "dz6/data/homework/database" {
  capabilities = ["read"]
}

path "dz6/metadata/homework/database" {
  capabilities = ["read"]
}
POLICY

    echo "PASS: policy homework-db-read создана"

    vault write \
      auth/kubernetes/role/homework-backend \
      bound_service_account_names=vault-auth \
      bound_service_account_namespaces=homework \
      audience=vault \
      policies=homework-db-read \
      ttl=10m \
      token_max_ttl=30m \
      >/dev/null

    echo "PASS: role homework-backend создана"

    unset VAULT_TOKEN
  '

echo
echo "=== Проверка несекретных параметров ==="

kubectl get serviceaccount vault-auth \
  -n "$APP_NAMESPACE"

kubectl get clusterrolebinding vault-tokenreview

kubectl exec \
  -n "$VAULT_NAMESPACE" \
  "$VAULT_POD" -- \
  sh -ceu '
    export VAULT_ADDR=https://127.0.0.1:8200
    export VAULT_SKIP_VERIFY=true
    export VAULT_TOKEN
    VAULT_TOKEN=$(cat /tmp/dz6-root-token)

    vault read auth/kubernetes/role/homework-backend

    unset VAULT_TOKEN
  '

cleanup_token
trap - EXIT

echo
echo "PASS: Kubernetes Auth, policy и role Vault настроены"

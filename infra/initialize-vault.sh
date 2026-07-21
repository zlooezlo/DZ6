#!/usr/bin/env bash

set -Eeuo pipefail
set +x

test "$(hostname)" = "kube1" || {
  echo "STOP: сценарий необходимо выполнять на kube1"
  exit 1
}

VAULT_NAMESPACE="${VAULT_NAMESPACE:-vault}"
VAULT_POD="${VAULT_POD:-vault-0}"
INIT_FILE="${INIT_FILE:-$HOME/vault-init.json}"

command -v kubectl >/dev/null 2>&1 || {
  echo "STOP: kubectl не найден"
  exit 1
}

command -v python3 >/dev/null 2>&1 || {
  echo "STOP: python3 не найден"
  exit 1
}

kubectl wait \
  --for=jsonpath='{.status.phase}'=Running \
  "pod/$VAULT_POD" \
  -n "$VAULT_NAMESPACE" \
  --timeout=300s

STATUS_JSON=$(kubectl exec \
  -n "$VAULT_NAMESPACE" \
  "$VAULT_POD" -- \
  env \
    VAULT_ADDR=https://127.0.0.1:8200 \
    VAULT_SKIP_VERIFY=true \
    vault status \
      -format=json \
  2>/dev/null || true)

test -n "$STATUS_JSON" || {
  echo "STOP: не удалось получить состояние Vault"
  exit 1
}

INITIALIZED=$(python3 -c '
import json
import sys

data = json.load(sys.stdin)
print(str(data["initialized"]).lower())
' <<<"$STATUS_JSON")

if test "$INITIALIZED" = "false"; then
  test ! -e "$INIT_FILE" || {
    echo "STOP: Vault не инициализирован, но $INIT_FILE уже существует"
    exit 1
  }

  umask 077

  TEMP_FILE=$(mktemp "$HOME/.vault-init.XXXXXX")

  cleanup_temp() {
    rm -f "$TEMP_FILE"
  }

  trap cleanup_temp EXIT

  echo "=== Инициализация Vault: shares=3, threshold=2 ==="

  kubectl exec \
    -n "$VAULT_NAMESPACE" \
    "$VAULT_POD" -- \
    env \
      VAULT_ADDR=https://127.0.0.1:8200 \
      VAULT_SKIP_VERIFY=true \
      vault operator init \
        -key-shares=3 \
        -key-threshold=2 \
        -format=json \
    >"$TEMP_FILE"

  chmod 0600 "$TEMP_FILE"
  mv "$TEMP_FILE" "$INIT_FILE"
  trap - EXIT

  echo "PASS: recovery material сохранён в $INIT_FILE с правами 0600"
else
  echo "INFO: Vault уже инициализирован"
fi

test -s "$INIT_FILE" || {
  echo "STOP: отсутствует $INIT_FILE"
  exit 1
}

test "$(stat -c '%a' "$INIT_FILE")" = "600" || {
  echo "STOP: файл $INIT_FILE должен иметь права 0600"
  exit 1
}

python3 -c '
import json
import sys

with open(sys.argv[1], encoding="utf-8") as file:
    data = json.load(file)

keys = data.get("unseal_keys_b64", [])
threshold = data.get("unseal_threshold")

if len(keys) < 2:
    raise SystemExit("STOP: найдено менее двух unseal-ключей")

if threshold != 2:
    raise SystemExit(f"STOP: неожиданный threshold={threshold}")

print(f"PASS: recovery material корректен, shares={len(keys)}, threshold={threshold}")
' "$INIT_FILE"

STATUS_JSON=$(kubectl exec \
  -n "$VAULT_NAMESPACE" \
  "$VAULT_POD" -- \
  env \
    VAULT_ADDR=https://127.0.0.1:8200 \
    VAULT_SKIP_VERIFY=true \
    vault status \
      -format=json \
  2>/dev/null || true)

SEALED=$(python3 -c '
import json
import sys

data = json.load(sys.stdin)
print(str(data["sealed"]).lower())
' <<<"$STATUS_JSON")

if test "$SEALED" = "true"; then
  set -o pipefail

  for INDEX in 0 1; do
    echo "=== Передача unseal key $((INDEX + 1)) из 2 ==="

    python3 -c '
import json
import sys

with open(sys.argv[1], encoding="utf-8") as file:
    data = json.load(file)

print(data["unseal_keys_b64"][int(sys.argv[2])])
' "$INIT_FILE" "$INDEX" \
      | kubectl exec \
          -i \
          -n "$VAULT_NAMESPACE" \
          "$VAULT_POD" -- \
          sh -c '
            IFS= read -r unseal_key

            VAULT_ADDR=https://127.0.0.1:8200 \
            VAULT_SKIP_VERIFY=true \
              vault operator unseal "$unseal_key" \
              >/dev/null

            unset unseal_key
          '

    echo "PASS: unseal key $((INDEX + 1)) принят"
  done
else
  echo "INFO: Vault уже распечатан"
fi

echo
echo "=== Итоговое состояние Vault ==="

kubectl exec \
  -n "$VAULT_NAMESPACE" \
  "$VAULT_POD" -- \
  env \
    VAULT_ADDR=https://127.0.0.1:8200 \
    VAULT_SKIP_VERIFY=true \
    vault status

kubectl wait \
  --for=condition=Ready \
  "pod/$VAULT_POD" \
  -n "$VAULT_NAMESPACE" \
  --timeout=180s

echo
echo "PASS: Vault инициализирован, распечатан и готов"

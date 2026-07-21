#!/usr/bin/env bash

set -Eeuo pipefail

test "$(hostname)" = "kube1" || {
  echo "STOP: сценарий необходимо выполнять на kube1"
  exit 1
}

VAULT_NAMESPACE="${VAULT_NAMESPACE:-vault}"
APP_NAMESPACE="${APP_NAMESPACE:-homework}"
CA_DIR="${CA_DIR:-$HOME/dz6-pki}"
TLS_DIR="${TLS_DIR:-$CA_DIR/vault}"
CERT_DAYS="${CERT_DAYS:-825}"

for COMMAND in kubectl openssl; do
  command -v "$COMMAND" >/dev/null 2>&1 || {
    echo "STOP: команда $COMMAND не найдена"
    exit 1
  }
done

test -s "$CA_DIR/ca.crt" || {
  echo "STOP: отсутствует $CA_DIR/ca.crt"
  exit 1
}

test -s "$CA_DIR/ca.key" || {
  echo "STOP: отсутствует $CA_DIR/ca.key"
  exit 1
}

umask 077

install -d \
  -m 0700 \
  "$TLS_DIR"

CONFIG_FILE="$TLS_DIR/vault-openssl.cnf"
KEY_FILE="$TLS_DIR/vault.key"
CSR_FILE="$TLS_DIR/vault.csr"
CERT_FILE="$TLS_DIR/vault.crt"

cat >"$CONFIG_FILE" <<'CONFIG'
[req]
prompt = no
distinguished_name = distinguished_name
req_extensions = request_extensions

[distinguished_name]
CN = vault.vault.svc.cluster.local
O = DZ6

[request_extensions]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @subject_alt_names

[subject_alt_names]
DNS.1 = vault
DNS.2 = vault.vault
DNS.3 = vault.vault.svc
DNS.4 = vault.vault.svc.cluster.local
DNS.5 = vault-internal
DNS.6 = vault-internal.vault
DNS.7 = vault-internal.vault.svc
DNS.8 = vault-internal.vault.svc.cluster.local
CONFIG

if test -e "$KEY_FILE" || test -e "$CERT_FILE"; then
  test -s "$KEY_FILE" && test -s "$CERT_FILE" || {
    echo "STOP: найден только один из файлов vault.key или vault.crt"
    exit 1
  }

  echo "INFO: используется существующий сертификат Vault"
else
  echo "=== Создание закрытого ключа Vault ==="

  openssl genpkey \
    -algorithm RSA \
    -pkeyopt rsa_keygen_bits:3072 \
    -out "$KEY_FILE"

  chmod 0600 "$KEY_FILE"

  echo "=== Создание CSR Vault ==="

  openssl req \
    -new \
    -key "$KEY_FILE" \
    -out "$CSR_FILE" \
    -config "$CONFIG_FILE"

  echo "=== Выпуск сертификата Vault ==="

  openssl x509 \
    -req \
    -in "$CSR_FILE" \
    -CA "$CA_DIR/ca.crt" \
    -CAkey "$CA_DIR/ca.key" \
    -CAcreateserial \
    -out "$CERT_FILE" \
    -days "$CERT_DAYS" \
    -sha256 \
    -extfile "$CONFIG_FILE" \
    -extensions request_extensions

  chmod 0600 "$CSR_FILE"
  chmod 0644 "$CERT_FILE"
fi

echo
echo "=== Проверка сертификата Vault ==="

openssl verify \
  -CAfile "$CA_DIR/ca.crt" \
  "$CERT_FILE"

openssl x509 \
  -in "$CERT_FILE" \
  -noout \
  -checkhost vault.vault.svc.cluster.local

openssl x509 \
  -in "$CERT_FILE" \
  -noout \
  -subject \
  -issuer \
  -dates \
  -fingerprint \
  -sha256 \
  -ext subjectAltName

echo
echo "=== Создание namespace ==="

kubectl create namespace "$VAULT_NAMESPACE" \
  --dry-run=client \
  -o yaml \
  | kubectl apply -f -

kubectl create namespace "$APP_NAMESPACE" \
  --dry-run=client \
  -o yaml \
  | kubectl apply -f -

echo
echo "=== Создание TLS Secret Vault ==="

kubectl create secret generic vault-server-tls \
  -n "$VAULT_NAMESPACE" \
  --from-file=vault.crt="$CERT_FILE" \
  --from-file=vault.key="$KEY_FILE" \
  --from-file=vault.ca="$CA_DIR/ca.crt" \
  --dry-run=client \
  -o yaml \
  | kubectl apply -f -

echo
echo "=== Создание CA Secret для VSO ==="

kubectl create secret generic vault-ca \
  -n "$APP_NAMESPACE" \
  --from-file=ca.crt="$CA_DIR/ca.crt" \
  --dry-run=client \
  -o yaml \
  | kubectl apply -f -

echo
echo "=== Проверка Secret без вывода значений ==="

kubectl get secret \
  vault-server-tls \
  -n "$VAULT_NAMESPACE"

kubectl get secret \
  vault-ca \
  -n "$APP_NAMESPACE"

echo
echo "PASS: TLS-секреты Vault созданы без сохранения ключей в Git"

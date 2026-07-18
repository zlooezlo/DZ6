#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

NAMESPACE="${NAMESPACE:-homework}"
CA_DIR="${CA_DIR:-$HOME/dz6-pki}"
TLS_DIR="${TLS_DIR:-$CA_DIR/postgres-ha}"
CA_CERT="$CA_DIR/ca.crt"
CA_KEY="$CA_DIR/ca.key"
SERVER_KEY="$TLS_DIR/postgres-ha.key"
SERVER_CSR="$TLS_DIR/postgres-ha.csr"
SERVER_CERT="$TLS_DIR/postgres-ha.crt"
OPENSSL_CONFIG="$TLS_DIR/postgres-ha-openssl.cnf"

for REQUIRED in "$CA_CERT" "$CA_KEY"; do
  if [[ ! -s "$REQUIRED" ]]; then
    printf 'ERROR: required CA file not found: %s\n' "$REQUIRED" >&2
    exit 1
  fi
done

install --directory --mode 0700 "$TLS_DIR"

cat >"$OPENSSL_CONFIG" <<'EOF'
[req]
prompt = no
distinguished_name = dn
req_extensions = req_ext

[dn]
CN = postgres-ha-rw.homework.svc.cluster.local
O = DZ6

[req_ext]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = postgres-ha-rw
DNS.2 = postgres-ha-rw.homework
DNS.3 = postgres-ha-rw.homework.svc
DNS.4 = postgres-ha-rw.homework.svc.cluster.local
DNS.5 = postgres-ha-ro
DNS.6 = postgres-ha-ro.homework
DNS.7 = postgres-ha-ro.homework.svc
DNS.8 = postgres-ha-ro.homework.svc.cluster.local
DNS.9 = postgres-ha-r
DNS.10 = postgres-ha-r.homework
DNS.11 = postgres-ha-r.homework.svc
DNS.12 = postgres-ha-r.homework.svc.cluster.local
EOF

openssl genpkey \
  -algorithm RSA \
  -pkeyopt rsa_keygen_bits:3072 \
  -out "$SERVER_KEY"

openssl req \
  -new \
  -key "$SERVER_KEY" \
  -config "$OPENSSL_CONFIG" \
  -out "$SERVER_CSR"

SERIAL="0x$(openssl rand -hex 16)"

openssl x509 \
  -req \
  -in "$SERVER_CSR" \
  -CA "$CA_CERT" \
  -CAkey "$CA_KEY" \
  -set_serial "$SERIAL" \
  -days 825 \
  -sha256 \
  -extensions req_ext \
  -extfile "$OPENSSL_CONFIG" \
  -out "$SERVER_CERT"

chmod 0600 "$SERVER_KEY"
chmod 0644 "$SERVER_CERT"

openssl verify -CAfile "$CA_CERT" "$SERVER_CERT"
openssl x509 -in "$SERVER_CERT" -noout \
  -subject -issuer -dates -serial -fingerprint -sha256 -ext subjectAltName
openssl x509 -in "$SERVER_CERT" -noout \
  -checkhost postgres-ha-rw.homework.svc.cluster.local

kubectl create secret generic postgres-ha-server-ca \
  --namespace "$NAMESPACE" \
  --from-file=ca.crt="$CA_CERT" \
  --dry-run=client \
  --output=yaml \
  | kubectl apply --filename -

kubectl create secret tls postgres-ha-server-tls \
  --namespace "$NAMESPACE" \
  --cert="$SERVER_CERT" \
  --key="$SERVER_KEY" \
  --dry-run=client \
  --output=yaml \
  | kubectl apply --filename -

DB_PASSWORD=$(kubectl get secret app-db-secret \
  --namespace "$NAMESPACE" \
  --output=jsonpath='{.data.DB_PASSWORD}' \
  | base64 --decode)

if [[ -z "$DB_PASSWORD" ]]; then
  printf 'ERROR: DB_PASSWORD could not be read\n' >&2
  exit 1
fi

kubectl create secret generic postgres-ha-app \
  --namespace "$NAMESPACE" \
  --type=kubernetes.io/basic-auth \
  --from-literal=username=app \
  --from-literal=password="$DB_PASSWORD" \
  --dry-run=client \
  --output=yaml \
  | kubectl apply --filename -

unset DB_PASSWORD
printf 'PASS: CNPG TLS and application secrets created\n'

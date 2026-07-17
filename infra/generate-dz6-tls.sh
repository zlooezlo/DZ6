#!/usr/bin/env bash
set -Eeuo pipefail

EXPECTED_HOSTNAME=${EXPECTED_HOSTNAME:-kube1}
APPLY_SECRETS=${APPLY_SECRETS:-true}

test "$(hostname)" = "${EXPECTED_HOSTNAME}" || {
  echo "Сценарий необходимо запускать на ${EXPECTED_HOSTNAME}" >&2
  exit 1
}

command -v openssl >/dev/null
if [[ ${APPLY_SECRETS} == true ]]; then
  command -v kubectl >/dev/null
fi

umask 077
PKI_DIR=${PKI_DIR:-"${HOME}/dz6-pki"}

if [[ -e ${PKI_DIR} ]]; then
  echo "Каталог ${PKI_DIR} уже существует." >&2
  echo "Для плановой ротации задайте новый PKI_DIR." >&2
  exit 1
fi

install -d -m 0700 "${PKI_DIR}"

openssl genrsa -out "${PKI_DIR}/ca.key" 4096
openssl req -x509 -new -sha256 -days 3650 \
  -key "${PKI_DIR}/ca.key" \
  -out "${PKI_DIR}/ca.crt" \
  -subj "/CN=DZ6 Internal CA/O=DZ6"

issue_server_certificate() {
  local name=$1
  local common_name=$2
  local sans=$3
  local extension_file="${PKI_DIR}/${name}.ext"

  openssl genrsa -out "${PKI_DIR}/${name}.key" 3072
  openssl req -new -sha256 \
    -key "${PKI_DIR}/${name}.key" \
    -out "${PKI_DIR}/${name}.csr" \
    -subj "/CN=${common_name}/O=DZ6"

  cat >"${extension_file}" <<EOF
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=${sans}
EOF

  openssl x509 -req -sha256 -days 825 \
    -in "${PKI_DIR}/${name}.csr" \
    -CA "${PKI_DIR}/ca.crt" \
    -CAkey "${PKI_DIR}/ca.key" \
    -CAcreateserial \
    -out "${PKI_DIR}/${name}.crt" \
    -extfile "${extension_file}"

  rm -f "${PKI_DIR}/${name}.csr" "${extension_file}"
  chmod 0600 "${PKI_DIR}/${name}.key"
  chmod 0644 "${PKI_DIR}/${name}.crt"
}

issue_server_certificate \
  external \
  dz6.local \
  'DNS:dz6.local'

issue_server_certificate \
  frontend \
  frontend.homework.svc.cluster.local \
  'DNS:frontend,DNS:frontend.homework,DNS:frontend.homework.svc,DNS:frontend.homework.svc.cluster.local'

issue_server_certificate \
  backend \
  backend.homework.svc.cluster.local \
  'DNS:backend,DNS:backend.homework,DNS:backend.homework.svc,DNS:backend.homework.svc.cluster.local'

issue_server_certificate \
  postgres \
  postgres.homework.svc.cluster.local \
  'DNS:postgres,DNS:postgres.homework,DNS:postgres.homework.svc,DNS:postgres.homework.svc.cluster.local,DNS:postgres-headless,DNS:postgres-headless.homework.svc.cluster.local,DNS:postgres-0.postgres-headless.homework.svc.cluster.local'

for certificate in external frontend backend postgres; do
  openssl verify \
    -CAfile "${PKI_DIR}/ca.crt" \
    "${PKI_DIR}/${certificate}.crt"
done

if [[ ${APPLY_SECRETS} != true ]]; then
  echo
  echo "Сертификаты выпущены без создания Kubernetes Secrets."
  echo "PKI: ${PKI_DIR}"
  exit 0
fi

kubectl create namespace homework \
  --dry-run=client \
  -o yaml \
  | kubectl apply -f -

kubectl create secret tls dz6-external-tls \
  --namespace homework \
  --cert="${PKI_DIR}/external.crt" \
  --key="${PKI_DIR}/external.key" \
  --dry-run=client \
  -o yaml \
  | kubectl apply -f -

kubectl create secret generic dz6-ca \
  --namespace homework \
  --from-file=ca.crt="${PKI_DIR}/ca.crt" \
  --dry-run=client \
  -o yaml \
  | kubectl apply -f -

for component in frontend backend postgres; do
  kubectl create secret generic "${component}-tls" \
    --namespace homework \
    --from-file=tls.crt="${PKI_DIR}/${component}.crt" \
    --from-file=tls.key="${PKI_DIR}/${component}.key" \
    --from-file=ca.crt="${PKI_DIR}/ca.crt" \
    --dry-run=client \
    -o yaml \
    | kubectl apply -f -
done

kubectl label secret \
  dz6-external-tls dz6-ca frontend-tls backend-tls postgres-tls \
  --namespace homework \
  app.kubernetes.io/part-of=dz6 \
  --overwrite

echo
echo "Сертификаты выпущены и Secrets применены."
echo "PKI: ${PKI_DIR}"
echo "CA для клиентской проверки: ${PKI_DIR}/ca.crt"
echo "Приватные ключи не копировать в Git."

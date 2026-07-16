#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Запустите скрипт через sudo" >&2
  exit 1
fi

CRIO_MINOR=${CRIO_MINOR:-v1.33}
CRIO_PACKAGE_VERSION=${CRIO_PACKAGE_VERSION:-1.33.13-1.1}
KUBELET_FLAGS=/var/lib/kubelet/kubeadm-flags.env
KUBELET_FLAGS_BACKUP=${KUBELET_FLAGS}.containerd-backup
CRIO_SOCKET=unix:///var/run/crio/crio.sock

if [[ ! -f ${KUBELET_FLAGS} ]]; then
  echo "Не найден ${KUBELET_FLAGS}" >&2
  exit 1
fi

apt-get update
apt-get install -y ca-certificates curl gpg

install -d -m 0755 /etc/apt/keyrings

curl -fsSL \
  "https://download.opensuse.org/repositories/isv:/cri-o:/stable:/${CRIO_MINOR}/deb/Release.key" \
  | gpg --batch --yes --dearmor \
      -o /etc/apt/keyrings/cri-o-apt-keyring.gpg

echo \
  "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://download.opensuse.org/repositories/isv:/cri-o:/stable:/${CRIO_MINOR}/deb/ /" \
  > /etc/apt/sources.list.d/cri-o.list

apt-get update
apt-get install -y "cri-o=${CRIO_PACKAGE_VERSION}"
apt-mark hold cri-o
systemctl enable --now crio

if [[ ! -e ${KUBELET_FLAGS_BACKUP} ]]; then
  install -m 0644 "${KUBELET_FLAGS}" "${KUBELET_FLAGS_BACKUP}"
fi

sed -i \
  "s|unix:///run/containerd/containerd.sock|${CRIO_SOCKET}|g" \
  "${KUBELET_FLAGS}"

if ! grep -q "${CRIO_SOCKET}" "${KUBELET_FLAGS}"; then
  echo "Endpoint kubelet не изменён" >&2
  exit 1
fi

cat > /etc/crictl.yaml <<EOF
runtime-endpoint: ${CRIO_SOCKET}
image-endpoint: ${CRIO_SOCKET}
timeout: 10
debug: false
EOF

crio --version
crictl version

cat <<'EOF'

Подготовка CRI-O завершена. Скрипт намеренно не останавливает действующий
runtime. Перед переключением:

1. Выполните drain узла с control plane.
2. Остановите kubelet.
3. Отключите containerd: systemctl disable --now containerd.
4. Перезагрузите узел.
5. Проверьте Ready, системные DaemonSet Pod, DNS и CNI.
6. Выполните uncordon только после успешных проверок.
EOF

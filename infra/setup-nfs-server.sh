#!/usr/bin/env bash

set -Eeuo pipefail

NFS_EXPORT_PATH="${NFS_EXPORT_PATH:-/srv/nfs/k8s}"
NFS_CLIENT_CIDR="${NFS_CLIENT_CIDR:-192.168.56.0/24}"
EXPORT_FILE="/etc/exports.d/kubernetes.exports"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Запустите скрипт через sudo: sudo $0" >&2
  exit 1
fi

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y nfs-kernel-server nfs-common

install -d -o nobody -g nogroup -m 0777 "${NFS_EXPORT_PATH}"
install -d -m 0755 /etc/exports.d

printf '%s %s(rw,sync,no_subtree_check)\n' \
  "${NFS_EXPORT_PATH}" \
  "${NFS_CLIENT_CIDR}" >"${EXPORT_FILE}"

exportfs -rav
systemctl enable --now nfs-server

systemctl is-active --quiet nfs-server
exportfs -v

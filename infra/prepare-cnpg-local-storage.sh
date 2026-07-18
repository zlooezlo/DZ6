#!/usr/bin/env bash
set -Eeuo pipefail

readonly DATA_DIR="${CNPG_DATA_DIR:-/var/lib/cnpg/postgres-ha}"
readonly POSTGRES_UID="${POSTGRES_UID:-26}"
readonly POSTGRES_GID="${POSTGRES_GID:-102}"

if [[ $EUID -ne 0 ]]; then
  printf 'Run this script as root on kube1, kube2 and kube3.\n' >&2
  exit 1
fi

NODE=$(hostname -s)

case "$NODE" in
  kube1|kube2|kube3) ;;
  *)
    printf 'ERROR: unsupported node: %s\n' "$NODE" >&2
    exit 1
    ;;
esac

install --directory \
  --owner "$POSTGRES_UID" \
  --group "$POSTGRES_GID" \
  --mode 0700 \
  "$DATA_DIR"

stat --format='path=%n uid=%u gid=%g mode=%a' "$DATA_DIR"
df --human-readable "$DATA_DIR"
printf 'PASS: local CNPG directory prepared on %s\n' "$NODE"

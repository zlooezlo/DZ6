#!/usr/bin/env bash
set -Eeuo pipefail

NAMESPACE="${NAMESPACE:-homework}"
CLUSTER="${CLUSTER:-postgres-ha}"

PRIMARY=$(kubectl get cluster "$CLUSTER" \
  --namespace "$NAMESPACE" \
  --output=jsonpath='{.status.currentPrimary}')
READY_INSTANCES=$(kubectl get cluster "$CLUSTER" \
  --namespace "$NAMESPACE" \
  --output=jsonpath='{.status.readyInstances}')

[[ -n "$PRIMARY" ]] || { printf 'FAIL: primary is not set\n' >&2; exit 1; }
[[ "$READY_INSTANCES" == "3" ]] || {
  printf 'FAIL: expected 3 ready instances, got %s\n' "$READY_INSTANCES" >&2
  exit 1
}

printf 'primary=%s\nreadyInstances=%s\n' "$PRIMARY" "$READY_INSTANCES"

kubectl get cluster "$CLUSTER" --namespace "$NAMESPACE" --output=wide
kubectl get pods --namespace "$NAMESPACE" \
  --selector="cnpg.io/cluster=$CLUSTER" \
  --label-columns=cnpg.io/instanceRole \
  --output=wide

printf '\n=== Synchronous replication ===\n'
kubectl exec --namespace "$NAMESPACE" "$PRIMARY" --container postgres -- \
  psql -U postgres -d app -x -c '
    SELECT application_name, client_addr, state, sync_state,
           write_lsn, flush_lsn, replay_lsn
    FROM pg_stat_replication
    ORDER BY application_name;
  '

kubectl exec --namespace "$NAMESPACE" "$PRIMARY" --container postgres -- \
  psql -U postgres -d app -c '
    SHOW synchronous_standby_names;
    SHOW synchronous_commit;
    SHOW ssl;
    SHOW ssl_min_protocol_version;
  '

printf '\n=== Data on all instances ===\n'
while read -r POD; do
  printf '%s: ' "$POD"
  kubectl exec --namespace "$NAMESPACE" "$POD" --container postgres -- \
    psql -U postgres -d app -At -F '|' -c '
      SELECT pg_is_in_recovery(), COUNT(*), COALESCE(MAX(id), 0),
             (SELECT COUNT(*) FROM persistence_proof)
      FROM visits;
    '
done < <(kubectl get pods --namespace "$NAMESPACE" \
  --selector="cnpg.io/cluster=$CLUSTER" \
  --output=name | sort)

kubectl get cronjob,pvc --namespace "$NAMESPACE" \
  --selector=app.kubernetes.io/name=postgres-ha-backup

printf 'PASS: PostgreSQL HA verification completed\n'

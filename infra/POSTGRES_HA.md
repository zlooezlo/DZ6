# PostgreSQL HA

CloudNativePG 1.30.0 manages three PostgreSQL 15.18 instances. Each instance
uses a static local PV on a different Kubernetes node. The database uses quorum
synchronous replication (`ANY 1`) and requires at least one synchronous standby
to confirm a commit.

## Components

- `install-cnpg.sh` installs the pinned CNPG operator after SHA256 validation.
- `prepare-cnpg-local-storage.sh` prepares the local data directory on each node.
- `generate-postgres-ha-tls.sh` creates a server certificate signed by the
  existing DZ6 CA and writes only Kubernetes Secrets, never secret material to Git.
- `k8s/cnpg-local-storage.yaml` defines the StorageClass and three node-bound PVs.
- `k8s/postgres-ha-cluster.yaml` defines the three-instance CNPG cluster.
- `k8s/postgres-ha-networkpolicy.yaml` contains least-privilege network rules.
- `k8s/postgres-ha-backup.yaml` creates a daily logical backup on a separate NFS PVC.
- `verify-postgres-ha.sh` performs non-mutating health, replication and data checks.

## Deployment order

1. Run `prepare-cnpg-local-storage.sh` with `sudo` on kube1, kube2 and kube3.
2. Run `install-cnpg.sh` on kube1.
3. Apply `k8s/cnpg-local-storage.yaml`.
4. Run `generate-postgres-ha-tls.sh` on kube1.
5. Apply NetworkPolicy and the CNPG Cluster manifest.
6. Wait for `cluster/postgres-ha` to become Ready.
7. Restore the logical dump and change `DB_HOST` to
   `postgres-ha-rw.homework.svc.cluster.local`.
8. Apply the backup CronJob and verify a real restore into a temporary database.

Do not commit CA private keys, PostgreSQL passwords, generated certificates,
database dumps, or rendered Secret manifests.

## Failure model

The PostgreSQL service tolerates failure of one database instance or worker node.
The three local copies avoid using the NFS server as the live database storage.
The Kubernetes control plane is still single-node and therefore remains an
infrastructure limitation outside the PostgreSQL replication layer.

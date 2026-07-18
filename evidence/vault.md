# HashiCorp Vault

Дата выполнения: `2026-07-18`

## Назначение

HashiCorp Vault развёрнут для централизованного хранения секретов приложения DZ6.

На первом этапе подготовлен постоянный Vault-сервер с TLS. Интеграция с backend через Vault Secrets Operator документируется отдельно после её настройки.

## Компоненты

- Helm chart: `hashicorp/vault:0.34.0`
- Vault: `2.0.3`
- режим: `standalone`
- storage backend: `file`
- Kubernetes StorageClass: `nfs-csi`
- PVC: `data-vault-0`, `2Gi`
- Service: `vault.vault.svc.cluster.local:8200`

## TLS

- Сертификат выпущен для: `vault.vault.svc.cluster.local`
- Subject: `CN = vault.vault.svc.cluster.local, O = DZ6`
- Срок действия: до `2028-10-20T19:15:54 GMT`

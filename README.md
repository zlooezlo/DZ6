# DZ6 — Kubernetes-кластер с защищённым приложением

В репозитории находится результат домашней работы по развёртыванию и эксплуатации трёхузлового Kubernetes-кластера, созданного средствами kubeadm.

В кластере работают frontend, backend, Traefik Ingress Controller, трёхэкземплярный PostgreSQL HA под управлением CloudNativePG, HashiCorp Vault и Vault Secrets Operator.

## Архитектура

Внешний прикладной тракт:

```text
Клиент
  → HTTPS Traefik :30443
  → HTTPS frontend :8443
  → HTTPS backend :8443
  → PostgreSQL TLS postgres-ha-rw :5432
```

Внешний HTTP отключён. Внутренние TLS-соединения проверяются с использованием собственного CA.

Пароль PostgreSQL хранится в HashiCorp Vault KV v2. Vault Secrets Operator синхронизирует его в Kubernetes Secret `vault-app-db-secret`. Deployment backend непосредственно использует этот Secret. При изменении данных `rolloutRestartTargets` запускает автоматическое обновление Pod backend.

## Основные версии

- Kubernetes: `1.33.13`
- CRI-O: `1.33.13`
- Calico: `3.32.1`
- NFS CSI Helm chart: `4.13.4`
- Traefik: `3.7.6`, Helm chart `41.0.2`
- PostgreSQL: `15.18`
- CloudNativePG: `1.30.0`
- HashiCorp Vault: `2.0.3`
- Vault Secrets Operator: `1.4.1`

## Состав репозитория

- `backend/` — Flask backend и Dockerfile;
- `frontend/` — nginx frontend и Dockerfile;
- `k8s/` — Kubernetes-манифесты приложения, RBAC, NetworkPolicy и PostgreSQL HA;
- `infra/` — Helm values, сценарии установки и эксплуатационные инструкции;
- `vault-config/` — ресурсы VaultConnection, VaultAuth и VaultStaticSecret;
- `evidence/` — команды и обезличенные доказательства выполненных проверок.

## Реализованные функции

- три узла Kubernetes в состоянии Ready;
- миграция всех узлов на CRI-O;
- межузловая Pod-сеть Calico и CoreDNS;
- NFS CSI и постоянные тома;
- безопасные Deployment frontend и backend;
- startup, readiness и liveness probes;
- ServiceAccount и RBAC с минимальными правами;
- default-deny и точечные NetworkPolicy;
- RollingUpdate, rollback и graceful shutdown;
- HTTPS-only через Traefik;
- внутренний PKI и проверка сертификатов;
- PostgreSQL HA с тремя экземплярами;
- синхронная репликация и автоматический failover;
- backup и контрольное восстановление PostgreSQL;
- HashiCorp Vault с TLS и постоянным хранилищем;
- Kubernetes Auth и минимальная Vault policy;
- доставка секрета через Vault Secrets Operator;
- согласованная ротация пароля PostgreSQL;
- автоматический rollout backend после обновления Secret.

## Безопасность секретов

Реальные пароли, root token Vault, unseal-ключи, приватные ключи PKI, kubeconfig и recovery-файлы не хранятся в Git.

В репозитории находятся только декларативная конфигурация, шаблоны и обезличенные результаты проверок.

## Доказательства

Подробные команды и результаты находятся в каталоге `evidence/`.

Основные документы:

- `evidence/operations.md`
- `evidence/network-policy.md`
- `evidence/certificate-renewal.md`
- `evidence/postgresql-ha.md`
- `evidence/vault.md`

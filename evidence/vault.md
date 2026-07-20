# HashiCorp Vault и согласованная ротация PostgreSQL

## Компоненты

- Helm chart Vault: `0.34.0`
- HashiCorp Vault: `2.0.3`
- Vault Secrets Operator: `1.4.1`
- режим Vault: `standalone`
- storage backend: `file`
- PVC: `data-vault-0`, `2Gi`, StorageClass `nfs-csi`
- TLS endpoint: `vault.vault.svc.cluster.local:8200`
- Secret Engine: KV v2, mount `dz6`
- путь секрета: `homework/database`
- Kubernetes Secret: `vault-app-db-secret`
- потребитель: `Deployment/backend`

Секретные значения, root token, unseal-ключи, приватные ключи, base64 и хеш пароля в Git не включены.

## TLS Vault

Сертификат выпущен для `vault.vault.svc.cluster.local`.

Параметры сертификата:

- Subject: `CN = vault.vault.svc.cluster.local, O = DZ6`
- CA: `DZ6 Internal CA`
- срок действия: до `2028-10-20 19:15:54 GMT`

Vault успешно отвечал на TLS health-check после инициализации и unseal.

## Vault Secrets Operator

Созданы ресурсы:

- `VaultConnection/vault`
- `VaultAuth/vault-auth`
- `VaultStaticSecret/backend-database`

Параметры `VaultStaticSecret`:

- `type: kv-v2`
- `vaultAuthRef: vault-auth`
- `mount: dz6`
- `path: homework/database`
- `destination.name: vault-app-db-secret`
- `hmacSecretData: true`
- `rolloutRestartTargets: Deployment/backend`
- `refreshAfter: 5m`

Deployment backend получает `DB_PASSWORD` непосредственно из Secret `vault-app-db-secret`.

## Проверка доставки несекретного поля

Перед ротацией пароля была отдельно проверена доставка поля `ROTATION_PROOF`.

Результат:

- `DB_PASSWORD` не изменился;
- `ROTATION_PROOF` доставлен из Vault;
- `SecretSynced=True`;
- `Healthy=True`;
- `Ready=True`;
- VSO добавил аннотацию `vso.secrets.hashicorp.com/restartedAt`;
- UID Pod backend изменились;
- backend после RollingUpdate остался работоспособен.

Этот тест подтверждал доставку Vault → VSO → Kubernetes Secret и автоматический rollout, но не являлся ротацией пароля PostgreSQL.

## Согласованная ротация DB_PASSWORD

Дата проверки: `2026-07-19`.

Исходное состояние:

- CloudNativePG `postgres-ha`: `3/3`, состояние `Cluster in healthy state`;
- текущий primary: `postgres-ha-2`;
- backend: `3/3`;
- `VaultStaticSecret/backend-database`: `Synced=True`, `Healthy=True`, `Ready=True`;
- таблица `visits`: `314` записей, максимальный идентификатор `346`.

Порядок ротации:

1. Backend временно масштабирован до нуля, чтобы исключить запросы со старыми учётными данными.
2. Создан новый случайный пароль без вывода значения в терминал и лог.
3. Пароль роли PostgreSQL `app` изменён на текущем primary CNPG.
4. То же значение записано в Vault KV v2.
5. Vault Secrets Operator синхронизировал `vault-app-db-secret`.
6. `rolloutRestartTargets` обновил шаблон Deployment.
7. Backend запущен в трёх репликах с новым Secret.
8. Выполнены отрицательная и положительная проверки подключения.

Результаты:

- старый пароль отклонён PostgreSQL;
- новый пароль принят;
- пользователь подключения: `app`;
- `ssl=true`;
- TLS: `TLSv1.3`;
- cipher: `TLS_AES_256_GCM_SHA384`;
- режим backend: `sslmode=verify-full`;
- `VaultStaticSecret`: `Synced=True`, `Healthy=True`, `Ready=True`;
- backend после ротации: `3/3`;
- `restartedAt=2026-07-19T21:26:28Z`;
- функциональный запрос создал запись `visit_id=347`;
- после проверки recovery-файл удалён;
- проверка лога не обнаружила пароль или Vault token.

Итог:

```text
PASS: старый пароль отклонён PostgreSQL
PASS: новый пароль принят PostgreSQL по verify-full
PASS: Vault → VSO → Kubernetes Secret синхронизирован
PASS: автоматический rollout backend выполнен
PASS: приложение после ротации работает
PASS: recovery-файл удалён
```

## Перезапуск Vault и NFS

После перезапуска Vault был обнаружен конфликт `fsGroup` с NFS `root_squash`:

```text
applyFSGroup failed: permission denied
```

Данные Vault принадлежали UID `100`, поэтому `fsGroup` был удалён из Pod securityContext без изменения данных PVC.

В `infra/vault-values.yaml` закреплён явный `statefulSet.securityContext` без `fsGroup`.

После исправления:

- `vault-0` перешёл в `Running`;
- после передачи двух unseal shares Vault получил `Sealed=false`;
- StatefulSet получил `READY 1/1`;
- VSO возобновил синхронизацию;
- backend сохранил доступ к PostgreSQL HA.

## Безопасные команды итоговой проверки

```bash
kubectl get statefulset,pod,pvc,service -n vault

kubectl get vaultstaticsecret backend-database \
  -n homework \
  -o wide

kubectl get deployment backend \
  -n homework \
  -o wide

kubectl get cluster postgres-ha \
  -n homework \
  -o wide
```

Ни одна из этих команд не выводит значение пароля, root token или unseal-ключи.

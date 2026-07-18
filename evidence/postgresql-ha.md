# Проверка отказоустойчивого PostgreSQL

Дата выполнения: `2026-07-18`

## Архитектура

- CloudNativePG: `1.30.0`.
- PostgreSQL: `15.18`.
- Экземпляры: `3`, по одному на `kube1`, `kube2`, `kube3`.
- Хранилище: три локальных PV класса `local-cnpg`, по `5Gi`.
- Репликация: streaming replication, quorum synchronous commit `ANY 1`.
- Клиентский TLS: `verify-full`, минимум TLS 1.3.
- Сервис записи: `postgres-ha-rw.homework.svc.cluster.local:5432`.
- Backup: ежедневный custom-format `pg_dump` на отдельный NFS PVC.

## Синхронная репликация

На primary присутствовали две активные потоковые реплики:

```text
application_name | postgres-ha-2
state            | streaming
sync_state       | quorum

application_name | postgres-ha-3
state            | streaming
sync_state       | quorum

synchronous_standby_names = ANY 1 (...)
synchronous_commit = on
ssl = on
ssl_min_protocol_version = TLSv1.3
```

Это означает, что успешная транзакция подтверждается только после записи WAL
как минимум одной синхронной репликой.

## Миграция данных

До миграции старая база содержала:

```text
visits_count=299
last_visit_id=299
persistence_proof_count=1
```

Custom-format dump был проверен через `pg_restore --list`. После восстановления
в HA-кластер данные на primary и обеих репликах совпадали:

```text
postgres-ha-1: f|299|299|1
postgres-ha-2: t|299|299|1
postgres-ha-3: t|299|299|1
```

После переключения backend на `postgres-ha-rw` была создана запись `300`.
Backend подтвердил TLS-подключение:

```json
{"database_tls":true,"sslmode":"verify-full","tls_version":"TLSv1.3"}
```

## Проверка failover

Перед отказом:

```text
primary=postgres-ha-1
node=kube3
```

Primary Pod был удалён. CloudNativePG автоматически назначил новый primary:

```text
primary=postgres-ha-2
node=kube2
cluster status=Cluster in healthy state
ready=3/3
```

Запись `301`, подтверждённая до отказа, сохранилась. После failover backend
успешно создал ещё одну запись с `visit_id=334`.

Разрыв sequence между `301` и `334` не является потерей строк. PostgreSQL
sequences не транзакционны: номера могут быть заняты повторными или прерванными
попытками записи во время переключения. Фактическое число строк увеличилось с
`301` до `302`, а обе контрольные записи присутствовали.

Итоговое состояние на всех экземплярах:

```text
postgres-ha-1: t|302|334|1
postgres-ha-2: f|302|334|1
postgres-ha-3: t|302|334|1
```

## Backup и проверка восстановления

CronJob `postgres-ha-backup` запускается ежедневно в `02:00 UTC`, использует
TLS `verify-full`, запрещает параллельные запуски и хранит dump на отдельном
PVC `postgres-ha-backups` класса `nfs-csi`.

Ручной контрольный Job завершился успешно:

```text
source_stats=302|334|1
backup_file=/backup/app-20260718T141226Z.dump
backup_size=8269
PASS: backup created and pg_restore catalog validated
```

SHA256 dump был проверен. Backup восстановлен во временную базу
`app_restore_verify`:

```text
restored_stats=302|334|1
tableowner=app
ssl=t
version=TLSv1.3
PASS: backup успешно восстановлен, данные совпадают
```

После проверки временная база и проверочный Pod удалены. CronJob, backup PVC и
рабочий HA-кластер сохранены.

## Ограничения

PostgreSQL выдерживает отказ одного экземпляра или worker-узла без потери
подтверждённых транзакций. Kubernetes control plane состоит из одного узла;
полный отказ kube1 остаётся ограничением инфраструктуры кластера. NFS хранит
резервные копии, но не используется для рабочих томов HA PostgreSQL.

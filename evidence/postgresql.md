# PostgreSQL StatefulSet и сохранность данных

## Конфигурация

PostgreSQL `15.18` запущен в `StatefulSet` с одной репликой. Образ использует
зафиксированный тег `postgres:15.18-alpine3.24`. Данные находятся на PVC
`postgres-data-postgres-0`, который динамически создал StorageClass `nfs-csi`.

Настоящий пароль создан непосредственно в кластере и отсутствует в Git:

```bash
read -rsp "Введите пароль PostgreSQL: " DB_PASSWORD
echo
kubectl create secret generic app-db-secret \
  -n homework \
  --from-literal=POSTGRES_PASSWORD="$DB_PASSWORD" \
  --from-literal=DB_PASSWORD="$DB_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -
unset DB_PASSWORD
```

Контейнер работает без root и без дополнительных Linux capabilities:

```text
uid=70(postgres) gid=70(postgres) groups=70(postgres)
```

`fsGroup` намеренно не задан. При NFS с `root_squash` kubelet не может
рекурсивно применить группу к каталогу `PGDATA` с правами `0700`, созданному
пользователем PostgreSQL. Доступ обеспечивается UID/GID `70`, а каталог тома
создаётся NFS CSI driver с `mountPermissions: "0777"`.

Startup- и readiness-пробы выполняют `SELECT 1`. Это исключает краткий ложный
положительный результат `pg_isready`, когда временный сервер `initdb` уже
принимает соединения, но база `app` ещё не создана. Для liveness достаточно
`pg_isready`, поскольку она проверяет жизнеспособность процесса сервера.

## Состояние StatefulSet и PVC

```text
NAME                        READY   CONTAINERS   IMAGES
statefulset.apps/postgres   1/1     postgres     postgres:15.18-alpine3.24

NAME             READY   STATUS    NODE
pod/postgres-0   1/1     Running   kube3

NAME                                             STATUS   CAPACITY   STORAGECLASS
persistentvolumeclaim/postgres-data-postgres-0   Bound    2Gi        nfs-csi
```

PostgreSQL подтвердил базу, пользователя и версию:

```text
current_database | current_user | version
app              | app          | PostgreSQL 15.18 on x86_64-pc-linux-musl
```

## Проверка сохранности после пересоздания Pod

До удаления Pod в таблицу `persistence_proof` добавлена строка:

```text
id | created_at                       | note
1  | 2026-07-16 12:53:12.321665+00    | created before pod deletion
```

StatefulSet пересоздал Pod с новым UID, но подключил прежний PV:

```text
Старый UID: 67876e5a-8c4c-4b77-b430-afd1b2e952a1
Новый UID:  01d4ffc7-aeb6-4a4f-82ac-f5cb1fa6e3f3
Старый PV:  pvc-4307893e-3e15-44ed-9ef0-504e5ab9ddc1
Новый PV:   pvc-4307893e-3e15-44ed-9ef0-504e5ab9ddc1
```

После пересоздания запрос вернул исходную строку. Это подтверждает, что данные
PostgreSQL хранятся на PersistentVolume, а не в файловой системе Pod.

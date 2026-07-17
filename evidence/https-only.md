# HTTPS-only: шифрование всего прикладного трафика

Дата проверки: `2026-07-17`

Кластер: Kubernetes `v1.33.13`, три узла, CRI-O `1.33.13`.

## Результат

В прикладном тракте полностью исключено взаимодействие по HTTP:

```text
клиент
  └─ HTTPS/TLS ─> Traefik
       └─ HTTPS/TLS с проверкой CA ─> frontend
            └─ HTTPS/TLS с проверкой CA ─> backend
                 └─ PostgreSQL TLS verify-full ─> PostgreSQL
```

Единственная опубликованная точка входа приложения:

```text
443:30443/TCP
```

NodePort `30080/TCP` не публикуется. Перенаправление с HTTP также не
используется: незашифрованная точка входа отсутствует.

## Использованные версии

| Компонент | Версия или образ |
|---|---|
| Traefik | `3.7.6`, Helm chart `41.0.2` |
| Frontend | `zlooezlo/k8s-homework-frontend:v2-tls` |
| Backend | `zlooezlo/k8s-homework-backend:v3-tls` |
| PostgreSQL | `postgres:15.18-alpine3.24` |

Опубликованные образы:

```text
backend:v3-tls
sha256:2ce1a5a21a40d6e8f6b35d7d812edb8c4aea6e5468688f355cfd84206be1ce3e

frontend:v2-tls
sha256:012f4a5a490d907edeb7ae206ba45f884e6869feae3551e7a4eb9a09e1767044
```

Оба контейнера запускаются без root:

```text
uid=10001(appuser) gid=10001(appuser) groups=10001(appuser)
uid=101(nginx) gid=101(nginx) groups=101(nginx)
```

## PKI и Kubernetes Secrets

На `kube1` сценарий `infra/generate-dz6-tls.sh` создал внутренний CA и
отдельные серверные сертификаты для:

- `dz6.local`;
- `frontend.homework.svc.cluster.local`;
- `backend.homework.svc.cluster.local`;
- `postgres.homework.svc.cluster.local`.

В namespace `homework` созданы Secrets:

```text
NAME               TYPE                DATA
dz6-external-tls   kubernetes.io/tls   2
dz6-ca             Opaque              1
frontend-tls       Opaque              3
backend-tls        Opaque              3
postgres-tls       Opaque              3
```

Приватные ключи хранятся только в `/home/name/dz6-pki` на `kube1` и в
Kubernetes Secrets. В Git они не добавляются.

Параметры внешнего сертификата:

```text
subject=CN = dz6.local, O = DZ6
issuer=CN = DZ6 Internal CA, O = DZ6
notBefore=Jul 17 19:33:35 2026 GMT
notAfter=Oct 19 19:33:35 2028 GMT
sha256 Fingerprint=2E:E6:D8:CB:C0:81:5C:D5:9D:0B:69:04:8E:18:2B:01:10:7A:39:3C:D4:3B:70:72:CD:02:BA:1B:A1:D8:85:0F
```

## Traefik и Ingress

Traefik публикует только защищённый NodePort:

```text
NAME      TYPE       PORT(S)
traefik   NodePort   443:30443/TCP
```

Ingress использует entrypoint `websecure`, TLS Secret
`dz6-external-tls` и host `dz6.local`.

Для соединения Traefik с frontend создан `ServersTransport`:

```yaml
spec:
  serverName: frontend.homework.svc.cluster.local
  rootCAsSecrets:
    - dz6-ca
```

Это включает проверку сертификата frontend, а не только шифрование без
проверки подлинности.

## Frontend и backend

Frontend слушает `8443/TCP` с TLS и проксирует API только по HTTPS:

```nginx
listen 8443 ssl;
proxy_pass https://backend:8443;
proxy_ssl_server_name on;
proxy_ssl_name backend.homework.svc.cluster.local;
proxy_ssl_trusted_certificate /etc/dz6-tls/ca.crt;
proxy_ssl_verify on;
```

Backend слушает `8443/TCP` через Gunicorn с параметрами `--certfile` и
`--keyfile`. Startup, readiness и liveness probes используют схему HTTPS.

Backend подключается к базе со следующими параметрами:

```text
DB_HOST=postgres.homework.svc.cluster.local
DB_SSLMODE=verify-full
DB_SSLROOTCERT=/etc/dz6-tls/ca.crt
```

## Проверка полного тракта

Проверка выполнялась с рабочей машины публичной частью внутреннего CA:

```bash
CA_FILE=/tmp/dz6-ca.crt infra/verify-https-only.sh
```

Результат:

```text
=== Проверка внешнего HTTPS ===
<title>Kubernetes Homework</title>
<h1>Kubernetes Homework</h1>
{"pod":"backend-869f965cb4-4vtxk","total":297,"version":"v3-tls","visit_id":297}

=== Проверка TLS backend -> PostgreSQL ===
{"cipher":"TLS_AES_256_GCM_SHA384","database_tls":true,"sslmode":"verify-full","tls_version":"TLSv1.3"}

=== Проверка отсутствия внешнего HTTP ===
PASS: внешний HTTP недоступен, HTTPS и TLS к PostgreSQL работают
```

Успешный ответ доказывает работоспособность всего тракта: при ошибке
проверки любого внутреннего сертификата Traefik или NGINX не смогли бы
проксировать запрос до backend.

## Принудительный TLS PostgreSQL

На сервере PostgreSQL включён SSL:

```text
 ssl
-----
 on
```

Актуальные правила `pg_hba.conf`:

```text
 line_number |   type    | address |  auth_method
-------------+-----------+---------+---------------
           2 | hostssl   | 0.0.0.0 | scram-sha-256
           3 | hostssl   | ::      | scram-sha-256
           4 | hostnossl | 0.0.0.0 | reject
           5 | hostnossl | ::      | reject
```

Проведён отдельный отрицательный тест с `sslmode=disable`:

```text
FATAL: pg_hba.conf rejects connection for host "10.244.9.169",
user "app", database "app", no encryption
command terminated with exit code 2
PASS: PostgreSQL отклонил незашифрованное соединение
```

Тестовый Pod после проверки удалён.

## Сохранность данных

Перед переключением выполнен `pg_dump` базы `app`. PostgreSQL продолжил
использовать существующий PVC. После rollout StatefulSet, backend и frontend
перешли в состояние Ready:

```text
deployment.apps/backend    3/3
deployment.apps/frontend   2/2
statefulset.apps/postgres   1/1
```

## Вывод

Внешний HTTP отключён. Все сетевые взаимодействия приложения защищены TLS,
внутренние сертификаты проверяются доверенным CA, а PostgreSQL технически
запрещает незашифрованные соединения. Пункт дополнительного задания
«полностью отказаться от HTTP» выполнен.

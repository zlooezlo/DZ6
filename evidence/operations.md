# Эксплуатационные проверки Kubernetes-кластера

Дата проверок: 17 июля 2026 года  
Namespace приложения: `homework`  
Kubernetes: `v1.33.13`  
Container Runtime: `CRI-O 1.33.13`

## Итог

Выполнены все восемь проверок из раздела 6. После каждой искусственной
неисправности рабочее состояние кластера было восстановлено.

| № | Проверка | Результат |
|---:|---|---|
| 1 | Self-healing Deployment | Пройдена |
| 2 | Rolling Update `v1 -> v2` | Пройдена без ошибок запросов |
| 3 | Rollback `v2 -> v1` | Пройден без ошибок запросов |
| 4 | Сохранность данных PostgreSQL | Пройдена |
| 5 | Неисправный selector Service | Обнаружен и восстановлен |
| 6 | Неисправный readiness probe | Обнаружен и восстановлен |
| 7 | Нарушение потока NetworkPolicy | Обнаружено и восстановлено |
| 8 | Drain рабочего узла | Пройден с переносом Pod |

## 1. Self-healing Deployment

У Deployment `backend` было три готовых реплики. Во время непрерывной
проверки через Ingress один Pod был удалён вручную.

```text
Удалённый Pod: backend-5f9c454ff-79vrt
Старый UID:    e43cca9f-9b07-4e91-b476-d1703e4de181

Созданный Pod: backend-5f9c454ff-fptxr
Новый UID:     4cd7d16a-201f-4f85-95ce-91760632eabf

Deployment: 3/3 Ready
Успешных запросов: 45
Ошибок: 0
```

Цепочка владельцев нового объекта:

```text
Deployment/backend -> ReplicaSet/backend-5f9c454ff -> Pod/backend-5f9c454ff-fptxr
```

ReplicaSet автоматически восстановил желаемое количество реплик, а внешний
маршрут оставался доступен.

## 2. Rolling Update без простоя

Для Deployment настроена безопасная стратегия обновления:

```yaml
minReadySeconds: 5
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 0
    maxSurge: 1
```

Перед завершением контейнера выполняется задержка, необходимая для обновления
EndpointSlice и сетевых правил:

```yaml
lifecycle:
  preStop:
    exec:
      command:
        - sh
        - -c
        - sleep 10
```

Во время обновления образа с `v1` до `v2` выполнялись непрерывные запросы через
Traefik Ingress.

```text
Образ до обновления: zlooezlo/k8s-homework-backend:v1
Образ после обновления: zlooezlo/k8s-homework-backend:v2
Успешных запросов: 100
Ошибок: 0
Ответов v1: 59
Ответов v2: 41
Итоговый Deployment: 3/3 Ready
```

Одновременное присутствие ответов обеих версий подтверждает постепенную замену
Pod, а отсутствие ошибок — доступность приложения на протяжении обновления.

## 3. Rollback без простоя

Deployment был возвращён с версии `v2` на сохранённую ревизию `v1` командой
`kubectl rollout undo`. Во время отката выполнялись непрерывные запросы.

```text
Успешных запросов: 100
Ошибок: 0
Ответов v2: 63
Ответов v1: 37
Итоговый образ: zlooezlo/k8s-homework-backend:v1
Итоговый Deployment: 3/3 Ready
```

После тестов кластер снова приведён к декларативному состоянию из
`k8s/backend-deployment.yaml`.

## 4. Сохранность данных PostgreSQL

Перед удалением Pod в PostgreSQL была создана контрольная запись:

```sql
CREATE TABLE IF NOT EXISTS persistence_proof (
    id BIGSERIAL PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    note TEXT NOT NULL
);

INSERT INTO persistence_proof (note)
VALUES ('created before pod deletion');
```

Результат до и после пересоздания Pod:

```text
Старый UID Pod: 67876e5a-8c4c-4b77-b430-afd1b2e952a1
Новый UID Pod:  01d4ffc7-aeb6-4a4f-82ac-f5cb1fa6e3f3

Старый PV: pvc-4307893e-3e15-44ed-9ef0-504e5ab9ddc1
Новый PV:  pvc-4307893e-3e15-44ed-9ef0-504e5ab9ddc1

id | note
1  | created before pod deletion
```

UID Pod изменился, PV остался прежним, контрольная запись сохранилась.

## 5. Диагностика selector Service

Selector Service `backend` был намеренно заменён:

```text
Рабочий selector:    app.kubernetes.io/name=backend
Неисправный selector: app.kubernetes.io/name=backend-broken
```

При неисправном selector:

```text
Deployment backend: 3/3 Ready
EndpointSlice backend-nft6h: <none>
HTTP frontend -> backend: timeout
```

Pod продолжали работать, но Service не имел endpoint. После возврата selector
появились три адреса EndpointSlice, а `/healthz` снова вернул
`{"status":"alive"}`.

## 6. Диагностика readiness probe

Путь readiness probe был намеренно изменён:

```text
Рабочий путь: /readyz
Неисправный путь: /definitely-not-ready
```

Новый Pod имел состояние:

```text
Pod: backend-598cb8d6d9-rbjwn
Phase: Running
Ready: false
Restarts: 0
Readiness probe failed: HTTP probe failed with statuscode: 404
EndpointSlice conditions: true,true,true,false
```

Три старые готовые реплики продолжали обслуживать Service, поэтому `/healthz`
возвращал `{"status":"alive"}`. После восстановления пути `/readyz` Deployment
вернулся к `3/3 Ready`.

## 7. Проверка NetworkPolicy

Для проверки был временно удалён разрешающий объект
`allow-frontend-to-backend`.

```text
DNS-сервер: 10.96.0.10
backend.homework.svc.cluster.local: 10.109.108.219
DNS: работает
HTTP frontend -> backend: timeout
```

Таким образом, DNS-egress оставался разрешён, а требуемый прикладной поток был
заблокирован политикой по умолчанию. После повторного применения
`k8s/network-policies.yaml` объект `allow-frontend-to-backend` появился снова,
а `/healthz` успешно вернул `{"status":"alive"}`.

Дополнительно проверено, что произвольный Pod в namespace не может обращаться
к backend напрямую, но разрешённый маршрут
`Traefik -> frontend -> backend -> PostgreSQL` работает.

## 8. Drain рабочего узла

Узел `kube3`, на котором работал `postgres-0`, был выведен из планирования:

```bash
kubectl drain kube3 \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --timeout=300s
```

Результат:

```text
kube3: Ready,SchedulingDisabled
postgres-0: 1/1 Running на kube2
PVC: postgres-data-postgres-0
PV: pvc-4307893e-3e15-44ed-9ef0-504e5ab9ddc1
Контрольная запись: created before pod deletion
```

После проверки узел был возвращён командой `kubectl uncordon kube3`. Данные
PostgreSQL сохранились благодаря PVC и NFS CSI.

## Финальное состояние

После завершения проверок:

```text
backend image: zlooezlo/k8s-homework-backend:v1
backend: 3/3 Ready
frontend: 2/2 Ready
postgres: 1/1 Ready
NetworkPolicy: восстановлены
Service selectors: восстановлены
readiness path: /readyz
Внешний маршрут через Traefik: работает
```


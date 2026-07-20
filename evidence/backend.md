> [!NOTE]
> Исторический этап до перехода на HTTPS. Актуальная конфигурация и проверки находятся в [evidence/https-only.md](https-only.md).

# Проверка backend

## Развёртывание

```bash
kubectl apply -f k8s/backend-configmap.yaml
kubectl apply -f k8s/backend-service.yaml
kubectl apply -f k8s/backend-deployment.yaml

kubectl rollout status deployment/backend \
  -n homework \
  --timeout=300s
```

Ожидаемый результат: Deployment содержит три готовые реплики, а Pod равномерно
распределены между worker-узлами.

```bash
kubectl get deployment,pod,service \
  -n homework \
  -o wide

kubectl get endpointslice \
  -n homework \
  -l kubernetes.io/service-name=backend \
  -o wide
```

EndpointSlice должен содержать три готовых endpoint на порту `8080`.

## Проверка Service и PostgreSQL

Запросы выполняются из временного Pod внутри кластера:

```bash
kubectl run backend-smoke \
  -n homework \
  --image=busybox:1.36.1 \
  --restart=Never \
  --rm -i \
  --command -- \
  sh -c '
    nslookup backend
    for i in 1 2 3 4 5 6; do
      wget -qO- http://backend:8080/
      echo
    done
    wget -qO- --post-data="" http://backend:8080/api/visits
    echo
  '
```

В ответе `/` присутствуют версия `v1` и имя обслужившего Pod. Последний запрос
создаёт запись в PostgreSQL и возвращает номер визита.

## Проверка security context и probe

```bash
POD=$(kubectl get pod \
  -n homework \
  -l app.kubernetes.io/name=backend \
  -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n homework "$POD" -- id

kubectl get pod "$POD" \
  -n homework \
  -o jsonpath='{.spec.containers[0].securityContext}'
echo

kubectl describe pod "$POD" \
  -n homework \
  | sed -n '/Startup:/,/Environment:/p'
```

Контейнер работает от UID/GID `10001`, privilege escalation запрещён, корневая
файловая система доступна только для чтения, а все Linux capabilities удалены.
Startup и liveness используют `/healthz`; readiness проверяет `/readyz`, который
выполняет запрос `SELECT 1` к PostgreSQL.

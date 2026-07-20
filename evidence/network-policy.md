> [!NOTE]
> Исторический этап до перехода на HTTPS. Актуальная конфигурация и проверки находятся в [evidence/https-only.md](https-only.md).

# Проверка NetworkPolicy

## Разрешённая модель

В namespace `homework` действует `default-deny-all`. Отдельными политиками
разрешены только следующие соединения:

```text
Traefik namespace -> frontend:8080
frontend          -> backend:8080
backend           -> postgres:5432
любой homework Pod -> CoreDNS:53/UDP,TCP
```

Ответный трафик для разрешённых соединений пропускается автоматически.

## Применение

```bash
kubectl apply -f k8s/network-policies.yaml

kubectl get networkpolicy -n homework
kubectl describe networkpolicy -n homework

kubectl wait \
  --for=condition=Ready \
  pod \
  --all \
  -n homework \
  --timeout=180s
```

## Положительные проверки

DNS из frontend должен разрешать Service backend:

```bash
FRONTEND_POD=$(kubectl get pod \
  -n homework \
  -l app.kubernetes.io/name=frontend \
  -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n homework "$FRONTEND_POD" -- \
  nslookup backend.homework.svc.cluster.local
```

Полный разрешённый маршрут проверяется с основной машины:

```bash
curl -fsS \
  -H 'Host: dz6.local' \
  -X POST \
  http://192.168.56.12:30080/api/visits
```

Запрос должен пройти через Traefik, frontend и backend и создать запись в
PostgreSQL.

## Отрицательные проверки

Произвольный Pod в namespace `homework` не имеет права обращаться к backend:

```bash
kubectl run network-deny-test \
  -n homework \
  --image=busybox:1.36.1 \
  --restart=Never \
  --command -- \
  sh -c '
    nslookup backend.homework.svc.cluster.local
    if wget -T 3 -qO- http://backend:8080/healthz; then
      echo "ERROR: backend unexpectedly reachable"
      exit 1
    fi
    echo "PASS: DNS works, direct backend access is denied"
    sleep 30
  '

kubectl wait \
  --for=condition=Ready \
  pod/network-deny-test \
  -n homework \
  --timeout=180s

kubectl logs -n homework network-deny-test
kubectl delete pod -n homework network-deny-test
```

Ожидается успешный DNS-ответ и сообщение
`PASS: DNS works, direct backend access is denied`.

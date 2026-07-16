# Проверка ServiceAccount и RBAC

## Модель доступа

Frontend, backend и PostgreSQL используют отдельные ServiceAccount. Этим
приложениям доступ к Kubernetes API не требуется, поэтому токен ServiceAccount
не монтируется и RoleBinding для них не создаётся.

Для диагностического чтения создан ServiceAccount `homework-reader`. Role
разрешает только `get`, `list`, `watch` для Pod, Service, ConfigMap, Event,
EndpointSlice, Deployment, ReplicaSet и StatefulSet, а также `get` для логов
Pod. Доступ к Secret и изменение ресурсов не разрешены.

## Развёртывание

```bash
kubectl apply -f k8s/serviceaccounts.yaml
kubectl apply -f k8s/rbac-reader.yaml
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/frontend-deployment.yaml
kubectl apply -f k8s/postgres-statefulset.yaml

kubectl rollout status deployment/backend -n homework --timeout=300s
kubectl rollout status deployment/frontend -n homework --timeout=300s
kubectl rollout status statefulset/postgres -n homework --timeout=300s
```

## Положительные и отрицательные проверки

```bash
READER=system:serviceaccount:homework:homework-reader

kubectl auth can-i list pods \
  --as="$READER" \
  -n homework

kubectl auth can-i get endpointslices.discovery.k8s.io \
  --as="$READER" \
  -n homework

kubectl auth can-i get secrets \
  --as="$READER" \
  -n homework

kubectl auth can-i delete pods \
  --as="$READER" \
  -n homework

kubectl auth can-i list pods \
  --as=system:serviceaccount:homework:backend \
  -n homework
```

Ожидаются ответы: `yes`, `yes`, `no`, `no`, `no`.

## Проверка Pod

```bash
kubectl get pods \
  -n homework \
  -o custom-columns='NAME:.metadata.name,SA:.spec.serviceAccountName,AUTOMOUNT:.spec.automountServiceAccountToken'

POD=$(kubectl get pod \
  -n homework \
  -l app.kubernetes.io/name=backend \
  -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n homework "$POD" -- \
  sh -c 'test ! -e /var/run/secrets/kubernetes.io/serviceaccount/token && echo "API token not mounted"'
```

У каждого workload указан собственный ServiceAccount и
`automountServiceAccountToken=false`. Проверка внутри backend подтверждает, что
API-токен отсутствует.

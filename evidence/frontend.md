# Проверка frontend

## Развёртывание

```bash
kubectl apply -f k8s/frontend-service.yaml
kubectl apply -f k8s/frontend-deployment.yaml

kubectl rollout status deployment/frontend \
  -n homework \
  --timeout=300s

kubectl get deployment,pod,service \
  -n homework \
  -o wide

kubectl get endpointslice \
  -n homework \
  -l kubernetes.io/service-name=frontend \
  -o wide
```

Ожидаемый результат: готовы две реплики frontend, размещённые на разных
worker-узлах, а EndpointSlice содержит два endpoint на порту `8080`.

## Полный маршрут frontend → backend → PostgreSQL

```bash
kubectl run frontend-smoke \
  -n homework \
  --image=busybox:1.36.1 \
  --restart=Never \
  --command -- \
  sh -c '
    set -e
    nslookup frontend.homework.svc.cluster.local
    wget -qO- http://frontend:8080/ | grep "Kubernetes Homework"
    wget -qO- http://frontend:8080/healthz
    wget -qO- --post-data="" http://frontend:8080/api/visits
    echo
    sleep 30
  '

kubectl wait \
  --for=condition=Ready \
  pod/frontend-smoke \
  -n homework \
  --timeout=180s

kubectl logs -n homework frontend-smoke
kubectl delete pod -n homework frontend-smoke
```

HTML и `/healthz` обслуживает nginx frontend. Запрос `/api/visits` nginx
передаёт Service `backend`, который создаёт запись в PostgreSQL.

## Проверка security context и probe

```bash
POD=$(kubectl get pod \
  -n homework \
  -l app.kubernetes.io/name=frontend \
  -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n homework "$POD" -- id

kubectl get deployment frontend \
  -n homework \
  -o jsonpath='runAsNonRoot={.spec.template.spec.securityContext.runAsNonRoot}{"\n"}runAsUser={.spec.template.spec.securityContext.runAsUser}{"\n"}allowPrivilegeEscalation={.spec.template.spec.containers[0].securityContext.allowPrivilegeEscalation}{"\n"}readOnlyRootFilesystem={.spec.template.spec.containers[0].securityContext.readOnlyRootFilesystem}{"\n"}capabilitiesDrop={.spec.template.spec.containers[0].securityContext.capabilities.drop}{"\n"}'
```

Nginx работает от UID/GID `101`, privilege escalation запрещён, корневая
файловая система доступна только для чтения, а все Linux capabilities удалены.
Startup, readiness и liveness probes обращаются к `/healthz`.

# Демонстрация RollingUpdate

## 1. Подготовка образов

```bash
export REGISTRY=registry.example.com/student
./build-images.sh
```

Замените `REGISTRY` в `k8s/backend-deployment.yaml` на то же значение.

## 2. Запуск v1

```bash
kubectl create namespace homework --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f k8s/backend-configmap.yaml
cp k8s/backend-secret.example.yaml /tmp/backend-secret.yaml
# Измените CHANGE_ME, затем:
kubectl apply -f /tmp/backend-secret.yaml
kubectl apply -f k8s/backend-service.yaml
kubectl apply -f k8s/backend-deployment.yaml
kubectl rollout status deployment/backend -n homework --timeout=180s
```

PostgreSQL должен быть уже доступен под DNS-именем `postgres.homework.svc` или `postgres` внутри namespace `homework`.

## 3. Наблюдение

В первом терминале:

```bash
kubectl get pod -n homework -l app.kubernetes.io/name=backend -w
```

Во втором терминале:

```bash
kubectl rollout history deployment/backend -n homework
```

В третьем терминале отправляйте запросы через Service, Ingress или port-forward:

```bash
kubectl port-forward -n homework service/backend 8080:8080
```

```bash
while true; do
  curl -fsS http://127.0.0.1:8080/ | jq -c '{version,pod,message}' || echo ERROR
  sleep 0.3
done
```

## 4. Обновление v1 -> v2

Измените только image в `k8s/backend-deployment.yaml`:

```yaml
image: REGISTRY/k8s-homework-backend:v2
```

Затем:

```bash
kubectl annotate deployment/backend -n homework \
  kubernetes.io/change-cause="backend v1 -> v2" --overwrite
kubectl apply -f k8s/backend-deployment.yaml
kubectl rollout status deployment/backend -n homework --timeout=180s
kubectl rollout history deployment/backend -n homework
```

Ожидаемый результат:

- создаётся новый ReplicaSet;
- одновременно допускается не более одного дополнительного Pod (`maxSurge: 1`);
- старый Ready Pod не удаляется, пока новый Pod не станет Ready (`maxUnavailable: 0`);
- ответы постепенно переключаются с `v1` на `v2`;
- успешные HTTP-запросы не прерываются при достаточных ресурсах кластера.

## 5. Rollback

```bash
kubectl rollout undo deployment/backend -n homework
kubectl rollout status deployment/backend -n homework --timeout=180s
kubectl rollout history deployment/backend -n homework
```

После rollback ответы снова должны показывать `version: v1`.

## 6. Что приложить к отчёту

- digest образов v1 и v2;
- diff манифеста Deployment;
- вывод `kubectl get rs -n homework` до и после обновления;
- вывод `kubectl rollout history`;
- лог непрерывных HTTP-запросов без ошибок;
- скриншот или текст, где видны ответы от v1 и v2 во время rollout;
- результат rollback.

# HTTPS-only для DZ6

Схема защищённого трафика:

1. клиент проверяет сертификат `dz6.local`;
2. Traefik проверяет сертификат frontend через `ServersTransport`;
3. frontend проверяет сертификат backend средствами NGINX;
4. backend подключается к PostgreSQL с `sslmode=verify-full`;
5. PostgreSQL отклоняет подключения без TLS правилами `hostnossl`.

Внешний HTTP NodePort не публикуется. Единственная внешняя точка приложения —
`https://dz6.local:30443`.

## 1. Сборка образов на рабочем компьютере

```bash
docker login -u zlooezlo

docker build \
  --build-arg APP_VERSION=v3-tls \
  --build-arg RELEASE_MESSAGE='end-to-end TLS release' \
  -t zlooezlo/k8s-homework-backend:v3-tls \
  backend

docker build \
  -t zlooezlo/k8s-homework-frontend:v2-tls \
  frontend

docker push zlooezlo/k8s-homework-backend:v3-tls
docker push zlooezlo/k8s-homework-frontend:v2-tls
docker logout
```

## 2. Передача файлов на kube1

```bash
scp \
  infra/generate-dz6-tls.sh \
  infra/deploy-https-only.sh \
  infra/traefik-values.yaml \
  k8s/backend-configmap.yaml \
  k8s/backend-deployment.yaml \
  k8s/backend-service.yaml \
  k8s/frontend-deployment.yaml \
  k8s/frontend-service.yaml \
  k8s/frontend-ingress.yaml \
  k8s/frontend-servers-transport.yaml \
  k8s/network-policies.yaml \
  k8s/postgres-statefulset.yaml \
  k8s/postgres-tls-config.yaml \
  name@192.168.56.11:/home/name/
```

## 3. Выпуск сертификатов на kube1

```bash
chmod +x ~/generate-dz6-tls.sh ~/deploy-https-only.sh
~/generate-dz6-tls.sh
```

Приватные ключи остаются в `/home/name/dz6-pki` на `kube1` и в Kubernetes
Secrets. В Git они не добавляются.

## 4. Проверка Helm и развёртывание

```bash
helm template traefik traefik/traefik \
  --version 41.0.2 \
  --namespace traefik \
  --values ~/traefik-values.yaml \
  >/tmp/traefik-https-only.yaml

~/deploy-https-only.sh
```

При переключении PostgreSQL на обязательный TLS старые backend Pods могут
кратковременно потерять readiness. Сценарий сразу применяет новый backend с
TLS-клиентом и ждёт завершения всех rollout.

## 5. Копирование только публичного CA на рабочий компьютер

```bash
scp \
  name@192.168.56.11:/home/name/dz6-pki/ca.crt \
  /tmp/dz6-ca.crt
```

## 6. Итоговая проверка

```bash
CA_FILE=/tmp/dz6-ca.crt \
  infra/verify-https-only.sh
```

Дополнительно на `kube1` проверяются сервисы, TLS PostgreSQL и отсутствие
HTTP NodePort:

```bash
kubectl get service traefik -n traefik
kubectl get ingress frontend -n homework
kubectl get serversTransport frontend-transport -n homework

kubectl exec -n homework postgres-0 -- \
  psql -U app -d app -c \
  "SELECT ssl, version, cipher FROM pg_stat_ssl WHERE pid = pg_backend_pid();"

kubectl get service traefik -n traefik \
  -o jsonpath='{.spec.ports[*].nodePort}{"\n"}'
```

Ожидается один NodePort `30443`, успешный HTTPS-запрос, `database_tls=true`
и отказ соединения с `30080`.

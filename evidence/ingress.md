# Проверка Ingress

## Контроллер

Для установки выбран поддерживаемый Traefik. Community ingress-nginx завершил
поддержку в марте 2026 года, поэтому новый стенд на нём не строился.

```bash
./infra/install-traefik.sh

helm list -n traefik
kubectl get deployment,pod,service -n traefik -o wide
kubectl get ingressclass traefik
```

Helm chart `41.0.2` устанавливает Traefik Proxy `3.7.6`. Контроллер работает в
двух репликах, а Service типа NodePort публикует HTTP на `30080` и HTTPS на
`30443`.

## Ingress-ресурс

```bash
kubectl apply -f k8s/frontend-ingress.yaml

kubectl get ingress -n homework -o wide
kubectl describe ingress frontend -n homework
```

Ingress с классом `traefik` направляет запросы для `dz6.local` в Service
`homework/frontend:8080`.

## Проверка с основной машины

Без изменения `/etc/hosts` маршрут проверяется явным HTTP-заголовком Host:

```bash
curl -fsS \
  -H 'Host: dz6.local' \
  http://192.168.56.12:30080/ \
  | grep 'Kubernetes Homework'

curl -fsS \
  -H 'Host: dz6.local' \
  -X POST \
  http://192.168.56.12:30080/api/visits
```

Первый запрос возвращает HTML frontend. Второй проходит через Traefik,
frontend nginx и backend до PostgreSQL. На следующем этапе HTTP будет заменён
на HTTPS с перенаправлением и TLS-сертификатом.

## Источники

- Kubernetes: `Ingress NGINX Retirement: What You Need to Know`, 11.11.2025.
- Traefik Helm chart release `v41.0.2`, 06.07.2026.
- Traefik documentation: `Setup Traefik on Kubernetes`.

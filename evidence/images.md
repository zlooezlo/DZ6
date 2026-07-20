# Финальные контейнерные образы

## Backend

- repository: `zlooezlo/k8s-homework-backend`
- tag: `v3-tls`
- digest: `sha256:2ce1a5a21a40d6e8f6b35d7d812edb8c4aea6e5468688f355cfd84206be1ce3e`
- runtime user: `uid=10001(appuser) gid=10001(appuser)`
- HTTPS port: `8443`

## Frontend

- repository: `zlooezlo/k8s-homework-frontend`
- tag: `v2-tls`
- digest: `sha256:012f4a5a490d907edeb7ae206ba45f884e6869feae3551e7a4eb9a09e1767044`
- runtime user: `uid=101(nginx) gid=101(nginx)`
- HTTPS port: `8443`

Оба образа запускаются без root-прав и входят в актуальный HTTPS-only тракт.

Образы `backend:v1`, `backend:v2` и `frontend:v1` относятся к историческим этапам до внедрения сквозного TLS.

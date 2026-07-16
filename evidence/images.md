# Сборка и публикация образов

Образы собраны Docker 29.3.1 и опубликованы в публичных репозиториях
Docker Hub пользователя `zlooezlo`. Тег `latest` не используется.

| Образ | Digest |
|---|---|
| `zlooezlo/k8s-homework-backend:v1` | `sha256:27624e64351721dd6ee3484a6f9a6a2d80d2739b866ce3c89fb2557525d4370f` |
| `zlooezlo/k8s-homework-backend:v2` | `sha256:6d147149f678fa40f8782d2ad6c120e02ea2b48901222f3e066bf62984332fc8` |
| `zlooezlo/k8s-homework-frontend:v1` | `sha256:0fd42e5937027037c81fbd24d758d77fc39c6883526673121d55dc6b8d4baae6` |

## Проверки

- backend работает от UID/GID `10001`;
- frontend работает от UID/GID `101`;
- Gunicorn успешно отвечает на `/` и `/healthz`;
- конфигурация Nginx прошла `nginx -t`;
- frontend отвечает `200 ok` на `/healthz`;
- frontend отдаёт страницу `Kubernetes Homework`.

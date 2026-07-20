# Доказательства выполнения проекта DZ6

Каталог содержит команды и обезличенные результаты практических проверок Kubernetes-кластера и приложения.

Основные документы:

- `backend.md` — исторический этап backend до перехода на HTTPS;
- `frontend.md` — исторический этап frontend до перехода на HTTPS;
- `ingress.md` — исторический этап HTTP Ingress;
- `network-policy.md` — внедрение и проверка NetworkPolicy;
- `https-only.md` — актуальная конфигурация сквозного TLS;
- `operations.md` — RollingUpdate, rollback, self-healing и graceful shutdown;
- `certificate-renewal.md` — замена сертификатов Kubernetes;
- `postgresql-ha.md` — CloudNativePG, репликация, failover, backup и restore;
- `vault.md` — Vault, VSO, автоматический rollout и ротация пароля;
- `rbac.md` — ServiceAccount и RBAC с минимальными правами;
- `images.md` — финальные TLS-образы и их digest.

Реальные пароли, токены, unseal-ключи, kubeconfig, приватные ключи и recovery-файлы в доказательства не включаются.

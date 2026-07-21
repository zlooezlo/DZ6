# Эксплуатационные файлы проекта DZ6

Каталог содержит сценарии, Helm values и инструкции, использованные для развёртывания и проверки проекта.

Основные файлы:

- `generate-dz6-tls.sh` — создание внутреннего CA и TLS-сертификатов приложения;
- `deploy-https-only.sh` — применение HTTPS-only конфигурации;
- `verify-https-only.sh` — проверка внешнего HTTPS и TLS к PostgreSQL;
- `HTTPS_ONLY.md` — описание сквозного TLS;
- `install-cnpg.sh` — установка CloudNativePG;
- `prepare-cnpg-local-storage.sh` — подготовка локальных томов CNPG;
- `generate-postgres-ha-tls.sh` — создание сертификата PostgreSQL HA;
- `verify-postgres-ha.sh` — проверка PostgreSQL HA;
- `POSTGRES_HA.md` — эксплуатация PostgreSQL HA;
- `vault-values.yaml` — актуальные Helm values HashiCorp Vault без `fsGroup`;
- `generate-vault-tls.sh` — выпуск сертификата и создание `vault-server-tls` и `vault-ca`;
- `initialize-vault.sh` — инициализация и безопасный unseal Vault;
- `configure-vault-kubernetes-auth.sh` — настройка KV v2, Kubernetes Auth, policy и role.

Сценарии не выводят значения паролей или приватных ключей. Реальные секреты создаются вне Git.

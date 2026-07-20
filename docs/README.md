# Документация проекта DZ6

Основное описание архитектуры, состава и порядка работы с проектом находится в корневом [README.md](../README.md).

Эксплуатационные инструкции размещены в каталоге [infra](../infra/README.md), а выполненные команды и обезличенные результаты проверок — в каталоге [evidence](../evidence/README.md).

Ключевые документы:

- [HTTPS-only](../infra/HTTPS_ONLY.md);
- [PostgreSQL HA](../infra/POSTGRES_HA.md);
- [эксплуатационные проверки](../evidence/operations.md);
- [замена сертификатов Kubernetes](../evidence/certificate-renewal.md);
- [доказательства PostgreSQL HA](../evidence/postgresql-ha.md);
- [HashiCorp Vault и ротация пароля](../evidence/vault.md).

Финальный отчёт в формате DOCX передаётся отдельно и не хранится в Git.

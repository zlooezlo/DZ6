FROM python:3.13-slim

ARG APP_VERSION=v3-tls
ARG RELEASE_MESSAGE="end-to-end TLS release"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8443

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py ./
RUN printf '{"version":"%s","message":"%s"}\n' \
      "$APP_VERSION" "$RELEASE_MESSAGE" > /app/build-info.json \
    && useradd --uid 10001 --no-create-home --shell /usr/sbin/nologin appuser \
    && chown -R 10001:10001 /app

USER 10001:10001
EXPOSE 8443

CMD ["gunicorn", "--bind", "0.0.0.0:8443", "--certfile", "/etc/dz6-tls/tls.crt", "--keyfile", "/etc/dz6-tls/tls.key", "--workers", "2", "--threads", "2", "--access-logfile", "-", "app:app"]

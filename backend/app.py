import json
import os
import socket
from pathlib import Path

from flask import Flask, jsonify
import psycopg

app = Flask(__name__)

BUILD_INFO_PATH = Path('/app/build-info.json')
try:
    BUILD_INFO = json.loads(BUILD_INFO_PATH.read_text(encoding='utf-8'))
except Exception:
    BUILD_INFO = {'version': 'dev', 'message': 'local development build'}


def db_connection_params() -> dict[str, object]:
    return {
        'host': os.getenv(
            'DB_HOST',
            'postgres.homework.svc.cluster.local',
        ),
        'port': int(os.getenv('DB_PORT', '5432')),
        'dbname': os.getenv('DB_NAME', 'app'),
        'user': os.getenv('DB_USER', 'app'),
        'password': os.getenv('DB_PASSWORD', ''),
        'connect_timeout': 2,
        'sslmode': os.getenv('DB_SSLMODE', 'verify-full'),
        'sslrootcert': os.getenv(
            'DB_SSLROOTCERT',
            '/etc/dz6-tls/ca.crt',
        ),
    }


def pod_name() -> str:
    return os.getenv('POD_NAME') or socket.gethostname()


@app.get('/')
def index():
    return jsonify(
        service='k8s-homework-backend',
        version=BUILD_INFO.get('version', 'unknown'),
        message=BUILD_INFO.get('message', ''),
        pod=pod_name(),
    )


@app.get('/healthz')
def healthz():
    # Liveness: проверяем только, что HTTP-процесс отвечает.
    return jsonify(status='alive'), 200


@app.get('/readyz')
def readyz():
    # Readiness: Pod получает трафик только когда доступна БД.
    try:
        with psycopg.connect(**db_connection_params()) as conn:
            with conn.cursor() as cur:
                cur.execute('SELECT 1')
                cur.fetchone()
        return jsonify(status='ready'), 200
    except Exception as exc:
        return jsonify(status='not-ready', error=type(exc).__name__), 503


@app.post('/api/visits')
@app.get('/api/visits')
def visits():
    with psycopg.connect(**db_connection_params()) as conn:
        with conn.cursor() as cur:
            cur.execute(
                '''
                CREATE TABLE IF NOT EXISTS visits (
                    id BIGSERIAL PRIMARY KEY,
                    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                    pod_name TEXT NOT NULL,
                    app_version TEXT NOT NULL
                )
                '''
            )
            cur.execute(
                'INSERT INTO visits (pod_name, app_version) VALUES (%s, %s) RETURNING id',
                (pod_name(), BUILD_INFO.get('version', 'unknown')),
            )
            visit_id = cur.fetchone()[0]
            cur.execute('SELECT COUNT(*) FROM visits')
            total = cur.fetchone()[0]
        conn.commit()
    return jsonify(
        visit_id=visit_id,
        total=total,
        pod=pod_name(),
        version=BUILD_INFO.get('version', 'unknown'),
    )


@app.get('/api/db-tls')
def database_tls():
    """Показывает параметры TLS текущего соединения с PostgreSQL."""
    with psycopg.connect(**db_connection_params()) as conn:
        with conn.cursor() as cur:
            cur.execute(
                '''
                SELECT ssl, version, cipher
                FROM pg_stat_ssl
                WHERE pid = pg_backend_pid()
                '''
            )
            ssl_enabled, tls_version, cipher = cur.fetchone()
    return jsonify(
        database_tls=ssl_enabled,
        tls_version=tls_version,
        cipher=cipher,
        sslmode=db_connection_params()['sslmode'],
    )

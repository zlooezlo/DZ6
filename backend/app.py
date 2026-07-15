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


def db_dsn() -> str:
    return (
        f"host={os.getenv('DB_HOST', 'postgres')} "
        f"port={os.getenv('DB_PORT', '5432')} "
        f"dbname={os.getenv('DB_NAME', 'app')} "
        f"user={os.getenv('DB_USER', 'app')} "
        f"password={os.getenv('DB_PASSWORD', '')} "
        "connect_timeout=2"
    )


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
        with psycopg.connect(db_dsn()) as conn:
            with conn.cursor() as cur:
                cur.execute('SELECT 1')
                cur.fetchone()
        return jsonify(status='ready'), 200
    except Exception as exc:
        return jsonify(status='not-ready', error=type(exc).__name__), 503


@app.post('/api/visits')
@app.get('/api/visits')
def visits():
    with psycopg.connect(db_dsn()) as conn:
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

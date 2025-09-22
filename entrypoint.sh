#!/bin/sh
set -eu

APP_DIR="/app/django_app"
: "${POSTGRES_HOST:=${DB_HOST:-db}}"
: "${POSTGRES_PORT:=${DB_PORT:-5432}}"
: "${POSTGRES_DB:=${DB_NAME:-appdb}}"
: "${POSTGRES_USER:=${DB_USER:-appuser}}"
: "${POSTGRES_PASSWORD:=${DB_PASSWORD:-apppass}}"
: "${DJANGO_STATIC_ROOT:=}"         # якщо задано — зберемо статику сюди
: "${BIND_ADDR:=0.0.0.0:8000}"
: "${WSGI_APP:=core.wsgi:application}"

echo "➡️  Waiting for Postgres at ${POSTGRES_HOST}:${POSTGRES_PORT}…"
python - <<PY
import os, time, sys
import psycopg
host=os.getenv("POSTGRES_HOST")
port=os.getenv("POSTGRES_PORT")
db  =os.getenv("POSTGRES_DB")
usr =os.getenv("POSTGRES_USER")
pwd =os.getenv("POSTGRES_PASSWORD")
for i in range(60):
    try:
        psycopg.connect(dbname=db, user=usr, password=pwd, host=host, port=port, connect_timeout=3).close()
        print("✅ Postgres is up.")
        sys.exit(0)
    except Exception as e:
        print(f"⏳ waiting for DB: {e}")
        time.sleep(2)
print("❌ DB not reachable in time"); sys.exit(1)
PY

cd "$APP_DIR"

echo "➡️  Applying migrations…"
python manage.py migrate --noinput

if [ -n "$DJANGO_STATIC_ROOT" ]; then
  echo "➡️  Collecting static to $DJANGO_STATIC_ROOT …"
  mkdir -p "$DJANGO_STATIC_ROOT" || true
  # collectstatic може падати, якщо STATIC_ROOT не налаштовано в settings.py – тоді просто попередимо
  python manage.py collectstatic --noinput || echo "⚠️  collectstatic failed (check STATIC_ROOT / DJANGO_STATIC_ROOT)"
fi

echo "🚀 Starting gunicorn: $WSGI_APP on $BIND_ADDR"
exec gunicorn "$WSGI_APP" --bind "$BIND_ADDR"

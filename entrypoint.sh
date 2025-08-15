#!/usr/bin/env bash
set -e

# чекати, доки Postgres прийматиме з’єднання
echo "Waiting for Postgres at ${POSTGRES_HOST:-db}:${POSTGRES_PORT:-5432}…"
until nc -z "${POSTGRES_HOST:-db}" "${POSTGRES_PORT:-5432}"; do
  sleep 1
done
echo "Postgres is up."

# міграції (ігноруємо, якщо проект ще не ініціалізовано)
if [ -f "django_app/manage.py" ]; then
  python django_app/manage.py migrate --noinput || true
fi

# DEV запуск — звичайний runserver (можна замінити на gunicorn)
exec python django_app/manage.py runserver 0.0.0.0:8000
# для gunicorn (коли вже є settings wsgi):
# exec gunicorn core.wsgi:application --bind 0.0.0.0:8000

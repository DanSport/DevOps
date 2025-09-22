# syntax=docker/dockerfile:1
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 ca-certificates && \
    rm -rf /var/lib/apt/lists/*

RUN python -m venv /venv
ENV PATH="/venv/bin:$PATH"

COPY requirements.txt .
# Якщо в майбутньому додаси пакети без готових wheel'ів, можливо доведеться прибрати --only-binary=:all:
RUN pip install --no-cache-dir --only-binary=:all: -r requirements.txt

COPY django_app/ ./django_app/
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

WORKDIR /app/django_app
EXPOSE 8000

# КЛЮЧОВО: запускаємо через entrypoint (всередині він зробить migrate/collectstatic і стартане gunicorn)
ENTRYPOINT ["/app/entrypoint.sh"]

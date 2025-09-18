
FROM python:3.12-slim AS builder
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1
# тільки для збирання коліс
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gcc git curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
# збираємо .whl у /wheels (швидко, кешується)
RUN pip wheel --wheel-dir /wheels -r requirements.txt

# -------- Stage 2: runtime --------
FROM python:3.12-slim AS runtime
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

# мінімальні системні бібліотеки для рантайму (наприклад, для psycopg)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
# інсталимо тільки готові колеса (без компіляції)
COPY --from=builder /wheels /wheels
RUN pip install --no-cache-dir --find-links=/wheels -r /wheels/*

# важливо: скопіюй manage.py і сам пакет проєкту
COPY django_app/core/manage.py ./                 # якщо він у корені репо
COPY django_app/ ./django_app/    # твій код
COPY entrypoint.sh ./             # якщо використовуєш
RUN chmod +x /app/entrypoint.sh

EXPOSE 8000
# production-сервер — gunicorn
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "django_app.core.wsgi:application"]

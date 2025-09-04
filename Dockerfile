FROM python:3.12-alpine

# Встановимо залежності, потрібні для psycopg[binary] і gunicorn мінімально
RUN apk add --no-cache libpq

# Папка застосунку
WORKDIR /app

# Спочатку лише requirements, щоб кешувався pip layer
COPY requirements.txt .

# Встановлення без кешу pip
ENV PIP_NO_CACHE_DIR=1
RUN pip install --no-cache-dir -r requirements.txt

# Копіюємо вихідний код (лише Django-проєкт і entrypoint)
COPY django_app/ ./django_app/
COPY entrypoint.sh ./
RUN chmod +x /app/entrypoint.sh

# Для gunicorn – порт 8000
EXPOSE 8000

# За замовчуванням – старт gunicorn (менше навантаження і стабільніше, ніж runserver)
WORKDIR /app/django_app
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "core.wsgi:application"]

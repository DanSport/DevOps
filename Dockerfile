FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# системні пакети (netcat для очікування БД, psycopg2 залежності)
RUN apt-get update && apt-get install -y \
    netcat-traditional build-essential libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# копіюємо увесь проєкт
COPY . .

# робимо entrypoint виконуваним
RUN chmod +x /app/entrypoint.sh

EXPOSE 8000
ENTRYPOINT ["/app/entrypoint.sh"]

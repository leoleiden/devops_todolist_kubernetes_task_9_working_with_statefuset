# Використання багатостадійної побудови для зменшення розміру кінцевого образу
# Стадія 'builder' для встановлення залежностей та збирання файлів
FROM python:3.10-slim-buster AS builder

# Встановіть залежності, необхідні для компіляції mysqlclient
# та інші системні залежності для Python-додатка.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    gcc \
    default-libmysqlclient-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Встановіть робочу директорію
WORKDIR /app

# Копіюємо файл requirements.txt та встановлюємо залежності
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Перемикаємося на нову, чисту базову стадію для кінцевого образу
FROM python:3.10-slim-buster

# Встановіть робочу директорію
WORKDIR /app

# Налаштуйте змінну оточення, щоб Python не буферизував вивід
ENV PYTHONUNBUFFERED 1

# Копіюємо збірки з попередньої стадії
COPY --from=builder /app /app

# Копіюємо решту файлів проекту
COPY . /app

# Відкриваємо порт, на якому буде працювати додаток
EXPOSE 8080

# Команда для запуску Gunicorn сервера.
# Міграції тепер запускаються як частина команди контейнера в Kubernetes Deployment.
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "todolist.wsgi:application"]

#!/bin/bash

# Переконайтеся, що ви знаходитесь в кореневій директорії вашого проекту,
# де знаходяться Dockerfile та YAML-файли.

echo "1. Creating Kind cluster..."
# Якщо кластер вже існує, ця команда може видати попередження, але продовжить роботу.
# Для повного скидання можна додати `kind delete cluster` перед цим.
kind create cluster --name todo-cluster # Якщо у вас є cluster.yml, додайте --config cluster.yml

echo "2. Building Docker image for the Todo App..."
# Переконайтеся, що Dockerfile знаходиться у поточному каталозі або вкажіть шлях до нього
docker build -t leoleiden/todo-app:latest . # Використовуйте ваш образ

echo "3. Loading Docker image into Kind cluster..."
kind load docker-image leoleiden/todo-app:latest --name todo-cluster

echo "4. Applying MySQL resources (Namespace, Secret, Headless Service, StatefulSet, ConfigMap)..."
kubectl apply -f statefulSet.yml

echo "5. Waiting for MySQL Pod (mysql-0) to be Ready..."
# Ми чекаємо на Pod з ім'ям "mysql-0" у namespace "mysql"
kubectl wait --namespace mysql --for=condition=Ready pod/mysql-0 --timeout=300s || { echo "MySQL Pod did not become Ready in time. Exiting."; exit 1; }

echo "6. Applying Todo App Deployment (including its Secret)..."
kubectl apply -f deployment.yml

echo "7. Applying Todo App Service..."
kubectl apply -f service.yml

echo "Deployment complete. Verifying resources..."

echo "--- MySQL Resources ---"
kubectl get namespace mysql
kubectl get secret -n mysql mysql-secrets
kubectl get svc -n mysql mysql
kubectl get statefulset -n mysql mysql
kubectl get pvc -n mysql -l app=mysql
kubectl get pod -n mysql -l app=mysql

echo "--- Todo App Resources ---"
kubectl get secret todo-app-secrets # Перевіряємо Secret для Todo App
kubectl get deployment todo-app-deployment
kubectl get svc todo-app-service
kubectl get pods -l app=todo-app

echo "To access the Todo App, use port-forwarding:"
echo "kubectl port-forward service/todo-app-service 8000:80"
echo "Then navigate to http://localhost:8000/ in your browser."

echo ""
echo "--- Initial Django Migrations for MySQL ---"
echo "You MUST run Django migrations to set up the database schema in MySQL."
echo "Execute the following commands after the deployment is complete and the Todo App Pod is Ready:"
echo "kubectl exec -it $(kubectl get pod -l app=todo-app -o jsonpath='{.items[0].metadata.name}') -- python manage.py makemigrations lists"
echo "kubectl exec -it $(kubectl get pod -l app=todo-app -o jsonpath='{.items[0].metadata.name}') -- python manage.py migrate"
echo "kubectl exec -it $(kubectl get pod -l app=todo-app -o jsonpath='{.items[0].metadata.name}') -- python manage.py createsuperuser --noinput || true"
echo "  (For createsuperuser, you might need to set DJANGO_SUPERUSER_USERNAME, DJANGO_SUPERUSER_EMAIL, DJANGO_SUPERUSER_PASSWORD as environment variables in deployment.yml for --noinput to work, or run it interactively)."
echo "  (Otherwise, run 'kubectl exec -it <your-todo-app-pod-name> -- python manage.py createsuperuser' and follow prompts)"
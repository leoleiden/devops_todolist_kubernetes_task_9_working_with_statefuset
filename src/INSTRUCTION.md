Markdown

# Інструкції з розгортання та валідації Django Todo-App у Kubernetes (Kind)

Цей документ містить покрокові інструкції щодо розгортання Django Todo-App, яка використовує базу даних MySQL, розгорнуту як `StatefulSet` у локальному Kubernetes кластері Kind. Облікові дані для MySQL та Django-додатку зберігаються у Kubernetes `Secret` для безпеки та гнучкості.

## Зміст

1.  [Огляд архітектури](#1-огляд-архітектури)
2.  [Попередні вимоги](#2-попередні-вимоги)
3.  [Структура проекту та файли](#3-структура-проекту-та-файли)
4.  [Підготовка до розгортання](#4-підготовка-до-розгортання)
    * 4.1. Оновлення `requirements.txt`
    * 4.2. Оновлення `todolist/settings.py`
    * 4.3. Перевірка `Dockerfile`
    * 4.4. Перевірка та оновлення YAML-файлів
        * `statefulSet.yml` (MySQL)
        * `deployment.yml` (Django App)
        * `service.yml` (Django App Service)
5.  [Процес розгортання](#5-процес-розгортання)
    * 5.1. Запуск `bootstrap.sh`
    * 5.2. Дії скрипта `bootstrap.sh`
6.  [Валідація розгортання](#6-валідація-розгортання)
    * 6.1. Перевірка кластера Kind
    * 6.2. Перевірка ресурсів MySQL
    * 6.3. Перевірка ресурсів Django Todo-App
    * 6.4. Перевірка логів додатка
7.  [Виконання міграцій Django](#7-виконання-міграцій-django)
8.  [Доступ до додатка](#8-доступ-до-додатка)
9.  [Перевірка персистентності даних (опціонально)](#9-перевірка-персистентності-даних-опціонально)
10. [Очищення (Cleanup)](#10-очищення-cleanup)
11. [Можливі проблеми та їх вирішення](#11-можливі-проблеми-та-їх-вирішення)

---

## 1. Огляд архітектури

* **Django Todo-App:** Ваш Python-додаток, розгорнутий як `Deployment`. Він підключається до бази даних MySQL.
* **MySQL Database:** Розгорнута як `StatefulSet` для забезпечення персистентності даних. Доступ до неї здійснюється через `Headless Service`.
* **Kubernetes Secrets:** Використовуються для безпечного зберігання облікових даних MySQL та конфігураційних даних Django (наприклад, `SECRET_KEY`).
* **Kind (Kubernetes in Docker):** Легкий інструмент для запуску локальних кластерів Kubernetes у контейнерах Docker.

## 2. Попередні вимоги

Переконайтеся, що на вашій системі встановлено наступне програмне забезпечення:

* **Docker:** Необхідний для запуску кластера Kind та збирання Docker-образів.
    * [Офіційний сайт Docker](https://docs.docker.com/get-docker/)
* **Kind (Kubernetes in Docker):** Інструмент для створення локальних кластерів Kubernetes.
    * [Встановлення Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
* **kubectl:** Інтерфейс командного рядка для взаємодії з кластерами Kubernetes.
    * [Встановлення kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

## 3. Структура проекту та файли

Переконайтеся, що всі необхідні файли знаходяться в кореневій директорії вашого проекту, або шлях до них правильно вказаний у скрипті `bootstrap.sh`.

* `Dockerfile`: Визначає, як створювати Docker-образ для вашого Django-додатку.
* `requirements.txt`: Перелік залежностей Python для вашого Django-додатку.
* `todolist/settings.py`: Налаштування Django-додатку (особливо конфігурація бази даних).
* `statefulSet.yml`: Kubernetes маніфести для розгортання MySQL (Namespace, Secret, Headless Service, StatefulSet, ConfigMap для ініціалізації БД).
* `deployment.yml`: Kubernetes маніфести для розгортання Django-додатку (Secret для додатка, Deployment).
* `service.yml`: Kubernetes маніфест для Service, який надає доступ до Django-додатку.
* `bootstrap.sh`: Скрипт автоматизації розгортання.

## 4. Підготовка до розгортання

Перед запуском скрипта `bootstrap.sh`, переконайтеся, що ваші файли конфігурації оновлені відповідно до вимог MySQL та Secrets.

### 4.1. Оновлення `requirements.txt`

Додайте залежність `mysqlclient` для підключення Django до MySQL:

```text
# ... інші ваші залежності
mysqlclient==2.1.1 # Або інша сумісна версія
4.2. Оновлення todolist/settings.py
Змініть конфігурацію бази даних у todolist/settings.py для використання MySQL та читання облікових даних зі змінних оточення:

Python

import os

# ... (початок файлу без змін) ...

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.mysql",
        "HOST": os.environ.get("MYSQL_HOST"),
        "PORT": os.environ.get("MYSQL_PORT", "3306"),
        "NAME": os.environ.get("MYSQL_DATABASE_NAME"),
        "USER": os.environ.get("MYSQL_USER"),
        "PASSWORD": os.environ.get("MYSQL_PASSWORD"),
    }
}

# ... (решта файлу без змін) ...
4.3. Перевірка Dockerfile
Переконайтеся, що ваш Dockerfile встановлює всі залежності з requirements.txt та запускає додаток на порті 8080 (як вказано в deployment.yml та service.yml). Він також повинен включати mysqlclient.

4.4. Перевірка та оновлення YAML-файлів
statefulSet.yml (MySQL)
Цей файл містить визначення Namespace, Secret для MySQL, Headless Service, StatefulSet та ConfigMap.
Переконайтеся, що:

Secret (mysql-secrets) містить поля MYSQL_ROOT_PASSWORD, MYSQL_USER, MYSQL_PASSWORD та MYSQL_DATABASE_NAME.

Headless Service має clusterIP: None та ім'я mysql.

StatefulSet має serviceName: "mysql" та replicas: 1 (для mysql-0).

Змінні оточення контейнера MySQL посилаються на mysql-secrets.

volumeClaimTemplates має storageClassName: "standard" (для Kind).

ConfigMap (mysql-initdb-config) містить init.sql, який створює базу даних та користувача, що відповідає даним у mysql-secrets.

deployment.yml (Django App)
Цей файл містить Secret для Django-додатку (todo-app-secrets) та його Deployment.
Переконайтеся, що:

Secret (todo-app-secrets) містить SECRET_KEY, DEBUG, а також всі облікові дані для підключення до MySQL (MYSQL_DATABASE_NAME, MYSQL_USER, MYSQL_PASSWORD, MYSQL_HOST, MYSQL_PORT).

Deployment має containerPort: 8080.

Усі змінні оточення для контейнера Django посилаються на todo-app-secrets.

Команда запуску додатка виконує міграції: command: ["/bin/sh"] та args: ["-c", "python manage.py makemigrations lists && python manage.py migrate && python manage.py runserver 0.0.0.0:8080"].

Liveness та Readiness Probe налаштовані на відповідні шляхи та порт 8080 (наприклад, /api/health, /api/ready).

service.yml (Django App Service)
Переконайтеся, що targetPort відповідає порту, на якому ваш Django-додаток слухає всередині контейнера (8080).

YAML

apiVersion: v1
kind: Service
metadata:
  name: todo-app-service
spec:
  selector:
    app: todo-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080 # ВАЖЛИВО: Цей порт має співпадати з containerPort у deployment.yml
      nodePort: 32055 # Це дозволить доступ через IP вузла Kind та цей порт
  type: NodePort
5. Процес розгортання
5.1. Запуск bootstrap.sh
Виконайте скрипт bootstrap.sh з кореневої директорії вашого проекту:

Bash

./bootstrap.sh
5.2. Дії скрипта bootstrap.sh
Скрипт bootstrap.sh автоматизує весь процес розгортання:

Створення кластера Kind: Створює кластер Kind з ім'ям todo-cluster.

Побудова Docker-образу: Ваш Django-додаток буде збудований у Docker-образі з тегом leoleiden/todo-app:latest.

Завантаження образу в Kind: Створений Docker-образ буде завантажений безпосередньо у вузли Kind (кластер todo-cluster), щоб Kubernetes міг його знайти.

Застосування MySQL ресурсів: Застосовується statefulSet.yml, який розгортає Namespace, Secret, Headless Service, StatefulSet та ConfigMap для вашої MySQL бази даних.

Очікування готовності MySQL: Скрипт чекає, поки Pod mysql-0 стане готовим, забезпечуючи, що база даних доступна, перш ніж розгортати додаток.

Застосування Django Todo-App: Застосовується deployment.yml, який розгортає Secret для додатка та сам Deployment Django Todo-App.

Застосування Django Service: Застосовується service.yml, який надає доступ до вашого Django-додатку.

Перевірка статусу: Скрипт виводить команди для перевірки стану всіх розгорнутих ресурсів.

6. Валідація розгортання
Після завершення виконання bootstrap.sh (і якщо він не видав помилок), виконайте наступні команди, щоб переконатися, що все працює належним чином.

6.1. Перевірка кластера Kind
Переконайтеся, що ваш кластер Kind працює та активний потрібний контекст:

Bash

# Перевірка наявних кластерів Kind
kind get clusters
# Очікуваний вивід: має бути 'todo-cluster'

# Перевірка наявних контекстів kubectl
kubectl config get-contexts
# Очікуваний вивід: має бути контекст 'kind-todo-cluster'

# Встановлення правильного контексту (якщо не встановлено автоматично)
kubectl config use-context kind-todo-cluster

# Перевірка інформації про кластер
kubectl cluster-info
# Або з явним контекстом: kubectl cluster-info --context kind-todo-cluster
# Очікуваний вивід: "Kubernetes control plane is running at..."

# Перегляньте вузли кластера
kubectl get nodes
# Очікуваний вивід: Вузол "todo-cluster-control-plane" (або подібний) у стані "Ready".
6.2. Перевірка ресурсів MySQL
Bash

echo "--- Перевірка Namespace MySQL ---"
kubectl get namespace mysql
# Очікуваний вивід: Namespace "mysql" у стані "Active"

echo "--- Перевірка Secret MySQL ---"
kubectl get secret -n mysql mysql-secrets
# Очікуваний вивід: Secret "mysql-secrets" типу "Opaque".

echo "--- Перевірка Headless Service MySQL ---"
kubectl get svc -n mysql mysql
# Очікуваний вивід: Service "mysql" з CLUSTER-IP "None". Це підтверджує, що він headless.

echo "--- Перевірка StatefulSet MySQL ---"
kubectl get statefulset -n mysql mysql
# Очікуваний вивід: StatefulSet "mysql" з 1 бажаною та 1 поточною реплікою, Ready 1/1.

echo "--- Перевірка Pod'ів MySQL ---"
kubectl get pod -n mysql -l app=mysql
# Очікуваний вивід: Pod "mysql-0" у стані "Running" та "Ready" (1/1).
6.3. Перевірка ресурсів Django Todo-App
Bash

echo "--- Перевірка Secret Django Todo-App ---"
kubectl get secret todo-app-secrets
# Очікуваний вивід: Secret "todo-app-secrets" типу "Opaque".

echo "--- Перевірка Deployment Django Todo-App ---"
kubectl get deployment todo-app-deployment
# Очікуваний вивід: Deployment "todo-app-deployment" з 1 бажаною та 1 поточною реплікою, Ready 1.

echo "--- Перевірка Service Django Todo-App ---"
kubectl get svc todo-app-service
# Очікуваний вивід: Service "todo-app-service" з TYPE "NodePort" та NODEPORT "32055".

echo "--- Перевірка Pod'ів Django Todo-App ---"
kubectl get pods -l app=todo-app
# Очікуваний вивід: Pod вашого додатка у стані "Running" та "Ready" (1/1).
6.4. Перевірка логів додатка
Переконайтеся, що Django-додаток успішно підключився до MySQL.

Знайдіть ім'я Pod'а вашого Django-додатку:

Bash

DJANGO_POD_NAME=$(kubectl get pod -l app=todo-app -o jsonpath='{.items[0].metadata.name}')
echo "Django Pod Name: $DJANGO_POD_NAME"
Перегляньте логи цього Pod'а:

Bash

kubectl logs $DJANGO_POD_NAME
# Шукайте повідомлення про успішне підключення до бази даних MySQL,
# а також про запуск сервера розробки Django (наприклад, "Starting development server at [http://0.0.0.0:8080/](http://0.0.0.0:8080/)").
7. Виконання міграцій Django
ВАЖЛИВО: Після успішного розгортання MySQL та Django-додатку, вам потрібно виконати міграції Django, щоб створити необхідні таблиці в базі даних MySQL. Це робиться один раз при першому розгортанні або при зміні моделей даних.

Виконайте наступні команди:

Bash

# 1. Створення файлів міграцій (якщо ви внесли зміни в моделі)
# Цей крок може бути інтегрований у command/args Deployment, але якщо ні, виконайте вручну.
kubectl exec -it $(kubectl get pod -l app=todo-app -o jsonpath='{.items[0].metadata.name}') -- python manage.py makemigrations lists

# 2. Застосування міграцій до бази даних MySQL
kubectl exec -it $(kubectl get pod -l app=todo-app -o jsonpath='{.items[0].metadata.name}') -- python manage.py migrate

# 3. Створення суперкористувача для доступу до Django Admin (опціонально)
# Якщо ви не налаштували змінні оточення для автоматичного створення, виконайте інтерактивно:
kubectl exec -it $(kubectl get pod -l app=todo-app -o jsonpath='{.items[0].metadata.name}') -- python manage.py createsuperuser
# Дотримуйтесь підказок у терміналі для введення імені користувача, email та пароля.
# Або, якщо ви налаштували змінні оточення для createsuperuser --noinput у deployment.yml,
# можете спробувати:
# kubectl exec -it $(kubectl get pod -l app=todo-app -o jsonpath='{.items[0].metadata.name}') -- python manage.py createsuperuser --noinput
8. Доступ до додатка
Щоб отримати доступ до вашого Todo-App з вашої хост-машини, використовуйте kubectl port-forward:

Bash

kubectl port-forward service/todo-app-service 8000:80
Ця команда перенаправляє трафік з локального порту 8000 на порт 80 вашого todo-app-service у кластері.

Відкрийте ваш веб-браузер і перейдіть за адресою:

http://localhost:8000/
Ви повинні побачити інтерфейс вашого Todo-App. Спробуйте додати нові завдання або Todo-листи, щоб перевірити взаємодію з базою даних.

9. Перевірка персистентності даних (опціонально)
Щоб перевірити, чи дані дійсно зберігаються у MySQL (через PersistentVolume), виконайте наступні кроки:

Додайте кілька нових Todo-завдань або Todo-листів через веб-інтерфейс додатка.

Видаліть Pod вашого Django-додатку, щоб симулювати перезапуск або збій:

Bash

kubectl delete pod $(kubectl get pod -l app=todo-app -o jsonpath='{.items[0].metadata.name}')
Дочекайтеся, поки Kubernetes автоматично створить і запустить новий Pod для todo-app-deployment. Перевірити стан Pod'ів можна командою:

Bash

kubectl get pods -l app=todo-app
Знову отримайте доступ до додатка через http://localhost:8000/ (вам, можливо, доведеться повторно запустити kubectl port-forward, якщо попередній сеанс було закрито).

Перевірте, чи всі раніше додані вами завдання та Todo-листи все ще присутні. Якщо так, це підтверджує успішну персистентність даних у MySQL.

10. Очищення (Cleanup)
Щоб видалити всі розгорнуті ресурси та очистити кластер Kind:

Видалення ресурсів Kubernetes:

Bash

kubectl delete -f deployment.yml
kubectl delete -f service.yml
kubectl delete -f statefulSet.yml # Це видалить StatefulSet, Headless Service, Secret та ConfigMap для MySQL
kubectl delete namespace mysql # Додатково видаляє namespace MySQL, якщо він більше не потрібен
Видалення кластера Kind:

Bash

kind delete cluster --name todo-cluster # Використовуйте правильне ім'я кластера Kind
Видалення Docker-образу (опціонально):

Bash

docker rmi leoleiden/todo-app:latest
11. Можливі проблеми та їх вирішення
Pod MySQL не запускається (CrashLoopBackOff або Pending):

Перевірте логи Pod'а MySQL: kubectl logs -n mysql mysql-0.

Переконайтеся, що MYSQL_ROOT_PASSWORD у Secret та init.sql збігаються.

Перевірте ConfigMap (mysql-initdb-config) на синтаксичні помилки SQL.

Перевірте наявність storageClassName: "standard" у volumeClaimTemplates для StatefulSet. Переконайтеся, що ваш Kind кластер має standard StorageClass (зазвичай є за замовчуванням).

Якщо Pod знаходиться в стані Pending, перевірте події: kubectl describe pod -n mysql mysql-0 (може бути проблема з PersistentVolumeClaim).

Pod Django Todo-App не запускається або не підключається до БД:

Перевірте логи Pod'а Django: kubectl logs $(kubectl get pod -l app=todo-app -o jsonpath='{.items[0].metadata.name}').

Переконайтеся, що todolist/settings.py правильно налаштований для MySQL і читає змінні оточення.

Перевірте deployment.yml:

Чи правильно передаються всі змінні оточення з todo-app-secrets?

Чи правильний MYSQL_HOST (має бути mysql-0.mysql.mysql.svc.cluster.local)?

Чи правильний MYSQL_PORT (3306)?

Чи є помилки у command або args (наприклад, шлях до manage.py)?

Переконайтеся, що Pod MySQL mysql-0 знаходиться у стані "Ready" (kubectl get pod -n mysql -l app=mysql).

Додаток доступний, але дані не зберігаються або виникають помилки з БД:

Переконайтеся, що ви виконали міграції Django (python manage.py migrate).

Перевірте, чи користувач MySQL (leoleiden) має необхідні права на базу даних tododb (це налаштовується в init.sql у ConfigMap).

Проблеми з port-forward:

Переконайтеся, що todo-app-service запущений: kubectl get svc todo-app-service.

Переконайтеся, що Pod додатка працює коректно.

Спробуйте інший локальний порт, якщо 8000 зайнятий (наприклад, kubectl port-forward service/todo-app-service 8001:80).

Переконайтеся, що немає конфлікту портів на вашій хост-машині.

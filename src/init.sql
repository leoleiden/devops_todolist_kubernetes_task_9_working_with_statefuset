CREATE DATABASE IF NOT EXISTS tododb;
CREATE USER IF NOT EXISTS 'leoleiden'@'%' IDENTIFIED BY '7410'; # <-- Виправлено користувача та пароль
GRANT ALL PRIVILEGES ON tododb.* TO 'leoleiden'@'%'; # <-- Виправлено користувача
FLUSH PRIVILEGES;

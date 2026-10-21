# Деплой Redmine с помощью Ansible

[![hexlet-check](https://github.com/Absaidov/devops-engineer-from-scratch-project-76/actions/workflows/hexlet-check.yml/badge.svg)](https://github.com/Absaidov/devops-engineer-from-scratch-project-76/actions)

Автоматизация подготовки двух Ubuntu-серверов и развёртывания Redmine в
Docker. Приложение работает на двух ВМ за Application Load Balancer и
использует управляемый кластер PostgreSQL в Yandex Cloud.

Задеплоенное приложение: [https://uit14.ru](https://uit14.ru)

Учебный проект Хекслета: https://ru.hexlet.io/programs/devops-engineer-from-scratch
Как это должно работать: https://asciinema.org/a/v4evn7XjCdou7Yh71IG0ljb0W

## Стек

- Ansible
- Docker Engine и Docker Compose
- Redmine `7.0.2`
- Managed Service for PostgreSQL
- Yandex Application Load Balancer
- роли `geerlingguy.pip` и `geerlingguy.docker`
- коллекция `community.docker`

## Требования

- Ansible установлен на локальной машине;
- приватный SSH-ключ находится в `~/.ssh/project-76` и имеет права `600`;
- обе виртуальные машины запущены и доступны по SSH;
- актуальные IP-адреса указаны в `inventory.ini`.
- кластер PostgreSQL содержит базу и пользователя `project76`;
- балансировщик направляет запросы на порт `3000` обеих ВМ.

## Установка

```bash
git clone https://github.com/Absaidov/devops-engineer-from-scratch-project-76.git
cd devops-engineer-from-scratch-project-76
chmod 600 ~/.ssh/project-76
make install
```

Команда `make install` устанавливает роли и коллекции из `requirements.yml`.
Makefile автоматически выбирает системный CA bundle для подключения к Ansible
Galaxy. При нестандартном расположении его можно передать явно:

```bash
make install CA_BUNDLE=/path/to/ca-bundle.pem
```

Приватный SSH-ключ и другие секреты добавлять в репозиторий нельзя.

## Локальный запуск Redmine

Для проверки официального образа запустите Docker Desktop, затем выполните:

```bash
docker run --rm --name project-76-redmine-local \
  --publish 3000:3000 \
  redmine:7.0.2-bookworm
```

После запуска Redmine доступен по адресу <http://localhost:3000>. Остановить
контейнер можно сочетанием `Ctrl+C`. Локальный запуск использует временную
SQLite-базу и нужен только для проверки образа.

## Использование

Проверить подключение Ansible к серверам:

```bash
make ping
```

Проверить синтаксис плейбука:

```bash
make syntax
```

Установить на обеих ВМ pip, Python SDK для Docker и Docker Engine:

```bash
make prepare
```

Для новой локальной машины зависимости и подготовку серверов можно выполнить
одной командой:

```bash
make setup
```

Проверить Docker Engine и установленный Python-пакет `docker`:

```bash
make check
```

## Деплой приложения

Плейбук получает пароль PostgreSQL и общий секрет Redmine из переменных
окружения локальной машины. Значения не хранятся в Git и не выводятся Ansible.

Перед первым деплоем введите пароль базы данных и сгенерируйте секрет:

```bash
read -s REDMINE_DB_PASSWORD
echo
export REDMINE_DB_PASSWORD
export REDMINE_SECRET_KEY_BASE="$(openssl rand -hex 64)"
make deploy
```

Сохраните `REDMINE_SECRET_KEY_BASE` в менеджере паролей и используйте то же
значение при следующих деплоях. Его замена завершит действующие пользовательские
сессии Redmine. Пароль базы данных также не следует передавать в командной строке
или добавлять в файлы репозитория. Для совместимости с конфигурацией официального
образа он не должен начинаться или заканчиваться пробелом, а также содержать
двойную кавычку или обратную косую черту.

Команда `make deploy` запускает только задачи с тегом `deploy`: роли подготовки
сервера повторно не выполняются. На каждой ВМ плейбук:

1. загружает корневой сертификат Yandex Cloud;
2. создаёт защищённый файл `/opt/project-76/redmine/.env` из Jinja-шаблона;
3. создаёт Docker volume для вложений;
4. запускает и проверяет контейнер `project-76-redmine` на порту `3000`.

Деплой идёт последовательно (`serial: 1`), чтобы две реплики одновременно не
выполняли миграции базы данных. Соединение с PostgreSQL защищено TLS с проверкой
сертификата.

Проверить приложение на обеих ВМ и через публичный адрес:

```bash
make health
```

После первой авторизации стандартной парой `admin` / `admin` Redmine потребует
сменить пароль администратора.

## Настройки балансировщика и HTTPS

- backend и HTTP health check используют порт `3000`;
- целевая группа содержит обе ВМ;
- группа безопасности ВМ принимает TCP `3000` только от группы безопасности
  балансировщика;
- HTTP-обработчик принимает запросы на порту `80`;
- HTTPS-обработчик принимает запросы на порту `443` и использует управляемый
  сертификат для `uit14.ru`;
- A-запись `uit14.ru` указывает на публичный IP балансировщика.

В учебном проекте volume с вложениями локален для каждой ВМ. Для production
общие пользовательские файлы следует вынести в совместимое объектное хранилище.

Плейбук `playbook.yml` применяется ко всем хостам (`hosts: all`). Переменные
ролей и Redmine, включая обязательную `redmine_port`, находятся в
`group_vars/all.yml`, а группа из двух серверов — в `inventory.ini` под именем
`webservers`.

Для ручного SSH-подключения доступны команды:

```bash
make ssh-vm-1
make ssh-vm-2
```

---

<details>
<summary>Автоматические тесты Хекслета</summary>

Тесты запускаются на каждый коммит. За запуск отвечает файл `.github/workflows/hexlet-check.yml` — не удаляйте и не переименовывайте ни его, ни репозиторий.

</details>

## О Хекслете

[Хекслет](https://ru.hexlet.io/) — школа программирования: авторские программы обучения с практикой, поддержкой наставников и реальными проектами, которые остаются в резюме. Этот репозиторий — один из таких проектов.

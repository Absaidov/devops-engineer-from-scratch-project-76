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
- Datadog Agent 7 и интеграция HTTP Check
- роли `geerlingguy.pip` и `geerlingguy.docker`
- коллекции `community.docker` и `datadog.dd`

## Требования

- Ansible установлен на локальной машине;
- приватный SSH-ключ находится в `~/.ssh/project-76` и имеет права `600`;
- обе виртуальные машины запущены и доступны по SSH;
- актуальные IP-адреса указаны в `inventory.ini`.
- кластер PostgreSQL содержит базу и пользователя `project76`;
- балансировщик направляет запросы на порт `3000` обеих ВМ.
- создан зашифрованный файл `group_vars/webservers/vault.yml` с секретами
  приложения и мониторинга.

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

Все Ansible-команды запрашивают пароль Ansible Vault. Это пароль для
расшифровки секретов проекта, а не пароль пользователя PostgreSQL.

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

Пароль PostgreSQL и общий секрет Redmine хранятся в целиком зашифрованном
Ansible Vault-файле `group_vars/webservers/vault.yml`. Создайте его командой:

```bash
EDITOR=nano make vault-create
```

Сначала команда дважды запросит новый пароль **Ansible Vault**. Запомните его:
без него расшифровать файл будет невозможно. Затем в открывшемся редакторе
добавьте YAML со значениями без угловых скобок:

```yaml
---
vault_redmine_db_password: "<пароль пользователя project76 в PostgreSQL>"
vault_redmine_secret_key_base: "<сохранённый текущий SECRET_KEY_BASE>"
```

Используйте то же значение `SECRET_KEY_BASE`, с которым приложение уже работает:
его замена завершит действующие пользовательские сессии Redmine. Пароль базы
данных не должен начинаться или заканчиваться пробелом, а также содержать двойную
кавычку или обратную косую черту.

Для последующего изменения секретов используйте `make vault-edit`. Команда
`make vault-view` выводит расшифрованные значения в терминал, поэтому запускайте
её только при необходимости. Зашифрованный `vault.yml` нужно хранить в Git, а
пароль от него — только в менеджере паролей и никогда не добавлять в репозиторий.

Чтобы не вводить Vault-пароль вручную при каждом запуске, можно сохранить его в
файле вне репозитория с правами `600` и передать путь явно:

```bash
make deploy VAULT_PASSWORD_FILE="$HOME/.config/ansible/project-76-vault-password"
```

После создания Vault-файла выполните деплой:

```bash
make deploy
```

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

## Мониторинг

Зарегистрируйтесь в Datadog и создайте **API key** в настройках организации.
Для агента нужен именно API key, а не Application key. Значение API key нельзя
добавлять в открытые файлы или историю команд.

Параметр `datadog_site` в `group_vars/webservers/vars.yml` должен соответствовать
адресу панели Datadog:

- `https://app.datadoghq.com` — `datadoghq.com`;
- `https://app.datadoghq.eu` — `datadoghq.eu`;
- `https://us3.datadoghq.com` — `us3.datadoghq.com`;
- для US5, AP1, AP2 и UK1 используется домен из адреса панели.

По умолчанию настроен сайт `datadoghq.com` (US1). Добавьте API key в
зашифрованный Vault-файл:

```bash
EDITOR=nano make vault-edit
```

Не удаляя существующие переменные, добавьте:

```yaml
vault_datadog_api_key: "<API key из Datadog>"
```

Установите новую коллекцию и настройте агент только на серверах группы
`webservers`:

```bash
make install
make monitoring
```

Проверить локальный `http_check` на обеих ВМ:

```bash
make monitoring-check
```

Каждый агент проверяет `http://127.0.0.1:3000/login`, поэтому результат отражает
состояние конкретного экземпляра Redmine. В Datadog должны появиться две ВМ,
service check `http.can_connect` и метрика `network.http.response_time`. Передача
данных может занять несколько минут. Новые входящие правила группы безопасности
не нужны: агент сам устанавливает исходящие HTTPS-соединения с Datadog.

Команда `make deploy` по-прежнему запускает только приложение. Для изменения
ключа используйте `make vault-edit`, затем повторно выполните `make monitoring`.

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
ролей находятся в `group_vars/all.yml`, а параметры Redmine, включая обязательную
`redmine_port`, — в `group_vars/webservers/vars.yml`. Секреты находятся в
зашифрованном `group_vars/webservers/vault.yml`. Группа из двух серверов описана
в `inventory.ini` под именем `webservers`.

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

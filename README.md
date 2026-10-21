# Деплой Docker-образов с помощью Ansible

[![hexlet-check](https://github.com/Absaidov/devops-engineer-from-scratch-project-76/actions/workflows/hexlet-check.yml/badge.svg)](https://github.com/Absaidov/devops-engineer-from-scratch-project-76/actions)

Автоматизация подготовки двух Ubuntu-серверов и развёртывания
контейнеризированного приложения с помощью Ansible.

Учебный проект Хекслета: https://ru.hexlet.io/programs/devops-engineer-from-scratch
Как это должно работать: https://asciinema.org/a/v4evn7XjCdou7Yh71IG0ljb0W

## Стек

- Ansible
- Docker Engine и Docker Compose
- роли `geerlingguy.pip` и `geerlingguy.docker`
- коллекция `community.docker`

## Требования

- Ansible установлен на локальной машине;
- приватный SSH-ключ находится в `~/.ssh/project-76` и имеет права `600`;
- обе виртуальные машины запущены и доступны по SSH;
- актуальные IP-адреса указаны в `inventory.ini`.

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

Плейбук `playbook.yml` применяется ко всем хостам (`hosts: all`). Переменные
ролей находятся в `group_vars/all.yml`, а группа из двух серверов — в
`inventory.ini` под именем `webservers`.

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

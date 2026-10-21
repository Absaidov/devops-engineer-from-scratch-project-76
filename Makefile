SSH ?= ssh
SSH_USER ?= ubuntu
SSH_KEY ?= $(HOME)/.ssh/project-76

ANSIBLE ?= ansible
ANSIBLE_GALAXY ?= ansible-galaxy
ANSIBLE_PLAYBOOK ?= ansible-playbook
INVENTORY ?= inventory.ini
PLAYBOOK ?= playbook.yml
CA_BUNDLE ?= $(firstword $(wildcard /etc/ssl/cert.pem /etc/ssl/certs/ca-certificates.crt))
GALAXY_ENV = $(if $(CA_BUNDLE),SSL_CERT_FILE="$(CA_BUNDLE)")

VM_1_IP ?= 178.154.233.39
VM_2_IP ?= 178.154.235.206
REDMINE_PORT ?= 3000
APP_URL ?= https://uit14.ru

SSH_OPTIONS = -i "$(SSH_KEY)" -o IdentitiesOnly=yes
SSH_CHECK_OPTIONS = $(SSH_OPTIONS) -o BatchMode=yes -o ConnectTimeout=10

.PHONY: install deps setup prepare deploy health ping syntax check ssh-vm-1 ssh-vm-2 ssh-check

install:
	$(GALAXY_ENV) $(ANSIBLE_GALAXY) install -r requirements.yml

deps: install

setup: install prepare

prepare:
	$(ANSIBLE_PLAYBOOK) -i "$(INVENTORY)" "$(PLAYBOOK)" --tags prepare

deploy:
	@test -n "$$REDMINE_DB_PASSWORD" || { echo "REDMINE_DB_PASSWORD is not set" >&2; exit 1; }
	@test -n "$$REDMINE_SECRET_KEY_BASE" || { echo "REDMINE_SECRET_KEY_BASE is not set" >&2; exit 1; }
	$(ANSIBLE_PLAYBOOK) -i "$(INVENTORY)" "$(PLAYBOOK)" --tags deploy

health:
	$(ANSIBLE) webservers -i "$(INVENTORY)" -m ansible.builtin.command \
		-a "curl --fail --silent --show-error --output /dev/null http://127.0.0.1:$(REDMINE_PORT)/login"
	curl --fail --silent --show-error --location "$(APP_URL)/login" >/dev/null
	@echo "Redmine is available at $(APP_URL)"

ping:
	$(ANSIBLE) all -i "$(INVENTORY)" -m ansible.builtin.ping

syntax:
	$(ANSIBLE_PLAYBOOK) -i "$(INVENTORY)" "$(PLAYBOOK)" --syntax-check

check:
	$(ANSIBLE) webservers -i "$(INVENTORY)" -m ansible.builtin.command -a "docker version"
	$(ANSIBLE) webservers -i "$(INVENTORY)" -m ansible.builtin.command \
		-a 'python3 -c "import docker; print(docker.__version__)"'

ssh-vm-1:
	$(SSH) $(SSH_OPTIONS) "$(SSH_USER)@$(VM_1_IP)"

ssh-vm-2:
	$(SSH) $(SSH_OPTIONS) "$(SSH_USER)@$(VM_2_IP)"

ssh-check:
	$(SSH) $(SSH_CHECK_OPTIONS) "$(SSH_USER)@$(VM_1_IP)" \
		'printf "vm-1: OK - "; hostname'
	$(SSH) $(SSH_CHECK_OPTIONS) "$(SSH_USER)@$(VM_2_IP)" \
		'printf "vm-2: OK - "; hostname'

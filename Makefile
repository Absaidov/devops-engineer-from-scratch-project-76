SSH ?= ssh
SSH_USER ?= ubuntu
SSH_KEY ?= $(HOME)/.ssh/project-76

ANSIBLE ?= ansible
ANSIBLE_GALAXY ?= ansible-galaxy
ANSIBLE_PLAYBOOK ?= ansible-playbook
ANSIBLE_VAULT ?= ansible-vault
INVENTORY ?= inventory.ini
PLAYBOOK ?= playbook.yml
VAULT_FILE ?= group_vars/webservers/vault.yml
VAULT_ID ?= project76
VAULT_PASSWORD_FILE ?=
CA_BUNDLE ?= $(firstword $(wildcard /etc/ssl/cert.pem /etc/ssl/certs/ca-certificates.crt))
GALAXY_ENV = $(if $(CA_BUNDLE),SSL_CERT_FILE="$(CA_BUNDLE)")
VAULT_SOURCE = $(if $(strip $(VAULT_PASSWORD_FILE)),$(VAULT_PASSWORD_FILE),prompt)
VAULT_ARGS = --vault-id "$(VAULT_ID)@$(VAULT_SOURCE)"

VM_1_IP ?= 178.154.233.39
VM_2_IP ?= 178.154.235.206
REDMINE_PORT ?= 3000
APP_URL ?= https://uit14.ru

SSH_OPTIONS = -i "$(SSH_KEY)" -o IdentitiesOnly=yes
SSH_CHECK_OPTIONS = $(SSH_OPTIONS) -o BatchMode=yes -o ConnectTimeout=10

.PHONY: install deps setup prepare deploy health monitoring monitoring-check ping syntax check vault-create vault-edit vault-view ssh-vm-1 ssh-vm-2 ssh-check

install:
	$(GALAXY_ENV) $(ANSIBLE_GALAXY) install -r requirements.yml

deps: install

setup: install prepare

prepare:
	$(ANSIBLE_PLAYBOOK) -i "$(INVENTORY)" "$(PLAYBOOK)" $(VAULT_ARGS) --tags prepare

deploy:
	$(ANSIBLE_PLAYBOOK) -i "$(INVENTORY)" "$(PLAYBOOK)" $(VAULT_ARGS) --tags deploy

monitoring:
	$(ANSIBLE_PLAYBOOK) -i "$(INVENTORY)" "$(PLAYBOOK)" $(VAULT_ARGS) --tags monitoring

monitoring-check:
	$(ANSIBLE) webservers -i "$(INVENTORY)" $(VAULT_ARGS) --become \
		-m ansible.builtin.command -a "datadog-agent check http_check"

health:
	$(ANSIBLE) webservers -i "$(INVENTORY)" $(VAULT_ARGS) -m ansible.builtin.command \
		-a "curl --fail --silent --show-error --output /dev/null http://127.0.0.1:$(REDMINE_PORT)/login"
	curl --fail --silent --show-error --location "$(APP_URL)/login" >/dev/null
	@echo "Redmine is available at $(APP_URL)"

ping:
	$(ANSIBLE) all -i "$(INVENTORY)" $(VAULT_ARGS) -m ansible.builtin.ping

syntax:
	$(ANSIBLE_PLAYBOOK) -i "$(INVENTORY)" "$(PLAYBOOK)" $(VAULT_ARGS) --syntax-check

check:
	$(ANSIBLE) webservers -i "$(INVENTORY)" $(VAULT_ARGS) -m ansible.builtin.command -a "docker version"
	$(ANSIBLE) webservers -i "$(INVENTORY)" $(VAULT_ARGS) -m ansible.builtin.command \
		-a 'python3 -c "import docker; print(docker.__version__)"'

vault-create:
	@test ! -e "$(VAULT_FILE)" || { echo "$(VAULT_FILE) already exists; use make vault-edit" >&2; exit 1; }
	@mkdir -p "$(dir $(VAULT_FILE))"
	$(ANSIBLE_VAULT) create $(VAULT_ARGS) "$(VAULT_FILE)"

vault-edit:
	@test -f "$(VAULT_FILE)" || { echo "$(VAULT_FILE) does not exist; use make vault-create" >&2; exit 1; }
	$(ANSIBLE_VAULT) edit $(VAULT_ARGS) "$(VAULT_FILE)"

vault-view:
	@test -f "$(VAULT_FILE)" || { echo "$(VAULT_FILE) does not exist; use make vault-create" >&2; exit 1; }
	@echo "Warning: this command prints decrypted secrets to the terminal." >&2
	$(ANSIBLE_VAULT) view $(VAULT_ARGS) "$(VAULT_FILE)"

ssh-vm-1:
	$(SSH) $(SSH_OPTIONS) "$(SSH_USER)@$(VM_1_IP)"

ssh-vm-2:
	$(SSH) $(SSH_OPTIONS) "$(SSH_USER)@$(VM_2_IP)"

ssh-check:
	$(SSH) $(SSH_CHECK_OPTIONS) "$(SSH_USER)@$(VM_1_IP)" \
		'printf "vm-1: OK - "; hostname'
	$(SSH) $(SSH_CHECK_OPTIONS) "$(SSH_USER)@$(VM_2_IP)" \
		'printf "vm-2: OK - "; hostname'

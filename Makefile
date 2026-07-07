########################################
# Tests de non-régression — personal-gen-ai
#
#   make test     lance toutes les couches
#   make fmt      vérifie le formatage Terraform
#   make validate terraform validate sur les 6 stacks
#   make lint     shellcheck + bash -n sur les scripts
#   make unit     tests bats (dispatcher + bootstrap)
#   make tftest   terraform test mocké (requiert Terraform >= 1.7)
#   make sec      scan sécurité IaC (checkov)
########################################

STACKS  := aws runpod exoscale vastai ovhcloud lyceum
STACKDIR := providers
SCRIPTS := deploy.sh common/bootstrap.sh common/nginx-https.sh

.PHONY: test fmt validate lint unit tftest sec

test: fmt validate lint unit tftest sec

fmt:
	terraform fmt -check -recursive

validate:
	@set -e; for s in $(STACKS); do \
		echo "== validate $$s"; \
		terraform -chdir=$(STACKDIR)/$$s init -backend=false -input=false -upgrade >/dev/null; \
		terraform -chdir=$(STACKDIR)/$$s validate; \
	done

lint:
	shellcheck $(SCRIPTS) tests/mocks/bin/*
	@for s in $(SCRIPTS); do bash -n $$s && echo "bash -n OK: $$s"; done

unit:
	bats tests/

tftest:
	@ver=$$(terraform version -json | sed -n 's/.*"terraform_version": *"\([0-9.]*\)".*/\1/p'); \
	major_minor=$$(echo $$ver | cut -d. -f1-2); \
	if [ "$$(printf '%s\n1.7\n' $$major_minor | sort -V | head -1)" != "1.7" ]; then \
		echo "SKIP tftest : Terraform $$ver < 1.7 (mock_provider requis)"; \
	else \
		set -e; for s in $(STACKS); do \
			echo "== terraform test $$s"; \
			terraform -chdir=$(STACKDIR)/$$s init -backend=false -input=false >/dev/null; \
			terraform -chdir=$(STACKDIR)/$$s test; \
		done; \
	fi

sec:
	checkov -d . --config-file .checkov.yaml

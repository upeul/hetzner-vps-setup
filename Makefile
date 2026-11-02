.PHONY: lint syntax ansible terraform safety init plan apply destroy configure inventory verify
lint: syntax ansible terraform safety
syntax:
	@for script in setup/scripts/*.sh; do bash -n "$$script" || exit; done
	@shellcheck setup/scripts/*.sh
	@python3 -c 'import ast,pathlib; [ast.parse(p.read_text()) for p in pathlib.Path("setup/scripts").glob("*.py")]'
ansible:
	cd setup/ansible && ansible-playbook -i inventory/hosts.example.yml site.yml --syntax-check
terraform:
	@tmp=$$(mktemp -d); trap 'rm -rf "$$tmp"' EXIT; cp setup/terraform/*.tf setup/terraform/.terraform.lock.hcl "$$tmp/"; cd "$$tmp"; tofu init -backend=false -input=false && tofu validate
safety:
	bash setup/scripts/validate-repo-safety.sh

init plan apply destroy:
	cd setup/terraform && tofu $@
configure:
	cd setup/ansible && ansible-playbook -i inventory/hosts.yml site.yml -K
inventory:
	@test -f setup/ansible/inventory/hosts.yml || cp setup/ansible/inventory/hosts.example.yml setup/ansible/inventory/hosts.yml
	@echo "Edite setup/ansible/inventory/hosts.yml antes de configurar."
verify:
	@echo "Execute na VPS com TTY: bash /tmp/verify-acceptance.sh"

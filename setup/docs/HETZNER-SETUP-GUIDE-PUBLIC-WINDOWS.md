# Instalação pelo Windows com WSL

Leia o [README](../../README.md). Instale WSL com Ubuntu 24.04 pelo procedimento [oficial Microsoft](https://learn.microsoft.com/windows/wsl/install), reinicie quando solicitado e abra Bash no Ubuntu. Mantenha checkout e chave no filesystem Linux do WSL, não no disco montado do Windows.

## Preparar o controlador

No Bash do WSL:

```bash
sudo apt-get update
sudo apt-get install -y ansible curl gpg openssl
ansible --version
```

Confira a primeira linha: é necessário `ansible-core` 2.16 ou mais recente para as collections deste projeto. Se o pacote da distribuição estiver abaixo disso instale uma versão suportada em ambiente isolado e mantenha-o ativo durante os comandos Ansible:

```bash
sudo apt-get install -y python3-venv
python3 -m venv ~/.venvs/devvps-ansible
source ~/.venvs/devvps-ansible/bin/activate
python -m pip install ansible-core==2.19.15
ansible --version
```

Instale OpenTofu seguindo o [procedimento oficial Debian/Ubuntu](https://opentofu.org/docs/intro/install/deb/). Não suponha que o pacote exista no repositório padrão. Confira `tofu version` antes de prosseguir. Gere o hash local:

```bash
openssl passwd -6
```

Copie o hash completo para `admin_password_hash` quando indicado. Instale Tailscale no Windows e confirme que o WSL alcança o IP da tailnet antes do Ansible. A disponibilidade depende da rede WSL e das políticas locais. Use caminhos Linux e SSH do WSL em todas as etapas seguintes.

## Criar a infraestrutura

Na raiz do checkout abra Bash. Todos os comandos locais a seguir usam Bash.

```bash
set -euo pipefail
REPO_ROOT="$PWD"
test -d "$REPO_ROOT/setup/terraform"
ssh-keygen -t ed25519 -C dev-vps -f ~/.ssh/dev_vps_ed25519
# Escolha passphrase e guarde a senha em gerenciador.
```

Use o comando de hash indicado para sua plataforma. Guarde também a senha local escolhida: ela autentica console e sudo, não SSH. O hash é sensível e não deve ser publicado.

```bash
read -r -s -p 'Token Hetzner: ' HCLOUD_TOKEN; printf '\n'
export HCLOUD_TOKEN
cd "$REPO_ROOT/setup/terraform"
umask 077
cp terraform.tfvars.example terraform.tfvars
${EDITOR:-vi} terraform.tfvars
# Configure chave pública, hash completo, SKU e região. Não use o placeholder.
tofu init
tofu plan -out=bootstrap.tfplan
# Revise custos, firewall e plano antes da próxima linha.
tofu apply bootstrap.tfplan
unset HCLOUD_TOKEN
```

O firewall cloud nasce sem entrada pública. Confira disponibilidade e impostos no [catálogo oficial](https://www.hetzner.com/cloud/). Não abra SSH público para o bootstrap padrão. Espere cloud-init terminar e entre pelo console Hetzner como `admin` com a senha local. O console não aceita chave SSH como senha. O usuário `ide` e as contas dos agentes serão criados pelo Ansible depois.

## Conectar o overlay

Instale Tailscale no controlador pela [página oficial](https://tailscale.com/download). No console da VPS execute:

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --accept-routes=false
sudo tailscale set --ssh=false
tailscale ip -4
```

Abra a URL de autenticação no navegador do controlador e aprove o dispositivo. Anote o endereço exibido. A política da tailnet precisa permitir TCP/22 do controlador para a VPS, inclusive quando usa tags. Use OpenSSH sobre Tailscale, não Tailscale SSH. Sem UDP direto há fallback DERP via TCP/443.

Revise o exemplo de [política da tailnet](../config/tailscale-acl.example.json). Substitua o login fictício e registre a tag indicada antes de aplicá-lo. Confira também regras preexistentes que possam ampliar o acesso.

No controlador substitua o endereço de exemplo pelo IP exibido e teste uma nova sessão:

```bash
ssh -i ~/.ssh/dev_vps_ed25519 admin@100.x.x.x
```

Se precisar do bootstrap público emergencial, configure `bootstrap_open_ssh=true` com `bootstrap_ssh_cidr` igual ao seu IP/32 ou IPv6/128. Feche-o por novo apply assim que o overlay funcionar. Nunca use CIDR mundial.

## Aplicar Ansible

No Bash do controlador:

```bash
cd "$REPO_ROOT/setup/ansible"
ansible-galaxy collection install -r requirements.yml
cp inventory/hosts.example.yml inventory/hosts.yml
${EDITOR:-vi} inventory/hosts.yml
# Ajuste ansible_host para o IP da tailnet e mantenha ansible_user: admin.
# Defina ansible_ssh_private_key_file: ~/.ssh/dev_vps_ed25519
ansible-playbook -i inventory/hosts.yml site.yml -K
```

`-K` pede a senha local de `admin` em cada execução. Antes do apply mantenha console disponível. Não resete UFW. O role SSH valida configuração efetiva antes de recarregar e as contas `ide`, `agent-claude`, `agent-codex` e `agent-grok` não recebem sudo. O layout privado fica em `/srv/dev/worktrees`. A allowlist de repositórios é apenas política administrativa: personalize `setup/config/repo-allowlist.example.yaml` antes de aplicar.

## Aceite e IDE

No controlador:

```bash
cd "$REPO_ROOT"
scp -i ~/.ssh/dev_vps_ed25519 setup/scripts/verify-acceptance.sh admin@100.x.x.x:/tmp/
ssh -t -i ~/.ssh/dev_vps_ed25519 admin@100.x.x.x 'bash /tmp/verify-acceptance.sh'
```

O script exige TTY e distingue PASS, FAIL e INCONCLUSIVE. Ele não coleta provas externas e termina inconclusivo em produção por esse motivo. Registre separadamente que o IP público não aceita SSH, que uma nova conexão overlay funciona e que console/rescue recupera acesso. O script sozinho não certifica a VPS. Não trate smoke de container como aceite de produção.

Configure sua IDE Remote SSH como `ide`, nunca como `admin`. Use sessões SSH separadas para cada agente. Teste que `sudo -l` nega privilégios e que um agente não atravessa o diretório 0700 de outro. Para instalar CLIs veja as instruções manuais em `setup/scripts/install-clis.sh`; autenticação é individual por UID. Não copie tokens entre contas.

O egress padrão `observe` não bloqueia saída. Só ative `enforce` com rollback e testes negativos do [runbook](RUNBOOK.md). Leia a nota de CVE-2026-98432 e os limites do [README](../../README.md). Atualizações automáticas não substituem reboot para kernel corrigido.

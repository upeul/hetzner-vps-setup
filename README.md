# VPS de desenvolvimento na Hetzner

Infraestrutura reproduzível para uma VPS Ubuntu 24.04 com OpenTofu, Ansible e acesso OpenSSH por chave sobre Tailscale. Destinada ao desenvolvimento remoto pessoal, não à hospedagem de dados de produção.

## O que está incluído

- Firewall cloud sem entrada pública por padrão e UFW restrito ao overlay.
- Administrador `admin`, conta de IDE `ide` e contas `agent-claude`, `agent-codex` e `agent-grok` sem sudo.
- Diretórios privados por UID em `/srv/dev/worktrees`, atualizações automáticas e hardening de SSH.
- Egress por UID com nftables: `observe` registra sem bloquear; `enforce` é opcional.
- Mitigação temporária de CVE-2026-98432, verificações locais e exemplos sem credenciais.

## Pré-requisitos e custo

Conta Hetzner com 2FA, projeto e token limitado ao projeto, tailnet Tailscale, chave SSH com passphrase e acesso ao console de recuperação. Controlador macOS ou Windows com WSL Ubuntu, OpenTofu e Ansible. Confira SKU, região, IVA, IPv4, snapshots e teto mensal no [catálogo oficial Hetzner](https://www.hetzner.com/cloud/). Não há preço fixo garantido por este projeto.

## Início rápido

1. Leia o [guia Mac](setup/docs/HETZNER-SETUP-GUIDE-PUBLIC-MAC.md) ou o [guia Windows](setup/docs/HETZNER-SETUP-GUIDE-PUBLIC-WINDOWS.md).
2. Crie uma chave local e preencha os exemplos somente em arquivos ignorados pelo Git.
3. Revise `tofu plan`, crie a VPS e conecte Tailscale pelo console.
4. Teste acesso e recuperação antes do Ansible. Execute as verificações antes de trabalhar.
5. Consulte o [runbook](setup/docs/RUNBOOK.md) para reapply, rollback e atualizações.

## Modelo de ameaça e limites

UIDs, permissões e firewall reduzem exposição, não isolam uma máquina hostil como VMs independentes. Root e o administrador continuam privilegiados. Allowlist de repositórios é política administrativa, não bloqueia clones. Egress por IP/CDN não valida hostname, SNI nem repositório; `observe` não restringe saída. Credenciais de ferramentas podem permitir exfiltração. Não coloque dados pessoais, credenciais de produção ou segredos de clientes nesta VPS. Snapshots podem conter segredos.

## CVE-2026-98432

Consulte o [tracker oficial Ubuntu](https://ubuntu.com/security/CVE-2026-98432). A mitigação do role reduz exposição via MPTCP e opções IPv4, mas não substitui kernel corrigido e reboot. Confira a versão efetiva do kernel após reiniciar. Contexto: [guia público de mitigação](https://github.com/upeul/cve-2026-98432-linux).

## Estado de validação

CI cobre sintaxe Bash, shellcheck, sintaxe Ansible, validação OpenTofu, segredos e segurança de arquivos. Um smoke em container não certifica kernel, firewall cloud, autenticação SSH real, tailnet ou recuperação pelo console. Antes de uso real execute o aceite na VPS e os testes externos indicados; resultados inconclusivos não são aprovação. Não há promessa de auditoria ou certificação de segurança. Este código é fornecido sem garantia sob a [licença MIT](LICENSE). Reporte falhas conforme [SECURITY.md](SECURITY.md).

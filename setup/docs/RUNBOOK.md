# Operação e recuperação

## Conectar o overlay

No console Hetzner conecte Tailscale conforme a seção de mesmo nome do [guia Mac](HETZNER-SETUP-GUIDE-PUBLIC-MAC.md#conectar-o-overlay) ou do [guia Windows](HETZNER-SETUP-GUIDE-PUBLIC-WINDOWS.md#conectar-o-overlay). Ambos incluem instalação, autenticação e desativação de Tailscale SSH. Antes de aplicar Ansible teste uma nova conexão OpenSSH como `admin` pela tailnet e mantenha o console acessível.

## Reaplicar

Na raiz do checkout, entre em `setup/ansible` e execute `ansible-playbook -i inventory/hosts.yml site.yml -K`. O prompt pede a senha local de `admin`. Mantenha console Hetzner e uma conexão SSH aberta. Uma execução sem mudanças deve terminar com `changed=0`, mas atualizações de pacotes ou snapshots DNS podem produzir mudanças legítimas.

## Atualizações e CVE

Confira `uname -r` contra o tracker Ubuntu de CVE-2026-98432. Atualizações automáticas não demonstram que o kernel em execução foi corrigido. Programe reboot pelo console, teste nova conexão e repita o aceite. Snapshot não é backup externo e pode conter segredos.

## Egress avançado

O padrão é `observe`, sem bloqueio. Antes de ativar `enforce`, teste console, Tailscale e uma nova sessão SSH. Na VPS programe rollback temporizado:

```bash
sudo systemd-run --unit=egress-rollback --on-active=5m /bin/bash -c 'systemctl stop devvps-egress-refresh.timer; /usr/local/sbin/render-egress-nftables.sh /etc/devvps/egress-allowlist.yaml /etc/nftables.d/egress-allowlist.nft observe /etc/devvps/egress-users --apply'
```

No controlador, em `setup/ansible`, aplique `ansible-playbook -i inventory/hosts.yml site.yml -K -e egress_mode=enforce`. Teste conexões permitidas e negadas como cada UID restrito. Confira `sudo nft list table inet egress_allow`. Se tudo estiver correto cancele `sudo systemctl stop egress-rollback.timer` na VPS. Se falhar use o console, execute o renderer em observe com os argumentos acima e reaplique com `-e egress_mode=observe`. Persista o modo escolhido em group_vars antes de reiniciar. O timer transitório sobrevive à sessão, não ao reboot; libere o nome da unidade após cada ensaio.

## Verificação e recuperação

Copie `setup/scripts/verify-acceptance.sh` para a VPS e execute via SSH com TTY. Sem testes externos de cloud firewall, negação pública e recuperação o resultado completo será INCONCLUSIVE. Não use `--container-smoke` em produção para contornar esse resultado. Nunca abra SSH para o mundo ou habilite senha SSH para recuperar: prefira o console/rescue oficial, sem desativar os controles permanentemente.

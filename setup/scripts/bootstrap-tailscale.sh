#!/usr/bin/env bash
# Instala Tailscale e faz join interativo. Rodar NO HOST como admin via console Hetzner ou SSH Tailscale.
set -euo pipefail

if [[ "$(id -un)" != "${ADMIN_USER:-admin}" ]]; then
  echo "Execute como admin (ou ajuste o script)." >&2
  exit 1
fi

curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --accept-routes=false
# Desativar também em hosts que já tinham Tailscale SSH habilitado.
sudo tailscale set --ssh=false

echo ""
echo "Tailscale join iniciado. Autentique no browser se solicitado."
echo "Depois: tailscale status; copie o IP 100.x para ansible/inventory/hosts.yml"
echo "Acesso por OpenSSH sobre a tailnet; autenticação por chave e política do sshd."

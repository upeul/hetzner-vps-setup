output "server_id" {
  value       = hcloud_server.vps_dev.id
  description = "ID do servidor no painel Hetzner"
}

output "server_ipv4" {
  value       = hcloud_server.vps_dev.ipv4_address
  description = "IP pública - SSH bloqueado pelo firewall; usar só após Tailscale ou console"
}

output "server_ipv6" {
  value = hcloud_server.vps_dev.ipv6_address
}

output "firewall_id" {
  value = hcloud_firewall.deny_inbound_public.id
}

output "next_steps" {
  value = <<-EOT
    1. Console Hetzner: login admin com a senha cujo hash foi fornecido no create.
    2. Instalar Tailscale sem Tailscale SSH (ver setup/docs/RUNBOOK.md, seção Conectar o overlay).
    3. Comprovar OpenSSH por chave via tailnet e fechar eventual bootstrap público.
    4. Copiar IP Tailscale para setup/ansible/inventory/hosts.yml.
    5. Em setup/ansible: ansible-playbook -K site.yml (senha de sudo).
  EOT
}

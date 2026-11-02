locals {
  ssh_public_key = var.ssh_public_key != "" ? var.ssh_public_key : file(pathexpand(var.ssh_public_key_path))
}

resource "hcloud_ssh_key" "admin" {
  name       = "admin-bootstrap"
  public_key = local.ssh_public_key
  labels     = var.labels
}

# Cloud Firewall: default deny inbound. Bootstrap SSH opcional (desligar após Tailscale).
resource "hcloud_firewall" "deny_inbound_public" {
  name   = "${var.server_name}-deny-inbound-public"
  labels = var.labels

  lifecycle {
    precondition {
      condition     = !var.bootstrap_open_ssh || var.bootstrap_ssh_cidr != null
      error_message = "bootstrap_open_ssh exige bootstrap_ssh_cidr explícito."
    }
  }

  dynamic "rule" {
    for_each = var.bootstrap_open_ssh ? [1] : []
    content {
      direction   = "in"
      protocol    = "tcp"
      port        = "22"
      source_ips  = [var.bootstrap_ssh_cidr]
      description = "TEMP bootstrap SSH - disable after Tailscale"
    }
  }
}

resource "hcloud_server" "vps_dev" {
  name        = var.server_name
  server_type = var.server_type
  location    = var.location
  image       = "ubuntu-24.04"
  ssh_keys    = [hcloud_ssh_key.admin.id]

  firewall_ids = [hcloud_firewall.deny_inbound_public.id]

  labels = var.labels

  # Cloud-init só roda na criação. Alterá-lo não deve substituir o host existente.
  lifecycle {
    ignore_changes = [user_data]
  }

  # Cloud-init mínimo - SEM Tailscale auth key
  user_data = <<-EOF
    #cloud-config
    package_update: false
    package_upgrade: false
    timezone: UTC
    locale: en_US.UTF-8
    users:
      - name: admin
        gecos: Administrator
        groups: [sudo]
        shell: /bin/bash
        sudo: ALL=(ALL) ALL
        lock_passwd: false
        passwd: '${var.admin_password_hash}'
        ssh_authorized_keys:
          - ${trimspace(local.ssh_public_key)}
    ssh_pwauth: false
    disable_root: false
    runcmd:
      - timedatectl set-timezone UTC
  EOF
}

variable "hcloud_token" {
  type        = string
  description = "Opcional. Preferir export HCLOUD_TOKEN. Ou TF_VAR_hcloud_token / terraform.tfvars."
  sensitive   = true
  default     = null
  nullable    = true
}

variable "project_name" {
  type        = string
  description = "Hetzner Cloud project name"
  default     = "dev-vps"
}

variable "server_name" {
  type    = string
  default = "dev-vps-1"
}

variable "server_type" {
  type        = string
  description = "Preferência: cx53. Consulte preço e disponibilidade no console Hetzner antes do apply."
  default     = "cx53"

  validation {
    condition = contains([
      "cx53", "cx43",
      "cax41", "cax31",
      "cpx42", "cpx32", "cpx31", "cpx52",
      "ccx13", "ccx23",
    ], var.server_type)
    error_message = "Tipo fora da lista permitida no setup."
  }
}

variable "location" {
  type        = string
  description = "nbg1 Nuremberg; fallback fsn1"
  default     = "nbg1"

  validation {
    condition     = contains(["nbg1", "fsn1", "hel1"], var.location)
    error_message = "Região deve ser nbg1 ou fallback documentado."
  }
}

variable "ssh_public_key_path" {
  type        = string
  description = "Caminho local da chave pública SSH de admin"
  default     = "~/.ssh/dev_vps_ed25519.pub"
}

variable "ssh_public_key" {
  type        = string
  description = "Alternativa: colar chave pública inline (sobrescreve path)"
  default     = ""
}

variable "bootstrap_open_ssh" {
  type        = bool
  description = "TEMPORÁRIO: abrir TCP/22 na IP pública só para bootstrap Tailscale. Desligar depois."
  default     = false
}

variable "bootstrap_ssh_cidr" {
  type        = string
  description = "CIDR explícito para bootstrap SSH, prefixo mínimo /24 IPv4 ou /64 IPv6; preferir /32 ou /128."
  default     = null
  nullable    = true

  validation {
    condition = var.bootstrap_ssh_cidr == null ? true : try(
      cidrhost(var.bootstrap_ssh_cidr, 0) != "" &&
      tonumber(split("/", var.bootstrap_ssh_cidr)[1]) >= (strcontains(split("/", var.bootstrap_ssh_cidr)[0], ":") ? 64 : 24),
      false
    )
    error_message = "Informe um CIDR válido com prefixo mínimo /24 para IPv4 ou /64 para IPv6."
  }
}

variable "labels" {
  type = map(string)
  default = {
    env     = "personal-dev"
    owner   = "admin"
  }
}

variable "admin_password_hash" {
  type        = string
  description = "Hash SHA-512 crypt para senha local/sudo de admin (mkpasswd -m sha-512). Não é senha SSH. Só aplicado na criação."
  sensitive   = true
  nullable    = false

  validation {
    condition     = can(regex("^\\$6\\$(rounds=[0-9]+\\$)?[./0-9A-Za-z]{1,16}\\$[./0-9A-Za-z]{86}$", var.admin_password_hash))
    error_message = "Forneça um hash SHA-512 crypt completo gerado localmente, nunca uma senha em texto."
  }
}

variable "proxmox_endpoint" {
  description = "URL da API do servidor Proxmox (ex: https://192.168.1.100:8006/)"
  type        = string
  sensitive   = true
}

variable "proxmox_api_token" {
  description = "Token de autenticação da API do Proxmox"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Ignorar verificação de certificado SSL autoassinado (true apenas em rede local controlada)"
  type        = bool
  default     = false
}

variable "kali_iso_file_id" {
  description = "ID do arquivo ISO do Kali Linux no storage do Proxmox (ex: HD-500GB:iso/kali-linux-2026.1-installer-amd64.iso)"
  type        = string
}

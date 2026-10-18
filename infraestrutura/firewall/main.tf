terraform {
  required_version = ">= 1.6.0, < 2.0.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.66.1"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = var.proxmox_insecure
}

resource "proxmox_virtual_environment_vm" "pfsense_firewall" {
  name      = "pfSense-Automated"
  node_name = "pve"
  vm_id     = 100 

  on_boot = true 

  stop_on_destroy = true

  cpu {
    cores = 2
  }

  memory {
    dedicated = 2048
  }

  # Disco Rígido Virtual no SSD (Alta Performance)
  disk {
    datastore_id = "local-lvm"
    file_format  = "raw"
    interface    = "scsi0"
    size         = 20
  }

  # Leitor de CD/DVD Virtual
  cdrom {
    enabled   = true
    file_id   = var.pfsense_iso_file_id
    interface = "ide2"
  }

  boot_order = ["scsi0", "ide2"]

  # Placas de Rede Conectadas aos Switches Virtuais
  network_device {
    bridge = "vmbr0" # WAN (Conexão com a rede doméstica)
    model  = "virtio"
  }
  
  network_device {
    bridge = "vmbr1" # OPT1 (Rede do Kali Linux)
    model  = "virtio"
  }
  
  network_device {
    bridge = "vmbr2" # LAN (Rede da Zona de Exploração)
    model  = "virtio"
  }

  operating_system {
    type = "other" # pfSense é baseado em FreeBSD, 'other' é a tag correta
  }
}
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

resource "proxmox_virtual_environment_vm" "kali_attack" {
  name      = "Kali-Linux"
  node_name = "pve"
  vm_id     = 101
  tags      = ["atacante", "kali"]

  keyboard_layout = "pt-br"

  on_boot         = false
  stop_on_destroy = true


  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 4096
  }

  vga { 
    type = "qxl" 
  }

  # Disco Rígido Virtual no SSD (Alta Performance para ferramentas e wordlists)
  disk {
    datastore_id = "local-lvm"
    file_format  = "raw"
    interface    = "scsi0"
    size         = 40
  }

  # Leitor de CD/DVD Virtual (ISO do Kali Linux no HD secundário)
  cdrom {
    enabled   = true
    file_id   = var.kali_iso_file_id
    interface = "ide2"
  }

  boot_order = ["scsi0", "ide2"]

  # Placa de Rede conectada EXCLUSIVAMENTE à Rede de Ataque (vmbr1 - OPT1 do pfSense)
  network_device {
    bridge = "vmbr1"
    model  = "virtio"
  }

  operating_system {
    type = "l26" # Kernel Linux moderno (Debian / Kali Linux)
  }
}

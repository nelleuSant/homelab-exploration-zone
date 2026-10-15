terraform {
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
  insecure  = true
}

resource "proxmox_virtual_environment_vm" "pfsense_firewall" {
  name      = "pfSense-Automated"
  node_name = "pve"
  vm_id     = 100 

  on_boot = true 

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
    # ATENÇÃO: Substitua pelo nome exato do arquivo .iso que você subiu!
    file_id   = "HD-500GB:iso/netgate-installer-v1.2-RELEASE-amd64.iso"
    interface = "ide2"
  }

  boot_order = ["ide2", "scsi0"] # Boota primeiro no CD, depois no HD

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
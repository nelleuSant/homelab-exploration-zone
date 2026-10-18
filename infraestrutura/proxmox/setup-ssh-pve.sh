#!/bin/bash

echo "=========================================="
echo "  Automação de Chave SSH - Hardening"
echo "=========================================="
echo ""

# 1. Solicita o IP do servidor alvo ao usuário
read -p "Digite o IP do servidor Proxmox: " SERVER_IP

# Define o caminho padrão da chave ed25519
KEY_PATH="$HOME/.ssh/id_ed25519"

# 2. Verifica se a chave já existe localmente
if [ ! -f "$KEY_PATH" ]; then
    echo "[+] Nenhuma chave ed25519 encontrada. Gerando uma nova chave..."
    # Gera a chave silenciosamente (-q) sem passphrase (-N "")
    ssh-keygen -t ed25519 -f "$KEY_PATH" -N "" -q -C "automacao-proxmox"
    echo "[+] Chave gerada com sucesso em $KEY_PATH."
else
    echo "[*] A chave SSH já existe em $KEY_PATH. Pulando a etapa de geração."
fi

# 3. Envia a chave pública para o servidor
echo "[+] Transferindo a chave pública para root@$SERVER_IP..."
echo "[!] Você precisará digitar a senha do root do Proxmox uma última vez."
ssh-copy-id -i "$KEY_PATH.pub" root@"$SERVER_IP"

# 4. Finalização
echo ""
echo "=========================================="
echo "[+] Automação concluída!"
echo "[>] Teste o acesso digitando: ssh root@$SERVER_IP"
echo "=========================================="
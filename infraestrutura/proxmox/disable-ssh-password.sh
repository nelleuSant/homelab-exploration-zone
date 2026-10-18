#!/bin/bash

echo "==============================================="
echo "  Hardening SSH: Desativar Login por Senha"
echo "==============================================="
echo ""

# 1. Solicita o IP do servidor
read -p "Digite o IP do servidor Proxmox: " SERVER_IP

echo "[+] Conectando ao servidor e aplicando configuração de segurança..."

# 2. Executa o comando remoto via SSH
# O sed vai procurar por PasswordAuthentication (mesmo que tenha um # na frente) e substituir por "PasswordAuthentication no"
ssh root@"$SERVER_IP" "sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config && systemctl restart sshd"

# 3. Verifica se a execução foi bem-sucedida
if [ $? -eq 0 ]; then
    echo "[+] Configuração alterada e serviço SSH reiniciado com sucesso no Proxmox!"
    echo ""
    echo "[>] VALIDANDO A SEGURANÇA..."
    echo "Tente forçar o acesso por senha com o comando abaixo. O servidor DEVE rejeitar com 'Permission denied':"
    echo "ssh root@$SERVER_IP -o PubkeyAuthentication=no"
else
    echo "[-] ERRO: Não foi possível conectar ou alterar as configurações."
    echo "    Certifique-se de que a chave SSH já foi transferida (usando o script anterior) e que o IP está correto."
fi

echo "==============================================="
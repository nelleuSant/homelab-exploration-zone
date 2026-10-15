### ✅ Fase 1 Concluída: Preparação do Hipervisor Proxmox VE

A base do servidor (Intel i5-8400) foi estabelecida com sucesso e otimizada para o ambiente do laboratório:

*   **Instalação Base:** Proxmox VE instalado nativamente no SSD primário (230 GB). Isso garante alta velocidade de leitura/escrita (I/O) para as máquinas virtuais críticas (Kali Linux, pfSense e Active Directory).
*   **Ajuste de Repositórios (No-Subscription):** 
    *   Os repositórios comerciais (`pve-enterprise` e `ceph enterprise`) foram desabilitados para evitar erros de autorização.
    *   Os repositórios comunitários gratuitos (`pve-no-subscription` e `ceph-squid no-subscription`) foram ativados.
    *   O hipervisor foi 100% atualizado para a versão mais recente dos pacotes Debian/Proxmox.
*   **Provisionamento de Datastore:** O disco rígido secundário (HDD de 500 GB) foi formatado (ext4) e montado no Proxmox como um Diretório isolado (`HD-500GB`). Ele servirá como repositório de armazenamento a frio para imagens ISO, templates de contêineres e backups das máquinas vulneráveis.
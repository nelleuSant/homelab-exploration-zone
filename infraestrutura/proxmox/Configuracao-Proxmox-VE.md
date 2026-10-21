# 🛡️ Proxmox VE - Hipervisor Core do Laboratório

Este diretório contém a documentação técnica e o histórico de configurações do hipervisor primário (Proxmox VE). Este servidor é a espinha dorsal do laboratório de cibersegurança, responsável por hospedar roteadores virtuais, máquinas de ataque, ambientes vulneráveis e diretórios corporativos de forma isolada e segura.

---

## 💻 1. Infraestrutura e Provisionamento

O servidor foi dimensionado para garantir o máximo de I/O para as máquinas virtuais críticas, separando o processamento da área de armazenamento a frio.

* **Hardware Base:** Intel Core i5-8400
* **Storage Primário (Hot Data):** SSD de 230 GB. Dedicado exclusivamente à instalação nativa do sistema operacional (Proxmox VE) e aos discos virtuais das VMs críticas (pfSense, Kali Linux, Active Directory).
* **Storage Secundário (Cold Data):** HDD de 500 GB (formatado em `ext4`). Montado como um diretório isolado (`HD-500GB`) para armazenar imagens ISO, templates de contêineres (CT) e atuar como repositório de backups das VMs.

## ⚙️ 2. Configuração de Repositórios

Para manter o sistema atualizado de forma estável e sem alertas de licenciamento comercial, os repositórios do APT foram ajustados:

* 🔴 **Desabilitados:** Repositórios comerciais (`pve-enterprise` e `ceph enterprise`).
* 🟢 **Habilitados:** Repositórios comunitários (`pve-no-subscription` e `ceph-squid no-subscription`).
* O hipervisor é mantido na versão mais recente dos pacotes Debian/Proxmox através de rotinas de atualização (`apt update && apt dist-upgrade`).

## 🔒 3. Hardening e Segurança (Defesa em Profundidade)

Como o Proxmox controla todo o ambiente virtual, sua segurança é prioridade máxima. Se o hipervisor for comprometido, qualquer segmentação nas camadas inferiores (como no pfSense) torna-se inútil. As seguintes políticas de *hardening* foram aplicadas:

### 3.1. Autenticação e Acesso
* **MFA (Multi-Factor Authentication):** Exigência de 2FA configurada para todos os acessos administrativos via Interface Web (porta 8006).
* **Acesso SSH Restrito:** 
  * Acesso por senha via SSH foi completamente desabilitado (`PasswordAuthentication no` no arquivo `/etc/ssh/sshd_config`).
  * O acesso via terminal (porta 22) requer obrigatoriamente autenticação por chaves criptográficas (`ed25519`) restritas à máquina de gerenciamento autorizada.

### 3.2. Firewall do Hipervisor
O firewall nativo do Proxmox foi ativado nos níveis de **Datacenter** e **Node**. Foi implementada uma política de *Default Drop* (bloqueio por padrão), permitindo apenas tráfego administrativo estritamente necessário.

**Regra de Gerenciamento (Inbound):**
```text
Direction: in
Action:   ACCEPT
Protocol: TCP
Source:   "<SEU_IP>" (Rede Gerencial/Doméstica Autorizada)
Ports:    8006 (Web GUI), 22 (SSH)
Enable: [X]
```

> **Nota de Segurança:** Qualquer tentativa de acesso às portas de gerenciamento originada de IPs fora da rede autorizada (incluindo possíveis movimentações laterais a partir de máquinas vulneráveis dentro do próprio laboratório) é automaticamente rejeitada pelo hipervisor.


## 🛠️ 4. Automação de Hardening (IaC)

Para garantir a padronização e agilizar a configuração de segurança do acesso remoto, foram desenvolvidos scripts em Bash que automatizam a transição da autenticação por senha para chaves criptográficas.

* **`setup-ssh-pve.sh`**: Script para a máquina gerencial que verifica a existência de chaves `ed25519`, gera um novo par (se necessário) e exporta a chave pública para o hipervisor alvo via `ssh-copy-id`.
* **`disable-ssh-password.sh`**: Script executado a partir da máquina gerencial que, via SSH, altera remotamente o arquivo `/etc/ssh/sshd_config` (utilizando `sed`) para desabilitar o `PasswordAuthentication` e reinicia o daemon do SSH automaticamente no Proxmox, mitigando ataques de força bruta.

## 🤖 5. Gestão de Identidade para Automação (Terraform)

Para permitir o provisionamento automatizado de máquinas virtuais via **Terraform** sem comprometer a segurança do hipervisor, foi adotado o **Princípio do Menor Privilégio (PoLP)**. 


### 5.1. Configuração de Acesso (API Token)
* Foi criado um **usuário dedicado** exclusivamente para a execução do Terraform.
* O acesso ocorre via **API Token**, limitado às ações essenciais para o ciclo de vida das VMs (criar, alterar, configurar redes, iniciar/parar).

### 5.2. Escopo de Permissões (Role)
Foi criada uma *Role* customizada no Proxmox, associada ao token do Terraform, contendo apenas as permissões estritamente necessárias listadas abaixo:

**Datastore & Pool:**
* `Datastore.AllocateSpace`
* `Datastore.Audit`
* `Pool.Allocate`

**Rede & Sistema:**
* `SDN.Use`
* `Sys.Audit`
* `Sys.Console`
* `Sys.Modify`
* `Sys.PowerMgmt`

**Virtual Machines (Ciclo de Vida e Configuração):**
* `VM.Allocate`
* `VM.Audit`
* `VM.Clone`
* `VM.Config.CDROM`
* `VM.Config.Cloudinit`
* `VM.Config.CPU`
* `VM.Config.Disk`
* `VM.Config.HWType`
* `VM.Config.Memory`
* `VM.Config.Network`
* `VM.Config.Options`
* `VM.Migrate`
* `VM.Monitor`
* `VM.PowerMgmt`


---
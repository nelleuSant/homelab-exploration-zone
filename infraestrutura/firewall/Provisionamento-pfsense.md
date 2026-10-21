# 🔥 Firewall e Roteador Core — pfSense (IaC com Terraform)

Este documento detalha o provisionamento automatizado da máquina virtual do **pfSense** sobre o hipervisor Proxmox VE utilizando **Terraform**, bem como a arquitetura de segmentação de rede, políticas de *hardening* e aplicação das regras de filtragem via *Golden Config* (`config.xml`).

O pfSense atua como a barreira central de segurança do laboratório: ele interconecta e monitora o tráfego entre a **Rede de Ataque (`vmbr1`)** e a **Zona de Exploração (`vmbr2`)**, ao mesmo tempo em que isola estritamente a **Rede Doméstica (`vmbr0`)** contra qualquer tentativa de comunicação ou vazamento originado dentro do ambiente de testes.

---

## 🖥️ 1. Especificações Técnicas da VM (`main.tf`)

O hardware virtual foi dimensionado no manifesto [`main.tf`](main.tf) para oferecer baixa latência de roteamento e alta disponibilidade no boot do servidor físico (**Intel Core i5-8400 | 16 GB RAM**):

| Parâmetro | Valor Configurado (`main.tf`) | Justificativa Técnica |
| :--- | :--- | :--- |
| **Nome / VM ID** | `pfSense-Automated` (`100`) | Primeira VM da topologia (`ID 100`), identificando o serviço central de rede. |
| **Inicialização Automática** | `on_boot = true` | Garante que o firewall, o servidor DHCP e o roteamento subam automaticamente assim que o Proxmox ligar. |
| **Desligamento Forçado** | `stop_on_destroy = true` | Permite que o Terraform desligue a VM com segurança caso seja necessário recriá-la sem depender do QEMU Guest Agent. |
| **Processador (CPU)** | `2 Cores` | Capacidade de processamento dedicada para inspeção de estados (*stateful firewall*), NAT e serviços de rede (DNS/DHCP). |
| **Memória RAM** | `2048 MB` (2 GB dedicados) | Suficiente para manter tabelas de estados (`maximumtableentries: 400.000`), Unbound DNS e pacotes de sistema com folga. |
| **Armazenamento (Disco)** | `20 GB` em `local-lvm` (`scsi0` / `raw`) | Alocado no **SSD primário** para inicialização rápida e escrita ágil de logs do sistema e RRD. |
| **Mídia de Instalação** | `ide2` (`var.pfsense_iso_file_id`) | Aponta para o instalador oficial (*Netgate Installer*) armazenado no HDD secundário (`HD-500GB`). |
| **Ordem de Boot** | `["scsi0", "ide2"]` | Na primeira execução (com o disco `scsi0` ainda vazio), a BIOS salta automaticamente para o CD-ROM (`ide2`). Após a instalação no SSD, a VM passa a dar boot diretamente pelo `scsi0`. |
| **Sistema Operacional** | `other` | Como o pfSense é baseado no **FreeBSD**, a tag `other` é a recomendação correta no Proxmox (em vez de `l26`, que é específica para kernels Linux). |

---

## 🌐 2. Mapeamento de Interfaces e Segmentação de Rede

A ordem de declaração dos blocos `network_device` no [`main.tf`](main.tf) determina a numeração das interfaces paravirtualizadas (`virtio` -> `vtnetX`) dentro do FreeBSD/pfSense:

| Ordem no `main.tf` | Interface no pfSense | Bridge no Proxmox | Papel na Arquitetura | Endereçamento IPv4 | Faixa DHCP |
| :---: | :---: | :---: | :--- | :--- | :--- |
| **1ª Placa** | `WAN` (`vtnet0`) | `vmbr0` | Conexão com o roteador residencial (saída para Internet e acesso ao WebGUI de gerência). | `DHCP` (Rede Doméstica) | — |
| **2ª Placa** | `OPT1` (`vtnet1`) | `vmbr1` | **Rede de Ataque** (barramento virtual isolado onde reside o Kali Linux). | `10.0.10.1/24` | `10.0.10.10` – `10.0.10.100` |
| **3ª Placa** | `LAN` (`vtnet2`) | `vmbr2` | **Zona de Exploração** (barramento virtual isolado onde residem os alvos vulneráveis). | `10.0.20.1/24` | `10.0.20.10` – `10.0.20.100` |

---

## 🛡️ 3. Políticas de Firewall e Hardening Aplicadas

As configurações de segurança consolidadas no arquivo `config.xml` (e disponibilizadas publicamente de forma sanitizada em [`config.xml.example`](config.xml.example)) implementam o conceito de **Defesa em Profundidade**:

### 3.1. Blindagem do Sistema e Gerenciamento
* **WebGUI Criptografado (`HTTPS`):** O painel administrativo opera exclusivamente sobre TLS/HTTPS na porta `443` (`<protocol>https</protocol>`).
* **Desativação da Regra *Anti-Lockout* na LAN (`<noantilockout/>`):** Por padrão, o pfSense cria uma regra invisível na interface `LAN` liberando acesso total ao WebGUI e SSH. Como neste laboratório a interface `LAN` (`vmbr2`) abriga as **máquinas vulneráveis**, a regra *Anti-Lockout* foi desabilitada para impedir que um alvo comprometido acesse o painel do firewall.
* **Alias de Proteção Administrativa (`Portas_Gerencia_FW`):** Agrupa as portas `22` (SSH), `80` (HTTP) e `443` (HTTPS) para bloquear tentativas de acesso administrativo ao próprio firewall (`This Firewall / (self)`) vindas das redes internas, **sem bloquear a porta `53` (DNS)**.
* **Desativação Completa de IPv6:** As opções `dhcp6` na WAN, `track6` na LAN e `<ipv6allow/>` foram removidas, e as regras de bloqueio aplicam-se a `inet46` (IPv4 + IPv6). Isso evita que o tráfego contorne as regras IPv4 caso o roteador doméstico distribua prefixos IPv6.
* **Remoção de Community SNMP Padrão:** A string padrão `public` do serviço SNMP foi removida.

### 3.2. Matriz de Regras de Filtragem (`<filter>`)

#### Interface `WAN` (`vmbr0` - Rede Doméstica)
1. **Gerência Autorizada (`PASS`):** Permite conexões TCP originadas **exclusivamente da sub-rede doméstica (`WAN net`)** com destino ao endereço IP da WAN (`WAN address`) nas portas do alias `Portas_Gerencia_FW` (`22, 80, 443`). Permite que você gerencie o pfSense a partir do seu computador pessoal.

#### Interface `OPT1` (`vmbr1` - Rede de Ataque / Kali Linux)
1. **Proteção do Firewall (`BLOCK`):** Bloqueia qualquer conexão TCP da `OPT1 net` para o próprio pfSense (`(self)`) nas portas `22, 80, 443` (`Portas_Gerencia_FW`).
2. **Isolamento da Rede Doméstica (`BLOCK`):** Bloqueia (`inet46`) qualquer tráfego originado na `OPT1 net` com destino à `WAN net` (*"Bloquear acesso a casa"*).
3. **Permissão de Ataque e Internet (`PASS`):** Libera o tráfego restante da `OPT1 net` (`any`), permitindo que o Kali Linux ataque a **Zona de Exploração (`10.0.20.0/24`)** e acesse a Internet via NAT para baixar ferramentas e atualizações.

#### Interface `LAN` (`vmbr2` - Zona de Exploração / Alvos Vulneráveis)
1. **Proteção do Firewall (`BLOCK`):** Bloqueia qualquer conexão TCP da `LAN net` para o próprio pfSense (`(self)`) nas portas `22, 80, 443` (`Portas_Gerencia_FW`).
2. **Isolamento da Rede Doméstica (`BLOCK`):** Bloqueia (`inet46`) qualquer comunicação da `LAN net` em direção à `WAN net` (*"Bloquear acesso a Rede Domestica (WAN) a partir da Zona de Exploracao"*).
3. **Regra de Manutenção Temporária (`PASS` - Desabilitada por padrão):** Regra mantida desativada (`<disabled/>`) abaixo dos bloqueios. Quando habilitada pontualmente para baixar pacotes ou containers nas VMs-alvo, os bloqueios nas posições 1 e 2 garantem que os alvos **continuem impedidos de acessar a rede doméstica ou o WebGUI do pfSense**.
4. **Isolamento Padrão (*Default Deny*):** Enquanto a regra de manutenção está desativada, os alvos vulneráveis na `vmbr2` não conseguem iniciar conexões para fora de sua sub-rede (apenas respondem aos pacotes iniciados pelo Kali Linux).

---

## 🚀 4. Passo a Passo de Provisionamento

### Pré-requisitos
* O instalador ISO do pfSense (*Netgate Installer*) deve estar salvo no storage `HD-500GB` do Proxmox.
* As bridges `vmbr0`, `vmbr1` e `vmbr2` já devem estar criadas no nó `pve`.

### Etapa 1: Configurar as Variáveis Locais (`terraform.tfvars`)
No diretório `infraestrutura/firewall/`, crie o arquivo `terraform.tfvars` a partir do arquivo de exemplo e proteja suas permissões:

```bash
cd infraestrutura/firewall
cp terraform.tfvars.example terraform.tfvars
chmod 600 terraform.tfvars
```

Preencha o `terraform.tfvars` com os dados reais do seu servidor Proxmox:

```hcl
proxmox_endpoint    = "https://SEU_HOST_PROXMOX:8006/"
proxmox_api_token   = "terraform@pam!terraform=SEU_TOKEN_AQUI"
proxmox_insecure    = true
pfsense_iso_file_id = "HD-500GB:iso/netgate-installer-v1.2-RELEASE-amd64.iso"
```

> ⚠️ **Segurança de Repositório:** Os arquivos `terraform.tfvars`, `terraform.tfstate*` e `config.xml` estão listados no `.gitignore` na raiz do repositório para impedir o vazamento de tokens, hashes de senha e chaves privadas no GitHub.

### Etapa 2: Criar a VM com Terraform
Inicialize o plugin do provider `bpg/proxmox`, valide a sintaxe e aplique a configuração:

```bash
terraform init
terraform validate
terraform plan
terraform apply
```

Ao confirmar com `yes`, o Terraform criará e ligará a **VM 100 (`pfSense-Automated`)**. Conclua a instalação padrão do sistema no disco `scsi0` através do console noVNC do Proxmox.

### Etapa 3: Aplicar as Configurações e Regras (`config.xml`)
Com o pfSense instalado e acessível pela rede doméstica:

1. No navegador da sua máquina pessoal, acesse `https://<IP-WAN-DO-PFSENSE>` e faça login no WebGUI.
2. Acesse o menu **Diagnostics > Backup & Restore** e role até a seção **Restore Backup**.
3. **Para restaurar o backup completo (ambiente local):**
   * Mantenha **Restore area** em `All`.
   * Selecione o arquivo local `pfsense-autodeploy/conf/config.xml` e clique em **Restore Configuration**.
4. **Para quem está clonando o repositório público (`config.xml.example`):**
   * Utilize o arquivo [`config.xml.example`](config.xml.example) restaurando por seção em **Restore area** (*Interfaces*, *DHCP Server*, *Aliases* e *Firewall Rules*). Dessa forma, toda a topologia e as regras de segurança são importadas sem sobrescrever a senha de administrador e o certificado SSL gerados na instalação.

---

## 📂 5. Estrutura de Arquivos deste Diretório

* **`main.tf`**: Código principal do Terraform que define o hardware da VM `100`, discos, CD-ROM, `boot_order` e as 3 interfaces de rede (`vmbr0`, `vmbr1`, `vmbr2`).
* **`variables.tf`**: Declaração tipada das variáveis de entrada, com `sensitive = true` para o endpoint e token da API.
* **`terraform.tfvars.example`**: Modelo público sem credenciais para configuração local do Terraform.
* **`config.xml.example`**: Template sanitizado contendo todas as interfaces, faixas DHCP, alias e regras de firewall do pfSense, sem hashes de senha ou chaves privadas.
* **`pfsense-autodeploy/README.md`**: Documentação de auditoria sobre o script oficial `/usr/local/bin/apply_patches.php` (`<earlyshellcmd>`) do pacote nativo *System Patches*.

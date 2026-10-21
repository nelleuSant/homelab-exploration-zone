# 🧪 Homelab Exploration Zone

Laboratório de cibersegurança e pesquisa de vulnerabilidades implementado inteiramente sobre o hipervisor Proxmox VE. 

O ambiente centraliza o host de ataque (Kali Linux), a camada de controle/roteamento (pfSense) e os alvos vulneráveis em um único servidor físico dedicado. O tráfego ofensivo permanece 100% confinado na memória e nas bridges virtuais do hipervisor, garantindo que a rede doméstica e o computador pessoal atuem estritamente como clientes de gerenciamento web (GUI), sem exposição ou risco de vazamento de pacotes maliciosos.

> ⚠️ **Este laboratório é destinado exclusivamente a ambientes próprios ou explicitamente autorizados.**

---

## 🖥️ Especificações do Hardware

* **Processador:** Intel Core i5-8400 (6 núcleos / 6 threads, 2.80 GHz base até 4.00 GHz turbo)
* **Memória RAM:** 16 GB DDR4
* **Armazenamento Principal (SSD 230 GB):** Sistema operacional (Proxmox VE), swap e discos virtuais prioritários de alta I/O (pfSense, Kali Linux, Windows Server).
* **Armazenamento Secundário (HDD 500 GB):** Datastore dedicado a imagens ISO, templates, backups, snapshots e alvos Linux leves (Metasploitable, contêineres Docker).

---

## 🏗️ Arquitetura e Segmentação de Rede

O isolamento do laboratório é estruturado em três bridges Linux independentes dentro do Proxmox:

1. **`vmbr0` (Gerência & Acesso WAN):** Conectada à placa de rede física do servidor. Dá acesso à LAN doméstica para gerência do Proxmox (`https://IP:8006`) e fornece conexão de internet para a interface WAN do pfSense.
2. **`vmbr1` (Rede de Ataque - Não Atrelada a Portas Físicas):** Barramento virtual interno exclusivo para a máquina de ataque (Kali Linux) e a interface `OPT1` do pfSense.
3. **`vmbr2` (Zona de Exploração - Não Atrelada a Portas Físicas):** Barramento virtual isolado que abriga os alvos de exploração (Linux, Windows Active Directory, Docker) e a interface `LAN` do pfSense.

![Topologia de Rede](/docs/topologia.drawio.png)

---

## ⚙️ Instalação do Proxmox
O provisionamento do hypervisor no servidor foi feito instalando o Proxmox VE a partir de uma mídia USB inicializável, gerada através do software BalenaEtcher.

- ISO Proxmox VE 9.2 ISO Installer: [Link](https://www.proxmox.com/en/downloads/proxmox-virtual-environment)
- BalenaEtcher: [Link](https://etcher.balena.io/)

Durante o setup, todas as opções default (recomendadas) foram mantidas para o particionamento e configuração inicial, não havendo customizações nesta etapa. Após a instalação, através da interface web (WebGUI), foram realizadas as configurações descritas no arquivo [`Configuracao-Proxmox-VE`](/infraestrutura/proxmox/Configuracao-Proxmox-VE.md).

---

## ⚙️ Provisionamento do Firewall (Terraform + Golden Config)

A implantação do firewall pfSense combina **Infraestrutura como Código (Terraform)** para criação do hardware virtual no Proxmox e **restauração de backup (`config.xml`)** para aplicação das regras de segurança:

1. **Configuração de Variáveis do Terraform:**
   No diretório `infraestrutura/firewall/`, copie o arquivo de exemplo e preencha com os dados do seu servidor Proxmox:
   ```bash
   cp infraestrutura/firewall/terraform.tfvars.example infraestrutura/firewall/terraform.tfvars
   chmod 600 infraestrutura/firewall/terraform.tfvars
   ```
   Defina no `terraform.tfvars` a URL da API (`proxmox_endpoint`), o token (`proxmox_api_token`) e o caminho da ISO de instalação no storage (`pfsense_iso_file_id`).

2. **Criação da VM no Proxmox:**
   ```bash
   cd infraestrutura/firewall
   terraform init
   terraform apply
   ```
   O Terraform criará a VM `100` (`pfSense-Automated`) com disco de 20 GB no SSD (`local-lvm`), 3 interfaces de rede (`vmbr0`, `vmbr1`, `vmbr2`) e ordem de boot `["scsi0", "ide2"]` (que inicia automaticamente pelo CD-ROM na primeira execução, quando o disco `scsi0` ainda está vazio, e passa a iniciar pelo SSD após instalado).

3. **Aplicação das Regras e Configurações (`config.xml`):**
   Após concluir a instalação do pfSense no console do Proxmox:
   * Acesse o **WebGUI do pfSense** a partir de um navegador na rede doméstica (`https://<IP-WAN-DO-PFSENSE>`).
   * Navegue até **Diagnostics > Backup & Restore** (aba **Backup & Restore** > seção **Restore Backup**).
   * Caso esteja replicando este laboratório a partir do template público [`config.xml.example`](infraestrutura/firewall/config.xml.example), você pode restaurar por seção (**Restore area**: *Interfaces*, *DHCP Server*, *Aliases* e *Firewall Rules*) para importar toda a topologia e regras sem sobrescrever a senha de administrador e o certificado SSL da sua instância.
   * No ambiente local da autora, o arquivo completo `config.xml` (mantido fora do versionamento Git por conter hashes e chaves privadas) é restaurado integralmente em **Restore Configuration**.

---

## 📁 Estrutura do Repositório

```
homelab-exploration-zone/
├── README.md                              # Documentação principal e visão arquitetural
├── docs/                                  # Diagramas e topologia de rede
│   └── topologia.md
├── infraestrutura/
│   ├── proxmox/                           # Documentação da preparação do hipervisor e storages
│   │   └── fase1-base-proxmox.md
│   └── firewall/                          # Provisionamento IaC (Terraform) e regras do pfSense
│       ├── main.tf                        # Definição da VM, discos e bridges (vmbr0, vmbr1, vmbr2)
│       ├── variables.tf                   # Declaração de variáveis e parâmetros sensíveis
│       ├── terraform.tfvars.example       # Modelo de preenchimento de variáveis do Terraform
│       └── config.xml.example             # Template sanitizado das interfaces, DHCP, aliases e regras do pfSense
├── maquina-atacante/
│   └── kali-kvm/                          # Configurações e scripts da estação de ataque
└── alvos-exploracao/
    ├── active-directory/                  # Procedimentos de deployment do AD e scripts BadBlood
    ├── linux/                             # Notas de configuração de alvos Linux clássicos
    └── web-docker/                        # Arquivos Docker Compose (DVWA, OWASP Juice Shop)
```

---

## 🚀 Roadmap de Implantação

- [x] Fase 1: Preparação do Hipervisor Proxmox VE
    - Instalação limpa do Proxmox VE no SSD de 230 GB.
    - Particionamento e montagem do HDD de 500 GB como storage secundário (`HD-500GB`).
    - Atualização dos repositórios para a versão `no-subscription`.

- [x] Fase 2: Infraestrutura de Rede Virtual
    - Criação da bridge interna `vmbr1` (sem portas físicas associadas).
    - Criação da bridge interna `vmbr2` (sem portas físicas associadas).
    - Validação da retenção do tráfego interno no switch virtual do kernel.

- [x] Fase 3: Implantação Automatizada e Blindagem do Firewall (pfSense)
    - Provisionamento automatizado da VM do pfSense via **Terraform** (`bpg/proxmox`) com 3 interfaces virtuais (`vmbr0`, `vmbr1`, `vmbr2`).
    - Configuração das faixas de IP e DHCP via restore do `config.xml`: WAN via DHCP doméstico, `OPT1` (`10.0.10.1/24`) e `LAN` (`10.0.20.1/24`).
    - Blindagem de segurança: WebGUI em HTTPS restrito à `WAN net`, bloqueio de acesso administrativo (`22/80/443`) a partir das redes de laboratório, desativação de IPv6 e bloqueio explícito de qualquer comunicação originada na `vmbr1`/`vmbr2` em direção à rede doméstica (`WAN net`).

- [X] Fase 4: Provisionamento da Estação de Ataque
    - Instalação do Kali Linux conectado à interface `vmbr1` (armazenado no SSD).
    - Configuração do gateway apontando para a interface `OPT1` do pfSense (`10.0.10.1`).

- [ ] Fase 5: Provisionamento dos Alvos de Estudo
    - Instalação e deployment de alvos web em contêineres Docker via Alpine/Debian (`vmbr2`).
    - Implantação de laboratório Active Directory enxuto com Windows Server Evaluation e BadBlood (`vmbr2`).
    - Importação de máquinas legadas e desafios de exploração (Metasploitable, VulnHub).

## 📄 Licença e Aviso Legal
Distribuído sob a licença MIT. Consulte LICENSE para mais detalhes.

> ⚠️ Aviso Legal: Todo o tráfego gerado pelas ferramentas ofensivas deve ser mantido estritamente confinado aos barramentos virtuais isolados (vmbr1 e vmbr2). A realização de varreduras, ataques ou explorações sem consentimento prévio e formal contra alvos fora do ambiente virtualizado é estritamente ilegal.
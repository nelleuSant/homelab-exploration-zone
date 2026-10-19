# 🐉 Estação de Ataque — Kali Linux (IaC com Terraform)

Este diretório contém os manifestos de **Infraestrutura como Código (Terraform)** e a documentação técnica para o provisionamento automatizado da estação de testes de intrusão (**Kali Linux**) sobre o hipervisor Proxmox VE.

A máquina atua como a origem controlada de todas as auditorias, varreduras e explorações contra os alvos do laboratório, operando de forma 100% confinada dentro do barramento virtual de ataque (`vmbr1`).

---

## 🖥️ 1. Especificações Técnicas da VM

O dimensionamento foi planejado para extrair alta performance do hardware base (**Intel Core i5-8400 | 16 GB RAM**) sem comprometer os recursos destinados ao firewall pfSense e aos servidores-alvo (como o Active Directory):

| Parâmetro | Valor Configurado (`main.tf`) | Justificativa Técnica |
| :--- | :--- | :--- |
| **Nome / VM ID** | `Kali-Linux` (`101`) | Identificação padronizada logo após o firewall (`100`). |
| **Processador (CPU)** | `2 Cores` (`type = "host"`) | O modo `host` expõe as instruções reais da CPU física (como AES-NI/AVX2), acelerando ferramentas criptográficas e de *cracking*. |
| **Memória RAM** | `4096 MB` (4 GB dedicados) | Permite execução fluida da interface gráfica (XFCE), navegador, Burp Suite e Metasploit Framework simultaneamente. |
| **Vídeo / Display (`vga`)** | `type = "qxl"` (SPICE) | Habilita o protocolo **SPICE**, resolvendo falhas de mapeamento de teclado do noVNC e entregando aceleração gráfica 2D e *clipboard* compartilhado. |
| **Layout de Teclado** | `keyboard_layout = "pt-br"` | Define o mapa ABNT2 na camada do hipervisor Proxmox/QEMU. |
| **Armazenamento (Disco)** | `40 GB` em `local-lvm` (`scsi0` / `raw`) | Alocado no **SSD primário** para garantir alta taxa de I/O durante varreduras, indexação de bancos de dados e leitura de *wordlists*. |
| **Mídia de Instalação** | `ide2` (`var.kali_iso_file_id`) | Imagem ISO carregada a partir do storage secundário a frio (`HD-500GB`). |
| **Ordem de Boot** | `["scsi0", "ide2"]` | Na criação (com `scsi0` vazio), a BIOS inicia automaticamente pelo CD-ROM (`ide2`); após instalado, inicia direto pelo SSD sem entrar em loop. |
| **Inicialização no Boot** | `on_boot = false` | Por segurança e economia de recursos, a máquina ofensiva permanece desligada até que o laboratório seja utilizado. |
| **Sistema Operacional** | `l26` (Linux 2.6 - 6.x Kernel) | Tag nativa do Proxmox otimizada para kernels Debian/Kali modernos. |

---

## 🖥️ 2. Acesso Gráfico via SPICE (`qxl` + `virt-viewer`)

### Motivação: Problemas de Teclado no Console Web (noVNC)
Durante a instalação e operação do Kali Linux pelo navegador utilizando o console padrão (**noVNC**), ocorrem conflitos frequentes na tradução de *scancodes* do teclado brasileiro (**ABNT2 / `pt-br`**) — impedindo ou trocando caracteres essenciais em linha de comando (como `/`, `?`, `|`, `\`), mesmo com `keyboard_layout = "pt-br"` definido.

### Solução Implementada: Driver `qxl` + Cliente Nativo `virt-viewer`
Para contornar as limitações do navegador, o hardware de vídeo da VM foi configurado no [`main.tf`](main.tf) com o driver **`qxl`** (protocolo **SPICE**):

```hcl
  vga {
    type = "qxl"
  }
```

#### Como conectar a partir da máquina de gerência (CachyOS / Arch Linux):
1. **Instalar o cliente `virt-viewer` no sistema host (CachyOS):**
   ```bash
   sudo pacman -S virt-viewer
   ```
2. **Iniciar a sessão SPICE pelo Proxmox:**
   * Na interface Web do Proxmox, selecione a VM `101` (`Kali-Linux`).
   * Clique na **setinha ao lado do botão `Console`** (no canto superior direito) e selecione a opção **`SPICE`**.
   * O navegador fará o download de um arquivo de conexão temporário (`pve-spice.vv`).
   * Abra o arquivo baixado (ele será executado automaticamente pelo **Remote Viewer / `virt-viewer`**).

> 💡 **Vantagens do SPICE (`qxl`):** O `virt-viewer` captura o teclado nativamente direto do sistema operacional host (CachyOS) sem interferência do navegador, resolvendo 100% dos problemas de layout de teclado, além de oferecer baixa latência de vídeo e redimensionamento automático da janela.

---

## 🔒 3. Arquitetura de Rede e Segurança

A estação de ataque possui **uma única interface de rede virtual (`virtio`)**, conectada exclusivamente à bridge isolada **`vmbr1`**:

* **Interface no pfSense:** `OPT1` (`vtnet1`)
* **Sub-rede de Ataque:** `10.0.10.0/24`
* **Gateway Padrão (pfSense):** `10.0.10.1`
* **Endereço IP (DHCP / Estático):** `10.0.10.10/24`

### Políticas de Contenção Aplicadas pelo Firewall (pfSense)
1. **Isolamento de Camada 2:** A bridge `vmbr1` não possui nenhuma placa de rede física associada no servidor Proxmox.
2. **Proteção da Rede Doméstica (`WAN net`):** Qualquer pacote originado na `vmbr1` (`10.0.10.0/24`) com destino à rede residencial sofre *Drop* imediato no pfSense (IPv4 e IPv6).
3. **Proteção do Próprio Firewall (`Self`):** O Kali Linux é bloqueado de acessar as portas administrativas do pfSense (`22/SSH`, `80/HTTP` e `443/HTTPS`), impedindo alterações acidentais ou adulteração das regras de segurança a partir da rede de ataque.
4. **Acesso à Zona de Exploração e Internet:** O tráfego originado na `vmbr1` é roteado pelo pfSense para a **Zona de Exploração (`vmbr2` - `10.0.20.0/24`)** e possui saída NAT para a Internet (para atualização de pacotes `apt` e repositórios de ferramentas).

---

## 🚀 4. Passo a Passo de Provisionamento (Terraform)

### Pré-requisitos
1. A imagem ISO instaladora do Kali Linux deve estar armazenada no datastore `HD-500GB` do Proxmox (em **HD-500GB > ISO Images**).
2. A VM `100` (**pfSense**) já deve estar ativa para fornecer DHCP, DNS e gateway na interface `vmbr1`.

### Etapa 1: Configurar Variáveis Locais e Segredos
No diretório `maquina-atacante/`, crie o arquivo `terraform.tfvars` a partir do modelo versionado e restrinja suas permissões de leitura:

```bash
cd maquina-atacante
cp terraform.tfvars.example terraform.tfvars
chmod 600 terraform.tfvars
```

Edite o arquivo `terraform.tfvars` preenchendo os valores reais do seu ambiente:

```hcl
proxmox_endpoint  = "https://SEU_HOST_PROXMOX:8006/"
proxmox_api_token = "terraform@pam!terraform=SEU_TOKEN_AQUI"
proxmox_insecure  = true
kali_iso_file_id  = "HD-500GB:iso/kali-linux-installer-amd64.iso"
```

> ⚠️ **Importante:** O arquivo `terraform.tfvars` e os arquivos de estado (`terraform.tfstate*`) são ignorados pelo `.gitignore` na raiz do projeto e **nunca** devem ser enviados ao GitHub.

### Etapa 2: Inicializar e Validar o Terraform
```bash
terraform init
terraform validate
```

### Etapa 3: Planejar e Aplicar a Infraestrutura
Revise o plano de execução e confirme a criação da máquina virtual:

```bash
terraform plan
terraform apply
```

Após a confirmação (`yes`), o Proxmox provisionará e iniciará a **VM 101 (`Kali-Linux`)** automaticamente no instalador do sistema.

---

## 🧪 5. Pós-Instalação e Checklist de Validação

Assim que concluir a instalação padrão do Kali Linux via **SPICE (`virt-viewer`)** e realizar o primeiro login, execute os testes abaixo no terminal do Kali para validar a segurança da topologia:

### 1. Verificar Endereçamento IP e Rota Padrão
```bash
ip -br a
ip route
```
* **Resultado esperado:** Interface `eth0` com IP na faixa `10.0.10.x/24` (ex: `10.0.10.10/24`) e gateway `default via 10.0.10.1`.

### 2. Validar Isolamento da Rede Doméstica (Deve FALHAR / Timeout)
```bash
ping -c 3 192.168.1.1
```
* **Resultado esperado:** `100% packet loss` (bloqueado pela regra `"Bloquear acesso a casa"` na interface `OPT1` do pfSense).

### 3. Validar Bloqueio ao Painel Administrativo do pfSense (Deve FALHAR)
```bash
curl -kI --connect-timeout 5 https://10.0.10.1
```
* **Resultado esperado:** Timeout / falha de conexão (bloqueado pela regra `"Bloquear gerencia do pfSense a partir da Rede de Ataque"`).

### 4. Validar Conectividade com a Internet e DNS (Deve FUNCIONAR)
```bash
ping -c 3 1.1.1.1
sudo apt update
```
* **Resultado esperado:** Resposta normal de pacotes e atualização dos repositórios oficiais do Kali Linux.

---

## 📂 Arquivos deste Diretório

* **`main.tf`**: Declaração do provider `bpg/proxmox` e do recurso `proxmox_virtual_environment_vm.kali_attack`.
* **`variables.tf`**: Definição de tipos e marcação de variáveis sensíveis (`sensitive = true`).
* **`terraform.tfvars.example`**: Template seguro e sanitizado para preenchimento local das credenciais.

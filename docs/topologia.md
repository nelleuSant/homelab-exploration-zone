# Topologia da Zona de Exploração

O diagrama abaixo detalha a separação física e lógica entre a rede doméstica, a máquina atacante e o laboratório de alvos.

```mermaid
flowchart TD
    %% Infraestrutura Doméstica
    Router["Roteador Doméstico\nRede Doméstica (WAN net)"]
    CachyOS["CachyOS\nAcesso via Web GUI"]

    subgraph "Servidor Proxmox"
        Proxmox["Proxmox VE\nGerenciamento: vmbr0 (:8006)"]
        FW["pfSense Firewall (VM 100)\nWAN: vmbr0 (DHCP) | OPT1: vmbr1 (10.0.10.1/24) | LAN: vmbr2 (10.0.20.1/24)"]
        
        subgraph "Rede de Ataque (vmbr1)"
            Kali["Kali Linux\nIP: 10.0.10.10/24"]
        end

        subgraph "Zona de Exploração (vmbr2)"
            Vuln1["Metasploitable\nIP: 10.0.20.11/24"]
            Vuln2["Active Directory\nIP: 10.0.20.12/24"]
            Vuln3["Docker Web Apps\nIP: 10.0.20.13/24"]
        end
    end

    %% Conexões
    Router <-->|"Cabo Físico (vmbr0)"| Proxmox
    Router <-->|"Cabo Físico"| CachyOS
    CachyOS -.->|"Gerenciamento HTTPS :8006"| Proxmox
    CachyOS -.->|"Gerenciamento WebGUI HTTPS :443"| FW
    
    %% Roteamento Interno do Proxmox
    Kali == "Tráfego de Ataque\n10.0.10.0/24 (Bloqueado :22/:80/:443 no FW)" ==> FW
    FW == "Tráfego Filtrado (OPT1 -> LAN)\n10.0.20.0/24" ==> Vuln1
    FW == "Tráfego Filtrado (OPT1 -> LAN)\n10.0.20.0/24" ==> Vuln2
    FW == "Tráfego Filtrado (OPT1 -> LAN)\n10.0.20.0/24" ==> Vuln3

    %% Isolamento da Rede Doméstica
    FW -.-x|"Bloqueio Estrito (Drop OPT1/LAN -> WAN net)"| Router

    %% Estilização
    classDef redeSegura fill:#2196F3,color:#fff,stroke:#fff,stroke-width:2px;
    classDef redeAtaque fill:#f44336,color:#fff,stroke:#fff,stroke-width:2px;
    classDef redeAlvo fill:#4CAF50,color:#fff,stroke:#fff,stroke-width:2px;
    classDef fw fill:#FF9800,color:#fff,stroke:#fff,stroke-width:2px;

    class Router,CachyOS,Proxmox redeSegura;
    class Kali redeAtaque;
    class Vuln1,Vuln2,Vuln3 redeAlvo;
    class FW fw;
```
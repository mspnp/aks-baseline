# Copilot Instructions for AKS Baseline

This repository is the **reference implementation** for the [Azure Kubernetes Service (AKS) baseline cluster](https://aka.ms/architecture/aks-baseline) architecture from Azure Architecture Center. It demonstrates the **minimum recommended baseline** for most AKS clusters and serves as the starting point for architectural conversations. Adapt it to your specific requirements before production use.

## Tech Stack

### Infrastructure as Code

- **Bicep** - All Azure infrastructure definitions
- **Azure CLI** - Deployment execution via `az deployment group create`
- **Azure Resource Manager** - Underlying deployment engine

### Azure Services

- **AKS** (v1.34) - Kubernetes cluster with Azure CNI Overlay networking
- **Azure Firewall** (Premium) - Egress traffic control and threat intelligence
- **Azure Application Gateway** (v2 with WAF) - Ingress and TLS termination
- **Azure Key Vault** - Secrets and certificate management
- **Azure Container Registry** - Private container image storage
- **Azure Monitor / Log Analytics** - Observability and diagnostics
- **Microsoft Entra ID** - Identity and RBAC integration

### Kubernetes Components

- **Flux** (AKS-managed extension) - GitOps operator for cluster bootstrapping
- **Traefik** - Ingress controller for internal traffic routing
- **Secrets Store CSI Driver** (AKS add-on) - Key Vault integration
- **Azure Workload Identity** (AKS add-on) - Pod identity management

### Manifests

- **Kustomize** - Workload manifest composition (`workload/kustomization.yaml`)
- **Kubernetes YAML** - Cluster baseline configurations

## Architecture Overview

This is an **infrastructure-focused** implementation using a hub-spoke network topology. It does not focus on workloads—the sample ASP.NET Core app exists only to demonstrate the infrastructure.

### Network Topology

- **Hub VNet** (`network-team/hub-regionA.bicep`): Central connectivity containing Azure Firewall (managed egress), Azure Bastion (secure management access), and a gateway subnet for VPN/ExpressRoute.
- **Spoke VNet** (`network-team/spoke-BU0001A0008.bicep`): Contains the AKS cluster with dedicated subnets for Application Gateway, ingress resources, cluster nodes, Private Link endpoints, and the API server (private cluster).

### Team Separation Model

The directory structure models organizational separation of duties:

| Directory | Team | Purpose |
|-----------|------|---------|
| `network-team/` | Networking | Hub-spoke topology, firewall rules, VNet peering |
| `workload-team/` | Platform/DevOps | AKS cluster, ACR, Key Vault, App Gateway, monitoring |
| `cluster-manifests/` | Platform/DevOps | Kubernetes baseline configs deployed via Flux GitOps |
| `workload/` | Application | Sample workload manifests (Kustomize) |

### Key Components

- **AKS** with Azure CNI Overlay, system/user node pool separation, Microsoft Entra ID integration, Azure RBAC for Kubernetes authorization
- **Azure Application Gateway** with WAF for ingress, terminating external TLS
- **Traefik** as the internal ingress controller, terminating internal TLS
- **Azure Firewall** controlling all egress traffic via UDRs
- **Flux GitOps** for cluster bootstrapping from `cluster-manifests/`
- **Azure Key Vault** with Secrets Store CSI Driver for certificate/secret management
- **Private cluster** with API server VNet integration

### Traffic Flow

1. Client → Application Gateway (TLS termination, WAF inspection)
2. App Gateway → Internal Load Balancer (re-encrypted with wildcard cert)
3. Load Balancer → Traefik ingress controller (TLS termination)
4. Traefik → Workload pods (HTTP)

All egress flows through Azure Firewall with explicit allow rules.

## Deployment

Deployments are executed via Azure CLI with Bicep—follow the numbered docs in `docs/deploy/` (01-12) sequentially.

```bash
# Deploy hub network
az deployment group create -g rg-enterprise-networking-hubs \
  -f network-team/hub-regionA.bicep \
  -p nodepoolSubnetResourceIds="['$NODEPOOL_SUBNET_RESOURCE_ID']"

# Deploy spoke network  
az deployment group create -g rg-enterprise-networking-spokes \
  -f network-team/spoke-BU0001A0008.bicep \
  -p hubVnetResourceId=$HUB_VNET_ID

# Deploy AKS cluster and supporting services

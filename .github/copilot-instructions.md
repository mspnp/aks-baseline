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

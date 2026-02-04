# Copilot Instructions for AKS Baseline

This repository is the **reference implementation** for the [Azure Kubernetes Service (AKS) baseline cluster](https://aka.ms/architecture/aks-baseline) architecture from Azure Architecture Center. It demonstrates the **minimum recommended baseline** for most AKS clusters and serves as the starting point for architectural conversations. Adapt it to your specific requirements before production use.

## Tech Stack

### Infrastructure as Code

- **Bicep** - All Azure infrastructure definitions
- **Azure CLI** - Deployment execution via `az deployment group create`

### Azure Services

- **AKS** - Kubernetes cluster with Azure CNI Overlay networking
- **Azure Firewall** (Premium) - Egress traffic control and threat intelligence
- **Azure Application Gateway** (with WAF) - Ingress and TLS termination
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

Deployments are executed via Azure CLI with Bicep—follow the numbered docs in `docs/deploy/` sequentially.

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
az deployment group create -g rg-bu0001a0008 \
  -f workload-team/cluster-stamp.bicep \
  -p targetVnetResourceId=$SPOKE_VNET_ID \
  -p clusterAdminMicrosoftEntraGroupObjectId=$CLUSTER_ADMIN_GROUP_ID ...
```

## Conventions

### Bicep Files

- Use `@description()` decorators on all parameters
- Parameters: camelCase (e.g., `targetVnetResourceId`)
- Resource names: kebab-case with location suffix for multi-region support (e.g., `vnet-${location}-hub`, `la-hub-${location}`). This convention enables deploying the same templates across different Azure regions.
- Always configure diagnostic settings to send logs to Log Analytics
- Modules live in `modules/` subdirectories

### Kubernetes Manifests

- **Workload namespace**: `a0008` (derived from business unit identifier "BU0001A0008")
- **Cluster-wide configs**: `cluster-baseline-settings` namespace
- Use `app.kubernetes.io/name` labels consistently
- User workloads target node pool `npuser01` via `nodeSelector`
- Security contexts: non-root user, drop all capabilities, disable privilege escalation

### Naming

- "Contoso Bicycle" is a fictional company providing narrative context
- Domain pattern: `bu0001a0008-00.aks-ingress.contoso.com` for internal ingress
- Resource naming follows pattern: `{resource-type}-{purpose}-{location}` or `{resource-type}-{unique-string}`

## Resources

### Deployment Documentation

Follow the numbered sequence in `docs/deploy/` (01-12)—each step builds on the previous:

| Step | File | Purpose |
|------|------|---------|
| 01 | `01-prerequisites.md` | Azure subscription, tooling, permissions |
| 02 | `02-ca-certificates.md` | TLS certificate generation |
| 03 | `03-microsoft-entra-id.md` | Identity and RBAC planning |
| 04 | `04-networking.md` | Hub-spoke network deployment |
| 05 | `05-bootstrap-prep.md` | GitOps and Flux preparation |
| 06 | `06-aks-cluster.md` | AKS cluster deployment |
| 07 | `07-bootstrap-validation.md` | Cluster bootstrapping validation |
| 08 | `08-workload-prerequisites.md` | Workload identity and secrets |
| 09 | `09-secret-management-and-ingress-controller.md` | Traefik and Key Vault setup |
| 10 | `10-workload.md` | Sample application deployment |
| 11 | `11-validation.md` | End-to-end validation |
| 12 | `12-cleanup.md` | Resource cleanup |

### Scripts

- `saveenv.sh` - Saves environment variables for session continuity

### Architecture Diagrams

- `docs/aks-baseline_details.drawio.svg` - Detailed architecture overview
- `network-team/network-topology.drawio` - Network topology diagram

### Related Resources

- [Azure Architecture Center - AKS Baseline](https://aka.ms/architecture/aks-baseline) - Companion guidance
- [AKS Baseline Automation](https://github.com/Azure/aks-baseline-automation) - CI/CD pipeline examples
- [Contoso Bicycle context](./contoso-bicycle/README.md) - Fictional company requirements

## Validation

Since this is an IaC reference implementation (not application code), there are no unit tests. Validation is performed through:

1. **Bicep compilation** - `az bicep build -f <file>.bicep`
2. **What-if deployment** - `az deployment group what-if -g <rg> -f <file>.bicep`
3. **Sequential deployment** - Follow docs/deploy steps in order
4. **End-to-end validation** - See `docs/deploy/11-validation.md`

## Pull Request Authoring Guidelines

When Copilot creates or assists with PRs in this repository, follow these guidelines:

### PR Title Format

Follow conventional commits with scope and area:

```
<type> (<scope>): [<area>] <imperative description>
```

**Types:**
- `feat` - New feature or capability
- `fix` - Bug fix or correction
- `docs` - Documentation only changes
- `refactor` - Code change that neither fixes a bug nor adds a feature
- `chore` - Maintenance tasks, dependency updates

**Scopes:**
- `docs` - Documentation changes
- `iac` - Infrastructure as Code (Bicep templates)
- `k8s` - Kubernetes manifests
- `misc` - Other changes

**Areas:**
- `networking` - Hub, spoke, firewall, peering (`network-team/`)
- `cluster` - AKS cluster, ACR, Key Vault (`workload-team/`)
- `workload` - Application manifests (`workload/`, `cluster-manifests/`)
- `misc` - Cross-cutting or other

**Examples:**
```
feat (iac): [networking] add NSG rules for Azure Bastion
fix (iac): [cluster] correct Key Vault RBAC role assignment
docs (docs): [cluster] clarify bootstrap validation steps
refactor (k8s): [workload] consolidate ingress annotations
chore (misc): [misc] update Kubernetes version to 1.34
```

### Commit Message Format

Individual commits within a PR use simple imperative style:

```
<lowercase imperative description>

<detailed explanation of what and why>
```

**Guidelines:**
- Start with lowercase verb (add, fix, update, remove, refactor)
- Keep first line under 50 characters
- Add blank line before detailed description

**Examples:**
```
add Tech Stack section

Document the complete technology stack used in this reference implementation:
- Infrastructure as Code: Bicep, Azure CLI, ARM
- Azure Services: AKS, Firewall, App Gateway, Key Vault, ACR, Monitor, Entra ID
```

### PR Description Structure

```markdown
## Summary
[Brief description of what changed and why]

## Changes
- [ ] Bicep templates modified: `path/to/file.bicep`
- [ ] Kubernetes manifests modified: `path/to/manifest.yaml`
- [ ] Documentation updated: `docs/deploy/XX-step.md`

## Validation Steps

### For Bicep Changes
1. Compile the template:
   ```bash
   az bicep build -f <modified-file>.bicep
   ```
2. Run what-if to preview changes:
   ```bash
   az deployment group what-if -g <resource-group> -f <modified-file>.bicep -p <parameters>
   ```
3. Verify no breaking changes to existing deployments

### For Kubernetes Manifest Changes
1. Validate YAML syntax:
   ```bash
   kubectl apply --dry-run=client -f <modified-file>.yaml
   ```
2. If cluster exists, validate against cluster:
   ```bash
   kubectl apply --dry-run=server -f <modified-file>.yaml
   ```
3. Verify Kustomize builds successfully:
   ```bash
   kubectl kustomize workload/
   ```

### For Documentation Changes
1. Verify all referenced files/paths exist
2. Verify Azure CLI commands are syntactically correct
3. Ensure step numbering remains sequential

## Testing Checklist
- [ ] Bicep compiles without errors
- [ ] No secrets or credentials in code
- [ ] Naming conventions followed (see Conventions section)
- [ ] Diagnostic settings configured for new resources
- [ ] Documentation updated if behavior changes
```

### What Copilot Should Include in PRs

1. **Context**: Reference the related issue, architecture decision, or Azure documentation
2. **Scope**: Keep changes atomic—one logical change per PR
3. **Testing Evidence**: Include output of validation commands when possible
4. **Deployment Impact**: Note if changes require redeployment of existing resources
5. **Breaking Changes**: Clearly flag any breaking changes to parameters or outputs

### Common Validation Commands

```bash
# Validate all Bicep files in a directory
find . -name "*.bicep" -exec az bicep build -f {} \;

# Lint Bicep with best practices
az bicep lint -f <file>.bicep

# Validate Kubernetes manifests
kubectl apply --dry-run=client -f cluster-manifests/ -R

# Build Kustomize output
kubectl kustomize workload/

# Check for hardcoded secrets (should return nothing)
grep -rE "(password|secret|key)\s*[:=]\s*['\"][^'\"]+['\"]" --include="*.bicep" --include="*.yaml"
```

### PR Labels to Consider

- `bicep` - Changes to infrastructure templates
- `kubernetes` - Changes to cluster manifests
- `documentation` - Changes to deployment docs
- `breaking-change` - Requires action from users with existing deployments
- `security` - Security-related changes

---

## Best Practices for This Instructions File

This file follows [GitHub's recommendations](https://github.blog/ai-and-ml/github-copilot/5-tips-for-writing-better-custom-instructions-for-copilot/) for copilot-instructions.md:

| Section | Best Practice | Status |
|---------|---------------|--------|
| **Project Overview** | Elevator pitch—what it is, who it's for, key features | ✅ |
| **Tech Stack** | List languages, frameworks, tools with brief context | ✅ |
| **Coding Guidelines** | Imperative rules, do's/don'ts, naming conventions | ✅ |
| **Project Structure** | Directory layout with descriptions | ✅ |
| **Resources** | Scripts, tools, documentation, MCP servers | ✅ |
| **Concise & Direct** | Use bullets and tables, avoid verbose prose | ✅ |
| **Examples** | Code snippets showing common patterns | ✅ |
| **PR Authoring** | Title format, description structure, validation steps | ✅ |
| **Commit Messages** | Simple imperative style, lowercase, detailed body | ✅ |

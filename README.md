# Azure Kubernetes Service (AKS) Baseline Reference Implementation

This reference implementation demonstrates the _recommended_ infrastructure architecture for hosting applications on an [AKS cluster](https://azure.microsoft.com/services/kubernetes-service).

This is meant to guide an interdisciplinary team or multiple teams like networking, security and development through the process of getting this secure baseline infrastructure deployed.

## Guidance

This project has a companion set of articles that describe challenges, design patterns, and best practices for a secure AKS cluster. You can find this article on the Azure Architecture Center:

[Baseline architecture for a secure AKS cluster](https://docs.microsoft.com/azure/architecture/reference-architectures/containers/aks/secure-baseline/)

## Architecture

This architecture is infrastructure focused, more so than workload. It mainly concentrates on the AKS cluster itself, including identity, post-deployment configuration, secret management, and network considerations.

The implementation presented here is the minimum recommended _baseline_ for expanded growth any AKS cluster. This implementation integrates with Azure services that will deliver observability, provide a network topology that will support multi-regional growth, and keep the in-cluster traffic secure as well.

We recommend customers strongly consider adopting a GitOps process for cluster management. An implementation of this is demonstrated in this reference, using [Flux](https://fluxcd.io).

Contoso Bicycle is a fictional small and fast-growing startup that provides online web services to its clientele in the west coast of North America. They have no on-premises data centers and all their containerized line of business applications are now about to be orchestrated by secure, enterprise-ready AKS clusters.

This implementation uses the [ASPNET Core Docker sample web app](https://github.com/dotnet/dotnet-docker/tree/master/samples/aspnetapp) as an example workload. This workload purposefully uninteresting, as it is here exclusively to help you experience the baseline infrastructure.

### Core components that compose this baseline

#### Azure platform

* AKS v1.17
  * System and User nodepool separation
  * AKS-managed Azure AD integration
  * Managed Identities
  * Azure CNI
  * Azure Monitor for Containers
* Azure Virtual Networks (hub-spoke)
* Azure Application Gateway (WAF)
* AKS-managed Internal Load Balancers
* Azure Firewall

#### In-cluster OSS components

* [Flux GitOps Operator](https://fluxcd.io)
* [Traefik Ingress Controller](https://docs.microsoft.com/azure/dev-spaces/how-to/ingress-https-traefik)
* [Azure AD Pod Identity](https://github.com/Azure/aad-pod-identity)
* [Azure KeyVault Secret Store CSI Provider](https://github.com/Azure/secrets-store-csi-driver-provider-azure)
* [Kured](https://docs.microsoft.com/azure/aks/node-updates-kured)

![TODO, Apply Description](https://docs.microsoft.com/azure/architecture/reference-architectures/containers/aks/secure-baseline/images/baseline-network-topology.png)

## Getting Started

Please start this journey by navigating to the `Preresites` section.

- [ ] [Prerequisites](./01-prerequisites.md)
- [ ] [Generate the CA certificates](./02-ca-certificates.md)
- [ ] [Azure Active Directory Integration](./03-aad.md)
- [ ] [Hub Spoke Network Topology](./04-networking.md)
- [ ] [AKS cluster](./05-aks-cluster.md)
- [ ] [GitOps](./06-gitops.md)
- [ ] [Workload Prerequisites](./07-workload-prerequisites.md)
- [ ] [Secret Managment and Ingress Controller](./08-secret-managment-and-ingress-controller.md)
- [ ] [Workload](./09-workload.md)
- [ ] [Validation](./10-validation.md)
- [ ] [Cleanup](./11-cleanup.md)

## GitHub Actions

For your reference, a [starter GitHub Actions workflow](./github-workflow/AKS-deploy.yml) has been built for your team to consider as part of your Infrastructure as Code (IaC) solution.

## Deployment Alternatives

We have also provided some sample deployment scripts that you could adapt for your own purposes while doing a POC/spike on this. Those scripts are found in the [inner-loop-scripts directory](./inner-loop-scripts). They include some additional considerations, and include some additional narrative as well. Consider checking them out.

## See also

* [Azure Kubernetes Service Documentation](https://docs.microsoft.com/azure/aks/)
* [Microsoft Azure Well-Architected Framework](https://docs.microsoft.com/azure/architecture/framework/)
* [Microservices architecture on AKS](https://docs.microsoft.com/azure/architecture/reference-architectures/microservices/aks)

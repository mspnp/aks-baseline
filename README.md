# Azure Kubernetes Service (AKS) baseline cluster

This reference implementation demonstrates the *recommended starting (baseline) infrastructure architecture* for a general purpose [AKS cluster](https://azure.microsoft.com/services/kubernetes-service). This implementation and document is meant to guide an interdisciplinary team or multiple distinct teams like networking, security and development through the process of getting this general purpose baseline infrastructure deployed and understanding the components of it.

We walk through the deployment here in a rather *verbose* method to help you understand each component of this cluster, ideally teaching you about each layer and providing you with the knowledge necessary to apply it to your workload.

## Azure Architecture Center guidance

This project has a companion set of articles that describe challenges, design patterns, and best practices for a secure AKS cluster. You can find this article on the Azure Architecture Center at [Azure Kubernetes Service (AKS) baseline cluster](https://aka.ms/architecture/aks-baseline). If you haven't reviewed it, we suggest you read it as it will give added context to the considerations applied in this implementation. Ultimately, this is the direct implementation of that specific architectural guidance.

## Architecture

**This architecture is infrastructure focused**, more so than on workload. It concentrates on the AKS cluster itself, including concerns with identity, post-deployment configuration, secret management, and network topologies.

The implementation presented here is the *minimum recommended baseline for most AKS clusters*. This implementation integrates with Azure services that deliver observability, provide a network topology that support multiregional growth, and keep the in-cluster traffic secure as well. This architecture should be considered your starting point for pre-production and production stages.

The material here is relatively dense. We strongly encourage you to dedicate time to walk through these instructions, with a mind to learning. Therefore, we do NOT provide any "one click" deployment here. To understand the relationship between the deployed resources, we suggest that you consult the [detailed architecture overview](./docs/aks-baseline_details.drawio.svg) while exploring your deployment. Once you've understood the components involved and identified the shared responsibilities between your team and your great organization, it is encouraged that you build suitable, auditable deployment processes around your final infrastructure.

Throughout the reference implementation, you will see reference to *Contoso Bicycle*. It is a fictional small and fast-growing startup that provides online web services to its clientele on the west coast of North America. They have no on-premises datacenters and all their containerized line of business applications are now about to be orchestrated by secure, enterprise-ready AKS clusters. You can read more about [their requirements and their IT team composition](./contoso-bicycle/README.md). This narrative provides grounding for some implementation details, naming conventions, and so on. You should adapt as you see fit.

Finally, this implementation uses the [ASP.NET Core Docker sample web app](https://github.com/dotnet/dotnet-docker/tree/master/samples/aspnetapp) as an example workload. This workload is purposefully uninteresting, as it is here exclusively to help you experience the baseline infrastructure.

### Core architecture components

#### Azure platform

- AKS v1.30
  - System and user [node pool separation](https://learn.microsoft.com/azure/aks/use-system-pools)
  - [AKS-managed Microsoft Entra ID integration](https://learn.microsoft.com/azure/aks/managed-aad)
  - Microsoft Entra ID-backed Kubernetes RBAC (*local user accounts disabled*)
  - Managed identities
  - [Azure CNI Overlay](https://learn.microsoft.com/azure/aks/concepts-network-azure-cni-overlay)
  - [Azure Monitor for containers](https://learn.microsoft.com/azure/azure-monitor/containers/container-insights-overview)
- Azure virtual networks (hub-spoke)
  - Azure Firewall managed egress
- Azure Application Gateway (WAF)
- AKS-managed internal load balancers

#### In-cluster OSS components

- [Azure Workload Identity](https://learn.microsoft.com/azure/aks/workload-identity-overview) *[AKS-managed add-on]*
- [Flux GitOps Operator](https://fluxcd.io) *[AKS-managed extension]*
- [ImageCleaner (Eraser)](https://learn.microsoft.com/azure/aks/image-cleaner) *[AKS-managed add-on]*
- [Kubernetes Reboot Daemon](https://learn.microsoft.com/azure/aks/node-updates-kured)
- [Secrets Store CSI Driver for Kubernetes](https://learn.microsoft.com/azure/aks/csi-secrets-store-driver) *[AKS-managed add-on]*
- [Traefik Ingress Controller](https://doc.traefik.io/traefik/v3.1/routing/providers/kubernetes-ingress/)

![Network diagram depicting a hub-spoke network with two peered VNets and main Azure resources used in the architecture.](https://learn.microsoft.com/azure/architecture/reference-architectures/containers/aks/images/secure-baseline-architecture.svg)

Also do not forget to view the [detailed architecture diagram](./docs/aks-baseline_details.drawio.svg) to understand how the deployed resources work together in this reference architecture.

## Deploy the reference implementation

A deployment of AKS-hosted workloads typically involves a separation of duties and lifecycle management in the areas of prerequisites, the host network, the cluster infrastructure, and finally the workload itself. Different teams often are responsible for each of these components. This reference implementation follows a similar approach. Also, be aware our primary purpose is to illustrate the topology and decisions of a baseline cluster. We feel a "step-by-step" flow will help you learn the pieces of the solution and give you insight into the relationship between them. Ultimately, lifecycle/SDLC management of your cluster and its dependencies will depend on your situation (team roles, organizational standards, and so on), and will be implemented as appropriate for your needs.

**Please start this learning journey in the *Preparing for the cluster* section.** If you follow this through to the end, you'll have our recommended baseline cluster installed, with an end-to-end sample workload running for you to reference in your own Azure subscription.

### 1. :rocket: Prepare for the cluster

There are considerations that must be addressed before you start deploying your cluster. Do I have enough permissions in my subscription and AD tenant to do a deployment of this size? How much of this will be handled by my team directly vs having another team be responsible?

- [ ] Begin by ensuring you [install and meet the prerequisites](./docs/deploy/01-prerequisites.md)
- [ ] [Procure client-facing and AKS Ingress Controller TLS certificates](./docs/deploy/02-ca-certificates.md)
- [ ] [Plan your Microsoft Entra ID integration](./docs/deploy/03-microsoft-entra-id.md)

### 2. :electric_plug: Build target network

Microsoft recommends AKS be deployed into a carefully planned network; sized appropriately for your needs and with proper network observability. Organizations typically favor a traditional hub-spoke model, which is reflected in this implementation. While this is a standard hub-spoke model, there are fundamental sizing and portioning considerations included that should be understood.

- [ ] [Build the hub-spoke network](./docs/deploy/04-networking.md)

### 3. :package: Deploy the cluster

This is the heart of the guidance in this reference implementation; paired with prior network topology guidance. Here you will deploy the Azure resources for your cluster and the adjacent services such as Azure Application Gateway WAF, Azure Monitor, Azure Container Registry, and Azure Key Vault. This is also where you will validate the cluster is bootstrapped.

- [ ] [Prep for cluster bootstrapping](./docs/deploy/05-bootstrap-prep.md)
- [ ] [Deploy the AKS cluster and supporting services](./docs/deploy/06-aks-cluster.md)
- [ ] [Validate cluster bootstrapping](./docs/deploy/07-bootstrap-validation.md)

We perform the prior steps manually here for you to understand the involved components, but we advocate for an automated DevOps process. Therefore, incorporate the prior steps into your CI/CD pipeline, as you would any infrastructure as code (IaC). See the dedicated [AKS baseline automation guidance](https://github.com/Azure/aks-baseline-automation#aks-baseline-automation) for additional details.

### 4. :package: Deploy your workload

Without a workload deployed to the cluster it will be hard to see how these decisions come together to work as a reliable application platform for your business. The deployment of this workload would typically follow a CI/CD pattern and may involve even more advanced deployment strategies (such as blue/green). The following steps represent a manual deployment, suitable for illustration purposes of this infrastructure.

- [ ] Just like the cluster, there are [workload prerequisites to address](./docs/deploy/08-workload-prerequisites.md)
- [ ] [Configure AKS Ingress Controller with Azure Key Vault integration](./docs/deploy/09-secret-management-and-ingress-controller.md)
- [ ] [Deploy the workload](./docs/deploy/10-workload.md)

### 5. :checkered_flag: Validate

Now that the cluster and the sample workload is deployed; it's time to look at how the cluster is functioning.

- [ ] [Perform end-to-end deployment validation](./docs/deploy/11-validation.md)

## :broom: Clean up resources

Most of the Azure resources deployed in the prior steps will incur ongoing charges unless removed.

- [ ] [Clean up all resources](./docs/deploy/12-cleanup.md)

## Preview and additional features

Kubernetes and, by extension, AKS are fast-evolving products. The [AKS roadmap](https://aka.ms/AKS/Roadmap) shows how quickly the product is changing. This reference implementation does take dependencies on select preview features which the AKS team describes as "Shipped & Improving." The rationale behind that is that many of the preview features stay in that state for only a few months before entering GA. If you are just architecting your cluster today, by the time you're ready for production, there is a good chance that many of the preview features are nearing or will have hit GA.

This implementation will not include every preview feature, but instead only those that add significant value to a general-purpose cluster. There are some additional preview features you may wish to evaluate in preproduction clusters that augment your posture around security, manageability, and so on. As these features come out of preview, this reference implementation may be updated to incorporate them. Consider trying out and providing feedback on the following:

- [BYO Kubelet Identity](https://learn.microsoft.com/azure/aks/use-managed-identity#bring-your-own-kubelet-mi)
- [Planned maintenance window](https://learn.microsoft.com/azure/aks/planned-maintenance)
- [BYO CNI (`--network-plugin none`)](https://learn.microsoft.com/azure/aks/use-byo-cni)
- [Simplified application autoscaling with Kubernetes Event-driven Autoscaling (KEDA) add-on](https://learn.microsoft.com/azure/aks/keda)

## Related reference implementations

The AKS baseline was used as the foundation for the following additional reference implementations. These build on the learnings of the AKS baseline and applies a specific Lens to the cluster to align a specific topology, requirement, or workload type.

- [AKS baseline for multiregion clusters](https://github.com/mspnp/aks-baseline-multi-region)
- [AKS baseline for regulated workloads](https://github.com/mspnp/aks-baseline-regulated)
- [AKS baseline for microservices](https://github.com/mspnp/aks-fabrikam-dronedelivery)
- [Azure landing zones, enterprise-scale reference implementation using Terraform](https://github.com/Azure/caf-terraform-landingzones-starter/tree/starter/enterprise_scale/construction_sets/aks/online/aks_secure_baseline)

## Advanced topics

This reference implementation intentionally does not cover more advanced scenarios. For example topics like the following are not addressed:

- Cluster lifecycle management with regard to SDLC and GitOps
- Workload SDLC integration (including concepts like [Bridge to Kubernetes](https://learn.microsoft.com/visualstudio/containers/bridge-to-kubernetes), advanced deployment techniques, [Draft](https://learn.microsoft.com/azure/aks/draft), and so on)
- Container security
- Multiple (related or unrelated) workloads owned by the same team
- Multiple workloads owned by disparate teams (AKS as a shared platform in your organization)
- Cluster-contained state (PV and PVC)
- Windows node pools
- Scale-to-zero node pools and event-based scaling (KEDA)
- [Terraform](https://learn.microsoft.com/azure/developer/terraform/create-k8s-cluster-with-tf-and-aks)
- [dapr](https://github.com/dapr/dapr)

Keep watching this space, as we build out reference implementation guidance on topics such as these. Further guidance delivered will use this baseline AKS implementation as their starting point. If you would like to contribute or suggest a pattern built on this baseline, [please get in touch](./CONTRIBUTING.md).

## Final thoughts

Kubernetes is a very flexible platform, giving infrastructure and application operators many choices to achieve their business and technology objectives. At points along your journey, you will need to consider when to take dependencies on Azure platform features, OSS solutions, support channels, regulatory compliance, and operational processes. **We encourage this reference implementation to be the place for you to *start* architectural conversations within your own team; adapting to your specific requirements, and ultimately delivering a solution that delights your customers.**

## Related documentation

- [Azure Kubernetes Service Documentation](https://learn.microsoft.com/azure/aks/)
- [Microsoft Azure Well-Architected Framework](https://learn.microsoft.com/azure/architecture/framework/)
- [Microservices architecture on AKS](https://learn.microsoft.com/azure/architecture/reference-architectures/containers/aks-microservices/aks-microservices)

## Contributions

Please see our [Contributor guide](./CONTRIBUTING.md).

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact <opencode@microsoft.com> with any additional questions or comments.

With :heart: from Microsoft Patterns & Practices, [Azure Architecture Center](https://aka.ms/architecture).
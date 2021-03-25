# Azure Kubernetes Service (AKS) for Multi-Region Deployment

This reference implementation will go over some design decisions from the baseline to detail them as a well as incorporate some new _recommended infrastructure options_ for a Multi Cluster architecture. In this oportunity, this implementation and document are meant to guide the multiple distinct teams introduced in the [AKS Baseline](https://github.com/mspnp/aks-secure-baseline) through the process of expanding from a single cluster to multiple clusters solution with a foundamental driver in mind which is **High Availability**.

Throughout the reference implementation, you will see reference to _Contoso Bicycle_. They are a fictional, small, and fast-growing startup that provides online web services to its clientele on the east coast of the United States. This narrative provides grounding for some implementation details, naming conventions, etc. You should adapt as you see fit.

| 🎓 Foundational Understanding |
|:------------------------------|
| **If you haven't familiarized yourself with the general-purpose [AKS baseline cluster](https://github.com/mspnp/aks-secure-baseline) architecture, you should start there before continuing here.** The architecture rationalized and constructed that implementation is the direct foundation of this body of work. This reference implementation avoids rearticulating points that are already addressed in the AKS baseline cluster. |

### Intro

The app team works on a cluster strategically located in the `East US 2` region as this is where most of their customer base can be found. They have been operating this single AKS cluster for a quite some time [following Microsoft's recommended baseline architecture](https://github.com/mspnp/aks-secure-baseline).

The baseline cluster was already available from different _Zones_ within the same region, but now they realize that if `East US 2` went fully down, zone coverage is not sufficient. Even though the SLA(s) are acceptable for their business continuity plan, they are starting to think what their options are, and how their stateless application (Application ID: a0042) could increase its availability in case of a complete regional outage. They started conversations with the business unit (BU0001) to increment the number of clusters by one. In other words, they are proposing to move to a multi-cluster infrastructure solution in which multiple instances of the same application could live.

This architectural decision will have multiple implications for the Contoso Bicycle organization. It is not just about repeating everything they have done before but instead planning how to efficiently share Azure resources as well as detect those that need to be added; how they are going to deploy more than one cluster as well as operate them; decide to which specific regions they deploy; and many more considerations striving for high availability.

### Federation

The business unit (BU0001) approves the creation of a second cluster that could help balance the traffic but mainly to serve as a hot backup; they are a bit worried about the required engineering effort though. The same application (Application Id: a0042) is about to span into multiple clusters, so there is a desire to find a good mechanism for its configuration management. With that in mind, the app team is looking at what _federation_ approaches they could follow to run different instances of the exact same app in different clusters.

They know that at this point things must be kept simply, in fact they could run these two application instances (Applications Ids: `a0042-03` and `a0042-04`) from the two regional clusters with just a bunch of useful scripts. But they want to be sure that the selected approach is not going to be adding impediments that could prevent from scaling out their fleet of clusters down to road if there was a requirment to scale up the amount application instances.

Depending on how federation is implemented it could open a door in which a single command execution has an instant ripple effect into all your clusters. While running clusters separately like silos could keep you safe from the same, but the cost could be really high to scale the number of clusters in the future.

They know that there is specialized tooling out there that helps manage a centralized control plane to push the workload(s) behavior top to bottom reacting to special events like a regional outage but they want to proceed with caution in this area for now.

Given that this reference implementation provides a middle ground solution in which an organization could build the basis for the future without this being a weight on their shoulders for just two clusters. Therefore, the recommendation is to manage the workload manifests separately per instance from a central _federation_ git repository in combination with a CI/CD pipeline. The latter is not implemented as part of this reference implementation.

### Multi cluster management in multiple regions

The new selected location is `Central US` which is the Azure paired region for `East US 2`. Now the networking team in conjunction with the app team are closely working together to understand what is the best way for laying down the new cluster.

All in all, the team resolution is to have CI/CD pipelines, traffic management, and centralized GitOps as well as centralize the git repos containing the workload manifests, and a single declarative stamp for the cluster creation with different parameter files per region.

![The federation diagram depicting the proposed cluster fleet topology running different instances of the same application from them.](images/aks-cluster-mgmnt-n-federation.png)

> :bulb: Multi Cluster and Federation's repos could be a monorepo or multiple repos as displayed from the digram above. In this reference implementation, the workload manifests, and ARM templates are shipped together from a single repo.

## Azure Architecture Center guidance

This project has a companion set of articles that describe challenges, design patterns, and best practices for an AKS multi cluster solution disigned to be deployed in multiple region to be highly available. You can find this article on the Azure Architecture Center at [Azure Kubernetes Service (AKS) Baseline Cluster for Multi-Region deployments](https://aka.ms/architecture/aks-baseline-multi-region). If you haven't reviewed it, we suggest you read it as it will give added context to the considerations applied in this implementation. Ultimately, this is the direct implementation of that specific architectural guidance.

| :construction: | The article series mentioned above has _not yet been published_. |
|----------------|:--------------------------|

## Architecture

**This architecture is infrastructure focused**, more so than on workload. It concentrates on two AKS clusters, including concerns like multi-region deployments, the desired state of the clusters, geo-replication, network topologies, and more.

The implementation presented here, like in the baseline, is the _minimum recommended starting (baseline) for a multiple AKS cluster solution_. This implementation integrates with Azure services that will deliver geo-replication, a centralized observability approach, a network topology that is going go with multi-regional growth, and an added benefit of additional traffic balancing as well.

The material here will try to be focused exclusively on the multi-regional growth. We strongly encourage you to allocate time to go over [the AKS Baseline](https://github.com/mspnp/aks-secure-baseline) first, and later follow all the instructions provided in here. We do NOT provide any "one click" deployment here. However, once you've understood the components involved and identified the shared responsibilities between your team and your great organization, it is encouraged that you build suitable, auditable deployment processes around your final infrastructure.

Finally, this implementation uses the [ASP.NET Core Docker sample web app](https://github.com/dotnet/dotnet-docker/tree/master/samples/aspnetapp) as an example workload. This workload is purposefully uninteresting, as it is here exclusively to help you experience the baseline infrastructure.

### Core architecture components

#### Azure platform

- Azure Kubernetes Service (AKS) v1.19
- Azure Virtual Networks (hub-spoke)
- Azure Front Door
- Azure Application Gateway (WAF)
- Azure Container Registry
- Azure Monitor Log Analitycs

#### In-cluster OSS components

- [Flux GitOps Operator](https://fluxcd.io)
- [Traefik Ingress Controller](https://doc.traefik.io/traefik/v1.7/user-guide/kubernetes/)
- [Azure AD Pod Identity](https://github.com/Azure/aad-pod-identity)
- [Azure KeyVault Secret Store CSI Provider](https://github.com/Azure/secrets-store-csi-driver-provider-azure)
- [Kured](https://docs.microsoft.com/azure/aks/node-updates-kured)

| :construction: | Diagram below does _NOT accurately reflect this architecture_. **Update Pending.** |
 |----------------|:--------------------------|

![Network diagram depicting a hub-spoke network with two peered VNets, each with three subnets and main Azure resources.](https://docs.microsoft.com/azure/architecture/reference-architectures/containers/aks/images/secure-baseline-architecture.svg)

## Deploy the reference implementation

- [ ] Begin by ensuring you [install and meet the prerequisites](./01-prerequisites.md)
- [ ] [Plan your Azure Active Directory integration](./02-aad.md)
- [ ] [Build the hub-spoke network](./03-networking.md)
- [ ] [Procure client-facing and AKS Ingress Controller TLS certificates](./04-ca-certificates.md)
- [ ] [Deploy the shared services for your clusters](./05-cluster-prerequisites.md)
- [ ] [Deploy the AKS cluster and supporting services](./06-aks-cluster.md)
- [ ] Just like the cluster, there are [workload prerequisites to address](./07-workload-prerequisites.md)
- [ ] [Configure AKS Ingress Controller with Azure Key Vault integration](./08-secret-managment-and-ingress-controller.md)
- [ ] [Deploy the workload](./09-workload.md)
- [ ] [Perform end-to-end deployment validation](./10-validation.md)
- [ ] [Cleanup all resources](./11-cleanup.md)

## Cost Considerations

The main cost on the current Reference Implementation is related to (in order):

1. Azure Firewall dedicated to control outbound traffic ~35%
1. Node Pool Virtual Machines used inside the cluster ~30%
1. AppGateway which control the ingress traffic to the private vnet ~15%
1. LogAnalitycs ~10%

Azure Firewall can be a shared resource, and maybe your company already has one and you can reuse. It is not recommended, but if you want to reduce cost, you can delete the Azure Firewall and take the risk.

The Virtual Machines on the AKS Cluster are needed. The Cluster can be shared by several applications. Anyway, you can analyze the size and the amount of nodes. The Reference Implementation has the minimum recommended nodes for production environments, but in a multi-cluster environment when you have at least two clusters, based on your traffic analysis, failover strategy and autoscaling configuration, you choose different numbers.

Keep an eye on LogAnalitycs as time goes by and manage the information which is collected. The main cost is related to data ingestion into the Log Analytics workspace, you can fine tune that.

There is WAF protection enabled on Application Gateway and Azure Front Door. The WAF rules on Azure Front Door have extra cost, you can disable these rules. The consequence is that not valid traffic will arrive at Application Gateway using resources instead of being eliminated as soon as possible.

## Preview features

While this reference implementation tends to avoid _preview_ features of AKS to ensure you have the best customer support experience; there are some features you may wish to evaluate in pre-production clusters that augment your posture around security, manageability, etc. Consider trying out and providing feedback on the following. As these features come out of preview, this reference implementation may be updated to incorporate them.

* [Preview features coming from the AKS Secure Baseline](https://github.com/mspnp/aks-secure-baseline#preview-features)
* _Currently the Azure Kubernetes Service (AKS) for Multi-Region Deployment does not implement any Preview feature directly_

## Next Steps

This reference implementation intentionally does not cover all scenarios. If you are looking for other topics that are not addressed here, please visit [AKS Secure Baseline for the complete list of covered scenarios around AKS](https://github.com/mspnp/aks-secure-baseline#advanced-topics).

## Related documentation

- [Azure Kubernetes Service Documentation](https://docs.microsoft.com/azure/aks/)
- [Microsoft Azure Well-Architected Framework](https://docs.microsoft.com/azure/architecture/framework/)
- [Microservices architecture on AKS](https://docs.microsoft.com/azure/architecture/reference-architectures/containers/aks-microservices/aks-microservices)

## Contributions

Please see our [contributor guide](./CONTRIBUTING.md).

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact <opencode@microsoft.com> with any additional questions or comments.

With :heart: from Microsoft Patterns & Practices, [Azure Architecture Center](https://aka.ms/architecture).

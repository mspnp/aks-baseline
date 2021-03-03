# Deploy the AKS cluster prerequisites and shared services

In the prior step, you [generated the user-facing TLS certificate](./04-ca-certificates.md); now follow the next step in the [AKS secure Baseline reference implementation](./) is deploying the shared service instances.

## Expected results

Following the steps below will result in the provisioning of the shared Azure resources needed for an AKS multi cluster solution.

| Object                        | Purpose                                                                                                                                                                                                                                                                                                  |
| ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Azure Container Registry      | A single Azure Container Registry instance for those container images shared across multiple clusters                                                                                                                                                                                                    |
| Azure Private Dns Zone        | The Private Dns Zone for the Azure Container Registry. Later cluster can link their vNets to it                                                                                                                                                                                                          |
| Azure Log Analytics Workspace | A Centralized Log Analytics workspace where all the logs are collected                                                                                                                                                                                                                                   |
| Azure Front Door              | Azure Front Door routes traffic to the fastest and available (healthy) backend. Public IP FQDN(s) emitted by the spoke network deployments are being configured in advance as AFD's backends. These regional PIP(s) are later assigned to the Azure Application Gateways Frontend Ip Configuration.      |

## Steps

1. Create the shared services resource group for your AKS clusters.

   > :book: The app team working on behalf of business unit 0001 (BU001) is about to deploy a new app (Application Id: 0042). This application needs to be deployed in a multiregion cluster infrastructure. But first the app team is required to assess the services that could be shared across the multiple clusters they are planning to create. To do this they are looking at global or regional but geo replicated services that are not cluster but workload specific.
   >
   > They create a new resource group to be one grouping all shared infrastructure resources.

   ```bash
   # [This takes less than one minute.]
   az group create --name rg-bu0001a0042-shared --location centralus
   ```

1. Read the FQDN values will have each Azure Application Gateway, the public ip DNS name already deployed

   ```bash
   APPGW_FQDN_BU0001A0042_03=$(az deployment group show --resource-group rg-enterprise-networking-spokes -n spoke-BU0001A0042-03 --query properties.outputs.appGwFqdn.value -o tsv)
   APPGW_FQDN_BU0001A0042_04=$(az deployment group show --resource-group rg-enterprise-networking-spokes -n spoke-BU0001A0042-04 --query properties.outputs.appGwFqdn.value -o tsv)
   ```

1. Deploy the AKS cluster prerequisites and shared services.

  > :book: The app team is about to provision three shared Azure resources. One is a non-regional and two regional, but more importantly they are deployed independently from their AKS Clusters:
  >
  > | Azure Resource                                                                                                | Non-Regional  |  East US 2  | Central US |
  > |---------------------------------------------------------------------------------------------------------------|:-------------:|:-----------:|:----------:|
  > | [Log Analytics in Azure Monitor](https://docs.microsoft.com/azure/azure-monitor/logs/log-analytics-overview)  |               |      ✓      |            |
  > | [Azure Container Registry](https://docs.microsoft.com/azure/container-registry/)                              |               |      ✓      |      ✓     |
  > | [Azure Front Door](https://docs.microsoft.com/azure/frontdoor/front-door-overview)                            |      ✓        |             |            |
  >
  > **Azure Monitor logs solution**
  >
  > The app team is creating multiple clusters for its new workload (Application Id: a0042). This array of clusters is a multi-region infrastructure solution composed by multiple Azure resources that regularly emit logs to Azure Monitor. All the collected data is stored in a [centralized Log Analytics workspace for the ease of operations](https://docs.microsoft.com/en-us/azure/frontdoor/front-door-overview) after confirming there is no need to split workspaces due to scale. The app team estimates that the ingestion rate is going to be less than `6GB/minute`, so they expect not to be throttled as this is supported by the default rate limit. If it was required, they could grow by changing this setup eventually. In other words, the design decision is to create a single Azure Log Analytics workspace instance in the `eastus2` region, and that is going to be shared among their multiple clusters. Additionally, there is no business requirement for a consolidated cross business units view at this moment, so the centralization is great option for them. Something the app team also considered while making a final decision is the fact that migrating from a _centralized_ solution to a _decentralized_ one can be much easier than doing it the other way around. As a result, the single workspace being created is a workload specific workspace, and these are some of the Azure services sending data to it:
  >
  > - Azure Container Registry
  > - Azure Application Gateway
  > - Azure Key Vault
  >
  >  In the future, the app team is considering to enforce the Azure resources to send their Diagnostics logs with an Azure Policy as well as granting different users access rights to keep the data in isolation using Azure RBAC, something that is possible within a single workspace.
  >
  >  :bulb:  Azure Log Analytics can be modeled in different ways depending on your organizational needs. It can be _centralized_ as in this reference implementation, or _decentralized_ or a combination of both, which is known as _hybrid_. Azure Log Analytics workspaces are in a geographic location for data storage; consider, for high availability, a distributed solution as the recommended approach instead. If you opt for a _centralized_ solution, you need to be sure that the geo data residency is not going to be an issue, and be aware that cross-region data transfer costs will apply.
  >
  > **Geo-Replicated Azure Container Registry**
  >
  > :book: The app team is starting to lay down the groundwork for a high availability, and they know that centralizing Azure resources might introduce single point of failures. Therefore, the app team is tasked to assess how the resources could be shared efficiently without losing reliability. When looking at the Azure Container Registry, it adds at least one additional complexity which is the proximity while pulling large container images. Based on this the team realizes that the _networking io_ is going to be an important factor, so having presence in multiple regions looks promising. Although managing registry instances per region insted of shared a single one could mitigate the risk of having a region down and improve latency, this approach won’t be falling back automatically nor replicating images by requiring in both cases manual intervention and/or additional procedures.  That is the reason why, the team selected the **Premium** tier that offers [Geo-Replication](https://docs.microsoft.com/en-us/azure/container-registry/container-registry-geo-replication) as a built-in feature; giving them the ability to share a single registry, higher availability, and at same time reducing network latency. The app team plans to geo-replicate the registries to the same regions where their AKS clusters are going to be deployed (`East US 2` and `Central US`), as this is the recommendation to optimize the DNS resolution. They pay close attention to the replicated regions, as they want no more regions than needed since the business unit (bu0001) incurs Premium SKU registry fees for _each region_ they geo-replicate to. Under this configuration, they will pay *two* times Premium per month to get region proximity and to ensure no extra network egress fees from distant regions.
  >
  > The app team is instructed to build the smallest container images they can. This is something they could achieve by following the [builder pattern](https://docs.docker.com/develop/develop-images/multistage-build/#before-multi-stage-builds) or the [mutli-stage builds](https://docs.docker.com/develop/develop-images/multistage-build/#use-multi-stage-builds). Both approaches will produce final smaller container images that are meant to be for runtime-only. This will be beneficial in many ways but mainly in the speed of replication as well as in the transfer costs. A key feature as part of ACR's geo-replication is that it will only replicate unique layers, also further reducing data transfer across regions.
  >
  > In case of a region is down, the app team is now covered by the Azure Traffic Manager in the background that comes on the scene to help deriving traffic to the registry located in the region that is closest to their multiple clusters in terms of network latency.
  >
  > After this initial design decision at the ACR level, the app team can also consider analyzing how they could tactically expand into [Availability Zones](https://docs.microsoft.com/azure/container-registry/zone-redundancy) as a way of being even more resilient.
  >
  > :bulb: Another benefit of having `Geo-Replication` is that permissions are now centralized in a single registry instance simplifying the security management a lot. Every AKS cluster owns a kubelet _System Managed Identity_ by design, and that identity is the one being granted with permissions against this shared ACR instance. At the same time, these indentities can get individually assigned with role permissions in other Azure resources that are meant to be cluster-specific preventing them from cross pollination effects (i.e. Azure Key Vault). As things develop, the combination of [Availability Zones](https://docs.microsoft.com/azure/container-registry/zone-redundancy), currently in _Preview_,  for redundancy within a region, and geo-replication across multiple regions, is the recommendation when looking for the highest reliability and performance of a container registry.
  >
  > **Azure Front Door**
  >
  > :book: TODO

   ```bash
   az deployment group create -g rg-bu0001a0042-shared -f shared-svcs-stamp.json -p location=eastus2  fontDoorBackend="['${APPGW_FQDN_BU0001A0042_03}','${APPGW_FQDN_BU0001A0042_04}']"
   ```

### Next step

:arrow_forward: [Deploy the AKS cluster](./06-aks-cluster.md)

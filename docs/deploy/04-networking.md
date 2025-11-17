# Deploy the hub-spoke network topology

In the previous steps, we completed the [Microsoft Entra group and user work](./03-microsoft-entra-id.md), which means we've met the prerequisites for the [AKS baseline cluster](../../). In this article, we perform our first Azure resource deployment, which is for the network resources.

## Subscription and resource group topology

This reference implementation is split across several resource groups in a single subscription. This configuration replicates the fact that many organizations will split certain responsibilities into specialized subscriptions, such as regional hubs/VWAN in a *Connectivity* subscription and workloads in application landing zone subscriptions.

We expect you to explore this reference implementation within a single subscription, but when you implement this cluster at your organization, you will need to take what you've learned here and apply it to your expected subscription and resource group topology, such as those [offered by the Cloud Adoption Framework](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/design-area/resource-org-subscriptions). This single subscription, multiple resource group model is for simplicity of demonstration purposes only.

## Expected results

### Resource groups

The following two resource groups will be created and populated with networking resources in the following steps.

| Name                            | Purpose                                   |
|---------------------------------|-------------------------------------------|
| rg-enterprise-networking-hubs-_region_   | Contains all of your organization's hub resources for a specific region. A regional hub includes an egress firewall and Log Analytics for network logging. |
| rg-enterprise-networking-spokes-_region_ | Contains all of your organization's regional spokes and related networking resources for a specific region. All spokes will peer with their regional hub and subnets will egress through the regional firewall in the hub. |

### Resources

- Regional Azure Firewall in a hub Virtual Network
- Network spoke for the cluster
- Network peering from the spoke to the hub
- Force tunnel UDR for cluster subnets to the hub
- Network Security Groups for all subnets that support them

## Steps

1. Sign into the Azure subscription that you'll be deploying the resources to.

   > :book: The networking team logins into the Azure subscription that will contain the regional hub. At Contoso Bicycle, all of their regional hubs are in the same, centrally-managed subscription, separated by resource groups per region.

   ```bash
   az login -t $TENANTID_AZURERBAC_AKS_BASELINE
   ```

1. Choose a location and create the networking hub resource group.

   > :book: The networking team has all their regional networking hubs for this region in the following resource group. (This resource group would have already existed.)

   ```bash
   # Update this to be where you want your resources, networking and eventually cluster, to be deployed
   # Please select a location that supports availability zones, as this reference implementation depends on it
   export LOCATION_AKS_BASELINE=eastus2

   # [This takes less than one minute to run.]
   az group create -n rg-enterprise-networking-hubs-${LOCATION_AKS_BASELINE} -l $LOCATION_AKS_BASELINE
   ```

1. Create the networking spokes resource group.

   > :book: The networking team also keeps all of their spokes in a centrally-managed resource group per region. (This resource group would have already existed or would have been part of an Azure landing zone that contains the cluster.)

   ```bash
   # [This takes less than one minute to run.]
   az group create -n rg-enterprise-networking-spokes-${LOCATION_AKS_BASELINE} -l $LOCATION_AKS_BASELINE
   ```

1. Create the regional network hub.

   > :book: When the networking team created the regional hub for eastus2, it didn't have any spokes yet defined, yet the networking team always lays out a base hub following a standard pattern (defined in `hub-default.bicep`). A hub always contains an Azure Firewall (with some org-wide policies), Azure Bastion, a gateway subnet for VPN connectivity, and Azure Monitor for network observability. They follow Microsoft's recommended sizing for the subnets.
   >
   > The networking team has decided that `10.200.[0-9].0` will be where all regional hubs are homed on their organization's network space. The `eastus2` hub (created below) will be `10.200.0.0/24`.
   >
   > Note: The subnets for Azure Bastion and cross-premises connectivity are deployed in this reference architecture, but the resources are not deployed. Since this reference implementation is expected to be deployed isolated from existing infrastructure; these IP addresses should not conflict with any existing networking you have, even if those IP addresses overlap. If you need to connect the reference implementation to existing networks, you will need to adjust the IP space as per your requirements as to not conflict in the reference ARM templates.

   ```bash
   # [This takes about ten minutes to run.]
   az deployment group create -g rg-enterprise-networking-hubs-${LOCATION_AKS_BASELINE} -f network-team/hub-default.bicep
   ```

   The hub deployment emits the following output:

      - `hubVnetId` - which you'll query in future steps when creating connected regional spokes. Such as, `/subscriptions/[id]/resourceGroups/rg-enterprise-networking-hubs-eastus2/providers/Microsoft.Network/virtualNetworks/vnet-eastus2-hub`

1. Capture the output from the hub network deployment that will be required in later steps.

   ```bash
   RESOURCEID_VNET_HUB=$(az deployment group show -g rg-enterprise-networking-hubs-${LOCATION_AKS_BASELINE} -n hub-default --query properties.outputs.hubVnetId.value -o tsv)
   echo RESOURCEID_VNET_HUB: $RESOURCEID_VNET_HUB
   ```

1. Create the spoke network that will be home to the AKS cluster and its adjacent resources.

   > :book: The networking team receives a request from a workload team in business unit (BU) 0001 for a network spoke to house their new AKS-based application (Internally know as Application ID: A0008). The network team talks with the workload team to understand their requirements and aligns those needs with Microsoft's best practices for a general-purpose AKS cluster deployment. They capture those specific requirements and deploy the spoke, aligning to those specs, and connecting it to the matching regional hub.

   ```bash
   # [This takes about four minutes to run.]
   az deployment group create -g rg-enterprise-networking-spokes-${LOCATION_AKS_BASELINE} -f ./network-team/spoke-BU0001A0008.bicep -p hubVnetResourceId="${RESOURCEID_VNET_HUB}"
   ```

   The spoke network deployment emits the following outputs:

     - `appGwPublicIpAddress` - The public IP address of the Azure Application Gateway (WAF) that will receive traffic for your workload.
     - `clusterVnetResourceId` - The resource ID of the virtual network where the cluster, App Gateway, and related resources will be deployed. Such as, `/subscriptions/[id]/resourceGroups/rg-enterprise-networking-spokes-eastus2/providers/Microsoft.Network/virtualNetworks/vnet-spoke-BU0001A0008-00`
     - `nodepoolSubnetResourceIds` - An array containing the subnet resource IDs of the AKS node pools in the spoke. Such as, `[ "/subscriptions/[id]/resourceGroups/rg-enterprise-networking-spokes-eastus2/providers/Microsoft.Network/virtualNetworks/vnet-hub-spoke-BU0001A0008-00/subnets/snet-clusternodes"]`

1. Capture the output from the spoke network deployment that will be required in later steps.

   ```bash
   RESOURCEID_SUBNET_NODEPOOLS=$(az deployment group show -g rg-enterprise-networking-spokes-${LOCATION_AKS_BASELINE} -n spoke-BU0001A0008 --query properties.outputs.nodepoolSubnetResourceIds.value -o json)
   echo RESOURCEID_SUBNET_NODEPOOLS: $RESOURCEID_SUBNET_NODEPOOLS
   ```

1. Update the shared, regional hub deployment to account for the networking requirements of the upcoming workload in the spoke.

   > :book: Now that their regional hub has its first spoke, the hub can no longer run off of the generic hub template. The networking team creates a named hub template (such as, `hub-eastus2.bicep`) to forever represent this specific hub and the features this specific hub needs in order to support its spokes' requirements. As new spokes are attached and new requirements arise for the regional hub, they will be added to this template file.

   ```bash
   # [This takes about 15 minutes to run.]
   az deployment group create -g rg-enterprise-networking-hubs-${LOCATION_AKS_BASELINE} -f ./network-team/hub-regionA.bicep -p nodepoolSubnetResourceIds="${RESOURCEID_SUBNET_NODEPOOLS}"
   ```

   > :book: At this point the networking team has delivered a spoke in which BU 0001's workload team can lay down their AKS cluster (ID: A0008). The networking team provides the necessary information to the workload team for them to reference in their infrastructure-as-code artifacts.
   >
   > Hubs and spokes are controlled by the networking team's GitHub Actions workflows. This automation is not included in this reference implementation as this body of work is focused on the AKS baseline and not the networking team's CI/CD practices.

## Private DNS zones

Private DNS zones in this reference implementation are implemented directly at the spoke level, meaning the workload team creates the Private Link DNS zones and records for the resources needed; furthermore, the workload is directly using Azure DNS for resolution. Your networking topology might support this decentralized model too. Alternatively, DNS and DNS zones for Private Link might be handed at the regional hub or in a [VWAN virtual hub extension](https://learn.microsoft.com/azure/architecture/guide/networking/private-link-virtual-wan-dns-virtual-hub-extension-pattern) by your networking team.

If your organization operates a centralized DNS model, you will need to integrate the management of DNS zone records for this implementation into your existing enterprise networking DNS zone strategy. Since this reference implementation is expected to be deployed in isolation from your existing infrastructure, this isn't something you need to address now - but will be something to understand and address when taking your solution to production.

### Save your work in-progress

```bash
# run the saveenv.sh script at any time to save environment variables created above to aks_baseline.env
./saveenv.sh

# if your terminal session gets reset, you can source the file to reload the environment variables
# source aks_baseline.env
```

### Next step

:arrow_forward: [Prep for cluster bootstrapping](./05-bootstrap-prep.md)

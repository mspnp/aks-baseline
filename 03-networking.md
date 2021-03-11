# Deploy the Hub-Spoke Network Topology

The prerequisites for the [AKS secure baseline cluster](./) are now completed with [Azure AD group and user work](./02-aad.md) performed in the prior steps. Now we will start with our first Azure resource deployment, the network resources.

## Subscription and resource group topology

This reference implementation is split across several resource groups in a single subscription. This is to replicate the fact that many organizations will split certain responsibilities into specialized subscriptions (e.g. regional hubs/vwan in a _Connectivity_ subscription and workloads in landing zone subscriptions). We expect you to explore this reference implementation within a single subscription, but when you implement this cluster at your organization, you will need to take what you've learned here and apply it to your expected subscription and resource group topology (such as those [offered by the Cloud Adoption Framework](https://docs.microsoft.com/azure/cloud-adoption-framework/decision-guides/subscriptions/).) This single subscription, multiple resource group model is for simplicity of demonstration purposes only.

## Expected results

### Resource Groups

The following two resource groups will be created and populated with networking resources in the steps below.

| Name                            | Purpose                                                                                                                                                                                              |
| ------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| rg-enterprise-networking-hubs   | Contains all of your organization's regional hubs. A regional hubs include an egress firewall and Log Analytics for network logging.                                                                 |
| rg-enterprise-networking-spokes | Contains all of your organization's regional spokes and related networking resources. All spokes will peer with their regional hub and subnets will egress through the regional firewall in the hub. |

### Resources

- Regional Azure Firewall in Hub Virtual Network
- Network Spoke for the Cluster
- Network Peering from the Spoke to the Hub
- Force Tunnel UDR for Cluster Subnets to the Hub
- Network Security Groups for all subnets that support them

## Steps

1. Login into the Azure subscription that you'll be deploying into.

   > :book: The networking team logins into the Azure subscription that will contain the regional hub. At Contoso Bicycle, all of their regional hubs are in the same, centrally-managed subscription.

   ```bash
   az login -t $TENANTID_AZURERBAC
   ```

1. Create the networking hubs resource group.

   > :book: The networking team has all their regional networking hubs in the following resource group. The group's default location does not matter, as it's not tied to the resource locations. (This resource group would have already existed.)

   ```bash
   # [This takes less than one minute to run.]
   az group create -n rg-enterprise-networking-hubs -l centralus
   ```

1. Create the networking spokes resource group.

   > :book: The networking team also keeps all of their spokes in a centrally-managed resource group. As with the hubs resource group, the location of this group does not matter and will not factor into where our network will live. (This resource group would have already existed.)

   ```bash
   # [This takes less than one minute to run.]
   az group create -n rg-enterprise-networking-spokes -l centralus
   ```

1. Create the two regional network hubs.

   > :book: When the networking team created the regional hubs for eastus2 and westus2, they didn't have any spokes yet defined, yet the networking team always lays out the base hubs following a standard pattern (defined in `hub-default.json`). A hub always contains an Azure Firewall (with some org-wide policies), Azure Bastion, a gateway subnet for VPN connectivity, and Azure Monitor for network observability. They follow Microsoft's recommended sizing for the subnets.
   >
   > The networking team has decided that `10.200.[0-9].0` will be where all regional hubs are homed on their organization's network space. The `eastus2` and `westus2` hubs (created below) will be `10.200.3.0/24` and `10.200.4.0/24` respectively.
   >
   > Note: The subnets for Azure Bastion and on-prem connectivity are deployed in this reference architecture, but the resources are not deployed. Since this reference implementation is expected to be deployed isolated from existing infrastructure; these IP addresses should not conflict with any existing networking you have, even if those IP addresses overlap. If you need to connect the reference implementation to existing networks, you will need to adjust the IP space as per your requirements as to not conflict in the reference ARM templates.

   ```bash
   # [This takes about five minutes to run.]
   az deployment group create -g rg-enterprise-networking-hubs -f networking/hub-default.json -n hub-region1 -p hubVnetAddressSpace="10.200.3.0/24" azureFirewallSubnetAddressSpace="10.200.3.0/26" azureGatewaySubnetAddressSpace="10.200.3.64/27" azureBastionSubnetAddressSpace="10.200.3.96/27" location=eastus2
   az deployment group create -g rg-enterprise-networking-hubs -f networking/hub-default.json -n hub-region2 -p hubVnetAddressSpace="10.200.4.0/24" azureFirewallSubnetAddressSpace="10.200.4.0/26" azureGatewaySubnetAddressSpace="10.200.4.64/27" azureBastionSubnetAddressSpace="10.200.4.96/27" location=centralus
   ```

   The hub creations will emit the following:

   - `hubVnetId` - which you'll will query in future steps when creating connected regional spokes. E.g. `/subscriptions/[subscription id]/resourceGroups/rg-enterprise-networking-hubs/providers/Microsoft.Network/virtualNetworks/vnet-eastus2-hub`

1. Create two spokes that will be home to the AKS clusters for the app team working on the A0042 and its adjacent resources.

   > :book: The networking team receives a request from an app team in business unit (BU) 0001. This is for the creation of network spokes to house their new AKS-based application (Internally know as Application ID: A0042). The network team talks with the app team to understand their requirements and aligns those needs with Microsoft's best practices for a secure AKS cluster deployment. As part of the non-functional requirements, the app team mentions they need to run 2 separated infrastructure instances of the same application. This is because the app team wants to be ready in case AKS introduces _Preview Features_ that could be a breaking in upcoming major releases like happened with `containerd` as the new default runtime. In those situtations, the app team wants to do some A/B testing of A0042 without fully disrupting its live and stable AKS cluster. The networking team realizes they are going to need two different spokes to fullfil the app team's desire. They capture those specific requirements and deploy the spokes (`BU0001A0042-03` and `BU0001A0042-04`), aligning to those specs, and connecting it to the matching regional hub.

   ```bash
   # [This takes about ten minutes to run.]
   RESOURCEID_VNET_HUB_REGION1=$(az deployment group show -g rg-enterprise-networking-hubs -n hub-region1 --query properties.outputs.hubVnetId.value -o tsv)
   RESOURCEID_VNET_HUB_REGION2=$(az deployment group show -g rg-enterprise-networking-hubs -n hub-region2 --query properties.outputs.hubVnetId.value -o tsv)
   az deployment group create -g rg-enterprise-networking-spokes -f networking/spoke-BU0001A0042.json -n spoke-BU0001A0042-03 -p hubVnetResourceId="${RESOURCEID_VNET_HUB_REGION1}" appInstanceId="03" clusterVNetAddressPrefix="10.243.0.0/16" clusterNodesSubnetAddressPrefix="10.243.0.0/22" clusterIngressServicesSubnetAdressPrefix="10.243.4.0/28" applicationGatewaySubnetAddressPrefix="10.243.4.16/28" location=eastus2
   az deployment group create -g rg-enterprise-networking-spokes -f networking/spoke-BU0001A0042.json -n spoke-BU0001A0042-04 -p hubVnetResourceId="${RESOURCEID_VNET_HUB_REGION2}" appInstanceId="04" clusterVNetAddressPrefix="10.244.0.0/16" clusterNodesSubnetAddressPrefix="10.244.0.0/22" clusterIngressServicesSubnetAdressPrefix="10.244.4.0/28" applicationGatewaySubnetAddressPrefix="10.244.4.16/28" location=centralus
   ```

   The spoke creation will emit the following:

   - `appGwFqdn` - The Public FQDN of the Azure Application Gateway (WAF) that will receive traffic for your workload.
   - `clusterVnetResourceId` - The resource ID of the VNet that the cluster will land in. E.g. `/subscriptions/[subscription id]/resourceGroups/rg-enterprise-networking-spokes/providers/Microsoft.Network/virtualNetworks/vnet-hub-spoke-BU0001a0042-00`
   - `nodepoolSubnetResourceIds` - An array containing the subnet resource IDs of the AKS node pools in the spoke. E.g. `["/subscriptions/[subscription id]/resourceGroups/rg-enterprise-networking-spokes/providers/Microsoft.Network/virtualNetworks/vnet-hub-spoke-BU0001a0042-00/subnets/snet-clusternodes"]`

1. Update the shared, regional hub deployment to account for the requirements of the multiple spokes.

   > :book: Once their hub has one or more spokes, it can no longer run off of the generic hub template. The networking team creates a named hub template (e.g. `hub-eastus2.json`) to forever represent this specific hub and the features this specific hub needs in order to support its spokes' requirements. As new spokes are attached and new requirements arise for the regional hub, they will be added to this template file.

   ```bash
    # [This takes about three minutes to run.]
   RESOURCEID_SUBNET_NODEPOOLS_BU0001A0042_03=$(az deployment group show -g  rg-enterprise-networking-spokes -n spoke-BU0001A0042-03 --query properties.outputs.nodepoolSubnetResourceIds.value -o tsv)
   RESOURCEID_SUBNET_NODEPOOLS_BU0001A0042_04=$(az deployment group show -g  rg-enterprise-networking-spokes -n spoke-BU0001A0042-04 --query properties.outputs.nodepoolSubnetResourceIds.value -o tsv)
   az deployment group create -g rg-enterprise-networking-hubs -f networking/hub-regionA.json -n hub-region1 -p nodepoolSubnetResourceIds="['${RESOURCEID_SUBNET_NODEPOOLS_BU0001A0042_03}']" hubVnetAddressSpace="10.200.3.0/24" azureFirewallSubnetAddressSpace="10.200.3.0/26" azureGatewaySubnetAddressSpace="10.200.3.64/27" azureBastionSubnetAddressSpace="10.200.3.96/27" location=eastus2
   az deployment group create -g rg-enterprise-networking-hubs -f networking/hub-regionA.json -n hub-region2 -p nodepoolSubnetResourceIds="['${RESOURCEID_SUBNET_NODEPOOLS_BU0001A0042_04}']" hubVnetAddressSpace="10.200.4.0/24" azureFirewallSubnetAddressSpace="10.200.4.0/26" azureGatewaySubnetAddressSpace="10.200.4.64/27" azureBastionSubnetAddressSpace="10.200.4.96/27" location=centralus
   ```

   > :book: At this point the networking team has delivered two spokes in which the BU 0001's app team can lay down their AKS clusters. The networking team provides the necessary information to the app teams for them to reference in their Infrastructure-as-Code artifacts.
   >
   > Hubs and spokes are controlled by the networking team's GitHub Actions workflows. This automation is not included in this reference implementation as this body of work is focused on the AKS baseline and not the networking team's CI/CD practices.

## Preparing for a Failover

> :book: The networking team is now dealing with multiple clusters in different regions. Understanding how the traffic flows at layers 4 and 7 through their deployed networking topology is now more critical than ever. That's why the team is evaluating different tooling that could provide monitoring over their networks.  One of the Azure Monitor products at subscription level is Network Watcher that offers two really interesting features such as NSG Flow Logs and with that [Traffic Analytics](https://docs.microsoft.com/azure/network-watcher/traffic-analytics). The latter can bring some light over the table when it is about analyzing traffic like from where it is being originated, how it is flowing thought the different regions, or how much is benign vs malicious together with many more details at the security and performance level. [With no upfront cost and no termination fees](https://azure.microsoft.com/pricing/details/network-watcher/) the business unit (BU0001) would be charged for collection and processing logs per GB at 10-min or 60-min intervals.

![Traffic Analytics Geo Map View of the AKS Multi Cluster reference implementation under load. Traffic is coming from a single Azure Front Door POP and is distrubuted to both regions after the first failover is complete](images/traffic-analytics-geo-map.gif)

> :bulb: The [AKS Baseline](https://github.com/mspnp/aks-secure-baseline) has already covered the how(s) and why(s) of the current [network topology segmentation](https://github.com/mspnp/aks-secure-baseline/blob/main/networking/topology.md). But something that is worth to remember while preparing for a high availability architecture is that the network needs to be right sized to absorb a sudden increase in traffic that might request twice the number of IPs when scheduling more _Pods_ to failover a region.

### Next step

:arrow_forward: [Generate your client-facing TLS certificate](./04-ca-certificates.md)

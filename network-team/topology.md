# AKS baseline network topology

> Note: This is part of the Azure Kubernetes Service (AKS) baseline cluster reference implementation. For more information see the [readme file in the root](../README.md).

There are multiple network CIDR ranges used throughout this reference implementation.

## Hub virtual network

`CIDR: 10.200.0.0/24`

This regional virtual network hub (shared) holds the following subnets:

- [Azure Firewall subnet]
- [Gateway subnet]
- [Azure Bastion subnet], with reference NSG in place

> For more information about this topology, you can read more at [Azure hub-spoke topology].

## Spoke virtual network

`CIDR: 10.240.0.0/16`

This virtual network holds the following subnets:

- [AKS System Nodepool] and [AKS User Nodepool] subnet
- [AKS Internal Load Balancer subnet]
- [Azure Application Gateway subnet]
- [Private Link Endpoint subnet]
- All with basic NSGs around each

In the future, this virtual network might hold more subnets like [Azure Container Instances Provider instance subnets], more [AKS Nodepools subnets], and more.

### Subnet details

| Subnet                                      | Upgrade Node | Nodes/VMs/Instance | % Seasonal scale out | +Nodes/VMs | Max IPs/Pods per VM/Node | [% Max Surge] | [% Max Unavailable] | +IPs/Pods per VM/Node | Tot. IPs/Pods per VM/Node | [Azure Subnet not assignable IPs factor] | [Private Endpoints] | [Minimum Subnet size] | Scaled Subnet size | [Subnet Mask bits] | CIDR       | Host        | Broadcast     |
|---------------------------------------------|-------------:|-------------------:|---------------------:|-----------:|-------------------------:|--------------:|--------------------:|----------------------:|--------------------------:|-----------------------------------------:|--------------------:|----------------------:|-------------------:|-------------------:|----------------|-------------|---------------|
| AKS system and user node pool Subnet         | 2            | 5                  | 200                  | 10         | [30]                     | 100           | 0                   | 30                    | 60                        | 5                                        | 0                   | 372                   | 982                | 22                 | 10.240.0.0/22  | 10.240.0.0  | 10.240.3.255  |
| AKS Internal Load Balancer Services Subnet  | -            | -                  | -                    | -          | 5                        | 100           | 100                 | 0                     | 5                         | 5                                        | 0                   | 10                    | 10                 | 28                 | 10.240.4.0/28  | 10.240.4.0  | 10.240.4.15   |
| Private Link Endpoint Subnet                | -            | -                  | -                    | -          | -                        | 100           | 100                 | 0                     | 0                         | 5                                        | 2                   | 7                     | 7                  | 28                 | 10.240.4.32/28 | 10.240.4.32 | 10.240.4.47   |
| Azure Application Gateway Subnet            | -            | [251]              | -                    | -          | -                        | 100           | 100                 | 0                     | 0                         | 5                                        | 0                   | 256                   | 256                | 24                 | 10.240.5.0/24  | 10.240.5.0  | 10.240.5.255  |
| Gateway Subnet (GatewaySubnet)              | -            | [27]               | -                    | -          | -                        | 100           | 100                 | 0                     | 0                         | 5                                        | 0                   | 32                    | 32                 | 27                 | 10.200.0.64/27 | 10.200.0.64 | 10.200.0.95   |
| Azure Firewall Subnet (AzureFirewallSubnet) | -            | [59]               | -                    | -          | -                        | 100           | 100                 | 0                     | 0                         | 5                                        | 0                   | 64                    | 64                 | 26                 | 10.200.0.0/26  | 10.200.0.0  | 10.200.0.63   |
| Azure Bastion Subnet (AzureBastionSubnet)   | -            | [50]               | -                    | -          | -                        | 100           | 100                 | 0                     | 0                         | 5                                        | 0                   | 64                    | 64                 | 26                 | 10.200.0.128/26 | 10.200.0.128 | 10.200.0.191  |

This reference implementation uses a /22 subnet for node pools, but in your solution you might be able to use a smaller subnet, depending on the number of nodes that you plan to scale to.

## Pod address space

`CIDR: 192.168.0.0/16`

The cluster uses [Azure CNI Overlay]. Pods within the cluster are assigned IP addresses from within a separate CIDR range to those used by the virtual networks.

Nodes are assigned IP addresses from within the spoke virtual network's subnet, and also are allocated a /24 block within the pod address space for their pods to use.

## Additional considerations

- [AKS System Nodepool] and [AKS User Nodepool] subnet:  multitenant or other advanced workloads may have nodepool isolation requirements that might demand more (and likely smaller) subnets.
- [AKS Internal Load Balancer subnet]: multitenant, multiple SSL termination rules, single PPE supporting dev/QA/UAT, and so on could lead to needing more ingress controllers, but for baseline, we should start with one.
- [Private Endpoints] subnet: Private Links are created for Azure Container Registry and Azure Key Vault, so these Azure services can be accessed using Private Endpoints within the spoke virtual network. There are multiple [Private Link deployment options]; in this implementation they are deployed to a dedicated subnet within the spoke virtual network.

[27]: https://learn.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpn-gateway-settings#gwsub
[251]: https://learn.microsoft.com/azure/application-gateway/configuration-overview#size-of-the-subnet
[59]: https://learn.microsoft.com/azure/firewall/firewall-faq#does-the-firewall-subnet-size-need-to-change-as-the-service-scales
[50]: https://learn.microsoft.com/azure/bastion/configuration-settings#instance
[30]: https://learn.microsoft.com/azure/aks/use-system-pools#system-and-user-node-pools
[% Max Surge]: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#max-surge
[% Max Unavailable]: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#max-unavailable
[Azure Subnet not assignable IPs factor]: https://learn.microsoft.com/azure/virtual-network/ip-services/private-ip-addresses#allocation-method
[Private Endpoints]: https://learn.microsoft.com/azure/private-link/private-endpoint-overview#private-endpoint-properties
[Minimum Subnet size]: https://learn.microsoft.com/azure/aks/configure-azure-cni#plan-ip-addressing-for-your-cluster
[Subnet Mask bits]: https://learn.microsoft.com/azure/virtual-network/virtual-networks-faq#how-small-and-how-large-can-vnets-and-subnets-be
[Azure hub-spoke topology]: https://learn.microsoft.com/azure/architecture/reference-architectures/hybrid-networking/hub-spoke
[Azure Firewall subnet]: https://learn.microsoft.com/azure/firewall/firewall-faq#does-the-firewall-subnet-size-need-to-change-as-the-service-scales
[Gateway subnet]: https://learn.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpn-gateway-settings#gwsub
[Azure Application Gateway subnet]: https://learn.microsoft.com/azure/application-gateway/configuration-infrastructure#virtual-network-and-dedicated-subnet
[Private Link Endpoint subnet]: https://learn.microsoft.com/azure/architecture/guide/networking/private-link-hub-spoke-network#networking
[Private Link deployment options]: https://learn.microsoft.com/azure/architecture/guide/networking/private-link-hub-spoke-network#decision-tree-for-private-link-deployment
[Azure Bastion subnet]: https://learn.microsoft.com/azure/bastion/configuration-settings#subnet
[AKS System Nodepool]: https://learn.microsoft.com/azure/aks/use-system-pools#system-and-user-node-pools
[AKS User Nodepool]: https://learn.microsoft.com/azure/aks/use-system-pools#system-and-user-node-pools
[AKS Internal Load Balancer subnet]: https://learn.microsoft.com/azure/aks/internal-lb#specify-a-different-subnet
[ACI Provider Instance]: https://learn.microsoft.com/azure/container-instances/container-instances-vnet
[AKS Nodepools subnets]: https://learn.microsoft.com/azure/aks/use-system-pools#system-and-user-node-pools
[Azure CNI Overlay]: https://learn.microsoft.com/azure/aks/azure-cni-overlay

# AKS baseline Network Topology

## Hub vnet

`CIDR: 10.200.0.0/24`

this VNet Hub (Shared) is meant to hold the following subnets:
  - [Azure Firewall subnet]
  - [Gateway subnet]
  - [Azure Bastion subnet]

> Note: for more information about this topology, please lets take a look at [Azure Hub-Spoke topology]

## Hub-Spoke vnet

`CIDR: 10.240.0.0/19`

this VNet Spoke 1 (Cluster) this vnet is meant to hold the following subnets:
  - [AKS System Nodepool subnet]
  - [AKS User Nodepool subnet]
  - [AKS Internal Load Balancer subnet]

In the future, this vnet might hold more subnets like [ACI Provider instance]
subnets, more [AKS Nodepools subnets], [Private endpoints], and more.

> Note: for more information about this topology, please lets take a look at [Azure Hub-Spoke topology]

## Subnet details

| Subnet                                                 | Upgrade Node | Nodes/VMs/Instance | % Xmas scale out | +Nodes/VMs | Max Ips/Pods per VM/Node | [% Max Surge] | [% Max Unavailable] | +Ips/Pods per VM/Node | Tot. Ips/Pods per VM/Node | [Azure Subnet not assignable Ips factor] | [Private Endpoints] | [Minimum Subnet size] | Scaled Subnet size | [Subnet Mask bits] | Cidr           | Host        | Broadcast     |
|--------------------------------------------------------|--------------|--------------------|------------------|------------|--------------------------|---------------|---------------------|-----------------------|---------------------------|------------------------------------------|---------------------|-----------------------|--------------------|--------------------|----------------|-------------|---------------|
| AKS System Nodepool (CoreDNS,tunnelfront, etc.) Subnet | 1            | 3                  | 0                | 0          | [30]                     | 100           | 100                 | 0                     | 30                        | 5                                        | 0                   | 129                   | 129                | 24                 | 10.240.16.0/24 | 10.240.16.0 | 10.240.16.255 |
| AKS User Nodepool 1 (Apps Workload Type A) Subnet      | 1            | 1                  | 5000             | 50         | [30]                     | 100           | 0                   | 30                    | 60                        | 5                                        | 0                   | 127                   | 3177               | 20                 | 10.240.0.0/20  | 10.240.0.0  | 10.240.15.255 |
| AKS Internal Load Balancer Services Subnet             | 0            | 0                  | 0                | 0          | 131                      | 100           | 100                 | 0                     | 131                       | 5                                        | 0                   | 136                   | 136                | 24                 | 10.240.17.0/24 | 10.240.17.0 | 10.240.17.255 |
| Azure Application Gateway Subnet                       | 0            | [11]               | 0                | 0          | 0                        | 100           | 100                 | 0                     | 0                         | 5                                        | 0                   | 16                    | 16                 | 28                 | 10.240.18.0/28 | 10.240.18.0 | 10.240.18.15  |
| Gateway Subnet (GatewaySubnet)                         | 0            | [27<sup>1</sup>]   | 0                | 0          | 0                        | 100           | 100                 | 0                     | 0                         | 5                                        | 0                   | 32                    | 32                 | 27                 | 10.200.0.64/27 | 10.200.0.64 | 10.200.0.95   |
| Azure Firewall Subnet (AzureFirewallSubnet)            | 0            | [59]               | 0                | 0          | 0                        | 100           | 100                 | 0                     | 0                         | 5                                        | 0                   | 64                    | 64                 | 26                 | 10.200.0.0/26  | 10.200.0.0  | 10.200.0.63   |
| Azure Bastion Subnet (AzureBastionSubnet)              | 0            | [27<sup>2</sup>]   | 0                | 0          | 0                        | 100           | 100                 | 0                     | 0                         | 5                                        | 0                   | 32                    | 32                 | 27                 | 10.200.0.96/27 | 10.200.0.96 | 10.200.0.127  |

[27<sup>1</sup>]: https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpn-gateway-settings#gwsub
[11]: https://docs.microsoft.com/en-us/azure/application-gateway/configuration-overview#size-of-the-subnet
[59]: https://docs.microsoft.com/en-us/azure/firewall/firewall-faq#does-the-firewall-subnet-size-need-to-change-as-the-service-scales
[27<sup>2</sup>]: https://docs.microsoft.com/en-us/azure/bastion/bastion-create-host-portal#createhost
[30]: https://docs.microsoft.com/en-us/azure/aks/use-system-pools#system-and-user-node-pools
[% Max Surge]: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#max-surge
[% Max Unavailable]: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#max-unavailable
[Add Ips/Pods]: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#rolling-update-deployment
[Azure Subnet not assignable Ips factor]: https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-ip-addresses-overview-arm#allocation-method-1
[Private Endpoints]: https://docs.microsoft.com/en-us/azure/private-link/private-endpoint-overview#private-endpoint-properties
[Minimum Subnet size]: https://docs.microsoft.com/en-us/azure/aks/configure-azure-cni#plan-ip-addressing-for-your-cluster
[Subnet Mask bits]: https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-faq#how-small-and-how-large-can-vnets-and-subnets-be
[Azure Hub-Spoke topology]: https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/hub-spoke
[Azure Firewall subnet]: https://docs.microsoft.com/en-us/azure/firewall/firewall-faq#does-the-firewall-subnet-size-need-to-change-as-the-service-scales
[Gateway subnet]: https://docs.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpn-gateway-settings#gwsub
[Azure Bastion subnet]: https://docs.microsoft.com/en-us/azure/bastion/bastion-create-host-portal#createhost
[AKS System Nodepool subnet]: https://docs.microsoft.com/en-us/azure/aks/use-system-pools#system-and-user-node-pools
[AKS User Nodepool subnet]: https://docs.microsoft.com/en-us/azure/aks/use-system-pools#system-and-user-node-pools
[AKS Internal Load Balancer subnet]: https://docs.microsoft.com/en-us/azure/aks/internal-lb#specify-a-different-subnet
[ACI Provider Instances]: https://docs.microsoft.com/en-us/azure/container-instances/container-instances-vnet
[AKS Nodepools subnets]: https://docs.microsoft.com/en-us/azure/aks/use-system-pools#system-and-user-node-pools

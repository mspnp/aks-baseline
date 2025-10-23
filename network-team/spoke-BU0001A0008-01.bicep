targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('The regional hub network to which this regional spoke will peer to.')
@minLength(79)
param hubVnetResourceId string

/*** VARIABLES ***/

@description('The spokes\'s regional affinity, must be the same as the hub\'s location. All resources tied to this spoke will also be homed in this region. The network team maintains this approved regional list which is a subset of regions with Availability Zone support.')
var location = resourceGroup().location

/*** EXISTING RESOURCES ***/

@description('The resource group name containing virtual network in which the regional Azure Firewall is deployed.')
resource rgHubs 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  scope: subscription()
  name: split(hubVnetResourceId, '/')[4]
}

@description('The regional Azure Firewall that all regional spoke networks can egress through.')
resource hubFirewall 'Microsoft.Network/azureFirewalls@2021-05-01' existing = {
  scope: rgHubs
  name: 'fw-${location}'
}

resource hubLaWorkspace 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' existing = {
    scope: rgHubs
    name: 'la-hub-${location}'
}

/*** RESOURCES ***/

@description('Next hop to regional hub Azure Firewall')
resource afRouteTable 'Microsoft.Network/routeTables@2021-05-01' = {
    name: 'route-to-${location}-hub-fw'
    location: location
    properties: {
        routes: [
            {
                name: 'r-nexthop-to-fw'
                properties: {
                    nextHopType: 'VirtualAppliance'
                    addressPrefix: '0.0.0.0/0'
                    nextHopIpAddress: hubFirewall.properties.ipConfigurations[0].properties.privateIPAddress
                }
            }
        ]
    }
}

@description('NSG on the jumpbox image builder subnet.')
resource nsgJumpboxImgbuilderSubnet 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
    name: 'nsg-vnet-spoke-BU0001A0008-01-imageBuilder'
    location: location
    properties: {
        securityRules: [
            {
                name: 'AllowAzureLoadBalancer60001InBound'
                properties: {
                    description: 'Allows heath probe traffic to AIB Proxy VM on 60001 (SSH)'
                    protocol: 'Tcp'
                    sourcePortRange: '*'
                    sourceAddressPrefix: 'AzureLoadBalancer'
                    destinationPortRange: '60001'
                    destinationAddressPrefix: 'VirtualNetwork'
                    access: 'Allow'
                    priority: 100
                    direction: 'Inbound'
                }
            }
            {
                name: 'AllowVNet60001InBound'
                properties: {
                    description: 'Allows traffic from AIB Service PrivateLink to AIB Proxy VM'
                    protocol: 'Tcp'
                    sourcePortRange: '*'
                    sourceAddressPrefix: 'VirtualNetwork'
                    destinationPortRange: '60001'
                    destinationAddressPrefix: 'VirtualNetwork'
                    access: 'Allow'
                    priority: 110
                    direction: 'Inbound'
                }
            }
            {
                name: 'AllowVNet22InBound'
                properties: {
                    description: 'Allows Packer VM to receive SSH traffic from AIB Proxy VM'
                    protocol: 'Tcp'
                    sourcePortRange: '*'
                    sourceAddressPrefix: 'VirtualNetwork'
                    destinationPortRange: '22'
                    destinationAddressPrefix: 'VirtualNetwork'
                    access: 'Allow'
                    priority: 120
                    direction: 'Inbound'
                }
            }
            {
                name: 'DenyAllInBound'
                properties: {
                    description: 'Deny remaining traffic.'
                    protocol: '*'
                    sourcePortRange: '*'
                    sourceAddressPrefix: '*'
                    destinationPortRange: '*'
                    destinationAddressPrefix: '*'
                    access: 'Deny'
                    priority: 1000
                    direction: 'Inbound'
                }
            }
            {
                name: 'Allow443ToInternetOutBound'
                properties: {
                    description: 'Allow VMs to communicate to Azure management APIs, Azure Storage, and perform install tasks.'
                    protocol: 'Tcp'
                    sourcePortRange: '*'
                    sourceAddressPrefix: 'VirtualNetwork'
                    destinationPortRange: '443'
                    destinationAddressPrefix: 'Internet'
                    access: 'Allow'
                    priority: 100
                    direction: 'Outbound'
                }
            }
            {
                name: 'Allow80ToInternetOutBound'
                properties: {
                    description: 'Allow Packer VM to use apt-get to upgrade packages'
                    protocol: 'Tcp'
                    sourcePortRange: '*'
                    sourceAddressPrefix: 'VirtualNetwork'
                    destinationPortRange: '80'
                    destinationAddressPrefix: 'Internet'
                    access: 'Allow'
                    priority: 102
                    direction: 'Outbound'
                }
            }
            {
                name: 'AllowSshToVNetOutBound'
                properties: {
                    description: 'Allow Proxy VM to communicate to Packer VM'
                    protocol: 'Tcp'
                    sourcePortRange: '*'
                    sourceAddressPrefix: 'VirtualNetwork'
                    destinationPortRange: '22'
                    destinationAddressPrefix: 'VirtualNetwork'
                    access: 'Allow'
                    priority: 110
                    direction: 'Outbound'
                }
            }
            {
                name: 'DenyAllOutBound'
                properties: {
                    description: 'Deny all remaining outbound traffic'
                    protocol: '*'
                    sourcePortRange: '*'
                    sourceAddressPrefix: '*'
                    destinationPortRange: '*'
                    destinationAddressPrefix: '*'
                    access: 'Deny'
                    priority: 1000
                    direction: 'Outbound'
                }
            }
        ]
    }
}

resource nsgJumpboxImgbuilderSubnet_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
    name: 'toHub'
    scope: nsgJumpboxImgbuilderSubnet
    properties: {
        workspaceId: hubLaWorkspace.id
        logs: [
            {
                category: 'NetworkSecurityGroupEvent'
                enabled: true
            }
            {
                category: 'NetworkSecurityGroupRuleCounter'
                enabled: true
            }
        ]
    }
}

@description('This vnet is used exclusively for jumpbox image builds.')
resource imageBuilderVNet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
    name: 'vnet-spoke-BU0001A0008-01'
    location: location
    properties: {
        addressSpace: {
            addressPrefixes: [
                '10.241.0.0/28'
            ]
        }
        subnets: [
            {
                name: 'snet-imagebuilder'
                properties: {
                    addressPrefix: '10.241.0.0/28'
                    routeTable: {
                        id: afRouteTable.id
                    }
                    networkSecurityGroup: {
                        id: nsgJumpboxImgbuilderSubnet.id
                    }
                    privateEndpointNetworkPolicies: 'Enabled'
                    privateLinkServiceNetworkPolicies: 'Disabled'
                }
            }
        ]
    }

    resource snetImageBuilder 'subnets' existing = {
        name: 'snet-imagebuilder'
    }
}

@description('Peer to regional hub.')
resource imageBuilderVNetPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-05-01' = {
    name: 'spoke-to-${last(split(hubVnetResourceId, '/'))}'
    parent: imageBuilderVNet
    properties: {
        remoteVirtualNetwork: {
            id: hubVnetResourceId
        }
        allowForwardedTraffic: false
        allowVirtualNetworkAccess: true
        allowGatewayTransit: false
        useRemoteGateways: false
    }
}

resource imageBuilderVNet_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
    name: 'toHub'
    scope: imageBuilderVNet
    properties: {
      workspaceId: hubLaWorkspace.id
      metrics: [
        {
          category: 'AllMetrics'
          enabled: true
        }
      ]
    }
}

module hubsSpokesPeering 'modules/hubsSpokesPeeringDeployment.bicep' = {
    name: 'hub-to-jumpboxVNet-peering'
    scope: rgHubs
    params: {
      hubVNetResourceId: hubVnetResourceId
      spokesVNetName: imageBuilderVNet.name
      rgSpokes: resourceGroup().name
    }
    dependsOn: [
        imageBuilderVNetPeering
    ]
}

/*** OUTPUTS ***/

output imageBuilderSubnetResourceId string = imageBuilderVNet::snetImageBuilder.id

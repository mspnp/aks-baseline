targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('Subnet resource Id for the AKS image builder subnet')
@minLength(79)
param aksImageBuilderSubnetResourceId string

@description('A /24 to contain the regional firewall, management, and gateway subnet')
@minLength(10)
@maxLength(18)
param hubVnetAddressSpace string = '10.200.0.0/24'

@description('A /26 under the VNet Address Space for the regional Azure Firewall')
@minLength(10)
@maxLength(18)
param azureFirewallSubnetAddressSpace string = '10.200.0.0/26'

@description('A /27 under the VNet Address Space for our regional On-Prem Gateway')
@minLength(10)
@maxLength(18)
param azureGatewaySubnetAddressSpace string = '10.200.0.64/27'

@description('A /27 under the VNet Address Space for regional Azure Bastion')
@minLength(10)
@maxLength(18)
param azureBastionSubnetAddressSpace string = '10.200.0.96/27'

@description('Flow Logs are enabled by default, if for some reason they cause conflicts with flow log policies already in place in your subscription, you can disable them by passing "false" to this parameter.')
param deployFlowLogResources bool = true

/*** VARIABLES ***/

@description('The hub\'s regional affinity. All resources tied to this hub will also be homed in this region. The network team maintains an approved regional list which is a subset of regions with Availability Zone support. Defaults to the resource group\'s location for higher availability.')
var location = resourceGroup().location

/*** EXISTING RESOURCES ***/

@description('The resource group name containing virtual network in which Azure Image Builder will drop the compute into to perform the image build.')
resource rgBuilderVirutalNetwork 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  scope: subscription()
  name: split(aksImageBuilderSubnetResourceId, '/')[4]
}

@description('AKS Spoke Virtual Network')
resource aksSpokeVnet 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  scope: rgBuilderVirutalNetwork
  name: split(aksImageBuilderSubnetResourceId, '/')[8]
}

@description('AKS ImageBuilder subnet')
resource aksImageBuilderSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' existing = {
  parent: aksSpokeVnet
  name: last(split(aksImageBuilderSubnetResourceId, '/'))
}

/*** RESOURCES ***/

@description('This Log Analytics workspace stores logs from the regional hub network, its spokes, and bastion. Log analytics is a regional resource, as such there will be one workspace per hub (region)')
resource laHub 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: 'la-hub-${location}'
}

@description('Wraps the AzureBastion subnet in this regional hub. Source: https://learn.microsoft.com/azure/bastion/bastion-nsg')
resource nsgBastionSubnet 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: 'nsg-${location}-bastion'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowWebExperienceInbound'
        properties: {
          description: 'Allow our users in. Update this to be as restrictive as possible.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowControlPlaneInbound'
        properties: {
          description: 'Service Requirement. Allow control plane access. Regional Tag not yet supported.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowHealthProbesInbound'
        properties: {
          description: 'Service Requirement. Allow Health Probes.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowBastionHostToHostInbound'
        properties: {
          description: 'Service Requirement. Allow Required Host to Host Communication.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 130
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          description: 'No further inbound traffic allowed.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 1000
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowSshToVnetOutbound'
        properties: {
          description: 'Allow SSH out to the virtual network'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '22'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowRdpToVnetOutbound'
        properties: {
          description: 'Allow RDP out to the virtual network'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '3389'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 110
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowControlPlaneOutbound'
        properties: {
          description: 'Required for control plane outbound. Regional prefix not yet supported'
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '443'
          destinationAddressPrefix: 'AzureCloud'
          access: 'Allow'
          priority: 120
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowBastionHostToHostOutbound'
        properties: {
          description: 'Service Requirement. Allow Required Host to Host Communication.'
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 130
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowBastionCertificateValidationOutbound'
        properties: {
          description: 'Service Requirement. Allow Required Session and Certificate Validation.'
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '80'
          destinationAddressPrefix: 'Internet'
          access: 'Allow'
          priority: 140
          direction: 'Outbound'
        }
      }
      {
        name: 'DenyAllOutbound'
        properties: {
          description: 'No further outbound traffic allowed.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 1000
          direction: 'Outbound'
        }
      }
    ]
  }
}

resource nsgBastionSubnet_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: nsgBastionSubnet
  properties: {
    workspaceId: laHub.id
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

@description('The regional hub network')
resource vnetHub 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: 'vnet-${location}-hub'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        hubVnetAddressSpace
      ]
    }
    subnets: [
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: azureFirewallSubnetAddressSpace
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: azureGatewaySubnetAddressSpace
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: azureBastionSubnetAddressSpace
          networkSecurityGroup: {
            id: nsgBastionSubnet.id
          }
        }
      }
    ]
  }

  resource azureFirewallSubnet 'subnets' existing = {
    name: 'AzureFirewallSubnet'
  }

  resource azureBastionSubnet 'subnets' existing = {
    name: 'AzureBastionSubnet'
  }
}

resource vnetHub_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: vnetHub
  properties: {
    workspaceId: laHub.id
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

@description('Allocate three public IP addresses to the firewall')
var numFirewallIpAddressesToAssign = 3
resource pipsAzureFirewall 'Microsoft.Network/publicIPAddresses@2021-05-01' = [for i in range(0, numFirewallIpAddressesToAssign): {
  name: 'pip-fw-${location}-${padLeft(i, 2, '0')}'
  location: location
  sku: {
    name: 'Standard'
  }
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
    publicIPAddressVersion: 'IPv4'
  }
}]

@description('The public IP for the regional hub\'s Azure Bastion service.')
resource pipAzureBastion 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: 'pip-ab-${location}'
  location: location
  sku: {
    name: 'Standard'
  }
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
    publicIPAddressVersion: 'IPv4'
  }
}

@description('This regional hub\'s Azure Bastion service.')
resource azureBastion 'Microsoft.Network/bastionHosts@2021-05-01' = {
  name: 'ab-${location}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'hub-subnet'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnetHub::azureBastionSubnet.id
          }
          publicIPAddress: {
            id: pipAzureBastion.id
          }
        }
      }
    ]
  }
}

resource azureBastion_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: azureBastion
  properties: {
    workspaceId: laHub.id
    logs: [
      {
        category: 'BastionAuditLogs'
        enabled: true
      }
    ]
  }
}

@description('This holds IP addresses of known AKS Jumpbox image building subnets in attached spokes.')
resource imageBuilder_ipgroups 'Microsoft.Network/ipGroups@2021-05-01' = {
  name: 'ipg-${location}-AksJumpboxImageBuilders'
  location: location
  properties: {
    ipAddresses: [
      aksImageBuilderSubnet.properties.addressPrefix
    ]
  }
}

// Azure Firewall starter policy
resource fwPolicy 'Microsoft.Network/firewallPolicies@2023-11-01' existing = {
  name: 'fw-policies-${location}'

  resource imageBuilderNetworkRuleCollectionGroup 'ruleCollectionGroups' = {
    name: 'ImageBuilderNetworkRuleCollectionGroup'
    properties: {
      priority: 100
      ruleCollections: [
        {
          ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
          name: 'ntp'
          priority: 300
          action: {
            type: 'Allow'
          }
          rules: [
            {
              ruleType: 'NetworkRule'
              description: 'Network Time Protocol (NTP) time synchronization for image builder VMs.'
              ipProtocols: [
                'UDP'
              ]
              sourceAddresses: []
              sourceIpGroups: [
                resourceId('Microsoft.Network/ipGroups', imageBuilder_ipgroups.name)
              ]
              destinationAddresses: []
              destinationIpGroups: []
              destinationFqdns: [
                'ntp.ubuntu.com'
              ]
              destinationPorts: [
                '123'
              ]
            }
          ]
        }
      ]
    }
  }

    // Network hub starts out with no allowances for appliction rules
  resource imageBuilderApplicationRuleCollectionGroup 'ruleCollectionGroups' = {
    name: 'ImageBuilderApplicationRuleCollectionGroup'
    dependsOn: [
      imageBuilderNetworkRuleCollectionGroup
    ]
    properties: {
      priority: 500
      ruleCollections: [
        {
          ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
          name: 'AKSImageBuilder-Requirements'
          priority: 400
          action: {
            type: 'Allow'
          }
          rules: [
            {
              ruleType: 'ApplicationRule'
              name: 'to-azuremanagement'
              description: 'This for AIB VMs to communicate with Azure management API.'
              sourceIpGroups: [
                resourceId('Microsoft.Network/ipGroups', imageBuilder_ipgroups.name)
              ]
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              targetFqdns: [
#disable-next-line no-hardcoded-env-urls
                'management.azure.com'
              ]
            }
            {
              ruleType: 'ApplicationRule'
              name: 'to-blobstorage'
              description: 'This is required as the Proxy VM and Packer VM both read and write from transient storage accounts (no ability to know what storage accounts before the process starts.)'
              sourceIpGroups: [
                resourceId('Microsoft.Network/ipGroups', imageBuilder_ipgroups.name)
              ]
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              targetFqdns: [
#disable-next-line no-hardcoded-env-urls
                    '*.blob.core.windows.net'
              ]
            }
            {
              ruleType: 'ApplicationRule'
              name: 'apt-get'
              description: 'This is required as the Packer VM performs a package upgrade. [Step performed in the referenced jump box building process. Not needed if your jump box building process doesn\'t do this.]'
              sourceIpGroups: [
                resourceId('Microsoft.Network/ipGroups', imageBuilder_ipgroups.name)
              ]
              protocols: [
                {
                  protocolType: 'Http'
                  port: 80
                }
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              targetFqdns: [
                'azure.archive.ubuntu.com'
                'packages.microsoft.com'
                'archive.ubuntu.com'
                'security.ubuntu.com'
              ]
            }
            {
              ruleType: 'ApplicationRule'
              name: 'install-azcli'
              description: 'This is required as the Packer VM needs to install Azure CLI. [Step performed in the referenced jump box building process. Not needed if your jump box building process doesn\'t do this.]'
              sourceIpGroups: [
                resourceId('Microsoft.Network/ipGroups', imageBuilder_ipgroups.name)
              ]
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              targetFqdns: [
                'aka.ms'
#disable-next-line no-hardcoded-env-urls
                'azurecliextensionsync.blob.core.windows.net'
#disable-next-line no-hardcoded-env-urls
                'azurecliprod.blob.core.windows.net'
              ]
            }
            {
              ruleType: 'ApplicationRule'
              name: 'install-k8scli'
              description: 'This is required as the Packer VM needs to install k8s cli tooling. [Step performed in the referenced jump box building process. Not needed if your jump box building process doesn\'t do this.]'
              sourceIpGroups: [
                resourceId('Microsoft.Network/ipGroups', imageBuilder_ipgroups.name)
              ]
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              targetFqdns: [
                'objects.githubusercontent.com'
                'storage.googleapis.com'
                'api.github.com'
                'github-releases.githubusercontent.com'
                'release-assets.githubusercontent.com'
                'github.com'
              ]
            }
            {
              ruleType: 'ApplicationRule'
              name: 'install-helm'
              description: 'This is required as the Packer VM needs to install helm cli. [Step performed in the referenced jump box building process. Not needed if your jump box building process doesn\'t do this.]'
              sourceIpGroups: [
                resourceId('Microsoft.Network/ipGroups', imageBuilder_ipgroups.name)
              ]
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              targetFqdns: [
                'raw.githubusercontent.com'
                'get.helm.sh'
                'release-assets.githubusercontent.com'
                'github-releases.githubusercontent.com'
              ]
            }
            {
              ruleType: 'ApplicationRule'
              name: 'install-flux'
              description: 'This is required as the Packer VMs needs to install flux cli. [Step performed in the referenced jump box building process. Not needed if your jump box building process doesn\'t do this.]'
              sourceIpGroups: [
                resourceId('Microsoft.Network/ipGroups', imageBuilder_ipgroups.name)
              ]
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              targetFqdns: [
                'raw.githubusercontent.com'
                'api.github.com'
                'fluxcd.io'
                'release-assets.githubusercontent.com'
                'github-releases.githubusercontent.com'
              ]
            }
            {
              ruleType: 'ApplicationRule'
              name: 'install-terraform'
              description: 'This is required as the Packer VMs needs to install HashiCorp Terraform cli. [Step performed in the referenced jump box building process. Not needed if your jump box building process doesn\'t do this.]'
              sourceIpGroups: [
                resourceId('Microsoft.Network/ipGroups', imageBuilder_ipgroups.name)
              ]
              protocols: [
                {
                  protocolType: 'Https'
                  port: 443
                }
              ]
              targetFqdns: [
                'releases.hashicorp.com'
              ]
            }
          ]
        }
      ]
    }
  }
}
/*** OUTPUTS ***/

output hubVnetId string = vnetHub.id

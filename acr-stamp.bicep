targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('The regional network spoke VNet Resource ID that the cluster will be joined to.')
@minLength(79)
param targetVnetResourceId string

@allowed([
  'australiaeast'
  'canadacentral'
  'centralus'
  'eastus'
  'eastus2'
  'westus2'
  'francecentral'
  'germanywestcentral'
  'northeurope'
  'southafricanorth'
  'southcentralus'
  'uksouth'
  'westeurope'
  'japaneast'
  'southeastasia'
])
@description('AKS Service, Node Pool, and supporting services (KeyVault, App Gateway, etc) region. This needs to be the same region as the vnet provided in these parameters.')
param location string = 'eastus2'

@allowed([
  'australiasoutheast'
  'canadaeast'
  'eastus2'
  'westus'
  'centralus'
  'westcentralus'
  'francesouth'
  'germanynorth'
  'westeurope'
  'ukwest'
  'northeurope'
  'japanwest'
  'southafricawest'
  'northcentralus'
  'eastasia'
  'eastus'
  'westus2'
  'francecentral'
  'uksouth'
  'japaneast'
  'southeastasia'
])
@description('For Azure resources that support native geo-redunancy, provide the location the redundant service will have its secondary. Should be different than the location parameter and ideally should be a paired region - https://docs.microsoft.com/azure/best-practices-availability-paired-regions. This region does not need to support availability zones.')
param geoRedundancyLocation string = 'centralus'

/*** VARIABLES ***/

var subRgUniqueString = uniqueString('aks', subscription().subscriptionId, resourceGroup().id)

/*** EXISTING RESOURCES ***/

resource spokeResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  scope: subscription()
  name: '${split(targetVnetResourceId,'/')[4]}'
}

resource spokeVirtualNetwork 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  scope: spokeResourceGroup
  name: '${last(split(targetVnetResourceId,'/'))}'
  
  resource snetPrivateLinkEndpoints 'subnets@2021-05-01' existing = {
    name: 'snet-privatelinkendpoints'
  }
}

// Built-in policy: Container registries should have anonymous authentication disabled.
var pdAnonymousContainerRegistryAccessDisallowedId = tenantResourceId('Microsoft.Authorization/policyDefinitions', '9f2dea28-e834-476c-99c5-3507b4728395')

// Built-in policy: Container registries should have repository scoped access token disabled.
var pdAccessTokenContainerRegistryAccessDisallowedId = tenantResourceId('Microsoft.Authorization/policyDefinitions', 'ff05e24e-195c-447e-b322-5e90c9f9f366')

// Built-in policy: Container registries should have local admin account disabled.
var pdAdminAccountContainerRegistryAccessDisallowedId = tenantResourceId('Microsoft.Authorization/policyDefinitions', 'dc921057-6b28-4fbe-9b83-f7bec05db6c2')


/*** RESOURCES ***/

// This Log Analytics workspace will be the log sink for all resources in the cluster resource group. This includes ACR, the AKS cluster, Key Vault, etc. It also is the Container Insights log sink for the AKS cluster.
resource laAks 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: 'la-aks-${subRgUniqueString}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Ensure the container registry does not allow anon access (Azure RBAC only is allowed)
resource paAnonymousContainerRegistryAccessDisallowed 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: guid(resourceGroup().id, pdAnonymousContainerRegistryAccessDisallowedId)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[acraks${subRgUniqueString}] ${reference(pdAnonymousContainerRegistryAccessDisallowedId, '2021-06-01').displayName}', 120)
    description: reference(pdAnonymousContainerRegistryAccessDisallowedId, '2021-06-01').description
    enforcementMode: 'Default'
    policyDefinitionId: pdAnonymousContainerRegistryAccessDisallowedId
    parameters: {
      effect: {
        value: 'Deny'
      }
    }
  }
}

// Ensure the container registry does not allow sas token access (Azure RBAC only is allowed)
resource paAccessTokenContainerRegistryAccessDisallowed 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: guid(resourceGroup().id, pdAccessTokenContainerRegistryAccessDisallowedId)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[acraks${subRgUniqueString}] ${reference(pdAccessTokenContainerRegistryAccessDisallowedId, '2021-06-01').displayName}', 120)
    description: reference(pdAccessTokenContainerRegistryAccessDisallowedId, '2021-06-01').description
    enforcementMode: 'Default'
    policyDefinitionId: pdAccessTokenContainerRegistryAccessDisallowedId
    parameters: {
      effect: {
        value: 'Deny'
      }
    }
  }
}

// Ensure the container registry does not allow admin account access (Azure RBAC only is allowed)
resource paAdminAccountContainerRegistryAccessDisallowed 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: guid(resourceGroup().id, pdAdminAccountContainerRegistryAccessDisallowedId)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[acraks${subRgUniqueString}] ${reference(pdAdminAccountContainerRegistryAccessDisallowedId, '2021-06-01').displayName}', 120)
    description: reference(pdAdminAccountContainerRegistryAccessDisallowedId, '2021-06-01').description
    enforcementMode: 'Default'
    policyDefinitionId: pdAdminAccountContainerRegistryAccessDisallowedId
    parameters: {
      effect: {
        value: 'Deny'
      }
    }
  }
}

// Azure Container Registry will be exposed via Private Link, set up the related Private DNS zone and virtual network link to the spoke.
resource dnsPrivateZoneAcr 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.azurecr.io'
  location: 'global'
  properties: {}

  resource dnsVnetLinkAcrToSpoke 'virtualNetworkLinks@2020-06-01' = {
    name: 'to_${spokeVirtualNetwork.name}'
    location: 'global'
    properties: {
      virtualNetwork: {
        id: targetVnetResourceId
      }
      registrationEnabled: false
    }
  }
}

// The Container Registry that the AKS cluster will be authorized to use to pull images.
resource acrAks 'Microsoft.ContainerRegistry/registries@2021-09-01' = {
  name: 'acraks${subRgUniqueString}'
  location: location
  dependsOn: [
    paAccessTokenContainerRegistryAccessDisallowed  // These policy assignments are not true dependencies, but we want them in place before we deploy our ACR instance.
    paAdminAccountContainerRegistryAccessDisallowed
    paAnonymousContainerRegistryAccessDisallowed
  ]
  sku: {
    name: 'Premium'
  }
  properties: {
    adminUserEnabled: false
    networkRuleSet: {
      defaultAction: 'Deny'
      ipRules: []
    }
    policies: {
      quarantinePolicy: {
        status: 'disabled'
      }
      trustPolicy: {
        type: 'Notary'
        status: 'disabled'
      }
      retentionPolicy: {
        days: 15
        status: 'enabled'
      }
    }
    publicNetworkAccess: 'Disabled'
    encryption: {
      status: 'disabled'
    }
    dataEndpointEnabled: true
    networkRuleBypassOptions: 'AzureServices'
    zoneRedundancy: 'Disabled' // This Preview feature only supports three regions at this time, and eastus2's paired region (centralus), does not support this. So disabling for now.
  }

  resource acrReplication 'replications@2021-09-01' = {
    name: geoRedundancyLocation
    location: geoRedundancyLocation
    properties: {}
  }
}

resource acrAks_diagnosticsSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: acrAks
  properties: {
    workspaceId: laAks.id
    metrics: [
      {
        timeGrain: 'PT1M'
        category: 'AllMetrics'
        enabled: true
      }
    ]
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

// Expose Azure Container Registry via Private Link, into the cluster nodes subnet.
resource privateEndpointAcrToVnet 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: 'pe-${acrAks.name}'
  location: location
  dependsOn: [
    acrAks::acrReplication
  ]
  properties: {
    subnet: {
      id: spokeVirtualNetwork::snetPrivateLinkEndpoints.id
    }
    privateLinkServiceConnections: [
      {
        name: 'to_${spokeVirtualNetwork.name}'
        properties: {
          privateLinkServiceId: acrAks.id
          groupIds: [
            'registry'
          ]
        }
      }
    ]
  }

  resource privateDnsZoneGroupAcr 'privateDnsZoneGroups@2021-05-01' = {
    name: 'default'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'privatelink-azurecr-io'
          properties: {
            privateDnsZoneId: dnsPrivateZoneAcr.id
          }
        }
      ]
    }
  }
}

/*** OUTPUTS ***/

output containerRegistryName string = acrAks.name

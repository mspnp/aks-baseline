targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('The regional network spoke VNet Resource ID that the cluster will be joined to.')
@minLength(79)
param targetVnetResourceId string

@description('AKS Service, Node Pool, and supporting services (KeyVault, App Gateway, etc) region. This needs to be the same region as the virtual network provided in these parameters.')
param location string = resourceGroup().location

@description('For Azure resources that support native geo-redunancy, provide the location the redundant service will have its secondary. Should be different than the location parameter and ideally should be a paired region - https://learn.microsoft.com/azure/reliability/cross-region-replication-azure#azure-paired-regions. This region does not need to support availability zones.')
param geoRedundancyLocation string = 'centralus'

/*** VARIABLES ***/

var subRgUniqueString = uniqueString('aks', subscription().subscriptionId, resourceGroup().id)

/*** EXISTING RESOURCES ***/

resource spokeResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  scope: subscription()
  name: split(targetVnetResourceId,'/')[4]
}

resource spokeVirtualNetwork 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  scope: spokeResourceGroup
  name: last(split(targetVnetResourceId,'/'))
  
  resource snetPrivateLinkEndpoints 'subnets' existing = {
    name: 'snet-privatelinkendpoints'
  }
}

/*** RESOURCES ***/

// This Log Analytics workspace will be the log sink for all resources in the cluster resource group.
// This includes ACR, the AKS cluster, Key Vault, etc.
// It also is the Container Insights log sink for the AKS cluster.
resource laAks 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'la-aks-${subRgUniqueString}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    workspaceCapping: {
      dailyQuotaGb: -1 // No daily cap (configure alert below if enabled)
    }
  }
}

// Add a alert rule if the log analytics workspace daily data cap has been reached.
// Logging costs can be a significant part of any architecture, and putting a cap on
// a logging sink (none of which are applied here), can help keep costs in check but
// you run a risk of losing critical data.
resource sqrDailyDataCapBreach 'Microsoft.Insights/scheduledQueryRules@2022-06-15' = {
  name: 'Daily data cap breached for workspace ${laAks.name} CIQ-1'
  location: location
  properties: {
    description: 'This alert monitors daily data cap defined on a workspace and fires when the daily data cap is breached.'
    displayName: 'Daily data cap breached for workspace ${laAks.name} CIQ-1'
    severity: 1
    enabled: true
    scopes: [
      laAks.id
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    criteria: {
      allOf: [
        {
          query: '_LogOperation | where Operation == "Data collection Status" | where Detail contains "OverQuota"'
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
        }
      ]
    }
    actions: {
      actionGroups: [
      ]
    }
  }
}

// Apply the built-in 'Container registries should have anonymous authentication disabled' policy. Azure RBAC only is allowed.
resource pdAnonymousContainerRegistryAccessDisallowed 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: '9f2dea28-e834-476c-99c5-3507b4728395'
  scope: tenant()
}

resource paAnonymousContainerRegistryAccessDisallowed 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: guid(resourceGroup().id, pdAnonymousContainerRegistryAccessDisallowed.id)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[acraks${subRgUniqueString}] ${pdAnonymousContainerRegistryAccessDisallowed.properties.displayName}', 120)
    description: pdAnonymousContainerRegistryAccessDisallowed.properties.description
    enforcementMode: 'Default'
    policyDefinitionId: pdAnonymousContainerRegistryAccessDisallowed.id
    parameters: {
      effect: {
        value: 'Deny'
      }
    }
  }
}

// Apply the built-in 'Container registries should have local admin account disabled' policy. Azure RBAC only is allowed.
resource pdAdminAccountContainerRegistryAccessDisallowed 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: 'dc921057-6b28-4fbe-9b83-f7bec05db6c2'
  scope: tenant()
}

resource paAdminAccountContainerRegistryAccessDisallowed 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: guid(resourceGroup().id, pdAdminAccountContainerRegistryAccessDisallowed.id)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[acraks${subRgUniqueString}] ${pdAdminAccountContainerRegistryAccessDisallowed.properties.displayName}', 120)
    description: pdAdminAccountContainerRegistryAccessDisallowed.properties.description
    enforcementMode: 'Default'
    policyDefinitionId: pdAdminAccountContainerRegistryAccessDisallowed.id
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

  resource dnsVnetLinkAcrToSpoke 'virtualNetworkLinks' = {
    name: 'to_${spokeVirtualNetwork.name}'
    location: 'global'
    properties: {
      virtualNetwork: {
        id: spokeVirtualNetwork.id
      }
      registrationEnabled: false
    }
  }
}

// The Container Registry that the AKS cluster will be authorized to use to pull images.
resource acrAks 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: 'acraks${subRgUniqueString}'
  location: location
  dependsOn: [
    // These policy assignments are not true dependencies, but we want them in place before we deploy our ACR instance.
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
    zoneRedundancy: 'Enabled'
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

// Expose Azure Container Registry via Private Link, into the cluster nodes virtual network.
resource privateEndpointAcrToVnet 'Microsoft.Network/privateEndpoints@2023-11-01' = {
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

  resource privateDnsZoneGroupAcr 'privateDnsZoneGroups' = {
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

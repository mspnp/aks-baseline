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
  'westus3'
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
@description('For Azure resources that support native geo-redunancy, provide the location the redundant service will have its secondary. Should be different than the location parameter and ideally should be a paired region - https://learn.microsoft.com/azure/best-practices-availability-paired-regions. This region does not need to support availability zones.')
param geoRedundancyLocation string = 'centralus'

/*** VARIABLES ***/

var subRgUniqueString = uniqueString('aks', subscription().subscriptionId, resourceGroup().id)

/*** EXISTING RESOURCES ***/

resource spokeResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  scope: subscription()
  name: split(targetVnetResourceId,'/')[4]
}

resource spokeVirtualNetwork 'Microsoft.Network/virtualNetworks@2022-09-01' existing = {
  scope: spokeResourceGroup
  name: last(split(targetVnetResourceId,'/'))
  
  resource snetPrivateLinkEndpoints 'subnets' existing = {
    name: 'snet-privatelinkendpoints'
  }
}

/*** RESOURCES ***/

// This Log Analytics workspace will be the log sink for all resources in the cluster resource group. This includes ACR, the AKS cluster, Key Vault, etc. It also is the Container Insights log sink for the AKS cluster.
resource laAks 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
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
resource sqrDailyDataCapBreach 'Microsoft.Insights/scheduledQueryRules@2018-04-16' = {
  name: 'Daily data cap breached for workspace ${laAks.name} CIQ-1'
  location: location
  properties: {
    description: 'This alert monitors daily data cap defined on a workspace and fires when the daily data cap is breached.'
    displayName: 'Daily data cap breached for workspace ${laAks.name} CIQ-1'
    enabled: 'true'
    source: {
      dataSourceId: laAks.id
      queryType: 'ResultCount'
      authorizedResources: []
      query: '_LogOperation | where Operation == "Data collection Status" | where Detail contains "OverQuota"'
    }
    schedule: {
      frequencyInMinutes: 5
      timeWindowInMinutes: 5
    }
    action: {
      'odata.type': 'Microsoft.WindowsAzure.Management.Monitoring.Alerts.Models.Microsoft.AppInsights.Nexus.DataContracts.Resources.ScheduledQueryRules.AlertingAction'
      severity: '1'
      aznsAction: {
        actionGroup: []
      }
      throttlingInMin: 1440
      trigger: {
        threshold: 0
        thresholdOperator: 'GreaterThan'
      }
    }
  }
}

// Apply the built-in 'Container registries should have anonymous authentication disabled' policy. Azure RBAC only is allowed.
var pdAnonymousContainerRegistryAccessDisallowedId = tenantResourceId('Microsoft.Authorization/policyDefinitions', '9f2dea28-e834-476c-99c5-3507b4728395')
resource paAnonymousContainerRegistryAccessDisallowed 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
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

// Apply the built-in 'Container registries should have local admin account disabled' policy. Azure RBAC only is allowed.
var pdAdminAccountContainerRegistryAccessDisallowedId = tenantResourceId('Microsoft.Authorization/policyDefinitions', 'dc921057-6b28-4fbe-9b83-f7bec05db6c2')
resource paAdminAccountContainerRegistryAccessDisallowed 'Microsoft.Authorization/policyAssignments@2022-06-01' = {
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
resource acrAks 'Microsoft.ContainerRegistry/registries@2021-09-01' = {
  name: 'acraks${subRgUniqueString}'
  location: location
  dependsOn: [
    paAdminAccountContainerRegistryAccessDisallowed // These policy assignments are not true dependencies, but we want them in place before we deploy our ACR instance.
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

// Expose Azure Container Registry via Private Link, into the cluster nodes virtual network.
resource privateEndpointAcrToVnet 'Microsoft.Network/privateEndpoints@2022-09-01' = {
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

// Supports configuring the AKS Backup extension.
resource bvAksBackupVault 'Microsoft.DataProtection/backupVaults@2023-01-01' = {
  name: 'bvAksBackupVault'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    storageSettings: [
      {
        datastoreType: 'VaultStore'
        type: 'ZoneRedundant'
      }
    ]
    securitySettings: {
      immutabilitySettings: {
        state: 'Disabled'
      }
      softDeleteSettings: {
        state: 'On'
        retentionDurationInDays: 14
      }
    }
    featureSettings: {}
  }

  // Daily UTC midnight Kubernetes backup policy as an example. Configure policy as needed.
  resource aksPolicy 'backupPolicies' = {
    name: 'bp-aks-default-daily'
    properties: {
      objectType: 'BackupPolicy'
      datasourceTypes: [
        'Microsoft.ContainerService/managedClusters'
      ]
      policyRules: [
        {
          objectType: 'AzureBackupRule'
          name: 'BackupDaily'
          backupParameters: {
            objectType: 'AzureBackupParams'
            backupType: 'Incremental'
          }
          dataStore: {
            objectType: 'DataStoreInfoBase'
            dataStoreType: 'OperationalStore'
          }
          trigger: {
            objectType: 'ScheduleBasedTriggerContext'
            schedule: {
              timeZone: 'UTC'
              repeatingTimeIntervals: [
                'R/2023-01-01T00:00:00+00:00/P1D'
              ]
            }
            taggingCriteria: [
              {
                tagInfo: {
                  tagName: 'Default'
                }
                taggingPriority: 99
                isDefault: true
              }
            ]
          }
        }
        {
          objectType: 'AzureRetentionRule'
          name: 'Default'
          isDefault: true
          lifecycles: [
            {
              deleteAfter: {
                objectType: 'AbsoluteDeleteOption'
                duration: 'P7D'
              }
              targetDataStoreCopySettings: []
              sourceDataStore: {
                dataStoreType: 'OperationalStore'
                objectType: 'DataStoreInfoBase'
              }
            }
          ]
        }
      ]
    }
  }
}

// This stores AKS Backup content, to be used by all clusters
resource storageAksBackups 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: 'stbackup${subRgUniqueString}'
  location: location
  sku: {
    name: 'Standard_GRS'
  }
  kind: 'StorageV2'
  properties: {
    allowSharedKeyAccess: false
    defaultToOAuthAuthentication: true
    publicNetworkAccess: 'Disabled'
    allowCrossTenantReplication: false
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    isHnsEnabled: false
    isLocalUserEnabled: false
    isSftpEnabled: false
    routingPreference: {
      publishInternetEndpoints: true
      publishMicrosoftEndpoints: true
      routingChoice: 'MicrosoftRouting'
    }
    networkAcls: {
      bypass: 'None'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Deny'
    }
    encryption: {
      keySource: 'Microsoft.Storage'
      services: {
        file: {
          keyType: 'Account'
          enabled: true
        }
        blob: {
          keyType: 'Account'
          enabled: true
        }
      }
    }
    supportsHttpsTrafficOnly: true
    accessTier: 'Hot' 
  }

  resource blobservice 'blobServices' = {
    name: 'default'
  }
}

// Private DNS Zone for our AKS Backup storage account
resource dnsPrivateZoneBlob 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.blob.core.windows.net'
  location: 'global'
  properties: {}


  // Enabling Storage Account Private Link on cluster virtual network.
  resource vnetlnk 'virtualNetworkLinks' = {
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

resource storageAksBackups_diagnosticsSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: storageAksBackups::blobservice
  properties: {
    workspaceId: laAks.id
    logs: [
      {
        category: 'StorageRead'
        enabled: true
      }
      {
        category: 'StorageWrite'
        enabled: true
      }
      {
        category: 'StorageDelete'
        enabled: true
      }
    ]
  }
}

resource peAksBackupStorage 'Microsoft.Network/privateEndpoints@2022-07-01' = {
  name: 'pe-${storageAksBackups.name}'
  location: location
  properties: {
    subnet: {
      id: spokeVirtualNetwork::snetPrivateLinkEndpoints.id
    }
    privateLinkServiceConnections: [
      {
        name: 'to_${spokeVirtualNetwork.name}'
        properties: {
          privateLinkServiceId: storageAksBackups.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }

  resource pdnszg 'privateDnsZoneGroups' = {
    name: 'default'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'privatelink-blob-core-windows-net'
          properties: {
            privateDnsZoneId: dnsPrivateZoneBlob.id
          }
        }
      ]
    }
  }
}

/*** OUTPUTS ***/

output containerRegistryName string = acrAks.name

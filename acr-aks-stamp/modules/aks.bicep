param aksClusterName string
param location string
param aksControlPlaneIdentityName string
param aksNodeResourceGroup string
param aksIngressDomainName string
param aksIngressIdentityName string
param aksIngressLoadBalancerIp string
param aksAuthorizedIPRanges string
param appSubDomainName string
param acrName string
param vnetId string
param aksSubnetId string
param logAnalyticsWorkspaceName string
param useAzureRBAC bool
param clusterAdminAadGroupObjectId string
param clusterUserAadGroupObjectId string
param businessUnitTag string
param applicationIdentifierTag string
param fluxSettings object

var monitoringMetricsPublisherRole = '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/3913510d-42f4-4e42-8a64-420c390055eb'
var acrPullRole = '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/7f951dda-4ed3-4680-a7ca-43fe172d538d'
var containerInsightsSolutionName = 'ContainerInsights(${logAnalyticsWorkspaceName})'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-10-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource acr 'Microsoft.ContainerRegistry/registries@2020-11-01-preview' existing = {
  name: acrName
}

resource aksAcrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid('${aks.id}-${acrName}-${acrPullRole}')
  scope: acr
  properties: {
    principalId: reference(resourceId('Microsoft.ContainerService/managedClusters', aksClusterName), '2020-12-01').identityProfile.kubeletidentity.objectId
    roleDefinitionId: acrPullRole
    principalType: 'ServicePrincipal'
  }
}

resource aks 'Microsoft.ContainerService/managedClusters@2021-08-01' = {
  name: aksClusterName
  location: location
  tags: {
    'Business unit': businessUnitTag
    'Application identifier': applicationIdentifierTag
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
         '${resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', aksControlPlaneIdentityName)}': {
      }
    }
  }
  sku: {
    name: 'Basic'
    tier: 'Paid'
  }
  properties: {
    nodeResourceGroup: aksNodeResourceGroup
    enableRBAC: true
    enablePodSecurityPolicy: false
    publicNetworkAccess: 'Enabled'
    kubernetesVersion: '1.22.4'
    dnsPrefix: '${aksClusterName}-dns'
    agentPoolProfiles: [
      {
        name: 'npsystem'
        count: 3
        vmSize: 'Standard_DS2_v2'
        osDiskSizeGB: 80
        osDiskType: 'Ephemeral'
        osType: 'Linux'
        minCount: 3
        maxCount: 4
        vnetSubnetID: aksSubnetId
        enableAutoScaling: true
        type: 'VirtualMachineScaleSets'
        mode: 'System'
        scaleSetPriority: 'Regular'
        scaleSetEvictionPolicy: 'Delete'
        orchestratorVersion: '1.22.4'
        enableNodePublicIP: false
        maxPods: 30
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
        upgradeSettings: {
          maxSurge: '33%'
        }
        nodeTaints: [
          'CriticalAddonsOnly=true:NoSchedule'
        ]
      }
      {
        name: 'npuser01'
        count: 3
        vmSize: 'Standard_DS3_v2'
        osDiskSizeGB: 120
        osDiskType: 'Ephemeral'
        osType: 'Linux'
        minCount: 2
        maxCount: 5
        vnetSubnetID: aksSubnetId
        enableAutoScaling: true
        type: 'VirtualMachineScaleSets'
        mode: 'User'
        scaleSetPriority: 'Regular'
        scaleSetEvictionPolicy: 'Delete'
        orchestratorVersion: '1.22.4'
        enableNodePublicIP: false
        maxPods: 30
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
        upgradeSettings: {
          maxSurge: '33%'
        }
      }
    ]
    servicePrincipalProfile: {
      clientId: 'msi'
    }
    addonProfiles: {
      httpApplicationRouting: {
        enabled: false
      }
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceId: logAnalyticsWorkspace.id
        }
      }
      aciConnectorLinux: {
        enabled: false
      }
      azurepolicy: {
        enabled: true
        config: {
          version: 'v2'
        }
      }
      azureKeyvaultSecretsProvider: {
        enabled: true
        config: {
          enableSecretRotation: 'false'
        }
      }
    }
    networkProfile: {
      networkPolicy: 'azure'
      networkPlugin: 'azure'
      loadBalancerSku: 'standard'
      outboundType: 'loadBalancer'
      //outboundType: 'userDefinedRouting'
      //loadBalancerProfile: json('null')
      serviceCidr: '172.16.0.0/16'
      dnsServiceIP: '172.16.0.10'
      dockerBridgeCidr: '172.18.0.1/16'
    }
    aadProfile: {
      managed: true
      enableAzureRBAC: useAzureRBAC
      adminGroupObjectIDs: !useAzureRBAC ? array(clusterAdminAadGroupObjectId) : []
      tenantID: tenant().tenantId
    }
    autoScalerProfile: {
      'balance-similar-node-groups': 'false'
      expander: 'random'
      'max-empty-bulk-delete': '10'
      'max-graceful-termination-sec': '600'
      'max-node-provision-time': '15m'
      'max-total-unready-percentage': '45'
      'new-pod-scale-up-delay': '0s'
      'ok-total-unready-count': '3'
      'scale-down-delay-after-add': '10m'
      'scale-down-delay-after-delete': '20s'
      'scale-down-delay-after-failure': '3m'
      'scale-down-unneeded-time': '10m'
      'scale-down-unready-time': '20m'
      'scale-down-utilization-threshold': '0.5'
      'scan-interval': '10s'
      'skip-nodes-with-local-storage': 'true'
      'skip-nodes-with-system-pods': 'true'
    }
    apiServerAccessProfile: {
      authorizedIPRanges: [
        aksAuthorizedIPRanges
      ]
      enablePrivateCluster: false
    }
    podIdentityProfile: {
      enabled: false
      userAssignedIdentities: []
      userAssignedIdentityExceptions: []
    }
    disableLocalAccounts: true
    securityProfile: {
      azureDefender: {
        enabled: true
        logAnalyticsWorkspaceResourceId: logAnalyticsWorkspace.id
      }
    }
    oidcIssuerProfile: {
      enabled: true
    }
  }
  dependsOn: [
    aksPolicies
  ]
}

module aksNodes 'aksNodes.bicep' = {
  name: 'aksNodeSettings'
  params: {
    aksClusterKubeletIdentityPrincipalId: reference(resourceId('Microsoft.ContainerService/managedClusters', aksClusterName), '2020-03-01').identityProfile.kubeletidentity.objectId
  }
  scope: resourceGroup(aksNodeResourceGroup)
}

resource aksDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'Microsoft.Insights'
  scope: aks
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'cluster-autoscaler'
        enabled: true
      }
      {
        category: 'kube-controller-manager'
        enabled: true
      }
      {
        category: 'kube-audit-admin'
        enabled: true
      }
      {
        category: 'guard'
        enabled: true
      }
    ]
  }
}

module aksRBAC 'aksRBAC.bicep' = if (useAzureRBAC) {
  name: 'aksRBAC'
  params: {
    aksClusterName: aksClusterName
    clusterAdminAadGroupObjectId: clusterAdminAadGroupObjectId
    clusterUserAadGroupObjectId: clusterUserAadGroupObjectId
    aksIngressIdentityName: aksIngressIdentityName
    userNamespaceName: applicationIdentifierTag
  }
  dependsOn: [
    aks
  ]
}

resource aksIngressDnsZone 'Microsoft.Network/privateDnsZones@2018-09-01' = {
  name: aksIngressDomainName
  location: 'global'
  properties: {}
}

resource aksIngressDnsZoneRecord 'Microsoft.Network/privateDnsZones/A@2018-09-01' = {
  parent: aksIngressDnsZone
  name: appSubDomainName
  properties: {
    ttl: 3600
    aRecords: [
      {
        ipv4Address: aksIngressLoadBalancerIp
      }
    ]
  }
}

resource aksIngressDomainVNetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: aksIngressDnsZone
  name: 'to_aksvnet'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnetId
    }
    registrationEnabled: false
  }
}

module aksPolicies 'aksPolicies.bicep' = {
  name: 'aksPolicies'
  params: {
    acrName: acrName
    aksClusterName: aksClusterName
  }
}

resource flux 'Microsoft.KubernetesConfiguration/extensions@2021-09-01' = {
  scope: aks
  name: 'flux'
  properties: {
    extensionType: 'microsoft.flux'
    autoUpgradeMinorVersion: true
    releaseTrain: 'Stable'
    scope: {
      cluster: {
        releaseNamespace: 'flux-system'
      }
    }
    configurationSettings: {
      'helm-controller.enabled': 'false'
      'source-controller.enabled': 'true'
      'kustomize-controller.enabled': 'true'
      'notification-controller.enabled': 'false'
      'image-automation-controller.enabled': 'false'
      'image-reflector-controller.enabled': 'false'
    }
    configurationProtectedSettings: {}
  }
  dependsOn: [
    aksAcrPullRoleAssignment
  ]
}
resource fluxConfig 'Microsoft.KubernetesConfiguration/fluxConfigurations@2022-01-01-preview' = {
  scope: aks
  name: 'bootstrap'
  properties: {
    scope: 'cluster'
    namespace: 'flux-system'
    sourceKind: 'GitRepository'
    gitRepository: {
      url: fluxSettings.RepositoryUrl
      timeoutInSeconds: 180
      syncIntervalInSeconds: 300
      repositoryRef: {
        branch: fluxSettings.RepositoryBranch
        tag: null
        semver: null
        commit: null
      }
      sshKnownHosts: ''
      httpsUser: null
      httpsCACert: null
      localAuthRef: null
    }
    kustomizations: {
      unified: {
        path: fluxSettings.RepositorySubfolder
        timeoutInSeconds: 300
        syncIntervalInSeconds: 300
        retryIntervalInSeconds: null
        prune: true
        force: false
      }
    }
  }
  dependsOn: [
    flux
    aksAcrPullRoleAssignment
  ]
}

resource aksMetricsPublisherRole 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid('${aks.id}-omsagent-${monitoringMetricsPublisherRole}')
  scope: aks
  properties: {
    principalId: reference(aks.id, '2020-12-01').addonProfiles.omsagent.identity.objectId
    roleDefinitionId: monitoringMetricsPublisherRole
    principalType: 'ServicePrincipal'
  }
}

resource aksContainerInsightsSolution 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: containerInsightsSolutionName
  location: location
  properties: {
    workspaceResourceId: resourceId('Microsoft.OperationalInsights/workspaces', logAnalyticsWorkspaceName)
  }
  plan: {
    name: containerInsightsSolutionName
    product: 'OMSGallery/ContainerInsights'
    promotionCode: ''
    publisher: 'Microsoft'
  }
}

resource PodFailedScheduledQuery 'Microsoft.Insights/scheduledQueryRules@2018-04-16' = {
  name: 'PodFailedScheduledQuery'
  location: location
  properties: {
    description: 'Alert on pod Failed phase.'
    enabled: 'true'
    source: {
      query: '//https://docs.microsoft.com/azure/azure-monitor/insights/container-insights-alerts \r\n let endDateTime = now(); let startDateTime = ago(1h); let trendBinSize = 1m; let clusterName = "${aksClusterName}"; KubePodInventory | where TimeGenerated < endDateTime | where TimeGenerated >= startDateTime | where ClusterName == clusterName | distinct ClusterName, TimeGenerated | summarize ClusterSnapshotCount = count() by bin(TimeGenerated, trendBinSize), ClusterName | join hint.strategy=broadcast ( KubePodInventory | where TimeGenerated < endDateTime | where TimeGenerated >= startDateTime | distinct ClusterName, Computer, PodUid, TimeGenerated, PodStatus | summarize TotalCount = count(), PendingCount = sumif(1, PodStatus =~ "Pending"), RunningCount = sumif(1, PodStatus =~ "Running"), SucceededCount = sumif(1, PodStatus =~ "Succeeded"), FailedCount = sumif(1, PodStatus =~ "Failed") by ClusterName, bin(TimeGenerated, trendBinSize) ) on ClusterName, TimeGenerated | extend UnknownCount = TotalCount - PendingCount - RunningCount - SucceededCount - FailedCount | project TimeGenerated, TotalCount = todouble(TotalCount) / ClusterSnapshotCount, PendingCount = todouble(PendingCount) / ClusterSnapshotCount, RunningCount = todouble(RunningCount) / ClusterSnapshotCount, SucceededCount = todouble(SucceededCount) / ClusterSnapshotCount, FailedCount = todouble(FailedCount) / ClusterSnapshotCount, UnknownCount = todouble(UnknownCount) / ClusterSnapshotCount| summarize AggregatedValue = avg(FailedCount) by bin(TimeGenerated, trendBinSize)'
      dataSourceId: resourceId('Microsoft.OperationalInsights/workspaces', logAnalyticsWorkspaceName)
      queryType: 'ResultCount'
    }
    schedule: {
      frequencyInMinutes: 5
      timeWindowInMinutes: 10
    }
    action: {
      'odata.type': 'Microsoft.WindowsAzure.Management.Monitoring.Alerts.Models.Microsoft.AppInsights.Nexus.DataContracts.Resources.ScheduledQueryRules.AlertingAction'
      severity: '3'
      trigger: {
        thresholdOperator: 'GreaterThan'
        threshold: 3
        metricTrigger: {
          thresholdOperator: 'GreaterThan'
          threshold: 2
          metricTriggerType: 'Consecutive'
        }
      }
    }
  }
  dependsOn: [
    aksContainerInsightsSolution
  ]
}

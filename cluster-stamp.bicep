@description('The regional network spoke VNet Resource ID that the cluster will be joined to')
@minLength(79)
param targetVnetResourceId string

@description('Azure AD Group in the identified tenant that will be granted the highly privileged cluster-admin role. If Azure RBAC is used, then this group will get a role assignment to Azure RBAC, else it will be assigned directly to the cluster\'s admin group.')
param clusterAdminAadGroupObjectId string

@description('Azure AD Group in the identified tenant that will be granted the read only privileges in the a0008 namespace that exists in the cluster. This is only used when Azure RBAC is used for Kubernetes RBAC.')
param a0008NamespaceReaderAadGroupObjectId string

@description('Your AKS control plane Cluster API authentication tenant')
param k8sControlPlaneAuthorizationTenantId string

@description('The certificate data for app gateway TLS termination. It is base64')
param appGatewayListenerCertificate string

@description('The Base64 encoded AKS Ingress Controller public certificate (as .crt or .cer) to be stored in Azure Key Vault as secret and referenced by Azure Application Gateway as a trusted root certificate.')
param aksIngressControllerCertificate string

@description('IP ranges authorized to contact the Kubernetes API server. Passing an empty array will result in no IP restrictions. If any are provided, remember to also provide the public IP of the egress Azure Firewall otherwise your nodes will not be able to talk to the API server (e.g. Flux).')
param clusterAuthorizedIPRanges array = []

@description('AKS Service, Node Pool, and supporting services (KeyVault, App Gateway, etc) region. This needs to be the same region as the vnet provided in these parameters.')
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
param location string = 'eastus2'
param kubernetesVersion string = '1.22.4'

@description('Domain name to use for App Gateway and AKS ingress.')
param domainName string = 'contoso.com'

@description('Your cluster will be bootstrapped from this git repo.')
@minLength(9)
param gitOpsBootstrappingRepoHttpsUrl string = 'https://github.com/mspnp/aks-baseline'

@description('You cluster will be bootstrapped from this branch in the identifed git repo.')
@minLength(1)
param gitOpsBootstrappingRepoBranch string = 'main'

var monitoringMetricsPublisherRole = '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/3913510d-42f4-4e42-8a64-420c390055eb'
var acrPullRole = '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/7f951dda-4ed3-4680-a7ca-43fe172d538d'
var managedIdentityOperatorRole = '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/f1a07417-d97a-45cb-824c-7a7467783830'
var keyVaultReader = '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/21090545-7ca7-4776-b22c-e363652d74d2'
var keyVaultSecretsUserRole = '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/4633458b-17de-408a-b874-0445c86b69e6'
var clusterAdminRoleId = 'b1ff04bb-8a4e-4dc4-8eb5-8693973ce19b'
var clusterReaderRoleId = '7f6c6a51-bcf8-42ba-9220-52d62157d7db'
var serviceClusterUserRoleId = '4abbcc35-e782-43d8-92c5-2d3f1bd2253f'
var subRgUniqueString = uniqueString('aks', subscription().subscriptionId, resourceGroup().id)

var clusterName = 'aks-${subRgUniqueString}'
var nodeResourceGroupName = 'rg-${clusterName}-nodepools'
var logAnalyticsWorkspaceName = 'la-${clusterName}'
var defaultAcrName = 'acraks${subRgUniqueString}'

var vNetResourceGroup = split(targetVnetResourceId, '/')[4]
var vnetName = split(targetVnetResourceId, '/')[8]
var vnetNodePoolSubnetResourceId = '${targetVnetResourceId}/subnets/snet-clusternodes'
var vnetPrivateLinkEndpointsSubnetResourceId = '${targetVnetResourceId}/subnets/snet-privatelinkendpoints'

var agwName = 'apw-${clusterName}'

var aksIngressDomainName = 'aks-ingress.${domainName}'
var aksBackendDomainName = 'bu0001a0008-00.${aksIngressDomainName}'
var policyResourceIdAKSLinuxRestrictive = '/providers/Microsoft.Authorization/policySetDefinitions/42b8ef37-b724-4e24-bbc8-7a7708edfe00'
var policyResourceIdEnforceHttpsIngress = '/providers/Microsoft.Authorization/policyDefinitions/1a5b4dca-0b6f-4cf5-907c-56316bc1bf3d'
var policyResourceIdEnforceInternalLoadBalancers = '/providers/Microsoft.Authorization/policyDefinitions/3fc4dc25-5baf-40d8-9b05-7fe74c1bc64e'
var policyResourceIdRoRootFilesystem = '/providers/Microsoft.Authorization/policyDefinitions/df49d893-a74c-421d-bc95-c663042e5b80'
var policyResourceIdEnforceResourceLimits = '/providers/Microsoft.Authorization/policyDefinitions/e345eecc-fa47-480f-9e88-67dcc122b164'
var policyResourceIdEnforceImageSource = '/providers/Microsoft.Authorization/policyDefinitions/febd0533-8e55-448f-b837-bd0e06f16469'
var policyResourceIdEnforceDefenderInCluster = '/providers/Microsoft.Authorization/policyDefinitions/a1840de2-8088-4ea8-b153-b4c723e9cb01'
var policyAssignmentNameAKSLinuxRestrictive = guid(policyResourceIdAKSLinuxRestrictive, resourceGroup().name, clusterName)
var policyAssignmentNameEnforceHttpsIngress = guid(policyResourceIdEnforceHttpsIngress, resourceGroup().name, clusterName)
var policyAssignmentNameEnforceInternalLoadBalancers = guid(policyResourceIdEnforceInternalLoadBalancers, resourceGroup().name, clusterName)
var policyAssignmentNameRoRootFilesystem = guid(policyResourceIdRoRootFilesystem, resourceGroup().name, clusterName)
var policyAssignmentNameEnforceResourceLimits = guid(policyResourceIdEnforceResourceLimits, resourceGroup().name, clusterName)
var policyAssignmentNameEnforceImageSource = guid(policyResourceIdEnforceImageSource, resourceGroup().name, clusterName)
var policyAssignmentNameEnforceDefenderInCluster = guid(policyResourceIdEnforceDefenderInCluster, resourceGroup().name, clusterName)
var isUsingAzureRBACasKubernetesRBAC = (subscription().tenantId == k8sControlPlaneAuthorizationTenantId)

resource alaRgRecommendations 'Microsoft.Insights/activityLogAlerts@2020-10-01' = {
  name: 'AllAzureAdvisorAlert'
  location: 'Global'
  properties: {
    scopes: [
      resourceGroup().id
    ]
    condition: {
      allOf: [
        {
          field: 'category'
          equals: 'Recommendation'
        }
        {
          field: 'operationName'
          equals: 'Microsoft.Advisor/recommendations/available/action'
        }
      ]
    }
    actions: {
      actionGroups: []
    }
    enabled: true
    description: 'All azure advisor alerts'
  }
  dependsOn: []
}

resource ssPrometheusAll 'Microsoft.OperationalInsights/workspaces/savedSearches@2020-08-01' = {
  name: '${logAnalyticsWorkspaceName}/AllPrometheus'
  properties: {
    etag: '*'
    category: 'Prometheus'
    displayName: 'All collected Prometheus information'
    query: 'InsightsMetrics | where Namespace == "prometheus"'
    version: 1
  }
  dependsOn: []
}

resource ssPrometheusKuredRequestedReeboot 'Microsoft.OperationalInsights/workspaces/savedSearches@2020-08-01' = {
  name: '${logAnalyticsWorkspaceName}/NodeRebootRequested'
  properties: {
    etag: '*'
    category: 'Prometheus'
    displayName: 'Nodes reboot required by kured'
    query: 'InsightsMetrics | where Namespace == "prometheus" and Name == "kured_reboot_required" | where Val > 0'
    version: 1
  }
}

resource sci 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'ContainerInsights(${logAnalyticsWorkspaceName})'
  location: location
  properties: {
    containedResources: []
    referencedResources: []
    workspaceResourceId: resourceId('Microsoft.OperationalInsights/workspaces', logAnalyticsWorkspaceName)
  }
  plan: {
    name: 'ContainerInsights(${logAnalyticsWorkspaceName})'
    product: 'OMSGallery/ContainerInsights'
    promotionCode: ''
    publisher: 'Microsoft'
  }
  dependsOn: []
}

resource maHighNodeCPUUtilization 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Node CPU utilization high for ${clusterName} CI-1'
  location: 'global'
  properties: {
    autoMitigate: true
    scopes: [
      mc.id
    ]
    actions: []
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'host'
              operator: 'Include'
              values: [
                '*'
              ]
            }
          ]
          metricName: 'cpuUsagePercentage'
          metricNamespace: 'Insights.Container/nodes'
          name: 'Metric1'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
          skipMetricValidation: true
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'Node CPU utilization across the cluster.'
    enabled: true
    evaluationFrequency: 'PT1M'
    severity: 3
    targetResourceType: 'microsoft.containerservice/managedclusters'
    windowSize: 'PT5M'
  }
  dependsOn: [
    sci
  ]
}

resource maHighNodeWorkingSetMemoryUtilization 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Node working set memory utilization high for ${clusterName} CI-2'
  location: 'global'
  properties: {
    autoMitigate: true
    actions: []
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'host'
              operator: 'Include'
              values: [
                '*'
              ]
            }
          ]
          metricName: 'memoryWorkingSetPercentage'
          metricNamespace: 'Insights.Container/nodes'
          name: 'Metric1'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
          skipMetricValidation: true
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'Node working set memory utilization across the cluster.'
    enabled: true
    evaluationFrequency: 'PT1M'
    scopes: [
      mc.id
    ]
    severity: 3
    targetResourceType: 'microsoft.containerservice/managedclusters'
    windowSize: 'PT5M'
  }
  dependsOn: [
    sci
  ]
}

resource maJobsCompletedMoreThan6HoursAgo 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Jobs completed more than 6 hours ago for ${clusterName} CI-11'
  location: 'global'
  properties: {
    autoMitigate: true
    actions: []
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'controllerName'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'kubernetes namespace'
              operator: 'Include'
              values: [
                '*'
              ]
            }
          ]
          metricName: 'completedJobsCount'
          metricNamespace: 'Insights.Container/pods'
          name: 'Metric1'
          operator: 'GreaterThan'
          threshold: 0
          timeAggregation: 'Average'
          skipMetricValidation: true
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'This alert monitors completed jobs (more than 6 hours ago).'
    enabled: true
    evaluationFrequency: 'PT1M'
    scopes: [
      mc.id
    ]
    severity: 3
    targetResourceType: 'microsoft.containerservice/managedclusters'
    windowSize: 'PT1M'
  }
  dependsOn: [
    sci
  ]
}

resource maHighContainerCPUUsage 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Container CPU usage high for ${clusterName} CI-9'
  location: 'global'
  properties: {
    autoMitigate: true
    actions: []
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'controllerName'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'kubernetes namespace'
              operator: 'Include'
              values: [
                '*'
              ]
            }
          ]
          metricName: 'cpuExceededPercentage'
          metricNamespace: 'Insights.Container/containers'
          name: 'Metric1'
          operator: 'GreaterThan'
          threshold: 90
          timeAggregation: 'Average'
          skipMetricValidation: true
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'This alert monitors container CPU utilization.'
    enabled: true
    evaluationFrequency: 'PT1M'
    scopes: [
      mc.id
    ]
    severity: 3
    targetResourceType: 'microsoft.containerservice/managedclusters'
    windowSize: 'PT5M'
  }
  dependsOn: [
    sci
  ]
}

resource maHighContainerWorkingSetMemoryUsage 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Container working set memory usage high for ${clusterName} CI-10'
  location: 'global'
  properties: {
    autoMitigate: true
    actions: []
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'controllerName'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'kubernetes namespace'
              operator: 'Include'
              values: [
                '*'
              ]
            }
          ]
          metricName: 'memoryWorkingSetExceededPercentage'
          metricNamespace: 'Insights.Container/containers'
          name: 'Metric1'
          operator: 'GreaterThan'
          threshold: 90
          timeAggregation: 'Average'
          skipMetricValidation: true
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'This alert monitors container working set memory utilization.'
    enabled: true
    evaluationFrequency: 'PT1M'
    scopes: [
      mc.id
    ]
    severity: 3
    targetResourceType: 'microsoft.containerservice/managedclusters'
    windowSize: 'PT5M'
  }
  dependsOn: [
    sci
  ]
}

resource maPodsInFailedState 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Pods in failed state for ${clusterName} CI-4'
  location: 'global'
  properties: {
    autoMitigate: true
    actions: []
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'phase'
              operator: 'Include'
              values: [
                'Failed'
              ]
            }
          ]
          metricName: 'podCount'
          metricNamespace: 'Insights.Container/pods'
          name: 'Metric1'
          operator: 'GreaterThan'
          threshold: 0
          timeAggregation: 'Average'
          skipMetricValidation: true
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'Pod status monitoring.'
    enabled: true
    evaluationFrequency: 'PT1M'
    scopes: [
      mc.id
    ]
    severity: 3
    targetResourceType: 'microsoft.containerservice/managedclusters'
    windowSize: 'PT5M'
  }
  dependsOn: [
    sci
  ]
}

resource maHighDiskUsage 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Disk usage high for ${clusterName} CI-5'
  location: 'global'
  properties: {
    autoMitigate: true
    actions: []
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'host'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'device'
              operator: 'Include'
              values: [
                '*'
              ]
            }
          ]
          metricName: 'DiskUsedPercentage'
          metricNamespace: 'Insights.Container/nodes'
          name: 'Metric1'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
          skipMetricValidation: true
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'This alert monitors disk usage for all nodes and storage devices.'
    enabled: true
    evaluationFrequency: 'PT1M'
    scopes: [
      mc.id
    ]
    severity: 3
    targetResourceType: 'microsoft.containerservice/managedclusters'
    windowSize: 'PT5M'
  }
  dependsOn: [
    sci
  ]
}

resource maNodesInNotReadyStatus 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Nodes in not ready status for ${clusterName} CI-3'
  location: 'global'
  properties: {
    autoMitigate: true
    actions: []
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'status'
              operator: 'Include'
              values: [
                'NotReady'
              ]
            }
          ]
          metricName: 'nodesCount'
          metricNamespace: 'Insights.Container/nodes'
          name: 'Metric1'
          operator: 'GreaterThan'
          threshold: 0
          timeAggregation: 'Average'
          skipMetricValidation: true
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'Node status monitoring.'
    enabled: true
    evaluationFrequency: 'PT1M'
    scopes: [
      mc.id
    ]
    severity: 3
    targetResourceType: 'microsoft.containerservice/managedclusters'
    windowSize: 'PT5M'
  }
  dependsOn: [
    sci
  ]
}

resource maContainersGettingKilledOOM 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Containers getting OOM killed for ${clusterName} CI-6'
  location: 'global'
  properties: {
    autoMitigate: true
    actions: []
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'kubernetes namespace'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'controllerName'
              operator: 'Include'
              values: [
                '*'
              ]
            }
          ]
          metricName: 'oomKilledContainerCount'
          metricNamespace: 'Insights.Container/pods'
          name: 'Metric1'
          operator: 'GreaterThan'
          threshold: 0
          timeAggregation: 'Average'
          skipMetricValidation: true
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'This alert monitors number of containers killed due to out of memory (OOM) error.'
    enabled: true
    evaluationFrequency: 'PT1M'
    scopes: [
      mc.id
    ]
    severity: 3
    targetResourceType: 'microsoft.containerservice/managedclusters'
    windowSize: 'PT1M'
  }
  dependsOn: [
    sci
  ]
}

resource maHighPersistentVolumeUsage 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Persistent volume usage high for ${clusterName} CI-18'
  location: 'global'
  properties: {
    autoMitigate: true
    actions: []
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'podName'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'kubernetesNamespace'
              operator: 'Include'
              values: [
                '*'
              ]
            }
          ]
          metricName: 'pvUsageExceededPercentage'
          metricNamespace: 'Insights.Container/persistentvolumes'
          name: 'Metric1'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
          skipMetricValidation: true
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'This alert monitors persistent volume utilization.'
    enabled: false
    evaluationFrequency: 'PT1M'
    scopes: [
      mc.id
    ]
    severity: 3
    targetResourceType: 'microsoft.containerservice/managedclusters'
    windowSize: 'PT5M'
  }
  dependsOn: [
    sci
  ]
}

resource maPodsNotInReadyState 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Pods not in ready state for ${clusterName} CI-8'
  location: 'global'
  properties: {
    autoMitigate: true
    actions: []
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'controllerName'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'kubernetes namespace'
              operator: 'Include'
              values: [
                '*'
              ]
            }
          ]
          metricName: 'PodReadyPercentage'
          metricNamespace: 'Insights.Container/pods'
          name: 'Metric1'
          operator: 'LessThan'
          threshold: 80
          timeAggregation: 'Average'
          skipMetricValidation: true
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'This alert monitors for excessive pods not in the ready state.'
    enabled: true
    evaluationFrequency: 'PT1M'
    scopes: [
      mc.id
    ]
    severity: 3
    targetResourceType: 'microsoft.containerservice/managedclusters'
    windowSize: 'PT5M'
  }
  dependsOn: [
    sci
  ]
}

resource maRestartingContainerCount 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Restarting container count for ${clusterName} CI-7'
  location: 'global'
  properties: {
    autoMitigate: true
    actions: []
    criteria: {
      allOf: [
        {
          criterionType: 'StaticThresholdCriterion'
          dimensions: [
            {
              name: 'kubernetes namespace'
              operator: 'Include'
              values: [
                '*'
              ]
            }
            {
              name: 'controllerName'
              operator: 'Include'
              values: [
                '*'
              ]
            }
          ]
          metricName: 'restartingContainerCount'
          metricNamespace: 'Insights.Container/pods'
          name: 'Metric1'
          operator: 'GreaterThan'
          threshold: 0
          timeAggregation: 'Average'
          skipMetricValidation: true
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'This alert monitors number of containers restarting across the cluster.'
    enabled: true
    evaluationFrequency: 'PT1M'
    scopes: [
      mc.id
    ]
    severity: 3
    targetResourceType: 'Microsoft.ContainerService/managedClusters'
    windowSize: 'PT1M'
  }
  dependsOn: [
    sci
  ]
}

resource skva 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'KeyVaultAnalytics(${logAnalyticsWorkspaceName})'
  location: location
  properties: {
    containedResources: []
    referencedResources: []
    workspaceResourceId: resourceId('Microsoft.OperationalInsights/workspaces', logAnalyticsWorkspaceName)
  }
  plan: {
    name: 'KeyVaultAnalytics(${logAnalyticsWorkspaceName})'
    product: 'OMSGallery/KeyVaultAnalytics'
    promotionCode: ''
    publisher: 'Microsoft'
  }
  dependsOn: []
}

resource sqrPodFailed 'Microsoft.Insights/scheduledQueryRules@2018-04-16' = {
  name: 'PodFailedScheduledQuery'
  location: location
  properties: {
    autoMitigate: true
    displayName: '[${clusterName}] Scheduled Query for Pod Failed Alert'
    description: 'Alert on pod Failed phase.'
    enabled: 'true'
    source: {
      query: '//https://docs.microsoft.com/azure/azure-monitor/insights/container-insights-alerts \r\n let endDateTime = now(); let startDateTime = ago(1h); let trendBinSize = 1m; let clusterName = "${clusterName}"; KubePodInventory | where TimeGenerated < endDateTime | where TimeGenerated >= startDateTime | where ClusterName == clusterName | distinct ClusterName, TimeGenerated | summarize ClusterSnapshotCount = count() by bin(TimeGenerated, trendBinSize), ClusterName | join hint.strategy=broadcast ( KubePodInventory | where TimeGenerated < endDateTime | where TimeGenerated >= startDateTime | distinct ClusterName, Computer, PodUid, TimeGenerated, PodStatus | summarize TotalCount = count(), PendingCount = sumif(1, PodStatus =~ "Pending"), RunningCount = sumif(1, PodStatus =~ "Running"), SucceededCount = sumif(1, PodStatus =~ "Succeeded"), FailedCount = sumif(1, PodStatus =~ "Failed") by ClusterName, bin(TimeGenerated, trendBinSize) ) on ClusterName, TimeGenerated | extend UnknownCount = TotalCount - PendingCount - RunningCount - SucceededCount - FailedCount | project TimeGenerated, TotalCount = todouble(TotalCount) / ClusterSnapshotCount, PendingCount = todouble(PendingCount) / ClusterSnapshotCount, RunningCount = todouble(RunningCount) / ClusterSnapshotCount, SucceededCount = todouble(SucceededCount) / ClusterSnapshotCount, FailedCount = todouble(FailedCount) / ClusterSnapshotCount, UnknownCount = todouble(UnknownCount) / ClusterSnapshotCount| summarize AggregatedValue = avg(FailedCount) by bin(TimeGenerated, trendBinSize)'
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
  dependsOn: []
}

resource paAKSLinuxRestrictive 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: policyAssignmentNameAKSLinuxRestrictive
  properties: {
    displayName: '[${clusterName}] ${reference(policyResourceIdAKSLinuxRestrictive, '2020-09-01').displayName}'
    scope: subscriptionResourceId('Microsoft.Resources/resourceGroups', resourceGroup().name)
    policyDefinitionId: policyResourceIdAKSLinuxRestrictive
    parameters: {
      excludedNamespaces: {
        value: [
          'kube-system'
          'gatekeeper-system'
          'azure-arc'
          'cluster-baseline-settings'
        ]
      }
      effect: {
        value: 'audit'
      }
    }
  }
  dependsOn: []
}

resource paEnforceHttpsIngress 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: policyAssignmentNameEnforceHttpsIngress
  location: 'global'
  properties: {
    displayName: '[${clusterName}] ${reference(policyResourceIdEnforceHttpsIngress, '2020-09-01').displayName}'
    scope: subscriptionResourceId('Microsoft.Resources/resourceGroups', resourceGroup().name)
    policyDefinitionId: policyResourceIdEnforceHttpsIngress
    parameters: {
      excludedNamespaces: {
        value: []
      }
      effect: {
        value: 'deny'
      }
    }
  }
  dependsOn: []
}

resource paEnforceInternalLoadBalancers 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: policyAssignmentNameEnforceInternalLoadBalancers
  properties: {
    displayName: '[${clusterName}] ${reference(policyResourceIdEnforceInternalLoadBalancers, '2020-09-01').displayName}'
    scope: subscriptionResourceId('Microsoft.Resources/resourceGroups', resourceGroup().name)
    policyDefinitionId: policyResourceIdEnforceInternalLoadBalancers
    parameters: {
      excludedNamespaces: {
        value: []
      }
      effect: {
        value: 'deny'
      }
    }
  }
  dependsOn: []
}

resource paRoRootFilesystem 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: policyAssignmentNameRoRootFilesystem
  properties: {
    displayName: '[${clusterName}] ${reference(policyResourceIdRoRootFilesystem, '2020-09-01').displayName}'
    scope: subscriptionResourceId('Microsoft.Resources/resourceGroups', resourceGroup().name)
    policyDefinitionId: policyResourceIdRoRootFilesystem
    parameters: {
      excludedNamespaces: {
        value: [
          'kube-system'
          'gatekeeper-system'
          'azure-arc'
        ]
      }
      effect: {
        value: 'audit'
      }
    }
  }
  dependsOn: []
}

resource paEnforceResourceLimits 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: policyAssignmentNameEnforceResourceLimits
  dependsOn: []
  properties: {
    displayName: '[${clusterName}] ${reference(policyResourceIdEnforceResourceLimits, '2020-09-01').displayName}'
    scope: subscriptionResourceId('Microsoft.Resources/resourceGroups', resourceGroup().name)
    policyDefinitionId: policyResourceIdEnforceResourceLimits
    parameters: {
      cpuLimit: {
        value: '1000m'
      }
      memoryLimit: {
        value: '512Mi'
      }
      excludedNamespaces: {
        value: [
          'kube-system'
          'gatekeeper-system'
          'azure-arc'
          'cluster-baseline-settings'
          'flux-system'
        ]
      }
      effect: {
        value: 'deny'
      }
    }
  }
}

resource paEnforceImageSource 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: policyAssignmentNameEnforceImageSource
  properties: {
    displayName: '[${clusterName}] ${reference(policyResourceIdEnforceImageSource, '2020-09-01').displayName}'
    scope: subscriptionResourceId('Microsoft.Resources/resourceGroups', resourceGroup().name)
    policyDefinitionId: policyResourceIdEnforceImageSource
    parameters: {
      allowedContainerImagesRegex: {
        value: '${defaultAcrName}.azurecr.io/.+$|mcr.microsoft.com/.+$|azurearcfork8s.azurecr.io/azurearcflux/images/stable/.+$|docker.io/weaveworks/kured.+$|docker.io/library/.+$'
      }
      excludedNamespaces: {
        value: [
          'kube-system'
          'gatekeeper-system'
          'azure-arc'
        ]
      }
      effect: {
        value: 'deny'
      }
    }
  }
  dependsOn: []
}

resource paEnforceDefenderInCluster 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: policyAssignmentNameEnforceDefenderInCluster
  properties: {
    displayName: '[${clusterName}] ${reference(policyResourceIdEnforceDefenderInCluster, '2020-09-01').displayName}'
    description: 'Microsoft Defender for Containers should be enabled in the cluster.'
    scope: subscriptionResourceId('Microsoft.Resources/resourceGroups', resourceGroup().name)
    policyDefinitionId: policyResourceIdEnforceDefenderInCluster
    parameters: {
      effect: {
        value: 'Audit'
      }
    }
  }
  dependsOn: []
}

resource miClusterControlPlane 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'mi-${clusterName}-controlplane'
  location: location
}

resource miAppGatewayFrontend 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'mi-appgateway-frontend'
  location: location
}

resource podmiIngressController 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'podmi-ingress-controller'
  location: location
}

resource kv 'Microsoft.KeyVault/vaults@2021-11-01-preview' = {
  name: 'kv-${clusterName}'
  location: location
  properties: {
    accessPolicies: []
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
    }
    enableRbacAuthorization: true
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    enablePurgeProtection: false
    createMode: 'default'
    publicNetworkAccess: 'disabled'
  }  
  dependsOn: [
    miAppGatewayFrontend
    podmiIngressController
  ]

  resource kvsGatewayPublicCert 'secrets' = {
    name: 'gateway-public-cert'
    properties: {
      value: appGatewayListenerCertificate
    }
  }

  resource kvsAppGwIngressInternalAksIngressTls 'secrets' = {
    name: 'appgw-ingress-internal-aks-ingress-tls'
    properties: {
      value: aksIngressControllerCertificate
    }
  }
}

resource kv_diagnosticSettings  'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: kv
  name: 'default'
  properties: {
    workspaceId: resourceId('Microsoft.OperationalInsights/workspaces', logAnalyticsWorkspaceName)
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
  dependsOn: []
}

resource kvMiAppGatewayFrontendSecretsUserRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: kv
  name: '${guid(resourceGroup().id, 'mi-appgateway-frontend', keyVaultSecretsUserRole)}'
  properties: {
    roleDefinitionId: keyVaultSecretsUserRole
    principalId: miAppGatewayFrontend.properties.principalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: []
}

resource kvMiAppGatewayFrontendKeyVaultReader_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: kv
  name: '${guid(resourceGroup().id, 'mi-appgateway-frontend', keyVaultReader)}'
  properties: {
    roleDefinitionId: keyVaultReader
    principalId: miAppGatewayFrontend.properties.principalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: []
}

resource kvPodMiIngressControllerSecretsUserRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: kv
  name: '${guid(resourceGroup().id, 'podmi-ingress-controller', keyVaultSecretsUserRole)}'
  properties: {
    roleDefinitionId: keyVaultSecretsUserRole
    principalId: podmiIngressController.properties.principalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: []
}

resource kvPodMiIngressControllerKeyVaultReader_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: kv
  name: '${guid(resourceGroup().id, 'podmi-ingress-controller', keyVaultReader)}'
  properties: {
    roleDefinitionId: keyVaultReader
    principalId: podmiIngressController.properties.principalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: []
}

module ndEnsureClusterIdentityHasRbacToSelfManagedResources 'nested_EnsureClusterIdentityHasRbacToSelfManagedResources.bicep' = {
  name: 'EnsureClusterIdentityHasRbacToSelfManagedResources'
  scope: resourceGroup(vNetResourceGroup)
  params: {
    miClusterControlPlanePrincipalId: miClusterControlPlane.properties.principalId
    clusterControlPlaneIdentityName: miClusterControlPlane.name
    vnetName: vnetName
  }
}

resource pdzKv 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
  resource vnetlnk 'virtualNetworkLinks' = {
    name: 'to_${vnetName}'
    location: 'global'
    properties: {
      virtualNetwork: {
        id: targetVnetResourceId
      }
      registrationEnabled: false
    }
  }
  dependsOn: []
}

resource peKv 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: 'pe-${kv.name}'
  location: location
  properties: {
    subnet: {
      id: vnetPrivateLinkEndpointsSubnetResourceId
    }
    privateLinkServiceConnections: [
      {
        name: 'to_${vnetName}'
        properties: {
          privateLinkServiceId: kv.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
  dependsOn: []

  resource pdnszg 'privateDnsZoneGroups' = {
    name: 'default'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'privatelink-akv-net'
          properties: {
            privateDnsZoneId: pdzKv.id
          }
        }
      ]
    }
  }
}

resource pdzAksIngress 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: aksIngressDomainName
  location: 'global'
  dependsOn: []

  resource aksIngressDomainName_bu0001a0008_00 'A' = {
    name: 'bu0001a0008-00'
    properties: {
      ttl: 3600
      aRecords: [
        {
          ipv4Address: '10.240.4.4'
        }
      ]
    }
  }

  resource vnetlnk 'virtualNetworkLinks' = {
    name: 'to_${vnetName}'
    location: 'global'
    properties: {
      virtualNetwork: {
        id: targetVnetResourceId
      }
      registrationEnabled: false
    }
  }
}

resource mc 'Microsoft.ContainerService/managedClusters@2022-01-02-preview' = {
  name: clusterName
  location: location
  tags: {
    'Business unit': 'BU0001'
    'Application identifier': 'a0008'
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    dnsPrefix: uniqueString(subscription().subscriptionId, resourceGroup().id, clusterName)
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
        vnetSubnetID: vnetNodePoolSubnetResourceId
        enableAutoScaling: true
        type: 'VirtualMachineScaleSets'
        mode: 'System'
        scaleSetPriority: 'Regular'
        scaleSetEvictionPolicy: 'Delete'
        orchestratorVersion: kubernetesVersion
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
        count: 2
        vmSize: 'Standard_DS3_v2'
        osDiskSizeGB: 120
        osDiskType: 'Ephemeral'
        osType: 'Linux'
        minCount: 2
        maxCount: 5
        vnetSubnetID: vnetNodePoolSubnetResourceId
        enableAutoScaling: true
        type: 'VirtualMachineScaleSets'
        mode: 'User'
        scaleSetPriority: 'Regular'
        scaleSetEvictionPolicy: 'Delete'
        orchestratorVersion: kubernetesVersion
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
          logAnalyticsWorkspaceResourceId: resourceId('Microsoft.OperationalInsights/workspaces', logAnalyticsWorkspaceName)
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
    nodeResourceGroup: nodeResourceGroupName
    enableRBAC: true
    enablePodSecurityPolicy: false
    maxAgentPools: 2
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'azure'
      outboundType: 'userDefinedRouting'
      loadBalancerSku: 'standard'
      loadBalancerProfile: json('null')
      serviceCidr: '172.16.0.0/16'
      dnsServiceIP: '172.16.0.10'
      dockerBridgeCidr: '172.18.0.1/16'
    }
    aadProfile: {
      managed: true
      enableAzureRBAC: isUsingAzureRBACasKubernetesRBAC
      adminGroupObjectIDs: ((!isUsingAzureRBACasKubernetesRBAC) ? array(clusterAdminAadGroupObjectId) : [])
      tenantID: k8sControlPlaneAuthorizationTenantId
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
      authorizedIPRanges: clusterAuthorizedIPRanges
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
        logAnalyticsWorkspaceResourceId: resourceId('Microsoft.OperationalInsights/workspaces', logAnalyticsWorkspaceName)
      }
    }
    oidcIssuerProfile: {
      enabled: true
    }
    enableNamespaceResources: false
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${miClusterControlPlane.id}': {}
    }
  }
  sku: {
    name: 'Basic'
    tier: 'Paid'
  }
  dependsOn: [
    sci

    ndEnsureClusterIdentityHasRbacToSelfManagedResources

    paAKSLinuxRestrictive
    paEnforceHttpsIngress
    paEnforceInternalLoadBalancers
    paEnforceResourceLimits
    paRoRootFilesystem
    paEnforceImageSource
    paEnforceDefenderInCluster

    peKv
    kvPodMiIngressControllerKeyVaultReader_roleAssignment
    kvMiAppGatewayFrontendSecretsUserRole_roleAssignment
  ]
}

resource acr 'Microsoft.ContainerRegistry/registries@2021-12-01-preview' existing = {
  name: defaultAcrName
}

resource acrKubeletAcrPullRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: acr
  name: guid(mc.id, acrPullRole)
  properties: {
    roleDefinitionId: acrPullRole
    description: 'Allows AKS to pull container images from this ACR instance.'
    principalId: reference(mc.id, '2020-12-01').identityProfile.kubeletidentity.objectId
    principalType: 'ServicePrincipal'
  }
  dependsOn: []
}

resource mcOmsAgentMonitoringMetricsPublisherRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: mc
  name: guid(mc.id, 'omsagent', monitoringMetricsPublisherRole)
  properties: {
    roleDefinitionId: monitoringMetricsPublisherRole
    principalId: reference(mc.id, '2020-12-01').addonProfiles.omsagent.identity.objectId
    principalType: 'ServicePrincipal'
  }
  dependsOn: []
}

resource miKubeletManagedIdentityOperatorRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: podmiIngressController
  name: guid(resourceGroup().id, 'podmi-ingress-controller', managedIdentityOperatorRole)
  properties: {
    roleDefinitionId: managedIdentityOperatorRole
    principalId: reference(mc.id, '2020-12-01').identityProfile.kubeletidentity.objectId
    principalType: 'ServicePrincipal'
  }
  dependsOn: []
}

resource mcAadAdminGroupClusterAdminRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = if (isUsingAzureRBACasKubernetesRBAC) {
  scope: mc
  name: guid('aad-admin-group', mc.id, clusterAdminAadGroupObjectId)
  properties: {
    roleDefinitionId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/${clusterAdminRoleId}'
    description: 'Members of this group are cluster admins of this cluster.'
    principalId: clusterAdminAadGroupObjectId
    principalType: 'Group'
  }
  dependsOn: []
}

resource mcAadAdminGroupServiceClusterUserRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = if (isUsingAzureRBACasKubernetesRBAC) {
  scope: mc
  name: guid('aad-admin-group-sc', mc.id, clusterAdminAadGroupObjectId)
  properties: {
    roleDefinitionId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/${serviceClusterUserRoleId}'
    description: 'Members of this group are cluster users of this cluster.'
    principalId: clusterAdminAadGroupObjectId
    principalType: 'Group'
  }
  dependsOn: []
}

resource maAadA0008ReaderGroupClusterReaderRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = if (isUsingAzureRBACasKubernetesRBAC && (!(a0008NamespaceReaderAadGroupObjectId == clusterAdminAadGroupObjectId))) {
  scope: mc // TODO: reference namespace instead
  name: guid('aad-a0008-reader-group', mc.id, a0008NamespaceReaderAadGroupObjectId)
  properties: {
    roleDefinitionId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/${clusterReaderRoleId}'
    principalId: a0008NamespaceReaderAadGroupObjectId
    description: 'Members of this group are cluster admins of the a0008 namespace in this cluster.'
    principalType: 'Group'
  }
  dependsOn: []
}

resource maAadA0008ReaderGroupServiceClusterUserRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = if (isUsingAzureRBACasKubernetesRBAC && (!(a0008NamespaceReaderAadGroupObjectId == clusterAdminAadGroupObjectId))) {
  scope: mc
  name: guid('aad-a0008-reader-group-sc', mc.id, a0008NamespaceReaderAadGroupObjectId)
  properties: {
    roleDefinitionId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/${serviceClusterUserRoleId}'
    principalId: a0008NamespaceReaderAadGroupObjectId
    description: 'Members of this group are cluster users of this cluster.'
    principalType: 'Group'
  }
  dependsOn: []
}

resource mc_diagnosticSettings  'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: mc
  name: 'default'
  properties: {
    workspaceId: resourceId('Microsoft.OperationalInsights/workspaces', logAnalyticsWorkspaceName)
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
  dependsOn: []
}

resource mcFlux_extension 'Microsoft.KubernetesConfiguration/extensions@2021-09-01' = {
  scope: mc
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
    acrKubeletAcrPullRole_roleAssignment
  ]
}

resource mc_fluxConfiguration 'Microsoft.KubernetesConfiguration/fluxConfigurations@2022-03-01' = {
  scope: mc
  name: 'bootstrap'
  properties: {
    scope: 'cluster'
    namespace: 'flux-system'
    sourceKind: 'GitRepository'
    gitRepository: {
      url: gitOpsBootstrappingRepoHttpsUrl
      timeoutInSeconds: 180
      syncIntervalInSeconds: 300
      repositoryRef: {
        branch: gitOpsBootstrappingRepoBranch
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
        path: './cluster-manifests'
        dependsOn: []
        timeoutInSeconds: 300
        syncIntervalInSeconds: 300
        retryIntervalInSeconds: null
        prune: true
        force: false
      }
    }
  }
  dependsOn: [
    mcFlux_extension
    acrKubeletAcrPullRole_roleAssignment
  ]
}

module ndEnsureClusterUserAssignedHasRbacToManageVMSS 'nested_EnsureClusterUserAssignedHasRbacToManageVMSS.bicep' = {
  name: 'EnsureClusterUserAssignedHasRbacToManageVMSS'
  scope: resourceGroup(nodeResourceGroupName)
  params: {
    kubeletidentityObjectId: reference(mc.id, '2020-03-01').identityProfile.kubeletidentity.objectId
  }
  dependsOn: []
}

resource st 'Microsoft.EventGrid/systemTopics@2021-12-01' = {
  name: clusterName
  location: location
  properties: {
    source: mc.id
    topicType: 'Microsoft.ContainerService.ManagedClusters'
  }
  dependsOn: []
}

resource st_diagnosticSettings  'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: st
  name: 'default'
  properties: {
    workspaceId: resourceId('Microsoft.OperationalInsights/workspaces', logAnalyticsWorkspaceName)
    logs: [
      {
        category: 'DeliveryFailures'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
  dependsOn: []
}

resource agw 'Microsoft.Network/applicationGateways@2021-05-01' = {
  name: agwName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${miAppGatewayFrontend.id}': {}
    }
  }
  zones: pickZones('Microsoft.Network', 'applicationGateways', location, 3)
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
    }
    sslPolicy: {
      policyType: 'Custom'
      cipherSuites: [
        'TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384'
        'TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256'
      ]
      minProtocolVersion: 'TLSv1_2'
    }
    trustedRootCertificates: [
      {
        name: 'root-cert-wildcard-aks-ingress'
        properties: {
          keyVaultSecretId: '${reference(kv.name).vaultUri}secrets/appgw-ingress-internal-aks-ingress-tls'
        }
      }
    ]
    gatewayIPConfigurations: [
      {
        name: 'apw-ip-configuration'
        properties: {
          subnet: {
            id: '${targetVnetResourceId}/subnets/snet-applicationgateway'
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'apw-frontend-ip-configuration'
        properties: {
          publicIPAddress: {
            id: resourceId(subscription().subscriptionId, vNetResourceGroup, 'Microsoft.Network/publicIpAddresses', 'pip-BU0001A0008-00')
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port-443'
        properties: {
          port: 443
        }
      }
    ]
    autoscaleConfiguration: {
      minCapacity: 0
      maxCapacity: 10
    }
    webApplicationFirewallConfiguration: {
      enabled: true
      firewallMode: 'Prevention'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.2'
      exclusions: []
      fileUploadLimitInMb: 10
      disabledRuleGroups: []
    }
    enableHttp2: false
    sslCertificates: [
      {
        name: '${agwName}-ssl-certificate'
        properties: {
          keyVaultSecretId: '${reference(kv.name).vaultUri}secrets/gateway-public-cert'
        }
      }
    ]
    probes: [
      {
        name: 'probe-${aksBackendDomainName}'
        properties: {
          protocol: 'Https'
          path: '/favicon.ico'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: true
          minServers: 0
          match: {}
        }
      }
    ]
    backendAddressPools: [
      {
        name: aksBackendDomainName
        properties: {
          backendAddresses: [
            {
              fqdn: aksBackendDomainName
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'aks-ingress-backendpool-httpsettings'
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: true
          requestTimeout: 20
          probe: {
            id: resourceId('Microsoft.Network/applicationGateways/probes', agwName, 'probe-${aksBackendDomainName}')
          }
          trustedRootCertificates: [
            {
              id: resourceId('Microsoft.Network/applicationGateways/trustedRootCertificates', agwName, 'root-cert-wildcard-aks-ingress')
            }
          ]
        }
      }
    ]
    httpListeners: [
      {
        name: 'listener-https'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', agwName, 'apw-frontend-ip-configuration')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', agwName, 'port-443')
          }
          protocol: 'Https'
          sslCertificate: {
            id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', agwName, '${agwName}-ssl-certificate')
          }
          hostName: 'bicycle.${domainName}'
          hostNames: []
          requireServerNameIndication: true
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'apw-routing-rules'
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', agwName, 'listener-https')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', agwName, aksBackendDomainName)
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', agwName, 'aks-ingress-backendpool-httpsettings')
          }
        }
      }
    ]
  }
  dependsOn: [
    peKv
    kvMiAppGatewayFrontendKeyVaultReader_roleAssignment
    kvMiAppGatewayFrontendSecretsUserRole_roleAssignment
  ]
}

resource agwdiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: agw
  name: 'default'
  properties: {
    workspaceId: resourceId('Microsoft.OperationalInsights/workspaces', logAnalyticsWorkspaceName)
    logs: [
      {
        category: 'ApplicationGatewayAccessLog'
        enabled: true
      }
      {
        category: 'ApplicationGatewayPerformanceLog'
        enabled: true
      }
      {
        category: 'ApplicationGatewayFirewallLog'
        enabled: true
      }
    ]
  }
  dependsOn: []
}

output aksClusterName string = clusterName
output aksIngressControllerPodManagedIdentityResourceId string = podmiIngressController.id
output aksIngressControllerPodManagedIdentityClientId string = reference(podmiIngressController.id, '2018-11-30').clientId
output keyVaultName string = kv.name

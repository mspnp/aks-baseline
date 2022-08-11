targetScope = 'resourceGroup'

/*** PARAMETERS ***/

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
param kubernetesVersion string = '1.24.0'

@description('Domain name to use for App Gateway and AKS ingress.')
param domainName string = 'contoso.com'

@description('Your cluster will be bootstrapped from this git repo.')
@minLength(9)
param gitOpsBootstrappingRepoHttpsUrl string = 'https://github.com/mspnp/aks-baseline'

@description('You cluster will be bootstrapped from this branch in the identified git repo.')
@minLength(1)
param gitOpsBootstrappingRepoBranch string = 'main'

/*** VARIABLES ***/

var subRgUniqueString = uniqueString('aks', subscription().subscriptionId, resourceGroup().id)
var clusterName = 'aks-${subRgUniqueString}'
var agwName = 'apw-${clusterName}'

var aksIngressDomainName = 'aks-ingress.${domainName}'
var aksBackendDomainName = 'bu0001a0008-00.${aksIngressDomainName}'
var isUsingAzureRBACasKubernetesRBAC = (subscription().tenantId == k8sControlPlaneAuthorizationTenantId)

/*** EXISTING TENANT RESOURCES ***/

// Built-in 'Kubernetes cluster pod security restricted standards for Linux-based workloads' Azure Policy for Kubernetes initiative definition
var psdAKSLinuxRestrictiveId = tenantResourceId('Microsoft.Authorization/policySetDefinitions', '42b8ef37-b724-4e24-bbc8-7a7708edfe00')

// Built-in 'Kubernetes clusters should be accessible only over HTTPS' Azure Policy for Kubernetes policy definition
var pdEnforceHttpsIngressId = tenantResourceId('Microsoft.Authorization/policyDefinitions', '1a5b4dca-0b6f-4cf5-907c-56316bc1bf3d')

// Built-in 'Kubernetes clusters should use internal load balancers' Azure Policy for Kubernetes policy definition
var pdEnforceInternalLoadBalancersId = tenantResourceId('Microsoft.Authorization/policyDefinitions', '3fc4dc25-5baf-40d8-9b05-7fe74c1bc64e')

// Built-in 'Kubernetes cluster containers should run with a read only root file system' Azure Policy for Kubernetes policy definition
var pdRoRootFilesystemId = tenantResourceId('Microsoft.Authorization/policyDefinitions', 'df49d893-a74c-421d-bc95-c663042e5b80')

// Built-in 'AKS container CPU and memory resource limits should not exceed the specified limits' Azure Policy for Kubernetes policy definition
var pdEnforceResourceLimitsId = tenantResourceId('Microsoft.Authorization/policyDefinitions', 'e345eecc-fa47-480f-9e88-67dcc122b164')

// Built-in 'AKS containers should only use allowed images' Azure Policy for Kubernetes policy definition
var pdEnforceImageSourceId = tenantResourceId('Microsoft.Authorization/policyDefinitions', 'febd0533-8e55-448f-b837-bd0e06f16469')

// Built-in 'Kubernetes cluster pod hostPath volumes should only use allowed host paths' Azure Policy for Kubernetes policy definition
var pdAllowedHostPathsId = tenantResourceId('Microsoft.Authorization/policyDefinitions', '098fc59e-46c7-4d99-9b16-64990e543d75')

// Built-in 'Kubernetes cluster services should only use allowed external IPs' Azure Policy for Kubernetes policy definition
var pdAllowedExternalIPsId = tenantResourceId('Microsoft.Authorization/policyDefinitions', 'd46c275d-1680-448d-b2ec-e495a3b6cc89')

// Built-in 'Kubernetes clusters should not allow endpoint edit permissions of ClusterRole/system:aggregate-to-edit' Azure Policy for Kubernetes policy definition
var pdDisallowEndpointEditPermissionsId = tenantResourceId('Microsoft.Authorization/policyDefinitions', '1ddac26b-ed48-4c30-8cc5-3a68c79b8001')

// Built-in 'Kubernetes clusters should not use the default namespace' Azure Policy for Kubernetes policy definition
var pdDisallowNamespaceUsageId = tenantResourceId('Microsoft.Authorization/policyDefinitions', '9f061a12-e40d-4183-a00e-171812443373')

// Built-in 'Azure Kubernetes Service clusters should have Defender profile enabled' Azure Policy policy definition
var pdDefenderInClusterEnabledId = tenantResourceId('Microsoft.Authorization/policyDefinitions', 'a1840de2-8088-4ea8-b153-b4c723e9cb01')

// Built-in 'Azure Kubernetes Service Clusters should enable Azure Active Directory integration' Azure Policy policy definition
var pdAadIntegrationEnabledId = tenantResourceId('Microsoft.Authorization/policyDefinitions', '450d2877-ebea-41e8-b00c-e286317d21bf')

// Built-in 'Azure Kubernetes Service Clusters should have local authentication methods disabled' Azure Policy policy definition
var pdLocalAuthDisabledId = tenantResourceId('Microsoft.Authorization/policyDefinitions', '993c2fcd-2b29-49d2-9eb0-df2c3a730c32')

// Built-in 'Azure Policy Add-on for Kubernetes service (AKS) should be installed and enabled on your clusters' Azure Policy policy definition
var pdAzurePolicyEnabledId = tenantResourceId('Microsoft.Authorization/policyDefinitions', '0a15ec92-a229-4763-bb14-0ea34a568f8d')

// Built-in 'Authorized IP ranges should be defined on Kubernetes Services' Azure Policy policy definition
var pdAuthorizedIpRangesDefinedId = tenantResourceId('Microsoft.Authorization/policyDefinitions', '0e246bcf-5f6f-4f87-bc6f-775d4712c7ea')

// Built-in 'Kubernetes Services should be upgraded to a non-vulnerable Kubernetes version' Azure Policy policy definition
var pdOldKuberentesDisabledId = tenantResourceId('Microsoft.Authorization/policyDefinitions', 'fb893a29-21bb-418c-a157-e99480ec364c')

// Built-in 'Role-Based Access Control (RBAC) should be used on Kubernetes Services' Azure Policy policy definition
var pdRbacEnabledId = tenantResourceId('Microsoft.Authorization/policyDefinitions', 'ac4a19c2-fa67-49b4-8ae5-0b2e78c49457')

// Built-in 'Azure Kubernetes Service Clusters should use managed identities' Azure Policy policy definition
var pdManagedIdentitiesEnabledId = tenantResourceId('Microsoft.Authorization/policyDefinitions', 'da6e2401-19da-4532-9141-fb8fbde08431')

/*** EXISTING SUBSCRIPTION RESOURCES ***/

resource nodeResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: 'rg-${clusterName}-nodepools'
  scope: subscription()
}

// Built-in Azure RBAC role that is applied to a cluster to indicate they can be considered a user/group of the cluster, subject to additional RBAC permissions
resource serviceClusterUserRole 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  name: '4abbcc35-e782-43d8-92c5-2d3f1bd2253f'
  scope: subscription()
}

// Built-in Azure RBAC role that can be applied to a cluster or a namespace to grant read and write privileges to that scope for a user or group
resource clusterAdminRole 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  name: 'b1ff04bb-8a4e-4dc4-8eb5-8693973ce19b'
  scope: subscription()
}

// Built-in Azure RBAC role that can be applied to a cluster or a namespace to grant read privileges to that scope for a user or group
resource clusterReaderRole 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  name: '7f6c6a51-bcf8-42ba-9220-52d62157d7db'
  scope: subscription()
}

// Built-in Azure RBAC role that is applied to a cluster to grant its monitoring agent's identity with publishing metrics and push alerts permissions.
resource monitoringMetricsPublisherRole 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  name: '3913510d-42f4-4e42-8a64-420c390055eb'
  scope: subscription()
}

// Built-in Azure RBAC role that can be applied to an Azure Container Registry to grant the authority pull container images. Granted to the AKS cluster's kubelet identity.
resource acrPullRole 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  name: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
  scope: subscription()
}

// Built-in Azure RBAC role that must be applied to the kublet Managed Identity allowing it to further assign adding managed identities to the cluster's underlying VMSS.
resource managedIdentityOperatorRole 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  name: 'f1a07417-d97a-45cb-824c-7a7467783830'
  scope: subscription()
}

// Built-in Azure RBAC role that is applied a Key Vault to grant with metadata, certificates, keys and secrets read privileges.  Granted to App Gateway's managed identity.
resource keyVaultReaderRole 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  name: '21090545-7ca7-4776-b22c-e363652d74d2'
  scope: subscription()
}

// Built-in Azure RBAC role that is applied to a Key Vault to grant with secrets content read privileges. Granted to both Key Vault and our workload's identity.
resource keyVaultSecretsUserRole 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  name: '4633458b-17de-408a-b874-0445c86b69e6'
  scope: subscription()
}

/*** EXISTING RESOURCE GROUP RESOURCES ***/

// Azure Container Registry
resource acr 'Microsoft.ContainerRegistry/registries@2021-12-01-preview' existing = {
  scope: resourceGroup()
  name: 'acraks${subRgUniqueString}'
}

// Log Analytics Workspace
resource la 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' existing = {
  scope: resourceGroup()
  name: 'la-${clusterName}'
}

// Kubernetes namespace: a0008 -- this doesn't technically exist prior to deployment, but is required as a resource reference later in the template
// to support Azure RBAC-managed API Server access, scoped to the namespace level.
#disable-next-line BCP081 // this namespaces child type doesn't have a defined bicep type yet.
resource nsA0008 'Microsoft.ContainerService/managedClusters/namespaces@2022-01-02-preview' existing = {
  parent: mc
  name: 'a0008'
}

/*** EXISTING SPOKE RESOURCES ***/

// Spoke resource group
resource targetResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  scope: subscription()
  name: '${split(targetVnetResourceId,'/')[4]}'
}

// Spoke virtual network
resource targetVirtualNetwork 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  scope: targetResourceGroup
  name: '${last(split(targetVnetResourceId,'/'))}'
}

// Spoke virutual network's subnet for the cluster nodes
resource snetClusterNodes 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' existing = {
  parent: targetVirtualNetwork
  name: 'snet-clusternodes'
}

// Spoke virutual network's subnet for all private endpoints
resource snetPrivatelinkendpoints 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' existing = {
  parent: targetVirtualNetwork
  name: 'snet-privatelinkendpoints'
}

/*** RESOURCES ***/

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
}

// A query pack to hold any custom quries you may want to write to monitor your cluster or workloads
resource qpBaselineQueryPack 'Microsoft.OperationalInsights/queryPacks@2019-09-01' = {
  location: location
  name: 'AKS baseline bundled queries'
  properties: {}
}

// Example query that shows all scraped Prometheus metrics
resource qPrometheusAll 'Microsoft.OperationalInsights/queryPacks/queries@2019-09-01' = {
  parent: qpBaselineQueryPack
  name: guid(resourceGroup().id, 'PrometheusAll', clusterName)
  properties: {
    displayName: 'All collected Prometheus information'
    description: 'This is all collected Prometheus metrics'
    body: 'InsightsMetrics | where Namespace == "prometheus"'
    related: {
      categories: [
        'container'
      ]
    }
  }
}

// Example query that shows the usage of a specific Prometheus metric emitted by Kured
resource qNodeReboots 'Microsoft.OperationalInsights/queryPacks/queries@2019-09-01' = {
  parent: qpBaselineQueryPack
  name: guid(resourceGroup().id, 'KuredNodeReboot', clusterName)
  properties: {
    displayName: 'Kubenertes node reboot requested'
    description: 'Which Kubernetes nodes are flagged for reboot (based on Prometheus metrics).'
    body: 'InsightsMetrics | where Namespace == "prometheus" and Name == "kured_reboot_required" | where Val > 0'
    related: {
      categories: [
        'container'
        'management'
      ]
    }
  }
}

resource sci 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'ContainerInsights(${la.name})'
  location: location
  properties: {
    containedResources: []
    referencedResources: []
    workspaceResourceId: la.id
  }
  plan: {
    name: 'ContainerInsights(${la.name})'
    product: 'OMSGallery/ContainerInsights'
    promotionCode: ''
    publisher: 'Microsoft'
  }
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
  name: 'KeyVaultAnalytics(${la.name})'
  location: location
  properties: {
    containedResources: []
    referencedResources: []
    workspaceResourceId: la.id
  }
  plan: {
    name: 'KeyVaultAnalytics(${la.name})'
    product: 'OMSGallery/KeyVaultAnalytics'
    promotionCode: ''
    publisher: 'Microsoft'
  }
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
      dataSourceId: la.id
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
}

// Resource Group Azure Policy Assignments - Azure Policy for Kubernetes Policies

// Applying the built-in 'Kubernetes cluster pod security restricted standards for Linux-based workloads' initiative at the resource group level.
// Constraint Names: K8sAzureAllowedSeccomp, K8sAzureAllowedCapabilities, K8sAzureContainerNoPrivilege, K8sAzureHostNetworkingPorts, K8sAzureVolumeTypes, K8sAzureBlockHostNamespaceV2, K8sAzureAllowedUsersGroups, K8sAzureContainerNoPrivilegeEscalation
resource paAKSLinuxRestrictive 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: guid(psdAKSLinuxRestrictiveId, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${reference(psdAKSLinuxRestrictiveId, '2021-06-01').displayName}', 120)
    description: reference(psdAKSLinuxRestrictiveId, '2021-06-01').description
    policyDefinitionId: psdAKSLinuxRestrictiveId
    parameters: {
      excludedNamespaces: {
        value: [
          'kube-system'
          'gatekeeper-system'
          'azure-arc'
          'flux-system'

          // Known violations
          // K8sAzureAllowedSeccomp
          //  - Kured, no profile defined
          //  - AAD Pod Identity (nmi & mic), no profile defined
          // K8sAzureAllowedCapabilities
          //  - AAD Pod Identity (nmi), requests default unsupported DAC_READ_SEARCH, NET_ADMIN
          // K8sAzureContainerNoPrivilege
          //  - Kured, requires privileged to perform reboot
          // K8sAzureHostNetworkingPorts
          //  - AAD Pod Identity (nmi), hostNetwork and hostPort usage
          // K8sAzureVolumeTypes
          //  - AAD Pod Identity (nmi & mic), uses hostPath
          // K8sAzureBlockHostNamespaceV2
          //  - Kured, shared host namespace
          // K8sAzureAllowedUsersGroups
          //  - Kured, no runAsNonRoot, no runAsGroup, no supplementalGroups, no fsGroup
          //  - AAD Pod Identity (nmi & mic), runAsUser=0, no runAsGroup, no supplementalGroups, no fsGroup
          'cluster-baseline-settings'

          // Known violations
          // K8sAzureAllowedSeccomp
          //  - Traefik, no profile defined
          //  - aspnetapp-deployment, no profile defined
          // K8sAzureVolumeTypes
          //  - Traefik, uses csi
          // K8sAzureAllowedUsersGroups
          //  - Traefik, no supplementalGroups, no fsGroup
          //  = aspnetapp-deployment, no supplementalGroups, no fsGroup
          'a0008'
        ]
      }
      effect: {
        value: 'Audit'
      }
    }
  }
}

// Applying the built-in 'Kubernetes clusters should be accessible only over HTTPS' policy at the resource group level.
// Constraint Name: K8sAzureIngressHttpsOnly
resource paEnforceHttpsIngress 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: guid(pdEnforceHttpsIngressId, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${reference(pdEnforceHttpsIngressId, '2021-06-01').displayName}', 120)
    description: reference(pdEnforceHttpsIngressId, '2021-06-01').description
    policyDefinitionId: pdEnforceHttpsIngressId
    parameters: {
      excludedNamespaces: {
        value: []
      }
      effect: {
        value: 'Deny'
      }
    }
  }
}

// Applying the built-in 'Kubernetes clusters should use internal load balancers' policy at the resource group level.
// Constraint Name: K8sAzureLoadBalancerNoPublicIPs
resource paEnforceInternalLoadBalancers 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: guid(pdEnforceInternalLoadBalancersId, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${reference(pdEnforceInternalLoadBalancersId, '2021-06-01').displayName}', 120)
    description: reference(pdEnforceInternalLoadBalancersId, '2021-06-01').description
    policyDefinitionId: pdEnforceInternalLoadBalancersId
    parameters: {
      excludedNamespaces: {
        value: []
      }
      effect: {
        value: 'Deny'
      }
    }
  }
}

// Applying the built-in 'Kubernetes cluster containers should run with a read only root file system' policy at the resource group level.
// Constraint Name: K8sAzureReadOnlyRootFilesystem
resource paRoRootFilesystem 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: guid(pdRoRootFilesystemId, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${reference(pdRoRootFilesystemId, '2021-06-01').displayName}', 120)
    description: reference(pdRoRootFilesystemId, '2021-06-01').description
    policyDefinitionId: pdRoRootFilesystemId
    parameters: {
      excludedNamespaces: {
        value: [
          'kube-system'
          'gatekeeper-system'
          'azure-arc'
          'flux-system'
        ]
      }
      excludedContainers: {
        value: [
          'kured'   // Kured
          'nmi'     // AAD Pod Identity
          'mic'     // AAD Pod Identity
          'aspnet-webapp-sample'   // ASP.NET Core does not support read-only root
        ]
      }
      effect: {
        value: 'Deny'
      }
    }
  }
}


// Applying the built-in 'AKS container CPU and memory resource limits should not exceed the specified limits' policy at the resource group level.
// Constraint Name: K8sAzureContainerLimits
resource paEnforceResourceLimits 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: guid(pdEnforceResourceLimitsId, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${reference(pdEnforceResourceLimitsId, '2021-06-01').displayName}', 120)
    description: reference(pdEnforceResourceLimitsId, '2021-06-01').description
    policyDefinitionId: pdEnforceResourceLimitsId
    parameters: {
      cpuLimit: {
        value: '500m' // Kured = 500m, AAD Pod Identity = 200m, traefik-ingress-controller = 200m, aspnet-webapp-sample = 100m
      }
      memoryLimit: {
        value: '1Gi' // AAD Pod Identity = 1Gi, aspnet-webapp-sample = 256Mi, traefik-ingress-controller = 128Mi, Kured = 48Mi
      }
      excludedNamespaces: {
        value: [
          'kube-system'
          'gatekeeper-system'
          'azure-arc'
          'flux-system'
        ]
      }
      effect: {
        value: 'Deny'
      }
    }
  }
}

// Applying the built-in 'AKS containers should only use allowed images' policy at the resource group level.
// Constraint Name: K8sAzureContainerAllowedImages
resource paEnforceImageSource 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: guid(pdEnforceImageSourceId, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${reference(pdEnforceImageSourceId, '2021-06-01').displayName}', 120)
    description: reference(pdEnforceImageSourceId, '2021-06-01').description
    policyDefinitionId: pdEnforceImageSourceId
    parameters: {
      allowedContainerImagesRegex: {
        // If all images are pull into your ARC instance as described in these instructions you can remove the docker.io entries.
        value: '${acr.name}\\.azurecr\\.io/.+$|mcr\\.microsoft\\.com/.+$|docker\\.io/weaveworks/kured.+$|docker\\.io/library/.+$'
      }
      excludedNamespaces: {
        value: [
          'kube-system'
          'gatekeeper-system'
          'azure-arc'
        ]
      }
      effect: {
        value: 'Deny'
      }
    }
  }
}

// Applying the built-in 'Kubernetes cluster pod hostPath volumes should only use allowed host paths' policy at the resource group level.
resource paAllowedHostPaths 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: guid(pdAllowedHostPathsId, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${reference(pdAllowedHostPathsId, '2021-06-01').displayName}', 120)
    description: reference(pdAllowedHostPathsId, '2021-06-01').description
    policyDefinitionId: pdAllowedHostPathsId
    parameters: {
      excludedNamespaces: {
        value: [
          'kube-system'
          'gatekeeper-system'
          'azure-arc'
          'flux-system'
        ]
      }
      allowedHostPaths: {
        value: {
          paths: [] // Setting to empty blocks all host paths
        }
      }
      // AAD Pod Identity mounts: /run/xtables.lock, /etc/default/kubelet, and /etc/kubernetes/azure.json
      // If not using AAD Pod Identity (OSS version), then you can remove this exclusion
      excludedContainers: {
        value: [
          'nmi'
          'mic'
        ]
      }
      effect: {
        value: 'Deny'
      }
    }
  }
}

// Applying the built-in 'Kubernetes cluster services should only use allowed external IPs' policy at the resource group level.
// Constraint Name: K8sAzureExternalIPs
resource paAllowedExternalIPs 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: guid(pdAllowedExternalIPsId, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${reference(pdAllowedExternalIPsId, '2021-06-01').displayName}', 120)
    description: reference(pdAllowedExternalIPsId, '2021-06-01').description
    policyDefinitionId: pdAllowedExternalIPsId
    parameters: {
      excludedNamespaces: {
        value: [
          'kube-system'
          'gatekeeper-system'
          'azure-arc'
        ]
      }
      allowedExternalIPs: {
        value: []  // None allowed, internal load balancer IP only supported.
      }
      effect: {
        value: 'Deny'
      }
    }
  }
}

// Applying the built-in 'Kubernetes clusters should not allow endpoint edit permissions of ClusterRole/system:aggregate-to-edit' policy at the resource group level.
// See: CVE-2021-25740 & https://github.com/kubernetes/kubernetes/issues/103675
// Constraint Name: K8sAzureBlockEndpointEditDefaultRole
resource paDisallowEndpointEditPermissions 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: guid(pdDisallowEndpointEditPermissionsId, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${reference(pdDisallowEndpointEditPermissionsId, '2021-06-01').displayName}', 120)
    description: reference(pdDisallowEndpointEditPermissionsId, '2021-06-01').description
    policyDefinitionId: pdDisallowEndpointEditPermissionsId
    parameters: {
      excludedNamespaces: {
        value: [
          'kube-system'
          'gatekeeper-system'
          'azure-arc'
        ]
      }
      effect: {
        value: 'Audit' // As of 1.0.1, there is no Deny.
      }
    }
  }
}

// Applying the built-in 'Kubernetes clusters should not use the default namespace' policy at the resource group level.
// Constraint Name: K8sAzureBlockDefault
resource paDisallowNamespaceUsage 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: guid(pdDisallowNamespaceUsageId, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${reference(pdDisallowNamespaceUsageId, '2021-06-01').displayName}', 120)
    description: reference(pdDisallowNamespaceUsageId, '2021-06-01').description
    policyDefinitionId: pdDisallowNamespaceUsageId
    parameters: {
      excludedNamespaces: {
        value: [
          'kube-system'
          'gatekeeper-system'
          'azure-arc'
        ]
      }
      namespaces: {
        value: [
          'default' // List namespaces you'd like to disallow the usage of (typically 'default')
        ]
      }
      effect: {
        value: 'Audit' // Consider moving to Deny, this walkthrough does temporarly deploy a curl image in default, so leaving as Audit
      }
    }
  }
}

// Resource Group Azure Policy Assignments - Resource Provider Policies

// Applying the built-in 'Azure Kubernetes Service clusters should have Defender profile enabled' policy at the resource group level.
resource paDefenderInClusterEnabled 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: guid(pdDefenderInClusterEnabledId, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${reference(pdDefenderInClusterEnabledId, '2021-06-01').displayName}', 120)
    description: reference(pdDefenderInClusterEnabledId, '2021-06-01').description
    policyDefinitionId: pdDefenderInClusterEnabledId
    parameters: {
      effect: {
        value: 'Audit' // This policy (as of 1.0.2-preview) does not have a Deny option, otherwise that would be set here.
      }
    }
  }
}

// Applying the built-in 'Azure Kubernetes Service Clusters should enable Azure Active Directory integration' policy at the resource group level.
resource paAadIntegrationEnabled 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: guid(pdAadIntegrationEnabledId, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${reference(pdAadIntegrationEnabledId, '2021-06-01').displayName}', 120)
    description: reference(pdAadIntegrationEnabledId, '2021-06-01').description
    policyDefinitionId: pdAadIntegrationEnabledId
    parameters: {
      effect: {
        value: 'Audit' // This policy (as of 1.0.0) does not have a Deny option, otherwise that would be set here.
      }
    }
  }
}

// Applying the built-in 'Azure Kubernetes Service Clusters should have local authentication methods disabled' policy at the resource group level.
resource paLocalAuthDisabled 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: guid(pdLocalAuthDisabledId, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${reference(pdLocalAuthDisabledId, '2021-06-01').displayName}', 120)
    description: reference(pdLocalAuthDisabledId, '2021-06-01').description
    policyDefinitionId: pdLocalAuthDisabledId
    parameters: {
      effect: {
        value: 'Deny'
      }
    }
  }
}

// Applying the built-in 'Azure Policy Add-on for Kubernetes service (AKS) should be installed and enabled on your clusters' policy at the resource group level.
resource paAzurePolicyEnabled 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: guid(pdAzurePolicyEnabledId, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${reference(pdAzurePolicyEnabledId, '2021-06-01').displayName}', 120)
    description: reference(pdAzurePolicyEnabledId, '2021-06-01').description
    policyDefinitionId: pdAzurePolicyEnabledId
    parameters: {
      effect: {
        value: 'Audit'  // This policy (as of 1.0.2) does not have a Deny option, otherwise that would be set here.
      }
    }
  }
}

// Applying the built-in 'Authorized IP ranges should be defined on Kubernetes Services' policy at the resource group level.
resource paAuthorizedIpRangesDefined 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: guid(pdAuthorizedIpRangesDefinedId, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${reference(pdAuthorizedIpRangesDefinedId, '2021-06-01').displayName}', 120)
    description: reference(pdAuthorizedIpRangesDefinedId, '2021-06-01').description
    policyDefinitionId: pdAuthorizedIpRangesDefinedId
    parameters: {
      effect: {
        value: 'Audit'  // This policy (as of 2.0.1) does not have a Deny option, otherwise that would be set here.
      }
    }
  }
}

// Applying the built-in 'Kubernetes Services should be upgraded to a non-vulnerable Kubernetes version' policy at the resource group level.
resource paOldKuberentesDisabled 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: guid(pdOldKuberentesDisabledId, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${reference(pdOldKuberentesDisabledId, '2021-06-01').displayName}', 120)
    description: reference(pdOldKuberentesDisabledId, '2021-06-01').description
    policyDefinitionId: pdOldKuberentesDisabledId
    parameters: {
      effect: {
        value: 'Audit'  // This policy (as of 1.0.2) does not have a Deny option, otherwise that would be set here.
      }
    }
  }
}

// Applying the built-in 'Role-Based Access Control (RBAC) should be used on Kubernetes Services' policy at the resource group level.
resource paRbacEnabled 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: guid(pdRbacEnabledId, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${reference(pdRbacEnabledId, '2021-06-01').displayName}', 120)
    description: reference(pdRbacEnabledId, '2021-06-01').description
    policyDefinitionId: pdRbacEnabledId
    parameters: {
      effect: {
        value: 'Audit'  // This policy (as of 1.0.2) does not have a Deny option, otherwise that would be set here.
      }
    }
  }
}

// Applying the built-in 'Azure Kubernetes Service Clusters should use managed identities' policy at the resource group level.
resource paManagedIdentitiesEnabled 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: guid(pdManagedIdentitiesEnabledId, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${reference(pdManagedIdentitiesEnabledId, '2021-06-01').displayName}', 120)
    description: reference(pdManagedIdentitiesEnabledId, '2021-06-01').description
    policyDefinitionId: pdManagedIdentitiesEnabledId
    parameters: {
      effect: {
        value: 'Audit'  // This policy (as of 1.0.0) does not have a Deny option, otherwise that would be set here.
      }
    }
  }
}

// The control plane identity used by the cluster. Used for networking access (VNET joining and DNS updating)
resource miClusterControlPlane 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'mi-${clusterName}-controlplane'
  location: location
}

// User Managed Identity that App Gateway is assigned. Used for Azure Key Vault Access.
resource miAppGatewayFrontend 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'mi-appgateway-frontend'
  location: location
}

// User Managed Identity for the cluster's ingress controller pods. Used for Azure Key Vault Access
resource podmiIngressController 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'podmi-ingress-controller'
  location: location
}

resource kv 'Microsoft.KeyVault/vaults@2021-11-01-preview' = {
  name: 'kv-${clusterName}'
  location: location
  properties: {
    accessPolicies: [] // Azure RBAC is used instead
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    networkAcls: {
      bypass: 'AzureServices' // Required for AppGW communication
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
    createMode: 'default'
  }
  dependsOn: [
    miAppGatewayFrontend
    podmiIngressController
  ]

  resource kvsAppGwIngressInternalAksIngressTls 'secrets' = {
    name: 'appgw-ingress-internal-aks-ingress-tls'
    properties: {
      value: aksIngressControllerCertificate
    }
  }

  resource kvsGatewayPublicCert  'secrets' = {
    name: 'gateway-public-cert'
    properties: {
      value: appGatewayListenerCertificate
    }
  }
}

resource kv_diagnosticSettings  'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: kv
  name: 'default'
  properties: {
    workspaceId: la.id
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
}

// Grant the Azure Application Gateway managed identity with key vault reader role permissions; this allows pulling frontend and backend certificates.
resource kvMiAppGatewayFrontendSecretsUserRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: kv
  name: guid(resourceGroup().id, 'mi-appgateway-frontend', keyVaultSecretsUserRole.id)
  properties: {
    roleDefinitionId: keyVaultSecretsUserRole.id
    principalId: miAppGatewayFrontend.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Grant the Azure Application Gateway managed identity with key vault reader role permissions; this allows pulling frontend and backend certificates.
resource kvMiAppGatewayFrontendKeyVaultReader_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: kv
  name: guid(resourceGroup().id, 'mi-appgateway-frontend', keyVaultReaderRole.id)
  properties: {
    roleDefinitionId: keyVaultReaderRole.id
    principalId: miAppGatewayFrontend.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Grant the AKS cluster ingress controller pod managed identity with key vault reader role permissions; this allows our ingress controller to pull certificates.
resource kvPodMiIngressControllerSecretsUserRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: kv
  name: guid(resourceGroup().id, 'podmi-ingress-controller', keyVaultSecretsUserRole.id)
  properties: {
    roleDefinitionId: keyVaultSecretsUserRole.id
    principalId: podmiIngressController.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Grant the AKS cluster ingress controller pod managed identity with key vault reader role permissions; this allows our ingress controller to pull certificates
resource kvPodMiIngressControllerKeyVaultReader_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: kv
  name: guid(resourceGroup().id, 'podmi-ingress-controller', keyVaultReaderRole.id)
  properties: {
    roleDefinitionId: keyVaultReaderRole.id
    principalId: podmiIngressController.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

module ndEnsureClusterIdentityHasRbacToSelfManagedResources 'nested_EnsureClusterIdentityHasRbacToSelfManagedResources.bicep' = {
  name: 'EnsureClusterIdentityHasRbacToSelfManagedResources'
  scope: targetResourceGroup
  params: {
    miClusterControlPlanePrincipalId: miClusterControlPlane.properties.principalId
    clusterControlPlaneIdentityName: miClusterControlPlane.name
    targetVirtualNetworkName: targetVirtualNetwork.name
  }
}

// Enabling Azure Key Vault Private Link support.
resource pdzKv 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'

  // Enabling Azure Key Vault Private Link on cluster vnet.
  resource vnetlnk 'virtualNetworkLinks' = {
    name: 'to_${targetVirtualNetwork.name}'
    location: 'global'
    properties: {
      virtualNetwork: {
        id: targetVnetResourceId
      }
      registrationEnabled: false
    }
  }
}

resource peKv 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: 'pe-${kv.name}'
  location: location
  properties: {
    subnet: {
      id: snetPrivatelinkendpoints.id
    }
    privateLinkServiceConnections: [
      {
        name: 'to_${targetVirtualNetwork.name}'
        properties: {
          privateLinkServiceId: kv.id
          groupIds: [
            'vault'
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
    name: 'to_${targetVirtualNetwork.name}'
    location: 'global'
    properties: {
      virtualNetwork: {
        id: targetVnetResourceId
      }
      registrationEnabled: false
    }
  }
}

resource mc 'Microsoft.ContainerService/managedClusters@2022-03-02-preview' = {
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
        vnetSubnetID: snetClusterNodes.id
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
        vnetSubnetID: snetClusterNodes.id
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
          logAnalyticsWorkspaceResourceId: la.id
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
    nodeResourceGroup: nodeResourceGroup.name
    enableRBAC: true
    enablePodSecurityPolicy: false
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
        logAnalyticsWorkspaceResourceId: la.id
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

    // Azure Policy for Kubernetes policies that we'd want in place before pods start showing up
    // in the cluster.  The are not technically a depedency from the resource provider perspective,
    // but logically they need to be in place before workloads are, so focing that here. This also
    // ensures that the policies are applied to the cluster at bootstrapping time.
    paAKSLinuxRestrictive
    paAadIntegrationEnabled
    paAllowedExternalIPs
    paAllowedHostPaths
    paAuthorizedIpRangesDefined
    paAzurePolicyEnabled
    paDisallowEndpointEditPermissions
    paDisallowNamespaceUsage
    paEnforceHttpsIngress
    paEnforceImageSource
    paEnforceInternalLoadBalancers
    paEnforceResourceLimits
    paRoRootFilesystem

    // Azure Resource Provider policies that we'd like to see in place before the cluster is deployed
    // They are not technically a dependency, but logically they would have existed on the resource group
    // prior to the existence of the cluster, so forcing that here.
    paDefenderInClusterEnabled
    paAadIntegrationEnabled
    paLocalAuthDisabled
    paAzurePolicyEnabled
    paOldKuberentesDisabled
    paRbacEnabled
    paManagedIdentitiesEnabled

    peKv
    kvPodMiIngressControllerKeyVaultReader_roleAssignment
    kvPodMiIngressControllerSecretsUserRole_roleAssignment
  ]
}

resource acrKubeletAcrPullRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: acr
  name: guid(mc.id, acrPullRole.id)
  properties: {
    roleDefinitionId: acrPullRole.id
    description: 'Allows AKS to pull container images from this ACR instance.'
    principalId: mc.properties.identityProfile.kubeletidentity.objectId
    principalType: 'ServicePrincipal'
  }
}

// Grant the OMS Agent's Managed Identity the metrics publisher role to push alerts
resource mcOmsAgentMonitoringMetricsPublisherRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: mc
  name: guid(mc.id, 'omsagent', monitoringMetricsPublisherRole.id)
  properties: {
    roleDefinitionId: monitoringMetricsPublisherRole.id
    principalId: mc.properties.addonProfiles.omsagent.identity.objectId
    principalType: 'ServicePrincipal'
  }
}

// Grant the AKS cluster with Managed Identity Operator role permissions over the managed identity used for the ingress controller. Allows it to be assigned to the underlying VMSS.
resource miKubeletManagedIdentityOperatorRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  scope: podmiIngressController
  name: guid(resourceGroup().id, 'podmi-ingress-controller', managedIdentityOperatorRole.id)
  properties: {
    roleDefinitionId: managedIdentityOperatorRole.id
    principalId: mc.properties.identityProfile.kubeletidentity.objectId
    principalType: 'ServicePrincipal'
  }
}

resource mcAadAdminGroupClusterAdminRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = if (isUsingAzureRBACasKubernetesRBAC) {
  scope: mc
  name: guid('aad-admin-group', mc.id, clusterAdminAadGroupObjectId)
  properties: {
    roleDefinitionId: clusterAdminRole.id
    description: 'Members of this group are cluster admins of this cluster.'
    principalId: clusterAdminAadGroupObjectId
    principalType: 'Group'
  }
}

resource mcAadAdminGroupServiceClusterUserRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = if (isUsingAzureRBACasKubernetesRBAC) {
  scope: mc
  name: guid('aad-admin-group-sc', mc.id, clusterAdminAadGroupObjectId)
  properties: {
    roleDefinitionId: serviceClusterUserRole.id
    description: 'Members of this group are cluster users of this cluster.'
    principalId: clusterAdminAadGroupObjectId
    principalType: 'Group'
  }
}

resource maAadA0008ReaderGroupClusterReaderRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = if (isUsingAzureRBACasKubernetesRBAC && !(empty(a0008NamespaceReaderAadGroupObjectId)) && (!(a0008NamespaceReaderAadGroupObjectId == clusterAdminAadGroupObjectId))) {
  scope: nsA0008
  name: guid('aad-a0008-reader-group', mc.id, a0008NamespaceReaderAadGroupObjectId)
  properties: {
    roleDefinitionId: clusterReaderRole.id
    description: 'Members of this group are readers of the a0008 namespace in this cluster.'
    principalId: a0008NamespaceReaderAadGroupObjectId
    principalType: 'Group'
  }
}

resource maAadA0008ReaderGroupServiceClusterUserRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = if (isUsingAzureRBACasKubernetesRBAC && !(empty(a0008NamespaceReaderAadGroupObjectId)) && (!(a0008NamespaceReaderAadGroupObjectId == clusterAdminAadGroupObjectId))) {
  scope: mc
  name: guid('aad-a0008-reader-group-sc', mc.id, a0008NamespaceReaderAadGroupObjectId)
  properties: {
    roleDefinitionId: serviceClusterUserRole.id
    description: 'Members of this group are cluster users of this cluster.'
    principalId: a0008NamespaceReaderAadGroupObjectId
    principalType: 'Group'
  }
}

resource mc_diagnosticSettings  'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: mc
  name: 'default'
  properties: {
    workspaceId: la.id
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
      {
        category: 'kube-scheduler'
        enabled: false // Only enable while tuning or triaging issues with scheduling. On a normally operating cluster there is minimal value, relative to the log capture cost, to keeping this always enabled.
      }
    ]
  }
}

// Ensures that flux add-on (extension) is installed.
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

// Bootstraps your cluster using content from your repo.
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
  scope: nodeResourceGroup
  params: {
    kubeletidentityObjectId: mc.properties.identityProfile.kubeletidentity.objectId
  }
}

resource st 'Microsoft.EventGrid/systemTopics@2021-12-01' = {
  name: clusterName
  location: location
  properties: {
    source: mc.id
    topicType: 'Microsoft.ContainerService.ManagedClusters'
  }
}

resource st_diagnosticSettings  'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: st
  name: 'default'
  properties: {
    workspaceId: la.id
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
}

resource wafPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2021-05-01' = {
  name: 'waf-${clusterName}'
  location: location
  properties: {
    policySettings: {
      fileUploadLimitInMb: 10
      state: 'Enabled'
      mode: 'Prevention'
    }
    managedRules: {
      managedRuleSets: [
        {
            ruleSetType: 'OWASP'
            ruleSetVersion: '3.2'
            ruleGroupOverrides: []
        }
        {
          ruleSetType: 'Microsoft_BotManagerRuleSet'
          ruleSetVersion: '0.1'
          ruleGroupOverrides: []
        }
      ]
    }
  }
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
          keyVaultSecretId: kv::kvsAppGwIngressInternalAksIngressTls.properties.secretUri
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
            id: resourceId(subscription().subscriptionId, targetResourceGroup.name, 'Microsoft.Network/publicIpAddresses', 'pip-BU0001A0008-00')
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
    firewallPolicy: {
      id: wafPolicy.id
    }
    enableHttp2: false
    sslCertificates: [
      {
        name: '${agwName}-ssl-certificate'
        properties: {
          keyVaultSecretId: kv::kvsGatewayPublicCert.properties.secretUri
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
    workspaceId: la.id
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
}

/*** OUTPUTS ***/

output aksClusterName string = clusterName
output aksIngressControllerPodManagedIdentityResourceId string = podmiIngressController.id
output aksIngressControllerPodManagedIdentityClientId string = podmiIngressController.properties.clientId
output aksOidcIssuerUrl string = mc.properties.oidcIssuerProfile.issuerURL
output keyVaultName string = kv.name

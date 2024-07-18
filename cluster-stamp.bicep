targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('The regional network spoke VNet Resource ID that the cluster will be joined to')
@minLength(79)
param targetVnetResourceId string

@description('Microsoft Entra group in the identified tenant that will be granted the highly privileged cluster-admin role. If Azure RBAC is used, then this group will get a role assignment to Azure RBAC, else it will be assigned directly to the cluster\'s admin group.')
param clusterAdminMicrosoftEntraGroupObjectId string

@description('Microsoft Entra group in the identified tenant that will be granted the read only privileges in the a0008 namespace that exists in the cluster. This is only used when Azure RBAC is used for Kubernetes RBAC.')
param a0008NamespaceReaderMicrosoftEntraGroupObjectId string

@description('Your AKS control plane Cluster API authentication tenant')
param k8sControlPlaneAuthorizationTenantId string

@description('The PFX certificate for app gateway TLS termination. It is base64')
@secure()
param appGatewayListenerCertificate string

@description('The Base64 encoded AKS Ingress Controller public certificate (as .crt or .cer) to be stored in Azure Key Vault as secret and referenced by Azure Application Gateway as a trusted root certificate.')
param aksIngressControllerCertificate string

@description('IP ranges authorized to contact the Kubernetes API server. Passing an empty array will result in no IP restrictions. If any are provided, remember to also provide the public IP of the egress Azure Firewall otherwise your nodes will not be able to talk to the API server (e.g. Flux).')
param clusterAuthorizedIPRanges array = []

@description('AKS Service, Node Pool, and supporting services (KeyVault, App Gateway, etc) region. This needs to be the same region as the vnet provided in these parameters. This defaults to the resource group\'s location for higher reliability.')
param location string = resourceGroup().location

param kubernetesVersion string = '1.29'

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
resource psdAKSLinuxRestrictive 'Microsoft.Authorization/policySetDefinitions@2021-06-01' existing = {
  name: '42b8ef37-b724-4e24-bbc8-7a7708edfe00'
  scope: tenant()
}

// Built-in 'Kubernetes clusters should be accessible only over HTTPS' Azure Policy for Kubernetes policy definition
resource pdEnforceHttpsIngress 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: '1a5b4dca-0b6f-4cf5-907c-56316bc1bf3d'
  scope: tenant()
}

// Built-in 'Kubernetes clusters should use internal load balancers' Azure Policy for Kubernetes policy definition
resource pdEnforceInternalLoadBalancers 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: '3fc4dc25-5baf-40d8-9b05-7fe74c1bc64e'
  scope: tenant()
}

// Built-in 'Kubernetes cluster containers should run with a read only root file system' Azure Policy for Kubernetes policy definition
resource pdRoRootFilesystem 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: 'df49d893-a74c-421d-bc95-c663042e5b80'
  scope: tenant()
}

// Built-in 'AKS container CPU and memory resource limits should not exceed the specified limits' Azure Policy for Kubernetes policy definition
resource pdEnforceResourceLimits 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: 'e345eecc-fa47-480f-9e88-67dcc122b164'
  scope: tenant()
}

// Built-in 'AKS containers should only use allowed images' Azure Policy for Kubernetes policy definition
resource pdEnforceImageSource 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: 'febd0533-8e55-448f-b837-bd0e06f16469'
  scope: tenant()
}

// Built-in 'Kubernetes cluster pod hostPath volumes should only use allowed host paths' Azure Policy for Kubernetes policy definition
resource pdAllowedHostPaths 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: '098fc59e-46c7-4d99-9b16-64990e543d75'
  scope: tenant()
}

// Built-in 'Kubernetes cluster services should only use allowed external IPs' Azure Policy for Kubernetes policy definition
resource pdAllowedExternalIPs 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: 'd46c275d-1680-448d-b2ec-e495a3b6cc89'
  scope: tenant()
}

// Built-in 'Kubernetes clusters should not allow endpoint edit permissions of ClusterRole/system:aggregate-to-edit' Azure Policy for Kubernetes policy definition
resource pdDisallowEndpointEditPermissions 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: '1ddac26b-ed48-4c30-8cc5-3a68c79b8001'
  scope: tenant()
}

// Built-in 'Kubernetes clusters should not use the default namespace' Azure Policy for Kubernetes policy definition
resource pdDisallowNamespaceUsage 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: '9f061a12-e40d-4183-a00e-171812443373'
  scope: tenant()
}

// Built-in 'Azure Kubernetes Service clusters should have Defender profile enabled' Azure Policy policy definition
resource pdDefenderInClusterEnabled 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: 'a1840de2-8088-4ea8-b153-b4c723e9cb01'
  scope: tenant()
}

// Built-in 'Azure Kubernetes Service Clusters should enable Microsoft Entra ID integration' Azure Policy policy definition
resource pdEntraIdIntegrationEnabled 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: '450d2877-ebea-41e8-b00c-e286317d21bf'
  scope: tenant()
}

// Built-in 'Azure Kubernetes Service Clusters should have local authentication methods disabled' Azure Policy policy definition
resource pdLocalAuthDisabled 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: '993c2fcd-2b29-49d2-9eb0-df2c3a730c32'
  scope: tenant()
}

// Built-in 'Azure Policy Add-on for Kubernetes service (AKS) should be installed and enabled on your clusters' Azure Policy policy definition
resource pdAzurePolicyEnabled 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: '0a15ec92-a229-4763-bb14-0ea34a568f8d'
  scope: tenant()
}

// Built-in 'Authorized IP ranges should be defined on Kubernetes Services' Azure Policy policy definition
resource pdAuthorizedIpRangesDefined 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: '0e246bcf-5f6f-4f87-bc6f-775d4712c7ea'
  scope: tenant()
}

// Built-in 'Kubernetes Services should be upgraded to a non-vulnerable Kubernetes version' Azure Policy policy definition
resource pdOldKuberentesDisabled 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: 'fb893a29-21bb-418c-a157-e99480ec364c'
  scope: tenant()
}

// Built-in 'Role-Based Access Control (RBAC) should be used on Kubernetes Services' Azure Policy policy definition
resource pdRbacEnabled 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: 'ac4a19c2-fa67-49b4-8ae5-0b2e78c49457'
  scope: tenant()
}

// Built-in 'Azure Kubernetes Service Clusters should use managed identities' Azure Policy policy definition
resource pdManagedIdentitiesEnabled 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: 'da6e2401-19da-4532-9141-fb8fbde08431'
  scope: tenant()
}

/*** EXISTING SUBSCRIPTION RESOURCES ***/

resource nodeResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: 'rg-${clusterName}-nodepools'
  scope: subscription()
}

// Built-in Azure RBAC role that is applied to a cluster to indicate they can be considered a user/group of the cluster, subject to additional RBAC permissions
resource serviceClusterUserRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '4abbcc35-e782-43d8-92c5-2d3f1bd2253f'
  scope: subscription()
}

// Built-in Azure RBAC role that can be applied to a cluster or a namespace to grant read and write privileges to that scope for a user or group
resource clusterAdminRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'b1ff04bb-8a4e-4dc4-8eb5-8693973ce19b'
  scope: subscription()
}

// Built-in Azure RBAC role that can be applied to a cluster or a namespace to grant read privileges to that scope for a user or group
resource clusterReaderRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '7f6c6a51-bcf8-42ba-9220-52d62157d7db'
  scope: subscription()
}

// Built-in Azure RBAC role that is applied to a cluster to grant its monitoring agent's identity with publishing metrics and push alerts permissions.
resource monitoringMetricsPublisherRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '3913510d-42f4-4e42-8a64-420c390055eb'
  scope: subscription()
}

// Built-in Azure RBAC role that can be applied to an Azure Container Registry to grant the authority pull container images. Granted to the AKS cluster's kubelet identity.
resource acrPullRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
  scope: subscription()
}

// Built-in Azure RBAC role that is applied a Key Vault to grant with metadata, certificates, keys and secrets read privileges.  Granted to App Gateway's managed identity.
resource keyVaultReaderRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '21090545-7ca7-4776-b22c-e363652d74d2'
  scope: subscription()
}

// Built-in Azure RBAC role that is applied to a Key Vault to grant with secrets content read privileges. Granted to both Key Vault and our workload's identity.
resource keyVaultSecretsUserRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '4633458b-17de-408a-b874-0445c86b69e6'
  scope: subscription()
}

/*** EXISTING RESOURCE GROUP RESOURCES ***/

// Useful to think of these as resources that are not tied to the lifecycle of any individual
// cluster. Logging sinks, container registries, backup destinations, etc are typical
// resources that would exist before & after any individual cluster is deployed or is removed
// from the solution.

// Azure Container Registry
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  scope: resourceGroup()
  name: 'acraks${subRgUniqueString}'
}

// Log Analytics Workspace
resource la 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
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
resource targetResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  scope: subscription()
  name: split(targetVnetResourceId, '/')[4]
}

// Spoke virtual network
resource targetVirtualNetwork 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  scope: targetResourceGroup
  name: last(split(targetVnetResourceId, '/'))

  // Spoke virutual network's subnet for the cluster nodes
  resource snetClusterNodes 'subnets' existing = {
    name: 'snet-clusternodes'
  }

  // Spoke virutual network's subnet for all private endpoints
  resource snetPrivatelinkendpoints 'subnets' existing = {
    name: 'snet-privatelinkendpoints'
  }

  // Spoke virutual network's subnet for application gateway
  resource snetApplicationGateway 'subnets' existing = {
    name: 'snet-applicationgateway'
  }
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
  name: 'Container CPU usage violates the configured threshold for ${clusterName} CI-19'
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
          metricName: 'cpuThresholdViolated'
          metricNamespace: 'Insights.Container/containers'
          name: 'Metric1'
          operator: 'GreaterThan'
          threshold: 0  // This threshold is defined in the container-azm-ms-agentconfig.yaml file.
          timeAggregation: 'Average'
          skipMetricValidation: true
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'This alert monitors container CPU usage. It uses the threshold defined in the config map.'
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
  name: 'Container working set memory usage violates the configured threshold for ${clusterName} CI-20'
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
          metricName: 'memoryWorkingSetThresholdViolated'
          metricNamespace: 'Insights.Container/containers'
          name: 'Metric1'
          operator: 'GreaterThan'
          threshold: 0  // This threshold is defined in the container-azm-ms-agentconfig.yaml file.
          timeAggregation: 'Average'
          skipMetricValidation: true
        }
      ]
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
    }
    description: 'This alert monitors container working set memory usage. It uses the threshold defined in the config map.'
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

resource sqrPodFailed 'Microsoft.Insights/scheduledQueryRules@2022-06-15' = {
  name: 'PodFailedScheduledQuery'
  location: location
  properties: {
    autoMitigate: true
    displayName: '[${clusterName}] Scheduled Query for Pod Failed Alert'
    description: 'Alert on pod Failed phase.'
    severity: 3
    enabled: true
    scopes: [
      la.id
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT10M'
    criteria: {
      allOf: [
        {
          query: '//https://learn.microsoft.com/azure/azure-monitor/insights/container-insights-alerts \r\n let endDateTime = now(); let startDateTime = ago(1h); let trendBinSize = 1m; let clusterName = "${clusterName}"; KubePodInventory | where TimeGenerated < endDateTime | where TimeGenerated >= startDateTime | where ClusterName == clusterName | distinct ClusterName, TimeGenerated | summarize ClusterSnapshotCount = count() by bin(TimeGenerated, trendBinSize), ClusterName | join hint.strategy=broadcast ( KubePodInventory | where TimeGenerated < endDateTime | where TimeGenerated >= startDateTime | distinct ClusterName, Computer, PodUid, TimeGenerated, PodStatus | summarize TotalCount = count(), PendingCount = sumif(1, PodStatus =~ "Pending"), RunningCount = sumif(1, PodStatus =~ "Running"), SucceededCount = sumif(1, PodStatus =~ "Succeeded"), FailedCount = sumif(1, PodStatus =~ "Failed") by ClusterName, bin(TimeGenerated, trendBinSize) ) on ClusterName, TimeGenerated | extend UnknownCount = TotalCount - PendingCount - RunningCount - SucceededCount - FailedCount | project TimeGenerated, TotalCount = todouble(TotalCount) / ClusterSnapshotCount, PendingCount = todouble(PendingCount) / ClusterSnapshotCount, RunningCount = todouble(RunningCount) / ClusterSnapshotCount, SucceededCount = todouble(SucceededCount) / ClusterSnapshotCount, FailedCount = todouble(FailedCount) / ClusterSnapshotCount, UnknownCount = todouble(UnknownCount) / ClusterSnapshotCount| summarize AggregatedValue = avg(FailedCount) by bin(TimeGenerated, trendBinSize)'
          metricMeasureColumn: 'AggregatedValue'
          operator: 'GreaterThan'
          threshold: 3
          timeAggregation: 'Average'
          failingPeriods: {
            minFailingPeriodsToAlert: 2
            numberOfEvaluationPeriods: 2
          }
        }
      ]
    }
  }
}

// Resource Group Azure Policy Assignments - Azure Policy for Kubernetes Policies

// Applying the built-in 'Kubernetes cluster pod security restricted standards for Linux-based workloads' initiative at the resource group level.
// Constraint Names: K8sAzureAllowedSeccomp, K8sAzureAllowedCapabilities, K8sAzureContainerNoPrivilege, K8sAzureHostNetworkingPorts, K8sAzureVolumeTypes, K8sAzureBlockHostNamespaceV2, K8sAzureAllowedUsersGroups, K8sAzureContainerNoPrivilegeEscalation
resource paAKSLinuxRestrictive 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: guid(psdAKSLinuxRestrictive.id, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${psdAKSLinuxRestrictive.properties.displayName}', 120)
    description: psdAKSLinuxRestrictive.properties.description
    policyDefinitionId: psdAKSLinuxRestrictive.id
    parameters: {
      excludedNamespaces: {
        value: [
          'kube-system'
          'gatekeeper-system'
          'azure-arc'
          'flux-system'

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
resource paEnforceHttpsIngress 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: guid(pdEnforceHttpsIngress.id, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${pdEnforceHttpsIngress.properties.displayName}', 120)
    description: pdEnforceHttpsIngress.properties.description
    policyDefinitionId: pdEnforceHttpsIngress.id
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
resource paEnforceInternalLoadBalancers 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: guid(pdEnforceInternalLoadBalancers.id, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${pdEnforceInternalLoadBalancers.properties.displayName}', 120)
    description: pdEnforceInternalLoadBalancers.properties.description
    policyDefinitionId: pdEnforceInternalLoadBalancers.id
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
resource paRoRootFilesystem 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: guid(pdRoRootFilesystem.id, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${pdRoRootFilesystem.properties.displayName}', 120)
    description: pdRoRootFilesystem.properties.description
    policyDefinitionId: pdRoRootFilesystem.id
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
resource paEnforceResourceLimits 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: guid(pdEnforceResourceLimits.id, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${pdEnforceResourceLimits.properties.displayName}', 120)
    description: pdEnforceResourceLimits.properties.description
    policyDefinitionId: pdEnforceResourceLimits.id
    parameters: {
      cpuLimit: {
        value: '500m' // traefik-ingress-controller = 200m, aspnet-webapp-sample = 100m
      }
      memoryLimit: {
        value: '256Mi' // aspnet-webapp-sample = 256Mi, traefik-ingress-controller = 128Mi
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
resource paEnforceImageSource 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: guid(pdEnforceImageSource.id, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${pdEnforceImageSource.properties.displayName}', 120)
    description: pdEnforceImageSource.properties.description
    policyDefinitionId: pdEnforceImageSource.id
    parameters: {
      allowedContainerImagesRegex: {
        // If all images are pull into your ARC instance as described in these instructions you can remove the docker.io & ghcr.io entries.
        value: '${acr.name}\\.azurecr\\.io/.+$|mcr\\.microsoft\\.com/.+$|docker\\.io/library/.+$'
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
resource paAllowedHostPaths 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: guid(pdAllowedHostPaths.id, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${pdAllowedHostPaths.properties.displayName}', 120)
    description: pdAllowedHostPaths.properties.description
    policyDefinitionId: pdAllowedHostPaths.id
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
      effect: {
        value: 'Deny'
      }
    }
  }
}

// Applying the built-in 'Kubernetes cluster services should only use allowed external IPs' policy at the resource group level.
// Constraint Name: K8sAzureExternalIPs
resource paAllowedExternalIPs 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: guid(pdAllowedExternalIPs.id, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${pdAllowedExternalIPs.properties.displayName}', 120)
    description: pdAllowedExternalIPs.properties.description
    policyDefinitionId: pdAllowedExternalIPs.id
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
resource paDisallowEndpointEditPermissions 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: guid(pdDisallowEndpointEditPermissions.id, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${pdDisallowEndpointEditPermissions.properties.displayName}', 120)
    description: pdDisallowEndpointEditPermissions.properties.description
    policyDefinitionId: pdDisallowEndpointEditPermissions.id
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
resource paDisallowNamespaceUsage 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: guid(pdDisallowNamespaceUsage.id, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${pdDisallowNamespaceUsage.properties.displayName}', 120)
    description: pdDisallowNamespaceUsage.properties.description
    policyDefinitionId: pdDisallowNamespaceUsage.id
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
resource paDefenderInClusterEnabled 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: guid(pdDefenderInClusterEnabled.id, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${pdDefenderInClusterEnabled.properties.displayName}', 120)
    description: pdDefenderInClusterEnabled.properties.description
    policyDefinitionId: pdDefenderInClusterEnabled.id
    parameters: {
      effect: {
        value: 'Audit' // This policy (as of 1.0.2-preview) does not have a Deny option, otherwise that would be set here.
      }
    }
  }
}

// Applying the built-in 'Azure Kubernetes Service Clusters should enable Microsoft Entra ID integration' policy at the resource group level.
resource paMicrosoftEntraIdIntegrationEnabled 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: guid(pdEntraIdIntegrationEnabled.id, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${pdEntraIdIntegrationEnabled.properties.displayName}', 120)
    description: pdEntraIdIntegrationEnabled.properties.description
    policyDefinitionId: pdEntraIdIntegrationEnabled.id
    parameters: {
      effect: {
        value: 'Audit' // This policy (as of 1.0.0) does not have a Deny option, otherwise that would be set here.
      }
    }
  }
}

// Applying the built-in 'Azure Kubernetes Service Clusters should have local authentication methods disabled' policy at the resource group level.
resource paLocalAuthDisabled 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: guid(pdLocalAuthDisabled.id, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${pdLocalAuthDisabled.properties.displayName}', 120)
    description: pdLocalAuthDisabled.properties.description
    policyDefinitionId: pdLocalAuthDisabled.id
    parameters: {
      effect: {
        value: 'Deny'
      }
    }
  }
}

// Applying the built-in 'Azure Policy Add-on for Kubernetes service (AKS) should be installed and enabled on your clusters' policy at the resource group level.
resource paAzurePolicyEnabled 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: guid(pdAzurePolicyEnabled.id, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${pdAzurePolicyEnabled.properties.displayName}', 120)
    description: pdAzurePolicyEnabled.properties.description
    policyDefinitionId: pdAzurePolicyEnabled.id
    parameters: {
      effect: {
        value: 'Audit'  // This policy (as of 1.0.2) does not have a Deny option, otherwise that would be set here.
      }
    }
  }
}

// Applying the built-in 'Authorized IP ranges should be defined on Kubernetes Services' policy at the resource group level.
resource paAuthorizedIpRangesDefined 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: guid(pdAuthorizedIpRangesDefined.id, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${pdAuthorizedIpRangesDefined.properties.displayName}', 120)
    description: pdAuthorizedIpRangesDefined.properties.description
    policyDefinitionId: pdAuthorizedIpRangesDefined.id
    parameters: {
      effect: {
        value: 'Audit'  // This policy (as of 2.0.1) does not have a Deny option, otherwise that would be set here.
      }
    }
  }
}

// Applying the built-in 'Kubernetes Services should be upgraded to a non-vulnerable Kubernetes version' policy at the resource group level.
resource paOldKuberentesDisabled 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: guid(pdOldKuberentesDisabled.id, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${pdOldKuberentesDisabled.properties.displayName}', 120)
    description: pdOldKuberentesDisabled.properties.description
    policyDefinitionId: pdOldKuberentesDisabled.id
    parameters: {
      effect: {
        value: 'Audit'  // This policy (as of 1.0.2) does not have a Deny option, otherwise that would be set here.
      }
    }
  }
}

// Applying the built-in 'Role-Based Access Control (RBAC) should be used on Kubernetes Services' policy at the resource group level.
resource paRbacEnabled 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: guid(pdRbacEnabled.id, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${pdRbacEnabled.properties.displayName}', 120)
    description: pdRbacEnabled.properties.description
    policyDefinitionId: pdRbacEnabled.id
    parameters: {
      effect: {
        value: 'Audit'  // This policy (as of 1.0.2) does not have a Deny option, otherwise that would be set here.
      }
    }
  }
}

// Applying the built-in 'Azure Kubernetes Service Clusters should use managed identities' policy at the resource group level.
resource paManagedIdentitiesEnabled 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: guid(pdManagedIdentitiesEnabled.id, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${pdManagedIdentitiesEnabled.properties.displayName}', 120)
    description: pdManagedIdentitiesEnabled.properties.description
    policyDefinitionId: pdManagedIdentitiesEnabled.id
    parameters: {
      effect: {
        value: 'Audit'  // This policy (as of 1.0.0) does not have a Deny option, otherwise that would be set here.
      }
    }
  }
}

// Deploying and applying the custom policy 'Kubernetes cluster ingress TLS hosts must have defined domain suffix' as defined in nested_K8sCustomIngressTlsHostsHaveDefinedDomainSuffix.bicep
// Note: Policy definition must be deployed as module since policy definitions require a targetScope of 'subscription'.

module modK8sIngressTlsHostsHaveDefinedDomainSuffix 'nested_K8sCustomIngressTlsHostsHaveDefinedDomainSuffix.bicep' = {
  name: 'modK8sIngressTlsHostsHaveDefinedDomainSuffix'
  scope: subscription()
}

resource paK8sIngressTlsHostsHaveSpecificDomainSuffix 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: guid('K8sCustomIngressTlsHostsHaveDefinedDomainSuffix', resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${modK8sIngressTlsHostsHaveDefinedDomainSuffix.outputs.policyName}', 120)
    description: modK8sIngressTlsHostsHaveDefinedDomainSuffix.outputs.policyDescription
    policyDefinitionId: modK8sIngressTlsHostsHaveDefinedDomainSuffix.outputs.policyId
    parameters: {
      excludedNamespaces: {
        value: []
      }
      effect: {
        value: 'deny'
      }
      allowedDomainSuffixes: {
        value: [
          domainName
        ]
      }
    }
  }
}

// The control plane identity used by the cluster. Used for networking access (VNET joining and DNS updating)
resource miClusterControlPlane 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'mi-${clusterName}-controlplane'
  location: location
}

// User Managed Identity that App Gateway is assigned. Used for Azure Key Vault Access.
resource miAppGatewayFrontend 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'mi-appgateway-frontend'
  location: location
}

// User Managed Identity for the cluster's ingress controller pods via Workload Identity. Used for Azure Key Vault Access.
resource podmiIngressController 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'podmi-ingress-controller'
  location: location

  // Workload identity service account federation
  resource federatedCreds 'federatedIdentityCredentials' = {
    name: 'ingress-controller'
    properties: {
      issuer: mc.properties.oidcIssuerProfile.issuerURL
      subject: 'system:serviceaccount:a0008:traefik-ingress-controller'
      audiences: [
        'api://AzureADTokenExchange'
      ]
    }
  }
}

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
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

  resource kvsGatewayExternalCert 'secrets' = {
    name: 'gateway-external-pfx-cert'
    properties: {
      value: appGatewayListenerCertificate
    }
  }
}

resource kv_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
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
resource kvMiAppGatewayFrontendSecretsUserRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: kv
  name: guid(resourceGroup().id, 'mi-appgateway-frontend', keyVaultSecretsUserRole.id)
  properties: {
    roleDefinitionId: keyVaultSecretsUserRole.id
    principalId: miAppGatewayFrontend.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Grant the Azure Application Gateway managed identity with key vault reader role permissions; this allows pulling frontend and backend certificates.
resource kvMiAppGatewayFrontendKeyVaultReader_roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: kv
  name: guid(resourceGroup().id, 'mi-appgateway-frontend', keyVaultReaderRole.id)
  properties: {
    roleDefinitionId: keyVaultReaderRole.id
    principalId: miAppGatewayFrontend.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Grant the AKS cluster ingress controller's managed workload identity with Key Vault reader role permissions; this allows our ingress controller to pull certificates.
resource kvPodMiIngressControllerSecretsUserRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: kv
  name: guid(resourceGroup().id, 'podmi-ingress-controller', keyVaultSecretsUserRole.id)
  properties: {
    roleDefinitionId: keyVaultSecretsUserRole.id
    principalId: podmiIngressController.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Grant the AKS cluster ingress controller's managed workload identity with Key Vault reader role permissions; this allows our ingress controller to pull certificates
resource kvPodMiIngressControllerKeyVaultReader_roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
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
        id: targetVirtualNetwork.id
      }
      registrationEnabled: false
    }
  }
}

resource peKv 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: 'pe-${kv.name}'
  location: location
  properties: {
    subnet: {
      id: targetVirtualNetwork::snetPrivatelinkendpoints.id
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
        id: targetVirtualNetwork.id
      }
      registrationEnabled: false
    }
  }
}

resource mc 'Microsoft.ContainerService/managedClusters@2024-03-02-preview' = {
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
        osSKU: 'AzureLinux'
        minCount: 3
        maxCount: 4
        vnetSubnetID: targetVirtualNetwork::snetClusterNodes.id
        enableAutoScaling: true
        enableFIPS: false
        enableEncryptionAtHost: false
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
        osSKU: 'AzureLinux'
        minCount: 2
        maxCount: 5
        vnetSubnetID: targetVirtualNetwork::snetClusterNodes.id
        enableAutoScaling: true
        enableFIPS: false
        enableEncryptionAtHost: false
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
      ingressApplicationGateway: {
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
      openServiceMesh: {
        enabled: false
      }
      kubeDashboard: {
        enabled: false
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
      loadBalancerProfile: null
      serviceCidr: '172.16.0.0/16'
      dnsServiceIP: '172.16.0.10'
    }
    aadProfile: {
      managed: true
      enableAzureRBAC: isUsingAzureRBACasKubernetesRBAC
      adminGroupObjectIDs: ((!isUsingAzureRBACasKubernetesRBAC) ? array(clusterAdminMicrosoftEntraGroupObjectId) : [])
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
      enabled: false // Using Microsoft Entra Workload IDs for pod identities.
    }
    autoUpgradeProfile: {
      nodeOSUpgradeChannel: 'NodeImage'
      upgradeChannel: 'none'
    }
    azureMonitorProfile: {
      metrics: {
        enabled: false // This is for the AKS-PrometheusAddonPreview, which is not enabled in this cluster as Container Insights is already collecting.
      }
    }
    storageProfile: {  // By default, do not support native state storage, enable as needed to support workloads that require state
      blobCSIDriver: {
        enabled: false // Azure Blobs
      }
      diskCSIDriver: {
        enabled: false // Azure Disk
      }
      fileCSIDriver: {
        enabled: false // Azure Files
      }
      snapshotController: {
        enabled: false // CSI Snapshotter: https://github.com/kubernetes-csi/external-snapshotter
      }
    }
    workloadAutoScalerProfile: {
      keda: {
        enabled: false // Enable if using KEDA to scale workloads
      }
    }
    disableLocalAccounts: true
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
      imageCleaner: {
        enabled: true
        intervalHours: 120 // 5 days
      }
      azureKeyVaultKms: {
        enabled: false // Not enabled in the this deployment, as it is not used. Enable as needed.
      }
      nodeRestriction: {
        enabled: true // https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#noderestriction
      }
      defender: {
        logAnalyticsWorkspaceResourceId: la.id
        securityMonitoring: {
          enabled: true
        }
      }
    }
    oidcIssuerProfile: {
      enabled: true
    }
    ingressProfile: {
      webAppRouting: {
        enabled: false
      }
    }
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${miClusterControlPlane.id}': {}
    }
  }
  sku: {
    name: 'Base'
    tier: 'Standard'
  }
  dependsOn: [
    sci

    ndEnsureClusterIdentityHasRbacToSelfManagedResources

    // Azure Policy for Kubernetes policies that we'd want in place before pods start showing up
    // in the cluster.  The are not technically a dependency from the resource provider perspective,
    // but logically they need to be in place before workloads are, so forcing that here. This also
    // ensures that the policies are applied to the cluster at bootstrapping time.
    paAKSLinuxRestrictive
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
    paK8sIngressTlsHostsHaveSpecificDomainSuffix

    // Azure Resource Provider policies that we'd like to see in place before the cluster is deployed
    // They are not technically a dependency, but logically they would have existed on the resource group
    // prior to the existence of the cluster, so forcing that here.
    paDefenderInClusterEnabled
    paMicrosoftEntraIdIntegrationEnabled
    paLocalAuthDisabled
    paAzurePolicyEnabled
    paOldKuberentesDisabled
    paRbacEnabled
    paManagedIdentitiesEnabled

    peKv
    kvPodMiIngressControllerKeyVaultReader_roleAssignment
    kvPodMiIngressControllerSecretsUserRole_roleAssignment
  ]

  resource os_maintenanceConfigurations 'maintenanceConfigurations' = {
    name: 'aksManagedNodeOSUpgradeSchedule'
    properties: {
      maintenanceWindow: {
        durationHours: 12
        schedule: {
          weekly: {
            dayOfWeek: 'Tuesday'
            intervalWeeks: 1
          }
        }
        startTime: '21:00'
      }
    }
  }
}

resource acrKubeletAcrPullRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: acr
  name: guid(mc.id, acrPullRole.id)
  properties: {
    roleDefinitionId: acrPullRole.id
    description: 'Allows AKS to pull container images from this ACR instance.'
    principalId: mc.properties.identityProfile.kubeletidentity.objectId
    principalType: 'ServicePrincipal'
  }
}

// Grant the Azure Monitor (fka as OMS) Agent's Managed Identity the metrics publisher role to push alerts
resource mcAmaAgentMonitoringMetricsPublisherRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: mc
  name: guid(mc.id, 'amagent', monitoringMetricsPublisherRole.id)
  properties: {
    roleDefinitionId: monitoringMetricsPublisherRole.id
    principalId: mc.properties.addonProfiles.omsagent.identity.objectId
    principalType: 'ServicePrincipal'
  }
}

resource mcMicrosoftEntraAdminGroupClusterAdminRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (isUsingAzureRBACasKubernetesRBAC) {
  scope: mc
  name: guid('microsoft-entra-admin-group', mc.id, clusterAdminMicrosoftEntraGroupObjectId)
  properties: {
    roleDefinitionId: clusterAdminRole.id
    description: 'Members of this group are cluster admins of this cluster.'
    principalId: clusterAdminMicrosoftEntraGroupObjectId
    principalType: 'Group'
  }
}

resource mcMicrosoftEntraAdminGroupServiceClusterUserRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (isUsingAzureRBACasKubernetesRBAC) {
  scope: mc
  name: guid('microsoft-entra-admin-group-sc', mc.id, clusterAdminMicrosoftEntraGroupObjectId)
  properties: {
    roleDefinitionId: serviceClusterUserRole.id
    description: 'Members of this group are cluster users of this cluster.'
    principalId: clusterAdminMicrosoftEntraGroupObjectId
    principalType: 'Group'
  }
}

resource maMicrosoftEntraA0008ReaderGroupClusterReaderRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (isUsingAzureRBACasKubernetesRBAC && !(empty(a0008NamespaceReaderMicrosoftEntraGroupObjectId)) && (!(a0008NamespaceReaderMicrosoftEntraGroupObjectId == clusterAdminMicrosoftEntraGroupObjectId))) {
  scope: nsA0008
  name: guid('microsoft-entra-a0008-reader-group', mc.id, a0008NamespaceReaderMicrosoftEntraGroupObjectId)
  properties: {
    roleDefinitionId: clusterReaderRole.id
    description: 'Members of this group are readers of the a0008 namespace in this cluster.'
    principalId: a0008NamespaceReaderMicrosoftEntraGroupObjectId
    principalType: 'Group'
  }
}

resource maMicrosoftEntraA0008ReaderGroupServiceClusterUserRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (isUsingAzureRBACasKubernetesRBAC && !(empty(a0008NamespaceReaderMicrosoftEntraGroupObjectId)) && (!(a0008NamespaceReaderMicrosoftEntraGroupObjectId == clusterAdminMicrosoftEntraGroupObjectId))) {
  scope: mc
  name: guid('microsoft-entra-a0008-reader-group-sc', mc.id, a0008NamespaceReaderMicrosoftEntraGroupObjectId)
  properties: {
    roleDefinitionId: serviceClusterUserRole.id
    description: 'Members of this group are cluster users of this cluster.'
    principalId: a0008NamespaceReaderMicrosoftEntraGroupObjectId
    principalType: 'Group'
  }
}

resource mc_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
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
resource mcFlux_extension 'Microsoft.KubernetesConfiguration/extensions@2023-05-01' = {
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
      'notification-controller.enabled': 'true'  // As of testing on 29-Dec, this is required to avoid an error.  Normally it's not a required controller. YMMV
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
resource mc_fluxConfiguration 'Microsoft.KubernetesConfiguration/fluxConfigurations@2023-05-01' = {
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
        retryIntervalInSeconds: 300
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

resource st 'Microsoft.EventGrid/systemTopics@2022-06-15' = {
  name: clusterName
  location: location
  properties: {
    source: mc.id
    topicType: 'Microsoft.ContainerService.ManagedClusters'
  }
}

resource st_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
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

resource wafPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2023-11-01' = {
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
          ruleSetVersion: '1.0'
          ruleGroupOverrides: []
        }
      ]
    }
  }
}

resource agw 'Microsoft.Network/applicationGateways@2023-11-01' = {
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
            id: targetVirtualNetwork::snetApplicationGateway.id
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
          keyVaultSecretId: kv::kvsGatewayExternalCert.properties.secretUri
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
          priority: 100
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
output aksIngressControllerPodManagedIdentityClientId string = podmiIngressController.properties.clientId
output keyVaultName string = kv.name

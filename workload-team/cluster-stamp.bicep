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

@description('Domain name to use for App Gateway and AKS ingress.')
param domainName string = 'contoso.com'

@description('Your cluster will be bootstrapped from this git repo.')
@minLength(9)
param gitOpsBootstrappingRepoHttpsUrl string = 'https://github.com/mspnp/aks-baseline'

@description('You cluster will be bootstrapped from this branch in the identified git repo.')
@minLength(1)
param gitOpsBootstrappingRepoBranch string = 'main'

@description('The AKS cluster Internal Load Balancer IP Address')
param clusterInternalLoadBalancerIpAddress string = '10.240.4.4'

/*** VARIABLES ***/

var subRgUniqueString = uniqueString('aks', subscription().subscriptionId, resourceGroup().id)
var clusterName = 'aks-${subRgUniqueString}'
var agwName = 'apw-${clusterName}'

var aksIngressDomainName = 'aks-ingress.${domainName}'
var aksBackendDomainName = 'bu0001a0008-00.${aksIngressDomainName}'
var isUsingAzureRBACasKubernetesRBAC = (subscription().tenantId == k8sControlPlaneAuthorizationTenantId)

var kubernetesVersion = '1.30'

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

// An Azure Monitor workspace where cluster metrics related to Prometheus are collected
resource amw 'Microsoft.Monitor/accounts@2023-04-03' = {
  name: 'amw-${clusterName}'
  location: location
  properties: {
     publicNetworkAccess: 'Enabled'
  }
}

// A data collection endpoint to process Prometheus scraped metrics so they can be ingested by Azure Monitor
resource dce 'Microsoft.Insights/dataCollectionEndpoints@2023-03-11' = {
  name: 'MSProm-${location}-${clusterName}'
  location: location
  kind: 'Linux'
  properties: {
    networkAcls: {
      publicNetworkAccess: 'Enabled'
    }
  }
}

// A data collection rule that collects PrometheusMetrics from pods, nodes and cluster and configure Azure monitor workspace as destination  
resource dcr 'Microsoft.Insights/dataCollectionRules@2023-03-11' = {
  name: 'MSProm-${location}-${clusterName}'
  kind: 'Linux'
  location: location

  properties: {
    dataCollectionEndpointId: dce.id
    dataSources: {
      prometheusForwarder: [
        {
          name: 'PrometheusDataSource'
          streams: [
            'Microsoft-PrometheusMetrics'
          ]
          labelIncludeFilter: {}
        }
      ]
    }
    destinations: {
      monitoringAccounts: [
        {
          accountResourceId: amw.id
          name: amw.name
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Microsoft-PrometheusMetrics'
        ]
        destinations: [
          amw.name
        ]
      }
    ]
  }
}

// A diagnostic setting for all Prometheus DCR logs to be sent to log analytics
resource dcr_diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: dcr
  name: 'default'
  properties: {
    workspaceId: la.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

// Associate a data collection rule to the AKS Cluster
resource dcrAssociation 'Microsoft.Insights/dataCollectionRuleAssociations@2023-03-11' = {
  name: 'MSProm-${location}-${clusterName}'
  scope: mc
  properties: {
    dataCollectionRuleId: dcr.id
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

module alerts 'modules/alerts.bicep' = {
  name: 'alerts'
  params: {
    location: location
    clusterName: mc.name
    logAnalyticsWorkspaceResourceId: la.id
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

module ndEnsureClusterIdentityHasRbacToSelfManagedResources 'modules/role-assignment-EnsureClusterIdentityHasRbacToSelfManagedResources.bicep' = {
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
          ipv4Address: clusterInternalLoadBalancerIpAddress
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

module policies 'modules/policies.bicep' = {
  name: 'policies'
  params: {
    acrName: acr.name
    clusterName: clusterName
    domainName: domainName
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
      networkPluginMode: 'overlay'
      podCidr: '192.168.0.0/16'
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
        enabled: true
        kubeStateMetrics: {
          // https://learn.microsoft.com/azure/azure-monitor/containers/kubernetes-monitoring-enable
          // https://github.com/kubernetes/kube-state-metrics

          // Comma-separated list of Kubernetes annotations keys used in the resource's kube_resource_annotations metric.
          // For example, kube_pod_annotations is the annotations metric for the pods resource.
          // By default, this metric contains only name and namespace labels. To include more annotations,
          // provide a list of resource names in their plural form and Kubernetes annotation keys that you want to allow for them.
          // A single * can be provided for each resource to allow any annotations, but this has severe performance implications
          // https://github.com/prometheus-community/helm-charts/blob/e68c764aa6c764ec5934c6812ff0eaa0877ba275/charts/kube-state-metrics/values.yaml#L342
          metricAnnotationsAllowList: ''
          
          // Comma-separated list of more Kubernetes label keys that is used in the resource's kube_resource_labels metric kube_resource_labels metric.
          // For example, kube_pod_labels is the labels metric for the pods resource. By default this metric contains only name and namespace labels.
          // To include more labels, provide a list of resource names in their plural form and Kubernetes label keys that you want to allow for them.
          // A single * can be provided for each resource to allow any labels, but i this has severe performance implications.
          // https://github.com/prometheus-community/helm-charts/blob/e68c764aa6c764ec5934c6812ff0eaa0877ba275/charts/kube-state-metrics/values.yaml#L326
          metricLabelsAllowlist: ''
        }
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

    // Policies that we need in place before the cluster is deployed or pods are deployed to it.
    // They are not technically a dependency from the resource provider perspective,
    // but logically they need to be in place before workloads are, so forcing that here. This also
    // ensures that the policies are applied to the cluster at bootstrapping time.
    policies

    dcr

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

module ndEnsureClusterUserAssignedHasRbacToManageVMSS 'modules/role-assignment-EnsureClusterUserAssignedHasRbacToManageVMSS.bicep' = {
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
output ilbIpAddress string = pdzAksIngress::aksIngressDomainName_bu0001a0008_00.properties.aRecords[0].ipv4Address

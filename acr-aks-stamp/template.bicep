// Azure Regions
param location string = 'westeurope'
param geoRedundancyLocation string = 'northeurope'

// Unique Strings and Tags
param teamIdentitfier string = 'bu0001'
param appIdentitfier string = 'a0008'

// Resource Names
param acrName string = 'acr${teamIdentitfier}${appIdentitfier}'
param logAnalyticsWorkspaceName string = 'la-${teamIdentitfier}-${appIdentitfier}'
param aksClusterName string = 'aks-${teamIdentitfier}-${appIdentitfier}'
param keyVaultName string = 'kv-${teamIdentitfier}-${appIdentitfier}'
param appGWName string = 'appgw-${teamIdentitfier}-${appIdentitfier}'

// Additional Resource Groups
param vnetGroupName string = 'rg-Networking'
param aksNodeResourceGroup string = 'rg-${aksClusterName}-Nodes'

// Network
param vnetName string = 'vnet-spoke-${teamIdentitfier}${appIdentitfier}-00'
param appGWSubnetName string = 'snet-applicationgateway'
param privateLinkSubnetName string = 'snet-privatelink'
param aksSubnetName string = 'snet-clusternodes'
param aksIngressSubnetName string = 'snet-clusteringressservices'
param aksIngressLoadBalancerIp string = '10.240.4.4'
param aksAuthorizedIPRanges string = '0.0.0.0/0'

// DNS
param domainName string = 'contoso.com'
param aksIngressDomainName string = 'aks-ingress.${domainName}'
param aksBackendSubDomainName string = appIdentitfier
param appGWHostName string = 'bicycle.${domainName}'

// Identities
param aksControlPlaneIdentityName string = 'mi-${aksClusterName}-controlplane'
param appGWIdentityName string = 'mi-appgateway-frontend'
param aksIngressIdentityName string = 'podmi-ingress-controller'
param useAzureRBAC bool = true
param clusterAdminAadGroupObjectId string
param clusterUserAadGroupObjectId string

// Identifier and Secrets
param appGWListenerCertificateBase64 string // base64EncodedPfx
param aksIngressCertificateBase64 string // base64EncodedCer

// Flux GitOps
param fluxConfig object = {
  RepositoryUrl: 'https://github.com/mspnp/aks-baseline'
  RepositoryBranch: 'main'
  RepositorySubfolder: './cluster-manifests'
} 


resource vnetGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name: vnetGroupName
  scope: subscription()
}

resource vnet 'Microsoft.Network/virtualNetworks@2021-03-01' existing = {
  name: vnetName
  scope: vnetGroup
}

resource aksSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-03-01' existing = {
  name: aksSubnetName
  parent: vnet
}

resource appGWSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-03-01' existing = {
  name: appGWSubnetName
  parent: vnet
}

resource aksIngressSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-03-01' existing = {
  name: aksIngressSubnetName
  parent: vnet
}

resource privateLinkSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-03-01' existing = {
  name: privateLinkSubnetName
  parent: vnet
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: logAnalyticsWorkspaceName
  location: location
}

module acrModule 'modules/acr.bicep' = {
  name: 'acrStamp'
  params: {
    acrName: acrName
    geoRedundancyLocation: geoRedundancyLocation
    location: location
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    privateLinkSubnetId: privateLinkSubnet.id
    vnetId: vnet.id
  }
}

module managedIdentitiesModule 'modules/managedIdentities.bicep' = {
  name: 'managedIdentities'
  params: {
    aksControlPlaneIdentityName: aksControlPlaneIdentityName
    appGWIdentityName: appGWIdentityName
    aksIngressIdentityName: aksIngressIdentityName    
    location: location
  }
}

module keyVaultModule 'modules/keyvault.bicep' = {
  name: 'keyVaultStamp'
  params: {
    location: location
    appGWListenerCertificate: appGWListenerCertificateBase64
    aksIngressCertificate: aksIngressCertificateBase64
    keyVaultName: keyVaultName
    aksIngressIdentityPrincipalId: managedIdentitiesModule.outputs.aksIngressIdentityPrincipalId
    appGWIdentityPrincipalId: managedIdentitiesModule.outputs.appGWIdentityPrincipalId
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    privateLinkSubnetId: privateLinkSubnet.id
    vnetId: vnet.id
  }
}

module aksVnetContributorRoleAssignmentModule 'modules/vnet.bicep' = {
  name: 'EnsureClusterIdentityHasRbacToSelfManagedResources'
  params: {
    aksControlPlanePrincipalId: managedIdentitiesModule.outputs.aksControlPlaneIdentityPrincipalId
    aksSubnetName: aksSubnetName
    aksIngressSubnetName: aksIngressSubnetName
    vnetName: vnetName
  }
  scope: vnetGroup
}

module aksModule 'modules/aks.bicep' = {
  name: 'aks'
  params: {
    acrName: acrName
    aksClusterName: aksClusterName
    aksControlPlaneIdentityName: aksControlPlaneIdentityName
    aksNodeResourceGroup: aksNodeResourceGroup
    aksSubnetId: aksSubnet.id
    location: location
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    aksIngressDomainName: aksIngressDomainName
    aksIngressIdentityName: aksIngressIdentityName
    aksIngressLoadBalancerIp: aksIngressLoadBalancerIp
    aksAuthorizedIPRanges: aksAuthorizedIPRanges
    appSubDomainName: aksBackendSubDomainName
    vnetId: vnet.id
    useAzureRBAC: useAzureRBAC
    clusterAdminAadGroupObjectId: clusterAdminAadGroupObjectId
    clusterUserAadGroupObjectId: clusterUserAadGroupObjectId
    applicationIdentifierTag: appIdentitfier
    businessUnitTag: teamIdentitfier
    fluxSettings: fluxConfig
  }
}

module appGWModule 'modules/appgw.bicep' = {
  name: 'appGW'
  params: {
    aksBackendDomainName: '${aksBackendSubDomainName}.${aksIngressDomainName}'
    appGWHostName: appGWHostName
    appGWIdentityName: appGWIdentityName
    appGWListenerCertificateSecretId: keyVaultModule.outputs.appGWListenerCertificateSecretId
    aksIngressCertificateSecretId: keyVaultModule.outputs.aksIngressCertificateSecretId
    appGWName: appGWName
    appGWSubnetId: appGWSubnet.id
    location: location
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    trustedRootCertificatesRequired: !empty(aksIngressCertificateBase64)
  }
}

module monitoringModule 'modules/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    aksClusterName: aksClusterName
    location: location
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
  }
  dependsOn: [
    aksModule
    logAnalytics
  ]
}

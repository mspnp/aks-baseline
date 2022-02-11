// Azure Regions
var location = 'westeurope'
var geoRedundancyLocation = 'northeurope'

// Unique Strings and Tags
var teamIdentitfier = 'bu0001'
var appIdentitfier = 'a0008'

// Resource Names
var acrName = 'acr${teamIdentitfier}${appIdentitfier}'
var logAnalyticsWorkspaceName = 'la-${teamIdentitfier}-${appIdentitfier}'
var aksClusterName = 'aks-${teamIdentitfier}-${appIdentitfier}'
var keyVaultName = 'kv-${teamIdentitfier}-${appIdentitfier}'
var appGWName = 'appgw-${teamIdentitfier}-${appIdentitfier}'

// Additional Resource Groups
var vnetGroupName = 'rg-Networking'
var aksNodeResourceGroup = 'rg-${aksClusterName}-Nodes'

// Network
var vnetName = 'vnet-northeurope'
var appGWSubnetName = 'Subnet-AppGW'
var privateLinkSubnetName = 'Subnet-PrivateLink'
var aksSubnetName = 'Subnet-AKS'
var aksIngressSubnetName = 'Subnet-AKS-Ingress'
var aksIngressLoadBalancerIp = '10.240.4.4'
var aksAuthorizedIPRanges = '0.0.0.0/0'

// DNS
var domainName = 'contoso.com'
var aksIngressDomainName = 'aksingress.${domainName}'
var aksBackendSubDomainName = appIdentitfier
var appGWHostName = 'www.${domainName}'

// Identities
var aksControlPlaneIdentityName = 'mi-${aksClusterName}-controlplane'
var appGWIdentityName = 'mi-appgateway-frontend'
var aksIngressIdentityName = 'podmi-ingress-controller'
var useAzureRBAC = true
var clusterAdminAadGroupObjectId = '<GUID>'
var clusterUserAadGroupObjectId = '<GUID>'

// Identifier and Secrets
var appGWListenerCertificateBase64 = 'base64EncodedPfx'


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
  }
}

module appGWModule 'modules/appgw.bicep' = {
  name: 'appGW'
  params: {
    aksBackendDomainName: '${aksBackendSubDomainName}.${aksIngressDomainName}'
    appGWHostName: appGWHostName
    appGWIdentityName: appGWIdentityName
    appGWListenerCertificateSecretId: keyVaultModule.outputs.appGWListenerCertificateSecretId
    appGWName: appGWName
    appGWSubnetId: appGWSubnet.id
    location: location
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
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

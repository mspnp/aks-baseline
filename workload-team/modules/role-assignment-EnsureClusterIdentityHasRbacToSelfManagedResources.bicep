targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('The AKS Control Plane Principal Id to be given with Network Contributor Role in different spoke subnets, so it can join VMSS and load balancers resources to them.')
@minLength(36)
@maxLength(36)
param miClusterControlPlanePrincipalId string

@description('The AKS Control Plane Principal Name to be used to create unique role assignments names.')
@minLength(3)
@maxLength(128)
param clusterControlPlaneIdentityName string

@description('The regional network spoke VNet Resource name that the cluster is being joined to, so it can be used to discover subnets during role assignments.')
@minLength(1)
param targetVirtualNetworkName string

/*** VARIABLES ***/

@description('AKS Service, Node Pools, and supporting services (KeyVault, App Gateway, etc) region. This needs to be the same region as the vnet provided in these parameters.')
var location = resourceGroup().location

/*** EXISTING SUBSCRIPTION RESOURCES ***/

resource networkContributorRole 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  name: '4d97b98b-1d4f-4787-a291-c67834d212e7'
  scope: subscription()
}

resource dnsZoneContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'b12aa53e-6015-4669-85d0-8515ebb3ae7f'
  scope: subscription()
}

/*** EXISTING HUB RESOURCES ***/

resource pdzMc 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'privatelink.${location}.azmk8s.io'
}

resource targetVirtualNetwork 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: targetVirtualNetworkName
}

resource snetClusterNodes 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  parent: targetVirtualNetwork
  name: 'snet-clusternodes'
}

resource snetClusterIngress 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' existing = {
  parent: targetVirtualNetwork
  name: 'snet-clusteringressservices'
}

/*** RESOURCES ***/

resource vnetMiClusterControlPlaneDnsZoneContributorRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  scope: targetVirtualNetwork
  name: guid(targetVirtualNetwork.id, dnsZoneContributorRole.id, clusterControlPlaneIdentityName)
  properties: {
    roleDefinitionId: dnsZoneContributorRole.id
    description: 'Allows cluster identity to attach custom DNS zone with Private Link information to this virtual network.'
    principalId: miClusterControlPlanePrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource snetClusterNodesMiClusterControlPlaneNetworkContributorRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: snetClusterNodes
  name: guid(snetClusterNodes.id, networkContributorRole.id, miClusterControlPlanePrincipalId)
  properties: {
    roleDefinitionId: networkContributorRole.id
    description: 'Allows cluster identity to join the nodepool vmss resources to this subnet.'
    principalId: miClusterControlPlanePrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource snetClusterIngressServicesMiClusterControlPlaneSecretsUserRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: snetClusterIngress
  name: guid(snetClusterIngress.id, networkContributorRole.id, miClusterControlPlanePrincipalId)
  properties: {
    roleDefinitionId: networkContributorRole.id
    description: 'Allows cluster identity to join load balancers (ingress resources) to this subnet.'
    principalId: miClusterControlPlanePrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource pdzMcPrivatelinkAzmk8sIoMiClusterControlPlaneDnsZoneContributorRole_roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  scope: pdzMc
  name: guid(pdzMc.id, dnsZoneContributorRole.id, clusterControlPlaneIdentityName)
  properties: {
    roleDefinitionId: dnsZoneContributorRole.id
    description: 'Allows cluster identity to manage zone Entries for cluster\'s Private Link configuration.'
    principalId: miClusterControlPlanePrincipalId
    principalType: 'ServicePrincipal'
  }
}

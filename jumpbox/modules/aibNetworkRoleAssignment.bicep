targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('Required. The name of the virtual network in this resource group that the image builder will be connected to during the build.')
@minLength(1)
param targetVirtualNetworkName string

@description('Required. The principal object ID of the Azure Image Builder service\'s user managed identity that needs to join compute into the virtual network.')
@minLength(36)
param aibManagedIdentityPrincipalId string

@description('Required. The resource ID of the role definition to be assigned to the managed identity to support the networking operations.')
@minLength(80)
param aibNetworkRoleDefinitionResourceId string

/*** EXISTING RESOURCES ***/

@description('The existing Virtual Network in which Azure Image Builder will be connecting the image building compute into.')
resource vnetBuilder 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: targetVirtualNetworkName
}

/*** RESOURCES ***/

resource networkRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid(vnetBuilder.id, aibManagedIdentityPrincipalId, aibNetworkRoleDefinitionResourceId)
  scope: vnetBuilder
  properties: {
    principalId: aibManagedIdentityPrincipalId
    roleDefinitionId: aibNetworkRoleDefinitionResourceId
    description: 'Grants AIB required networking permissions. Validated at image template creation time.'
    principalType: 'ServicePrincipal'
  }
}

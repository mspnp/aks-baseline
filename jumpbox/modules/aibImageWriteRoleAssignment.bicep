targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('Required. The principal object ID of the Azure Image Builder service\'s user managed identity that needs to write the final image into this resource group.')
@minLength(36)
param aibManagedIdentityPrincipalId string

@description('Required. The resource ID of the role definition to be assigned to the managed identity to support the image writing process.')
@minLength(80)
param aibImageCreatorRoleDefinitionResourceId string

/*** RESOURCES ***/

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid(resourceGroup().id, aibManagedIdentityPrincipalId, aibImageCreatorRoleDefinitionResourceId)
  scope: resourceGroup()
  properties: {
    principalId: aibManagedIdentityPrincipalId
    roleDefinitionId: aibImageCreatorRoleDefinitionResourceId
    description: 'Grants AIB required permissions to write final jump box image in designated resource group.'
    principalType: 'ServicePrincipal'
  }
}

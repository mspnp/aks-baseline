param kubeletidentityObjectId string

var virtualMachineContributorRole = '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/9980e02c-c2be-4d73-94e8-173b1dc7cf3c'

resource id 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(resourceGroup().id)
  properties: {
    roleDefinitionId: virtualMachineContributorRole
    principalId: kubeletidentityObjectId
    principalType: 'ServicePrincipal'
  }
}

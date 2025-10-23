targetScope = 'subscription'

resource imageBuilderNetworkingRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' = {
  name: guid(subscription().id, 'Azure Image Builder Service Networking Role')
  properties: {
    roleName: '[Custom] Azure Image Builder Service Network Joiner'
    type: 'CustomRole'
    description: 'Required permissions for an Azure Image Builder Service assigned identity to use an existing vnet. Expected to be assigned at the virtual network resource (not subnet).'
    assignableScopes: [
      subscription().id
    ]
    permissions: [
      {
        actions: [
          'Microsoft.Network/virtualNetworks/read'
          'Microsoft.Network/virtualNetworks/subnets/join/action'
        ]
        notActions: []
        dataActions: []
        notDataActions: []
      }
    ]
  }
}

resource imageBuilderImageCreationRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' = {
  name: guid(subscription().id, 'Azure Image Builder Service Image Creation Role')
  properties: {
    roleName: '[Custom] Image Contributor'
    type: 'CustomRole'
    description: 'Required permissions for an Azure Image Builder Service assigned identity to deploy the generated image to a resource group. Expected to be assigned at the target RG level.'
    assignableScopes: [
      subscription().id
    ]
    permissions: [
      {
        actions: [
          'Microsoft.Compute/images/write'
          'Microsoft.Compute/images/read'
          'Microsoft.Compute/images/delete'
        ]
        notActions: []
        dataActions: []
        notDataActions: []
      }
    ]
  }
}

output roleResourceIds object = {
  customImageBuilderImageCreationRole: {
    guid: imageBuilderImageCreationRoleDefinition.name
    resourceId: imageBuilderImageCreationRoleDefinition.id
  }
  customImageBuilderNetworkingRole: {
    guid: imageBuilderNetworkingRoleDefinition.name
    resourceId: imageBuilderNetworkingRoleDefinition.id
  }
}

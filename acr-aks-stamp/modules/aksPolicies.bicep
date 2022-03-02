param aksClusterName string
param acrName string

var policyResourceIdAKSLinuxRestrictive = '/providers/Microsoft.Authorization/policySetDefinitions/42b8ef37-b724-4e24-bbc8-7a7708edfe00'
var policyResourceIdEnforceHttpsIngress = '/providers/Microsoft.Authorization/policyDefinitions/1a5b4dca-0b6f-4cf5-907c-56316bc1bf3d'
var policyResourceIdEnforceInternalLoadBalancers = '/providers/Microsoft.Authorization/policyDefinitions/3fc4dc25-5baf-40d8-9b05-7fe74c1bc64e'
var policyResourceIdRoRootFilesystem = '/providers/Microsoft.Authorization/policyDefinitions/df49d893-a74c-421d-bc95-c663042e5b80'
var policyResourceIdEnforceResourceLimits = '/providers/Microsoft.Authorization/policyDefinitions/e345eecc-fa47-480f-9e88-67dcc122b164'
var policyResourceIdEnforceImageSource = '/providers/Microsoft.Authorization/policyDefinitions/febd0533-8e55-448f-b837-bd0e06f16469'
var policyResourceIdEnforceDefenderInCluster = '/providers/Microsoft.Authorization/policyDefinitions/a1840de2-8088-4ea8-b153-b4c723e9cb01'
var policyAssignmentNameAKSLinuxRestrictive = guid(policyResourceIdAKSLinuxRestrictive, resourceGroup().name, aksClusterName)
var policyAssignmentNameEnforceHttpsIngress = guid(policyResourceIdEnforceHttpsIngress, resourceGroup().name, aksClusterName)
var policyAssignmentNameEnforceInternalLoadBalancers = guid(policyResourceIdEnforceInternalLoadBalancers, resourceGroup().name, aksClusterName)
var policyAssignmentNameRoRootFilesystem = guid(policyResourceIdRoRootFilesystem, resourceGroup().name, aksClusterName)
var policyAssignmentNameEnforceResourceLimits = guid(policyResourceIdEnforceResourceLimits, resourceGroup().name, aksClusterName)
var policyAssignmentNameEnforceImageSource = guid(policyResourceIdEnforceImageSource, resourceGroup().name, aksClusterName)
var policyAssignmentNameEnforceDefenderInCluster = guid(policyResourceIdEnforceDefenderInCluster, resourceGroup().name, aksClusterName)

resource policyAssignmentAKSLinuxRestrictive 'Microsoft.Authorization/policyAssignments@2020-09-01' = {
  name: policyAssignmentNameAKSLinuxRestrictive
  properties: {
    displayName: '[${aksClusterName}] ${reference(policyResourceIdAKSLinuxRestrictive, '2020-09-01').displayName}'
    scope: subscriptionResourceId('Microsoft.Resources/resourceGroups', resourceGroup().name)
    policyDefinitionId: policyResourceIdAKSLinuxRestrictive
    parameters: {
      excludedNamespaces: {
        value: [
          'kube-system'
          'gatekeeper-system'
          'azure-arc'
          'cluster-baseline-settings'
        ]
      }
      effect: {
        value: 'audit'
      }
    }
  }
}

resource policyAssignmentEnforceHttpsIngress 'Microsoft.Authorization/policyAssignments@2020-09-01' = {
  name: policyAssignmentNameEnforceHttpsIngress
  properties: {
    displayName: '[${aksClusterName}] ${reference(policyResourceIdEnforceHttpsIngress, '2020-09-01').displayName}'
    scope: subscriptionResourceId('Microsoft.Resources/resourceGroups', resourceGroup().name)
    policyDefinitionId: policyResourceIdEnforceHttpsIngress
    parameters: {
      excludedNamespaces: {
        value: []
      }
      effect: {
        value: 'deny'
      }
    }
  }
}

resource policyAssignmentEnforceInternalLoadBalancers 'Microsoft.Authorization/policyAssignments@2020-09-01' = {
  name: policyAssignmentNameEnforceInternalLoadBalancers
  properties: {
    displayName: '[${aksClusterName}] ${reference(policyResourceIdEnforceInternalLoadBalancers, '2020-09-01').displayName}'
    scope: subscriptionResourceId('Microsoft.Resources/resourceGroups', resourceGroup().name)
    policyDefinitionId: policyResourceIdEnforceInternalLoadBalancers
    parameters: {
      excludedNamespaces: {
        value: []
      }
      effect: {
        value: 'deny'
      }
    }
  }
}

resource policyAssignmentRoRootFilesystem 'Microsoft.Authorization/policyAssignments@2020-09-01' = {
  name: policyAssignmentNameRoRootFilesystem
  properties: {
    displayName: '[${aksClusterName}] ${reference(policyResourceIdRoRootFilesystem, '2020-09-01').displayName}'
    scope: subscriptionResourceId('Microsoft.Resources/resourceGroups', resourceGroup().name)
    policyDefinitionId: policyResourceIdRoRootFilesystem
    parameters: {
      excludedNamespaces: {
        value: [
          'kube-system'
          'gatekeeper-system'
          'azure-arc'
        ]
      }
      effect: {
        value: 'audit'
      }
    }
  }
}

resource policyAssignmentEnforceResourceLimits 'Microsoft.Authorization/policyAssignments@2020-09-01' = {
  name: policyAssignmentNameEnforceResourceLimits
  properties: {
    displayName: '[${aksClusterName}] ${reference(policyResourceIdEnforceResourceLimits, '2020-09-01').displayName}'
    scope: subscriptionResourceId('Microsoft.Resources/resourceGroups', resourceGroup().name)
    policyDefinitionId: policyResourceIdEnforceResourceLimits
    parameters: {
      cpuLimit: {
        value: '1000m'
      }
      memoryLimit: {
        value: '512Mi'
      }
      excludedNamespaces: {
        value: [
          'kube-system'
          'gatekeeper-system'
          'azure-arc'
          'cluster-baseline-settings'
          'flux-system'
        ]
      }
      effect: {
        value: 'deny'
      }
    }
  }
}

resource policyAssignmentEnforceImageSource 'Microsoft.Authorization/policyAssignments@2020-09-01' = {
  name: policyAssignmentNameEnforceImageSource
  properties: {
    displayName: '[${aksClusterName}] ${reference(policyResourceIdEnforceImageSource, '2020-09-01').displayName}'
    scope: subscriptionResourceId('Microsoft.Resources/resourceGroups', resourceGroup().name)
    policyDefinitionId: policyResourceIdEnforceImageSource
    parameters: {
      allowedContainerImagesRegex: {
        value: '${acrName}.azurecr.io/.+$|mcr.microsoft.com/.+$|azurearcfork8s.azurecr.io/azurearcflux/images/stable/.+$|docker.io/weaveworks/kured.+$|docker.io/library/.+$'
      }
      excludedNamespaces: {
        value: [
          'kube-system'
          'gatekeeper-system'
          'azure-arc'
        ]
      }
      effect: {
        value: 'deny'
      }
    }
  }
}

resource policyAssignmentEnforceDefenderInCluster 'Microsoft.Authorization/policyAssignments@2020-09-01' = {
  name: policyAssignmentNameEnforceDefenderInCluster
  properties: {
    displayName: '[${aksClusterName}] ${reference(policyResourceIdEnforceDefenderInCluster, '2020-09-01').displayName}'
    description: 'Microsoft Defender for Containers should be enabled in the cluster.'
    scope: subscriptionResourceId('Microsoft.Resources/resourceGroups', resourceGroup().name)
    policyDefinitionId: policyResourceIdEnforceDefenderInCluster
    parameters: {
      effect: {
        value: 'Audit'
      }
    }
  }
}

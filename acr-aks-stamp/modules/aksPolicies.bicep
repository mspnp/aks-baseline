param aksClusterName string
param acrName string

var policyResourceIdAKSLinuxRestrictive = '/providers/Microsoft.Authorization/policySetDefinitions/42b8ef37-b724-4e24-bbc8-7a7708edfe00'
var policyResourceIdEnforceHttpsIngress = '/providers/Microsoft.Authorization/policyDefinitions/1a5b4dca-0b6f-4cf5-907c-56316bc1bf3d'
var policyResourceIdEnforceInternalLoadBalancers = '/providers/Microsoft.Authorization/policyDefinitions/3fc4dc25-5baf-40d8-9b05-7fe74c1bc64e'
var policyResourceIdRoRootFilesystem = '/providers/Microsoft.Authorization/policyDefinitions/df49d893-a74c-421d-bc95-c663042e5b80'
var policyResourceIdEnforceResourceLimits = '/providers/Microsoft.Authorization/policyDefinitions/e345eecc-fa47-480f-9e88-67dcc122b164'
var policyResourceIdEnforceImageSource = '/providers/Microsoft.Authorization/policyDefinitions/febd0533-8e55-448f-b837-bd0e06f16469'
var policyAssignmentNameAKSLinuxRestrictiveName = guid(policyResourceIdAKSLinuxRestrictive, resourceGroup().name, aksClusterName)
var policyAssignmentNameEnforceHttpsIngressName = guid(policyResourceIdEnforceHttpsIngress, resourceGroup().name, aksClusterName)
var policyAssignmentNameEnforceInternalLoadBalancersName = guid(policyResourceIdEnforceInternalLoadBalancers, resourceGroup().name, aksClusterName)
var policyAssignmentNameRoRootFilesystemName = guid(policyResourceIdRoRootFilesystem, resourceGroup().name, aksClusterName)
var policyAssignmentNameEnforceResourceLimitsName = guid(policyResourceIdEnforceResourceLimits, resourceGroup().name, aksClusterName)
var policyAssignmentNameEnforceImageSourceName = guid(policyResourceIdEnforceImageSource, resourceGroup().name, aksClusterName)

resource policyAssignmentNameAKSLinuxRestrictive 'Microsoft.Authorization/policyAssignments@2020-03-01' = {
  name: policyAssignmentNameAKSLinuxRestrictiveName
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

resource policyAssignmentNameEnforceHttpsIngress 'Microsoft.Authorization/policyAssignments@2020-03-01' = {
  name: policyAssignmentNameEnforceHttpsIngressName
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

resource policyAssignmentNameEnforceInternalLoadBalancers 'Microsoft.Authorization/policyAssignments@2020-03-01' = {
  name: policyAssignmentNameEnforceInternalLoadBalancersName
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

resource policyAssignmentNameRoRootFilesystem 'Microsoft.Authorization/policyAssignments@2020-03-01' = {
  name: policyAssignmentNameRoRootFilesystemName
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

resource policyAssignmentNameEnforceResourceLimits 'Microsoft.Authorization/policyAssignments@2020-03-01' = {
  name: policyAssignmentNameEnforceResourceLimitsName
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

resource policyAssignmentNameEnforceImageSource 'Microsoft.Authorization/policyAssignments@2020-03-01' = {
  name: policyAssignmentNameEnforceImageSourceName
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

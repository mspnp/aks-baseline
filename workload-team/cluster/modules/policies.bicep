@description('Name of the AKS cluster.')
param clusterName string

@description('Domain name to use for App Gateway and AKS ingress.')
param domainName string

@description('Name of the Azure Container Registry (ACR) instance.')
param acrName string

/*** EXISTING TENANT RESOURCES ***/

// Built-in 'Kubernetes cluster pod security restricted standards for Linux-based workloads' Azure Policy for Kubernetes initiative definition
resource psdAKSLinuxRestrictive 'Microsoft.Authorization/policySetDefinitions@2021-06-01' existing = {
  name: '42b8ef37-b724-4e24-bbc8-7a7708edfe00'
  scope: tenant()
}

// Built-in 'Kubernetes clusters should be accessible only over HTTPS' Azure Policy for Kubernetes policy definition
resource pdEnforceHttpsIngress 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: '1a5b4dca-0b6f-4cf5-907c-56316bc1bf3d'
  scope: tenant()
}

// Built-in 'Kubernetes clusters should use internal load balancers' Azure Policy for Kubernetes policy definition
resource pdEnforceInternalLoadBalancers 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: '3fc4dc25-5baf-40d8-9b05-7fe74c1bc64e'
  scope: tenant()
}

// Built-in 'Kubernetes cluster containers should run with a read only root file system' Azure Policy for Kubernetes policy definition
resource pdRoRootFilesystem 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: 'df49d893-a74c-421d-bc95-c663042e5b80'
  scope: tenant()
}

// Built-in 'AKS container CPU and memory resource limits should not exceed the specified limits' Azure Policy for Kubernetes policy definition
resource pdEnforceResourceLimits 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: 'e345eecc-fa47-480f-9e88-67dcc122b164'
  scope: tenant()
}

// Built-in 'AKS containers should only use allowed images' Azure Policy for Kubernetes policy definition
resource pdEnforceImageSource 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: 'febd0533-8e55-448f-b837-bd0e06f16469'
  scope: tenant()
}

// Built-in 'Kubernetes cluster pod hostPath volumes should only use allowed host paths' Azure Policy for Kubernetes policy definition
resource pdAllowedHostPaths 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: '098fc59e-46c7-4d99-9b16-64990e543d75'
  scope: tenant()
}

// Built-in 'Kubernetes cluster services should only use allowed external IPs' Azure Policy for Kubernetes policy definition
resource pdAllowedExternalIPs 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: 'd46c275d-1680-448d-b2ec-e495a3b6cc89'
  scope: tenant()
}

// Built-in 'Kubernetes clusters should not allow endpoint edit permissions of ClusterRole/system:aggregate-to-edit' Azure Policy for Kubernetes policy definition
resource pdDisallowEndpointEditPermissions 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: '1ddac26b-ed48-4c30-8cc5-3a68c79b8001'
  scope: tenant()
}

// Built-in 'Kubernetes clusters should not use the default namespace' Azure Policy for Kubernetes policy definition
resource pdDisallowNamespaceUsage 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: '9f061a12-e40d-4183-a00e-171812443373'
  scope: tenant()
}

// Built-in 'Azure Kubernetes Service clusters should have Defender profile enabled' Azure Policy policy definition
resource pdDefenderInClusterEnabled 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: 'a1840de2-8088-4ea8-b153-b4c723e9cb01'
  scope: tenant()
}

// Built-in 'Azure Kubernetes Service Clusters should enable Microsoft Entra ID integration' Azure Policy policy definition
resource pdEntraIdIntegrationEnabled 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: '450d2877-ebea-41e8-b00c-e286317d21bf'
  scope: tenant()
}

// Built-in 'Azure Kubernetes Service Clusters should have local authentication methods disabled' Azure Policy policy definition
resource pdLocalAuthDisabled 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: '993c2fcd-2b29-49d2-9eb0-df2c3a730c32'
  scope: tenant()
}

// Built-in 'Azure Policy Add-on for Kubernetes service (AKS) should be installed and enabled on your clusters' Azure Policy policy definition
resource pdAzurePolicyEnabled 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: '0a15ec92-a229-4763-bb14-0ea34a568f8d'
  scope: tenant()
}

// Built-in 'Authorized IP ranges should be defined on Kubernetes Services' Azure Policy policy definition
resource pdAuthorizedIpRangesDefined 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: '0e246bcf-5f6f-4f87-bc6f-775d4712c7ea'
  scope: tenant()
}

// Built-in 'Kubernetes Services should be upgraded to a non-vulnerable Kubernetes version' Azure Policy policy definition
resource pdOldKubernetesDisabled 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: 'fb893a29-21bb-418c-a157-e99480ec364c'
  scope: tenant()
}

// Built-in 'Role-Based Access Control (RBAC) should be used on Kubernetes Services' Azure Policy policy definition
resource pdRbacEnabled 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: 'ac4a19c2-fa67-49b4-8ae5-0b2e78c49457'
  scope: tenant()
}

// Built-in 'Azure Kubernetes Service Clusters should use managed identities' Azure Policy policy definition
resource pdManagedIdentitiesEnabled 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: 'da6e2401-19da-4532-9141-fb8fbde08431'
  scope: tenant()
}

/*** RESOURCE GROUP AZURE POLICY ASSIGNMENTS - AZURE POLICY FOR KUBERNETES POLICIES ***/

// Applying the built-in 'Kubernetes cluster pod security restricted standards for Linux-based workloads' initiative at the resource group level.
// Constraint Names: K8sAzureAllowedSeccomp, K8sAzureAllowedCapabilities, K8sAzureContainerNoPrivilege, K8sAzureHostNetworkingPorts, K8sAzureVolumeTypes, K8sAzureBlockHostNamespaceV2, K8sAzureAllowedUsersGroups, K8sAzureContainerNoPrivilegeEscalation
resource paAKSLinuxRestrictive 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: guid(psdAKSLinuxRestrictive.id, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${psdAKSLinuxRestrictive.properties.displayName}', 120)
    description: psdAKSLinuxRestrictive.properties.description
    policyDefinitionId: psdAKSLinuxRestrictive.id
    parameters: {
      excludedNamespaces: {
        value: [
          'kube-system'
          'gatekeeper-system'
          'azure-arc'
          'flux-system'

          'cluster-baseline-settings'

          // Known violations
          // K8sAzureAllowedSeccomp
          //  - Traefik, no profile defined
          //  - aspnetapp-deployment, no profile defined
          // K8sAzureVolumeTypes
          //  - Traefik, uses csi
          // K8sAzureAllowedUsersGroups
          //  - Traefik, no supplementalGroups, no fsGroup
          //  = aspnetapp-deployment, no supplementalGroups, no fsGroup
          'a0008'
        ]
      }
      effect: {
        value: 'Audit'
      }
    }
  }
}

// Applying the built-in 'Kubernetes clusters should be accessible only over HTTPS' policy at the resource group level.
// Constraint Name: K8sAzureIngressHttpsOnly
resource paEnforceHttpsIngress 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: guid(pdEnforceHttpsIngress.id, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${pdEnforceHttpsIngress.properties.displayName}', 120)
    description: pdEnforceHttpsIngress.properties.description
    policyDefinitionId: pdEnforceHttpsIngress.id
    parameters: {
      excludedNamespaces: {
        value: []
      }
      effect: {
        value: 'Deny'
      }
    }
  }
}

// Applying the built-in 'Kubernetes clusters should use internal load balancers' policy at the resource group level.
// Constraint Name: K8sAzureLoadBalancerNoPublicIPs
resource paEnforceInternalLoadBalancers 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: guid(pdEnforceInternalLoadBalancers.id, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${pdEnforceInternalLoadBalancers.properties.displayName}', 120)
    description: pdEnforceInternalLoadBalancers.properties.description
    policyDefinitionId: pdEnforceInternalLoadBalancers.id
    parameters: {
      excludedNamespaces: {
        value: []
      }
      effect: {
        value: 'Deny'
      }
    }
  }
}

// Applying the built-in 'Kubernetes cluster containers should run with a read only root file system' policy at the resource group level.
// Constraint Name: K8sAzureReadOnlyRootFilesystem
resource paRoRootFilesystem 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: guid(pdRoRootFilesystem.id, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${pdRoRootFilesystem.properties.displayName}', 120)
    description: pdRoRootFilesystem.properties.description
    policyDefinitionId: pdRoRootFilesystem.id
    parameters: {
      excludedNamespaces: {
        value: [
          'kube-system'
          'gatekeeper-system'
          'azure-arc'
          'flux-system'
        ]
      }
      excludedContainers: {
        value: [
          'aspnet-webapp-sample'   // ASP.NET Core does not support read-only root
        ]
      }
      effect: {
        value: 'Deny'
      }
    }
  }
}


// Applying the built-in 'AKS container CPU and memory resource limits should not exceed the specified limits' policy at the resource group level.
// Constraint Name: K8sAzureContainerLimits
resource paEnforceResourceLimits 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: guid(pdEnforceResourceLimits.id, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${pdEnforceResourceLimits.properties.displayName}', 120)
    description: pdEnforceResourceLimits.properties.description
    policyDefinitionId: pdEnforceResourceLimits.id
    parameters: {
      cpuLimit: {
        value: '500m' // traefik-ingress-controller = 200m, aspnet-webapp-sample = 100m
      }
      memoryLimit: {
        value: '256Mi' // aspnet-webapp-sample = 256Mi, traefik-ingress-controller = 128Mi
      }
      excludedNamespaces: {
        value: [
          'kube-system'
          'gatekeeper-system'
          'azure-arc'
          'flux-system'
        ]
      }
      effect: {
        value: 'Deny'
      }
    }
  }
}

// Applying the built-in 'AKS containers should only use allowed images' policy at the resource group level.
// Constraint Name: K8sAzureContainerAllowedImages
resource paEnforceImageSource 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: guid(pdEnforceImageSource.id, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${pdEnforceImageSource.properties.displayName}', 120)
    description: pdEnforceImageSource.properties.description
    policyDefinitionId: pdEnforceImageSource.id
    parameters: {
      allowedContainerImagesRegex: {
        // PRODUCTION READINESS CHANGE REQUIRED
        // If all images are pull into your ACR instance as described in these instructions you can remove the docker.io entry.
        value: '${acrName}\\.azurecr\\.io/.+$|mcr\\.microsoft\\.com/.+$|docker\\.io/library/.+$'
      }
      excludedNamespaces: {
        value: [
          'kube-system'
          'gatekeeper-system'
          'azure-arc'
        ]
      }
      effect: {
        value: 'Deny'
      }
    }
  }
}

// Applying the built-in 'Kubernetes cluster pod hostPath volumes should only use allowed host paths' policy at the resource group level.
resource paAllowedHostPaths 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: guid(pdAllowedHostPaths.id, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${pdAllowedHostPaths.properties.displayName}', 120)
    description: pdAllowedHostPaths.properties.description
    policyDefinitionId: pdAllowedHostPaths.id
    parameters: {
      excludedNamespaces: {
        value: [
          'kube-system'
          'gatekeeper-system'
          'azure-arc'
          'flux-system'
        ]
      }
      allowedHostPaths: {
        value: {
          paths: [] // Setting to empty blocks all host paths
        }
      }
      effect: {
        value: 'Deny'
      }
    }
  }
}

// Applying the built-in 'Kubernetes cluster services should only use allowed external IPs' policy at the resource group level.
// Constraint Name: K8sAzureExternalIPs
resource paAllowedExternalIPs 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: guid(pdAllowedExternalIPs.id, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${pdAllowedExternalIPs.properties.displayName}', 120)
    description: pdAllowedExternalIPs.properties.description
    policyDefinitionId: pdAllowedExternalIPs.id
    parameters: {
      excludedNamespaces: {
        value: [
          'kube-system'
          'gatekeeper-system'
          'azure-arc'
        ]
      }
      allowedExternalIPs: {
        value: []  // None allowed, internal load balancer IP only supported.
      }
      effect: {
        value: 'Deny'
      }
    }
  }
}

// Applying the built-in 'Kubernetes clusters should not allow endpoint edit permissions of ClusterRole/system:aggregate-to-edit' policy at the resource group level.
// See: CVE-2021-25740 & https://github.com/kubernetes/kubernetes/issues/103675
// Constraint Name: K8sAzureBlockEndpointEditDefaultRole
resource paDisallowEndpointEditPermissions 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: guid(pdDisallowEndpointEditPermissions.id, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${pdDisallowEndpointEditPermissions.properties.displayName}', 120)
    description: pdDisallowEndpointEditPermissions.properties.description
    policyDefinitionId: pdDisallowEndpointEditPermissions.id
    parameters: {
      excludedNamespaces: {
        value: [
          'kube-system'
          'gatekeeper-system'
          'azure-arc'
        ]
      }
      effect: {
        value: 'Audit' // As of 1.0.1, there is no Deny.
      }
    }
  }
}

// Applying the built-in 'Kubernetes clusters should not use the default namespace' policy at the resource group level.
// Constraint Name: K8sAzureBlockDefault
resource paDisallowNamespaceUsage 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: guid(pdDisallowNamespaceUsage.id, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${pdDisallowNamespaceUsage.properties.displayName}', 120)
    description: pdDisallowNamespaceUsage.properties.description
    policyDefinitionId: pdDisallowNamespaceUsage.id
    parameters: {
      excludedNamespaces: {
        value: [
          'kube-system'
          'gatekeeper-system'
          'azure-arc'
        ]
      }
      namespaces: {
        value: [
          'default' // List namespaces you'd like to disallow the usage of (typically 'default')
        ]
      }
      effect: {
        value: 'Audit' // Consider moving to Deny, this walkthrough does temporarly deploy a curl image in default, so leaving as Audit
      }
    }
  }
}

/*** RESOURCE GROUP AZURE POLICY ASSIGNMENTS - RESOURCE PROVIDER POLICIES ***/

// Applying the built-in 'Azure Kubernetes Service clusters should have Defender profile enabled' policy at the resource group level.
resource paDefenderInClusterEnabled 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: guid(pdDefenderInClusterEnabled.id, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${pdDefenderInClusterEnabled.properties.displayName}', 120)
    description: pdDefenderInClusterEnabled.properties.description
    policyDefinitionId: pdDefenderInClusterEnabled.id
    parameters: {
      effect: {
        value: 'Audit' // This policy (as of 1.0.2-preview) does not have a Deny option, otherwise that would be set here.
      }
    }
  }
}

// Applying the built-in 'Azure Kubernetes Service Clusters should enable Microsoft Entra ID integration' policy at the resource group level.
resource paMicrosoftEntraIdIntegrationEnabled 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: guid(pdEntraIdIntegrationEnabled.id, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${pdEntraIdIntegrationEnabled.properties.displayName}', 120)
    description: pdEntraIdIntegrationEnabled.properties.description
    policyDefinitionId: pdEntraIdIntegrationEnabled.id
    parameters: {
      effect: {
        value: 'Audit' // This policy (as of 1.0.0) does not have a Deny option, otherwise that would be set here.
      }
    }
  }
}

// Applying the built-in 'Azure Kubernetes Service Clusters should have local authentication methods disabled' policy at the resource group level.
resource paLocalAuthDisabled 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: guid(pdLocalAuthDisabled.id, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${pdLocalAuthDisabled.properties.displayName}', 120)
    description: pdLocalAuthDisabled.properties.description
    policyDefinitionId: pdLocalAuthDisabled.id
    parameters: {
      effect: {
        value: 'Deny'
      }
    }
  }
}

// Applying the built-in 'Azure Policy Add-on for Kubernetes service (AKS) should be installed and enabled on your clusters' policy at the resource group level.
resource paAzurePolicyEnabled 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: guid(pdAzurePolicyEnabled.id, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${pdAzurePolicyEnabled.properties.displayName}', 120)
    description: pdAzurePolicyEnabled.properties.description
    policyDefinitionId: pdAzurePolicyEnabled.id
    parameters: {
      effect: {
        value: 'Audit'  // This policy (as of 1.0.2) does not have a Deny option, otherwise that would be set here.
      }
    }
  }
}

// Applying the built-in 'Authorized IP ranges should be defined on Kubernetes Services' policy at the resource group level.
resource paAuthorizedIpRangesDefined 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: guid(pdAuthorizedIpRangesDefined.id, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${pdAuthorizedIpRangesDefined.properties.displayName}', 120)
    description: pdAuthorizedIpRangesDefined.properties.description
    policyDefinitionId: pdAuthorizedIpRangesDefined.id
    parameters: {
      effect: {
        value: 'Audit'  // This policy (as of 2.0.1) does not have a Deny option, otherwise that would be set here.
      }
    }
  }
}

// Applying the built-in 'Kubernetes Services should be upgraded to a non-vulnerable Kubernetes version' policy at the resource group level.
resource paOldKubernetesDisabled 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: guid(pdOldKubernetesDisabled.id, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${pdOldKubernetesDisabled.properties.displayName}', 120)
    description: pdOldKubernetesDisabled.properties.description
    policyDefinitionId: pdOldKubernetesDisabled.id
    parameters: {
      effect: {
        value: 'Audit'  // This policy (as of 1.0.2) does not have a Deny option, otherwise that would be set here.
      }
    }
  }
}

// Applying the built-in 'Role-Based Access Control (RBAC) should be used on Kubernetes Services' policy at the resource group level.
resource paRbacEnabled 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: guid(pdRbacEnabled.id, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${pdRbacEnabled.properties.displayName}', 120)
    description: pdRbacEnabled.properties.description
    policyDefinitionId: pdRbacEnabled.id
    parameters: {
      effect: {
        value: 'Audit'  // This policy (as of 1.0.2) does not have a Deny option, otherwise that would be set here.
      }
    }
  }
}

// Applying the built-in 'Azure Kubernetes Service Clusters should use managed identities' policy at the resource group level.
resource paManagedIdentitiesEnabled 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: guid(pdManagedIdentitiesEnabled.id, resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${pdManagedIdentitiesEnabled.properties.displayName}', 120)
    description: pdManagedIdentitiesEnabled.properties.description
    policyDefinitionId: pdManagedIdentitiesEnabled.id
    parameters: {
      effect: {
        value: 'Audit'  // This policy (as of 1.0.0) does not have a Deny option, otherwise that would be set here.
      }
    }
  }
}

// Deploying and applying the custom policy 'Kubernetes cluster ingress TLS hosts must have defined domain suffix' as defined in nested_K8sCustomIngressTlsHostsHaveDefinedDomainSuffix.bicep
// Note: Policy definition must be deployed as module since policy definitions require a targetScope of 'subscription'.

module modK8sIngressTlsHostsHaveDefinedDomainSuffix 'policy-K8sCustomIngressTlsHostsHaveDefinedDomainSuffix.bicep' = {
  name: 'modK8sIngressTlsHostsHaveDefinedDomainSuffix'
  scope: subscription()
}

resource paK8sIngressTlsHostsHaveSpecificDomainSuffix 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: guid('K8sCustomIngressTlsHostsHaveDefinedDomainSuffix', resourceGroup().id, clusterName)
  location: 'global'
  scope: resourceGroup()
  properties: {
    displayName: take('[${clusterName}] ${modK8sIngressTlsHostsHaveDefinedDomainSuffix.outputs.policyName}', 120)
    description: modK8sIngressTlsHostsHaveDefinedDomainSuffix.outputs.policyDescription
    policyDefinitionId: modK8sIngressTlsHostsHaveDefinedDomainSuffix.outputs.policyId
    parameters: {
      excludedNamespaces: {
        value: []
      }
      effect: {
        value: 'deny'
      }
      allowedDomainSuffixes: {
        value: [
          domainName
        ]
      }
    }
  }
}

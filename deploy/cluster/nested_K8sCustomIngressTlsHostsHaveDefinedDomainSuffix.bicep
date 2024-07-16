targetScope = 'subscription'

/*** RESOURCES ***/

resource pdK8sCustomIngressTlsHostsHaveDefinedDomainSuffix 'Microsoft.Authorization/policyDefinitions@2023-04-01' = {
  scope: subscription()
  name: 'K8sCustomIngressTlsHostsHaveDefinedDomainSuffix'
  properties: {
    policyType: 'Custom'
    mode: 'Microsoft.Kubernetes.Data'
    displayName: 'Kubernetes cluster ingress TLS hosts must have defined domain suffix'
    description: 'Kubernetes cluster ingress TLS hosts must have defined domain suffix'
    policyRule: {
      if: {
        field: 'type'
        in: [
          'Microsoft.ContainerService/managedClusters'
        ]
      }
      then: {
        effect: '[parameters(\'effect\')]'
        details: {
          templateInfo: {
            sourceType: 'Base64Encoded'
            content: loadFileAsBase64('policies/EnsureClusterIdentityHasRbacToSelfManagedResources.yaml')
          }
          apiGroups: [
            'networking.k8s.io'
          ]
          kinds: [
            'Ingress'
          ]
          namespaces: '[parameters(\'namespaces\')]'
          excludedNamespaces: '[parameters(\'excludedNamespaces\')]'
          labelSelector: '[parameters(\'labelSelector\')]'
          values: {
            allowedDomainSuffixes: '[parameters(\'allowedDomainSuffixes\')]'
          }
        }
      }
    }
    parameters: {
      effect: {
        type: 'String'
        metadata: {
          displayName: 'Effect'
          description: '\'audit\' allows a non-compliant resource to be created or updated, but flags it as non-compliant. \'deny\' blocks the non-compliant resource creation or update. \'disabled\' turns off the policy.'
        }
        allowedValues: [
          'audit'
          'Audit'
          'deny'
          'Deny'
          'disabled'
          'Disabled'
        ]
        defaultValue: 'audit'
      }
      excludedNamespaces: {
        type: 'Array'
        metadata: {
          displayName: 'Namespace exclusions'
          description: 'List of Kubernetes namespaces to exclude from policy evaluation.'
        }
        defaultValue: [
          'kube-system'
          'gatekeeper-system'
          'azure-arc'
        ]
      }
      namespaces: {
        type: 'Array'
        metadata: {
          displayName: 'Namespace inclusions'
          description: 'List of Kubernetes namespaces to only include in policy evaluation. An empty list means the policy is applied to all resources in all namespaces.'
        }
        defaultValue: []
      }
      labelSelector: {
        type: 'Object'
        metadata: {
          displayName: 'Kubernetes label selector'
          description: 'Label query to select Kubernetes resources for policy evaluation. An empty label selector matches all Kubernetes resources.'
        }
        defaultValue: {
        }
        schema: {
          description: 'A label selector is a label query over a set of resources. The result of matchLabels and matchExpressions are ANDed. An empty label selector matches all resources.'
          type: 'object'
          properties: {
            matchLabels: {
              description: 'matchLabels is a map of {key,value} pairs.'
              type: 'object'
              additionalProperties: {
                type: 'string'
              }
              minProperties: 1
            }
            matchExpressions: {
              description: 'matchExpressions is a list of values, a key, and an operator.'
              type: 'array'
              items: {
                type: 'object'
                properties: {
                  key: {
                    description: 'key is the label key that the selector applies to.'
                    type: 'string'
                  }
                  operator: {
                    description: 'operator represents a key\'s relationship to a set of values.'
                    type: 'string'
                    enum: [
                      'In'
                      'NotIn'
                      'Exists'
                      'DoesNotExist'
                    ]
                  }
                  values: {
                    description: 'values is an array of string values. If the operator is In or NotIn, the values array must be non-empty. If the operator is Exists or DoesNotExist, the values array must be empty.'
                    type: 'array'
                    items: {
                      type: 'string'
                    }
                  }
                }
                required: [
                  'key'
                  'operator'
                ]
                additionalProperties: false
              }
              minItems: 1
            }
          }
          additionalProperties: false
        }
      }
      allowedDomainSuffixes: {
        type: 'Array'
        metadata: {
          displayName: 'List of compliant domain suffixes'
          description: 'List of compliant domain suffixes'
        }
      }
    }
  }
}


output policyId string = pdK8sCustomIngressTlsHostsHaveDefinedDomainSuffix.id
output policyName string = pdK8sCustomIngressTlsHostsHaveDefinedDomainSuffix.properties.displayName
output policyDescription string = pdK8sCustomIngressTlsHostsHaveDefinedDomainSuffix.properties.description

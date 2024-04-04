targetScope = 'subscription'

/*** RESOURCES ***/

resource pdK8sCustomIngressTlsHostsHaveDefinedDomainSuffix 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
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
            content: 'YXBpVmVyc2lvbjogdGVtcGxhdGVzLmdhdGVrZWVwZXIuc2gvdjFiZXRhMQpraW5kOiBDb25zdHJhaW50VGVtcGxhdGUKbWV0YWRhdGE6CiAgbmFtZTogazhzY3VzdG9taW5ncmVzc3Rsc2hvc3RzaGF2ZWRlZmluZWRkb21haW5zdWZmaXgKc3BlYzoKICBjcmQ6CiAgICBzcGVjOgogICAgICBuYW1lczoKICAgICAgICBraW5kOiBrOHNjdXN0b21pbmdyZXNzdGxzaG9zdHNoYXZlZGVmaW5lZGRvbWFpbnN1ZmZpeAogICAgICB2YWxpZGF0aW9uOgogICAgICAgIG9wZW5BUElWM1NjaGVtYToKICAgICAgICAgIHR5cGU6IG9iamVjdAogICAgICAgICAgcHJvcGVydGllczoKICAgICAgICAgICAgYWxsb3dlZERvbWFpblN1ZmZpeGVzOgogICAgICAgICAgICAgIHR5cGU6IGFycmF5CiAgICAgICAgICAgICAgaXRlbXM6CiAgICAgICAgICAgICAgICB0eXBlOiBzdHJpbmcKICB0YXJnZXRzOgogICAgLSB0YXJnZXQ6IGFkbWlzc2lvbi5rOHMuZ2F0ZWtlZXBlci5zaAogICAgICByZWdvOiB8CiAgICAgICAgcGFja2FnZSBrOHNjdXN0b21pbmdyZXNzdGxzaG9zdHNoYXZlZGVmaW5lZGRvbWFpbnN1ZmZpeAoKICAgICAgICB2aW9sYXRpb25beyJtc2ciOiBtc2csICJkZXRhaWxzIjoge319XSB7CiAgICAgICAgICBhbGxvd2VkRG9tYWluU3VmZml4ZXMgOj0gaW5wdXQucGFyYW1ldGVycy5hbGxvd2VkRG9tYWluU3VmZml4ZXMKICAgICAgICAgIGFsbERlZmluZWRIb3N0cyA6PSB7biB8IG4gOj0gaW5wdXQucmV2aWV3Lm9iamVjdC5zcGVjLnRsc1tfXS5ob3N0c1tfXX0KICAgICAgICAgIG1hdGNoZWRIb3N0cyA6PSB7IHsiaG9zdCI6IGgsICJtYXRjaGVkRG9tYWlucyI6IGR9IHwKICAgICAgICAgICAgaCA6PSBhbGxEZWZpbmVkSG9zdHNbX10gOwogICAgICAgICAgICBkIDo9IHsgbiB8IG4gOj0gYWxsb3dlZERvbWFpblN1ZmZpeGVzW19dIDsgZW5kc3dpdGgoaCwgbil9CiAgICAgICAgICB9CiAgICAgICAgICB1bm1hdGNoZWRIb3N0cyA6PSB7IGggfAogICAgICAgICAgICBoIDo9IG1hdGNoZWRIb3N0c1t4XS5ob3N0IDsgCiAgICAgICAgICAgIGQgOj0gbWF0Y2hlZEhvc3RzW3hdLm1hdGNoZWREb21haW5zIDsgCiAgICAgICAgICAgIGNvdW50KGQpID09IDAKICAgICAgICAgIH0KICAgICAgICAgIGNvdW50KHVubWF0Y2hlZEhvc3RzKSA+IDAKICAgICAgICAgIG1zZyA6PSBzcHJpbnRmKCJUTFMgaG9zdCBtdXN0IGhhdmUgb25lIG9mIGRlZmluZWQgZG9tYWluIHN1ZmZpeGVzLiBWYWxpZCBkb21haW4gbmFtZXMgYXJlICV2OyBkZWZpbmVkIFRMUyBob3N0cyBhcmUgJXY7IGluY29tcGxpYW50IGhvc3RzIGFyZSAldi4iLCBbYWxsb3dlZERvbWFpblN1ZmZpeGVzLCBhbGxEZWZpbmVkSG9zdHMsIHVubWF0Y2hlZEhvc3RzXSkKICAgICAgICB9'
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

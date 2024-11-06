targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('Name of the AKS cluster.')
param clusterName string

param location string = resourceGroup().location

/*** VARIABLES ***/

var kubernetesAlertRuleGroupName = 'KubernetesAlert-RecommendedMetricAlerts${clusterName}'
var kubernetesAlertRuleGroupDescription = 'Kubernetes Alert RuleGroup-RecommendedMetricAlerts - 0.1'

/*** EXISTING RESOURCES ***/
resource mc 'Microsoft.ContainerService/managedClusters@2024-03-02-preview' existing = {
  name: clusterName
}

resource amw 'Microsoft.Monitor/accounts@2023-04-03' existing = {
  name: 'amw-${clusterName}'
}

/*** RESOURCES ***/

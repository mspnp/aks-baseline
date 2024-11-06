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

resource kubernetesAlertRuleGroupName_Cluster_level 'Microsoft.AlertsManagement/prometheusRuleGroups@2023-03-01' = {
  name: '${kubernetesAlertRuleGroupName}-Cluster-level'
  location: location
  properties: {
    description: kubernetesAlertRuleGroupDescription
    scopes: [
      amw.id
      mc.id
    ]
    clusterName: clusterName
    interval: 'PT1M'
    rules: [
      {
        alert: 'KubeCPUQuotaOvercommit'
        expression: 'sum(min without(resource) (kube_resourcequota{job="kube-state-metrics", type="hard", resource=~"(cpu|requests.cpu)"}))  /sum(kube_node_status_allocatable{resource="cpu", job="kube-state-metrics"})  > 1.5'
        for: 'PT5M'
        annotations: {
          description: 'Cluster {{ $labels.cluster}} has overcommitted CPU resource requests for Namespaces. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/cluster-level-recommended-alerts).'
        }
        labels: {
          severity: 'warning'
        }
        enabled: true
        severity: 3
        resolveConfiguration: {
          autoResolved: true
          timeToResolve: 'PT10M'
        }
        actions: []
      }
      {
        alert: 'KubeMemoryQuotaOvercommit'
        expression: 'sum(min without(resource) (kube_resourcequota{job="kube-state-metrics", type="hard", resource=~"(memory|requests.memory)"}))  /sum(kube_node_status_allocatable{resource="memory", job="kube-state-metrics"})  > 1.5'
        for: 'PT5M'
        annotations: {
          description: 'Cluster {{ $labels.cluster}} has overcommitted memory resource requests for Namespaces. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/cluster-level-recommended-alerts).'
        }
        enabled: true
        severity: 3
        resolveConfiguration: {
          autoResolved: true
          timeToResolve: 'PT10M'
        }
        labels: {
          severity: 'warning'
        }
        actions: []
      }
      {
        alert: 'KubeClientErrors'
        expression: '(sum(rate(rest_client_requests_total{code=~"5.."}[5m])) by (cluster, instance, job, namespace)  / sum(rate(rest_client_requests_total[5m])) by (cluster, instance, job, namespace)) > 0.01'
        for: 'PT15M'
        annotations: {
          description: 'Kubernetes API server client \'{{ $labels.job }}/{{ $labels.instance }}\' is experiencing {{ $value | humanizePercentage }} errors. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/cluster-level-recommended-alerts).'
        }
        enabled: true
        severity: 3
        resolveConfiguration: {
          autoResolved: true
          timeToResolve: 'PT10M'
        }
        labels: {
          severity: 'warning'
        }
        actions: []
      }
      {
        alert: 'KubePersistentVolumeFillingUp'
        expression: 'kubelet_volume_stats_available_bytes{job="kubelet"}/kubelet_volume_stats_capacity_bytes{job="kubelet"} < 0.15 and kubelet_volume_stats_used_bytes{job="kubelet"} > 0 and predict_linear(kubelet_volume_stats_available_bytes{job="kubelet"}[6h], 4 * 24 * 3600) < 0 unless on(namespace, persistentvolumeclaim) kube_persistentvolumeclaim_access_mode{ access_mode="ReadOnlyMany"} == 1 unless on(namespace, persistentvolumeclaim) kube_persistentvolumeclaim_labels{label_excluded_from_alerts="true"} == 1'
        for: 'PT60M'
        annotations: {
          description: 'Based on recent sampling, the PersistentVolume claimed by {{ $labels.persistentvolumeclaim }} in Namespace {{ $labels.namespace }} is expected to fill up within four days. Currently {{ $value | humanizePercentage }} is available. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/cluster-level-recommended-alerts).'
        }
        enabled: true
        severity: 4
        resolveConfiguration: {
          autoResolved: true
          timeToResolve: 'PT15M'
        }
        labels: {
          severity: 'warning'
        }
        actions: []
      }
      {
        alert: 'KubePersistentVolumeInodesFillingUp'
        expression: 'kubelet_volume_stats_inodes_free{job="kubelet"} / kubelet_volume_stats_inodes{job="kubelet"} < 0.03'
        for: 'PT15M'
        annotations: {
          description: 'The PersistentVolume claimed by {{ $labels.persistentvolumeclaim }} in Namespace {{ $labels.namespace }} only has {{ $value | humanizePercentage }} free inodes. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/cluster-level-recommended-alerts).'
        }
        enabled: true
        severity: 4
        resolveConfiguration: {
          autoResolved: true
          timeToResolve: 'PT10M'
        }
        labels: {
          severity: 'warning'
        }
        actions: []
      }
      {
        alert: 'KubePersistentVolumeErrors'
        expression: 'kube_persistentvolume_status_phase{phase=~"Failed|Pending",job="kube-state-metrics"} > 0'
        for: 'PT05M'
        annotations: {
          description: 'The persistent volume {{ $labels.persistentvolume }} has status {{ $labels.phase }}. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/cluster-level-recommended-alerts).'
        }
        enabled: true
        severity: 4
        resolveConfiguration: {
          autoResolved: true
          timeToResolve: 'PT10M'
        }
        labels: {
          severity: 'warning'
        }
        actions: []
      }
      {
        alert: 'KubeContainerWaiting'
        expression: 'sum by (namespace, pod, container, cluster) (kube_pod_container_status_waiting_reason{job="kube-state-metrics"}) > 0'
        for: 'PT60M'
        annotations: {
          description: 'pod/{{ $labels.pod }} in namespace {{ $labels.namespace }} on container {{ $labels.container}} has been in waiting state for longer than 1 hour. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/cluster-level-recommended-alerts).'
        }
        enabled: true
        severity: 3
        resolveConfiguration: {
          autoResolved: true
          timeToResolve: 'PT10M'
        }
        labels: {
          severity: 'warning'
        }
        actions: []
      }
      {
        alert: 'KubeDaemonSetNotScheduled'
        expression: 'kube_daemonset_status_desired_number_scheduled{job="kube-state-metrics"} - kube_daemonset_status_current_number_scheduled{job="kube-state-metrics"} > 0'
        for: 'PT15M'
        annotations: {
          description: '{{ $value }} Pods of DaemonSet {{ $labels.namespace }}/{{ $labels.daemonset }} are not scheduled. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/cluster-level-recommended-alerts).'
        }
        enabled: true
        severity: 3
        resolveConfiguration: {
          autoResolved: true
          timeToResolve: 'PT10M'
        }
        labels: {
          severity: 'warning'
        }
        actions: []
      }
      {
        alert: 'KubeDaemonSetMisScheduled'
        expression: 'kube_daemonset_status_number_misscheduled{job="kube-state-metrics"} > 0'
        for: 'PT15M'
        annotations: {
          description: '{{ $value }} Pods of DaemonSet {{ $labels.namespace }}/{{ $labels.daemonset }} are running where they are not supposed to run. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/cluster-level-recommended-alerts).'
        }
        enabled: true
        severity: 3
        resolveConfiguration: {
          autoResolved: true
          timeToResolve: 'PT10M'
        }
        labels: {
          severity: 'warning'
        }
        actions: []
      }
      {
        alert: 'KubeQuotaAlmostFull'
        expression: 'kube_resourcequota{job="kube-state-metrics", type="used"}  / ignoring(instance, job, type)(kube_resourcequota{job="kube-state-metrics", type="hard"} > 0)  > 0.9 < 1'
        for: 'PT15M'
        annotations: {
          description: '{{ $value | humanizePercentage }} usage of {{ $labels.resource }} in namespace {{ $labels.namespace }} in {{ $labels.cluster}}. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/cluster-level-recommended-alerts).'
        }
        enabled: true
        severity: 3
        resolveConfiguration: {
          autoResolved: true
          timeToResolve: 'PT10M'
        }
        labels: {
          severity: 'warning'
        }
        actions: []
      }
    ]
  }
}

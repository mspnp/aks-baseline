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
        alert: 'KubeContainerOOMKilledCount'
        expression: 'sum by (cluster,container,controller,namespace)(kube_pod_container_status_last_terminated_reason{reason="OOMKilled"} * on(cluster,namespace,pod) group_left(controller) label_replace(kube_pod_owner, "controller", "$1", "owner_name", "(.*)")) > 0'
        for: 'PT5M'
        annotations: {
          description: 'Number of OOM killed containers is greater than 0. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/cluster-level-recommended-alerts).'
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

resource kubernetesAlertRuleGroupName_Node_level 'Microsoft.AlertsManagement/prometheusRuleGroups@2023-03-01' = {
  name: '${kubernetesAlertRuleGroupName}-Node-level'
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
        alert: 'KubeNodeUnreachable'
        expression: '(kube_node_spec_taint{job="kube-state-metrics",key="node.kubernetes.io/unreachable",effect="NoSchedule"} unless ignoring(key,value) kube_node_spec_taint{job="kube-state-metrics",key=~"ToBeDeletedByClusterAutoscaler|cloud.google.com/impending-node-termination|aws-node-termination-handler/spot-itn"}) == 1'
        for: 'PT15M'
        annotations: {
          description: '{{ $labels.node }} in {{ $labels.cluster}} is unreachable and some workloads may be rescheduled. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/node-level-recommended-alerts).'
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
        alert: 'KubeNodeReadinessFlapping'
        expression: 'sum(changes(kube_node_status_condition{status="true",condition="Ready"}[15m])) by (cluster, node) > 2'
        for: 'PT15M'
        annotations: {
          description: 'The readiness status of node {{ $labels.node }} in {{ $labels.cluster}} has changed more than 2 times in the last 15 minutes. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/node-level-recommended-alerts).'
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
        alert: 'KubeNodeDiskUsageHigh'
        expression: '100 - ((node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100) > 80'
        for: 'PT15M'
        annotations: {
          description: 'The disk usage on node {{ $labels.instance }} in {{ $labels.job }} has exceeded 80% and current usage is {{ $value | humanizePercentage }}%). For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/node-level-recommended-alerts).'
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

resource kubernetesAlertRuleGroupName_Pod_level 'Microsoft.AlertsManagement/prometheusRuleGroups@2023-03-01' = {
  name: '${kubernetesAlertRuleGroupName}-Pod-level'
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
        alert: 'KubePodCrashLooping'
        expression: 'max_over_time(kube_pod_container_status_waiting_reason{reason="CrashLoopBackOff", job="kube-state-metrics"}[5m]) >= 1'
        for: 'PT15M'
        annotations: {
          description: '{{ $labels.namespace }}/{{ $labels.pod }} ({{ $labels.container }}) in {{ $labels.cluster}} is restarting {{ printf "%.2f" $value }} / second. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts).'
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
        alert: 'KubePodContainerRestart'
        expression: 'sum by (namespace, controller, container, cluster)(increase(kube_pod_container_status_restarts_total{job="kube-state-metrics"}[1h])* on(namespace, pod, cluster) group_left(controller) label_replace(kube_pod_owner, "controller", "$1", "owner_name", "(.*)")) > 0'
        for: 'PT15M'
        annotations: {
          description: 'Pod container restarted in the last 1 hour. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts).'
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
        alert: 'KubePodReadyStateLow'
        expression: 'sum by (cluster,namespace,deployment)(kube_deployment_status_replicas_ready) / sum by (cluster,namespace,deployment)(kube_deployment_spec_replicas) <.8 or sum by (cluster,namespace,deployment)(kube_daemonset_status_number_ready) / sum by (cluster,namespace,deployment)(kube_daemonset_status_desired_number_scheduled) <.8 '
        for: 'PT5M'
        annotations: {
          description: 'Ready state of pods is less than 80%. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts).'
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
        alert: 'KubePodFailedState'
        expression: 'sum by (cluster, namespace, controller) (kube_pod_status_phase{phase="failed"} * on(namespace, pod, cluster) group_left(controller) label_replace(kube_pod_owner, "controller", "$1", "owner_name", "(.*)"))  > 0'
        for: 'PT5M'
        annotations: {
          description: 'Number of pods in failed state are greater than 0. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts).'
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
        alert: 'KubePodNotReadyByController'
        expression: 'sum by (namespace, controller, cluster) (max by(namespace, pod, cluster) (kube_pod_status_phase{job="kube-state-metrics", phase=~"Pending|Unknown"}  ) * on(namespace, pod, cluster) group_left(controller)label_replace(kube_pod_owner,"controller","$1","owner_name","(.*)")) > 0'
        for: 'PT15M'
        annotations: {
          description: '{{ $labels.namespace }}/{{ $labels.pod }} in {{ $labels.cluster}} by controller is not ready. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts).'
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
        alert: 'KubeStatefulSetGenerationMismatch'
        expression: 'kube_statefulset_status_observed_generation{job="kube-state-metrics"} != kube_statefulset_metadata_generation{job="kube-state-metrics"}'
        for: 'PT15M'
        annotations: {
          description: 'StatefulSet generation for {{ $labels.namespace }}/{{ $labels.statefulset }} does not match, this indicates that the StatefulSet has failed but has not been rolled back. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts).'
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
        alert: 'KubeJobFailed'
        expression: 'kube_job_failed{job="kube-state-metrics"}  > 0'
        for: 'PT15M'
        annotations: {
          description: 'Job {{ $labels.namespace }}/{{ $labels.job_name }} in {{ $labels.cluster}} failed to complete. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts).'
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
        alert: 'KubeletPodStartUpLatencyHigh'
        expression: 'histogram_quantile(0.99, sum(rate(kubelet_pod_worker_duration_seconds_bucket{job="kubelet"}[5m])) by (cluster, instance, le)) * on(cluster, instance) group_left(node) kubelet_node_name{job="kubelet"} > 60'
        for: 'PT10M'
        annotations: {
          description: 'Kubelet Pod startup latency is too high. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts).'
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
        alert: 'KubePVUsageHigh'
        expression: 'avg by (namespace, controller, container, cluster)(((kubelet_volume_stats_used_bytes{job="kubelet"} / on(namespace,cluster,pod,container) group_left kubelet_volume_stats_capacity_bytes{job="kubelet"}) * on(namespace, pod, cluster) group_left(controller) label_replace(kube_pod_owner, "controller", "$1", "owner_name", "(.*)"))) > .8'
        for: 'PT15M'
        annotations: {
          description: 'Average PV usage on pod {{ $labels.pod }} in container {{ $labels.container }}  is greater than 80%. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts).'
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
        alert: 'KubeDeploymentReplicasMismatch'
        expression: '(  kube_deployment_spec_replicas{job="kube-state-metrics"}    >  kube_deployment_status_replicas_available{job="kube-state-metrics"}) and (  changes(kube_deployment_status_replicas_updated{job="kube-state-metrics"}[10m])    ==  0)'
        for: 'PT15M'
        annotations: {
          description: 'Deployment {{ $labels.namespace }}/{{ $labels.deployment }} in {{ $labels.cluster}} replica mismatch. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts).'
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
        alert: 'KubeStatefulSetReplicasMismatch'
        expression: '(  kube_statefulset_status_replicas_ready{job="kube-state-metrics"}    !=  kube_statefulset_status_replicas{job="kube-state-metrics"}) and (  changes(kube_statefulset_status_replicas_updated{job="kube-state-metrics"}[10m])    ==  0)'
        for: 'PT15M'
        annotations: {
          description: 'StatefulSet {{ $labels.namespace }}/{{ $labels.statefulset }} in {{ $labels.cluster}} replica mismatch. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts).'
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
        alert: 'KubeHpaReplicasMismatch'
        expression: '(kube_horizontalpodautoscaler_status_desired_replicas{job="kube-state-metrics"}  !=kube_horizontalpodautoscaler_status_current_replicas{job="kube-state-metrics"})  and(kube_horizontalpodautoscaler_status_current_replicas{job="kube-state-metrics"}  >kube_horizontalpodautoscaler_spec_min_replicas{job="kube-state-metrics"})  and(kube_horizontalpodautoscaler_status_current_replicas{job="kube-state-metrics"}  <kube_horizontalpodautoscaler_spec_max_replicas{job="kube-state-metrics"})  and changes(kube_horizontalpodautoscaler_status_current_replicas{job="kube-state-metrics"}[15m]) == 0'
        for: 'PT15M'
        annotations: {
          description: 'Horizontal Pod Autoscaler in {{ $labels.cluster}} has not matched the desired number of replicas for longer than 15 minutes. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts).'
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
        alert: 'KubeHpaMaxedOut'
        expression: 'kube_horizontalpodautoscaler_status_current_replicas{job="kube-state-metrics"}  ==kube_horizontalpodautoscaler_spec_max_replicas{job="kube-state-metrics"}'
        for: 'PT15M'
        annotations: {
          description: 'Horizontal Pod Autoscaler in {{ $labels.cluster}} has been running at max replicas for longer than 15 minutes. For more information on this alert, please refer to this [link](https://aka.ms/aks-alerts/pod-level-recommended-alerts).'
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
    ]
  }
}

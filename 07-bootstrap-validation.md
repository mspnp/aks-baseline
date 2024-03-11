# Validate your cluster is bootstrapped and enrolled in GitOps

Now that the [AKS cluster](./06-aks-cluster.md) has been deployed, the next step to validate that your cluster has been placed under a GitOps management solution, Flux in this case.

## Steps

GitOps allows a team to author Kubernetes manifest files, persist them in their Git repo, and have them automatically apply to their cluster as changes occur. This reference implementation is focused on the baseline cluster, so Flux is managing cluster-level concerns. This is distinct from workload-level concerns, which would be possible as well to manage via Flux, and would typically be done by additional Flux configuration in the cluster. The namespace `cluster-baseline-settings` will be used to provide a logical division of the cluster bootstrap configuration from workload configuration. Examples of manifests that are applied:

- Cluster role bindings for the AKS-managed Microsoft Entra ID integration
- Cluster-wide configuration of Azure Monitor for Containers
- The workload's namespace named `a0008`

1. Install `kubectl` 1.27 or newer. (`kubectl` supports ±1 Kubernetes version.)

   ```bash
   sudo az aks install-cli
   kubectl version --client
   ```

   > Starting with `kubectl` 1.24, you must also have the `kubelogin` credential (exec) plug-in available for Microsoft Entra ID authentication. Installing `kubectl` via `az aks install-cli` does this already, but if you install `kubectl` in a different way, make sure `kubelogin` is [installed](https://github.com/Azure/kubelogin#getting-started).

1. Get the cluster name.

   ```bash
   AKS_CLUSTER_NAME=$(az aks list -g rg-bu0001a0008 --query '[0].name' -o tsv)
   echo AKS_CLUSTER_NAME: $AKS_CLUSTER_NAME
   ```

1. Validate the current day2 strategy this baseline follows to upagrade the AKS cluster

   ```bash
   az aks show -n $AKS_CLUSTER_NAME -g rg-bu0001a0008 --query "autoUpgradeProfile"
   ```

   ```outcome
   {
     "nodeOsUpgradeChannel": "NodeImage",
     "upgradeChannel": "node-image"
   }
   ```

   > This cluster now receives weekly updates for both the Operating System (OS) and Kubernetes. For workloads that need to always run the most secure OS version, you can opt-in for regular updates by selecting the `SecurityPatch` channel.

   > The node update phase of the cluster’s lifecycle belongs to day2 operations. Cluster operations will regularly update node images for two main reasons: 1) to update the Kubernetes cluster version, and 2) to keep up with node-level OS updates. A new AKS release introduces new features, such as addons and new Kubernetes versions, while new AKS node images bring changes at the OS level. Both types of releases adhere to Azure Safe Deployment Practices for rollout across all regions. For more information, please refer to [How to use the release tracker](https://learn.microsoft.com/azure/aks/release-tracker#how-to-use-the-release-tracker). Additionally, cluster operations aim to stay updated with supported Kubernetes versions for Service Level Agreement (SLA) compliance and to avoid accumulating updates, as version updates cannot be skipped at will. For more details, please see [Kubernetes version upgrades](https://learn.microsoft.com/azure/aks/upgrade-aks-cluster?tabs=azure-cli#kubernetes-version-upgrades).

   > When a new update becomes available, it can be manually applied for the greatest degree of control by making requests against the Azure control plane. Alternatively, the operations team can opt to automatically update to the latest version by configuring an update channel to follow the desired cadence. This can be combined with a planned maintenance window, one for Kubernetes version updates and another for OS-level upgrades. AKS offers two different configurable auto-upgrade channels dedicated to these update types. For more information, please refer to [Upgrade options for Azure Kubernetes Service (AKS) clusters](https://learn.microsoft.com/azure/aks/upgrade-cluster). Node pools in this AKS cluster span multiple availability zones. Therefore, it’s important to note that automatic updates are conducted based on a best-effort zone balancing in node groups. To prevent zone imbalance and increase availability, Nodes Max Surge and Pod Disruption Budget are configured in this baseline. By default, cluster nodes are updated one at a time. Max Surge can adjust the speed of a cluster upgrade. In clusters with 6+ nodes hosting disruption-sensitive workloads, a surge of up to `33%` is recommended for a safe upgrade pace. For more information, please see [Customer node surge upgrade](https://learn.microsoft.com/azure/aks/upgrade-aks-cluster?tabs=azure-cli#customize-node-surge-upgrade). To minimize disruption, production clusters should be configured with [node draining timeout](https://learn.microsoft.com/azure/aks/upgrade-aks-cluster?tabs=azure-cli#set-node-drain-timeout-valuei) and [soak time](https://learn.microsoft.com/azure/aks/upgrade-aks-cluster?tabs=azure-cli#set-node-soak-time-value), taking into account the specific characteristics of their workloads.

1. See your maitenance configuration

   ```bash
   az aks maintenanceconfiguration list --cluster-name $AKS_CLUSTER_NAME -g rg-bu0001a0008
   ```

> When managing an Azure Kubernetes Service (AKS) cluster, it is crucial to plan your upgrades thoughtfully. Here are some recommendations to consider:
>
> Mindful Timing for Upgrades:
> - Be mindful of when upgrades should occur. If you have overlapping maintenance windows, AKS will determine the running order.
> - To avoid conflicts, leave at least 24 hours between maintenance window configurations. The timing will depend on the number of nodes in your specific cluster and the duration required for upgrades.
>
> OS-Level Updates:
> - By default, the OS-level updates maintenance window is scheduled on a weekly cadence. This is because the OS channel is configured with `NodeImage`, where a new node image is shipped every week.
> - If you choose the `SecurityPatch` channel, consider changing the maintenance window to daily for more frequent updates.
>
> Kubernetes Version Management:
> - To stay current with the latest Kubernetes version, a monthly cadence is generally sufficient. However, you can adjust this based on your specific needs.
> - For more regular updates, configure your cluster to upgrade every two weeks.
>
> Maintenance Operations:
> - Keep in mind that performing maintenance operations is considered best-effort. They are not guaranteed to occur within a specific window.
> - While it’s not strictly recommended, if you require greater control, consider manually updating your cluster.
>
> Remember that these guidelines provide flexibility, allowing you to strike a balance between timely updates and operational control. Choose the approach that aligns best with your organization’s requirements.

1. Validate there are no available image upgrades. As this AKS cluster was recently deployed, only a race condition between publication of new available images and the deployment image fetch could result into a different state.

   ```bash
   az aks nodepool get-upgrades -n npuser01 --cluster-name $AKS_CLUSTER_NAME -g rg-bu0001a0008 && \
   az aks nodepool show -n npuser01 --cluster-name $AKS_CLUSTER_NAME -g rg-bu0001a0008 --query nodeImageVersion
   ```

   > Typically, base node iamges doesn't contain a suffix with a date (i.e. `AKSUbuntu-2204gen2containerd`). If the `nodeImageVersion` value looks like `AKSUbuntu-2204gen2containerd-202402.26.0` a SecurityPatch or NodeImage upgrade has been applied to the aks node.

1. Get AKS `kubectl` credentials.

   > In the [Microsoft Entra ID Integration](03-microsoft-entra-id.md) step, we placed our cluster under Microsoft Entra group-backed RBAC. This is the first time we are seeing this used. `az aks get-credentials` sets your `kubectl` context so that you can issue commands against your cluster. Even when you have enabled Microsoft Entra ID integration with your AKS cluster, an Azure user has sufficient permissions on the cluster resource can still access your AKS cluster by using the `--admin` switch to this command. Using this switch *bypasses* Microsoft Entra ID and uses client certificate authentication instead; that isn't what we want to happen. So in order to prevent that practice, local account access such as `clusterAdmin` or `clusterMonitoringUser`) is expressly disabled.
   >
   > In a following step, you'll log in with a user that has been added to the Microsoft Entra security group used to back the Kubernetes RBAC admin role. Executing the first `kubectl` command below will invoke the Microsoft Entra ID login process to authorize the *user of your choice*, which will then be authenticated against Kubernetes RBAC to perform the action. The user you choose to log in with *must be a member of the Microsoft Entra group bound* to the `cluster-admin` ClusterRole. For simplicity you could either use the "break-glass" admin user created in [Microsoft Entra ID Integration](03-microsoft-entra-id.md) (`bu0001a0008-admin`) or any user you assigned to the `cluster-admin` group assignment in your [`cluster-rbac.yaml`](cluster-manifests/cluster-rbac.yaml) file.

   ```bash
   az aks get-credentials -g rg-bu0001a0008 -n $AKS_CLUSTER_NAME
   ```

   :warning: At this point two important steps are happening:

      - The `az aks get-credentials` command will be fetch a `kubeconfig` containing references to the AKS cluster you have created earlier.
      - To *actually* use the cluster you will need to authenticate. For that, run any `kubectl` commands which at this stage will prompt you to authenticate against Microsoft Entra ID. For example, run the following command:

   ```bash
   kubectl get nodes
   ```

   Once the authentication happens successfully, some new items will be added to your `kubeconfig` file such as an `access-token` with an expiration period. For more information on how this process works in Kubernetes refer to the [related documentation](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#openid-connect-tokens).

1. Validate your cluster is bootstrapped.

   The bootstrapping process that already happened due to the usage of the Flux extension for AKS has set up the following, amoung other things

   - the workload's namespace named `a0008`
   - installed kured

   ```bash
   kubectl get namespaces
   kubectl get all -n cluster-baseline-settings
   ```

   These commands will show you results that were due to the automatic bootstrapping process your cluster experienced due to the Flux GitOps extension. This content mirrors the content found in [`cluster-manifests`](./cluster-manifests), and commits made there will reflect in your cluster within minutes of making the change.

The end result of all of this is that `kubectl` was not required for any part of the bootstrapping process of a cluster. The usage of `kubectl`-based access should be reserved for emergency break-fix situations and not for day-to-day configuration operations on this cluster. Between templates for Azure Resource definitions, and the bootstrapping of manifests via the GitOps extension, all normal configuration activities can be performed without the need to use `kubectl`. You will however see us use it for the upcoming workload deployment. This is because the SDLC component of workloads are not in scope for this reference implementation, as this is focused the infrastructure and baseline configuration.

## Alternatives

Using the AKS extension for Flux gives you a seamless bootstrapping process that applies immediately after the cluster resource is created in Azure. It also supports the inclusion of that bootstrapping as resource templates to align with your IaC strategy. Alternatively you could apply bootstrapping as a secondary step after the cluster is deployed and manage that process external to the lifecycle of the cluster. Doing so will open your cluster up to a prolonged window between the cluster being deployed and your bootstrapping being applied.

Furthermore, Flux doesn't need to be installed as an extension and instead the GitOps operator of your choice (such as ArgoCD) could be installed as part of your external bootstrapping process.

## Recommendations

It is recommended to have a clearly defined bootstrapping process that occurs as close as practicable to the actual cluster deployment for immediate enrollment of your cluster into your internal processes and tooling. GitOps lends itself well to this desired outcome, and you're encouraged to explore its usage for your cluster bootstrapping process and optionally also workload-level concerns. GitOps is often positioned best for fleet (many clusters) management for uniformity and its simplicity at scale; a more manual (via deployment pipelines) bootstrapping is common on small instance-count AKS deployments. Either process can work with either cluster topologies. Use a bootstrapping process that aligns with your desired objectives and constraints found within your organization and team.

### Next step

:arrow_forward: [Prepare for the workload by installing its prerequisites](./08-workload-prerequisites.md)

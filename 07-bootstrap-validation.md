# Validate your cluster is bootstrapped and enrolled in GitOps

Now that the [AKS cluster](./06-aks-cluster.md) has been deployed, the next step to validate that your cluster has been placed under a GitOps management solution, Flux in this case.

## Steps

GitOps allows a team to author Kubernetes manifest files, persist them in their Git repo, and have them automatically apply to their cluster as changes occur. This reference implementation is focused on the baseline cluster, so Flux is managing cluster-level concerns. This is distinct from workload-level concerns, which would be possible as well to manage via Flux, and would typically be done by additional Flux configuration in the cluster. The namespace `cluster-baseline-settings` will be used to provide a logical division of the cluster bootstrap configuration from workload configuration. Examples of manifests that are applied:

- Cluster role bindings for the AKS-managed Microsoft Entra ID integration
- Cluster-wide configuration of Azure Monitor for Containers
- The workload's namespace named `a0008`

1. Install `kubectl` 1.25 or newer. (`kubectl` supports ±1 Kubernetes version.)

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

   > This cluster is now receiving OS and Kubernetes updates on weekly bassis. For some workloads where it is imperative to be running always on top of the most secure OS version available, it is possible to opt-in for regular updates by picking up the `SecurityPatch` channel instead.

   > The node update phase of the cluster lifecycle belongs to day2 operations. Cluster ops will update their node images as regular as required for two main reasons, the first one is for the Kubernetes cluster version, and the second one is to keep up with node-level OS updates. A new AKS release will be introducing new features such as new addons as well as making new kubernetes versions available while new AKS Node Images introduce changes at the OS level. Both release types follow Azure Safe Deployments Practices to roll out to all regions. For more information please take a look [How to use the release tracker](https://learn.microsoft.com/azure/aks/release-tracker#how-to-use-the-release-tracker). Additionally, cluster ops want to keep up with supported kubernetes versions for SLA reasons as well as to prevent from piled up updates since version updates can't be skipped at one's discretion. For more information, please take a look at [Kubernetes version upgrades](https://learn.microsoft.com/azure/aks/upgrade-aks-cluster?tabs=azure-cli#kubernetes-version-upgrades).

   > Once a new update is available, it can be applied manually for the greatest degree of control by placing requests against the Azure control plane. Alternatevely, ops team could opt-in to automatically update to the latest available version by configuring an udpate channel following a desired cadence combining this with a planned maintenance window, one for kubernetes version updates and another one for OS level upgrades. AKS provides with two configurable different auto-upgrade channels dedicated to the oforementioned update types. For more information, please refer to  [Upgrade options for Azure Kubernetes Service (AKS) clusters](https://learn.microsoft.com/azure/aks/upgrade-cluster). Nodepools in this AKS cluster span into multiple availability zones, so an important consideration is that automatic updates are conducted based on a best-effort zone balancing in node groups. Nodes Max Surge and Pod Disruption Budget are configured in this baseline to prevent from unbalanced zones increasing the Availabilty. By default clusters nodes are updated one at the time. Max Surge has the ability to increase or reduce the speed of a cluster upgrade. In clusters with 6+ nodes hosting worloads that are sensitive to disruptions, it is recommended up to `33%` surge to achieve a safe upgrade pace. For more information, please take a look at [Customer node surge upgrade](https://learn.microsoft.com/azure/aks/upgrade-aks-cluster?tabs=azure-cli#customize-node-surge-upgrade). To prevent from disruption, production clusters should be configured with [node draining timeout](https://learn.microsoft.com/azure/aks/upgrade-aks-cluster?tabs=azure-cli#set-node-drain-timeout-valuei) and [soak time](https://learn.microsoft.com/azure/aks/upgrade-aks-cluster?tabs=azure-cli#set-node-soak-time-value) by taking into account the specific charactistics of their workloads.

1. See your maitenance configuration

   ```bash
   az aks maintenanceconfiguration list --cluster-name $AKS_CLUSTER_NAME -g rg-bu0001a0008
   ```

   > It is recommended to be prescribed about when upgrades should occur. In case the maitenance windows overlap, AKS decides the running order. Leave at least 24h between maintance window configurations while it will depends based the number of nodes of a particular cluster and the time to upgrade being configured. The OS level updates maintenance window is scheduled to weekly cadence since the OS channel is configured with `NodeImage` where a new node image gets shipped every week. Consider changing this to daily if you opt in for the `SecurityPatch` channel. To stay on top of the kubernetes N-2 version, a monthly cadence is just fine while this cluster is configured every two weeks to keep it updated more regularly. Performing maintenance operations are considered best-effort only and aren't guaranteed to occur within a specified window. While not strictly recommended, for greater level of control consider updating a cluster manually.

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

Using the AKS extension for Flux gives you a seemless bootstrapping process that applies immediately after the cluster resource is created in Azure. It also supports the inclusion of that bootstrapping as resource templates to align with your IaC strategy. Alterantively you could apply bootstrapping as a secondary step after the cluster is deployed and manage that process external to the lifecycle of the cluster. Doing so will open your cluster up to a prolonged window between the cluster being deployed and your bootstrapping being applied.

Furthermore, Flux doesn't need to be installed as an extension and instead the GitOps operator of your choice (such as ArgoCD) could be installed as part of your external bootstrapping process.

## Recommendations

It is recommended to have a clearly defined bootstrapping process that occurs as close as practiable to the actual cluster deployment for immediate enrollment of your cluster into your internal processes and tooling. GitOps lends itself well to this desired outcome, and you're encouraged to explore its usage for your cluster bootstrapping process and optionally also workload-level concerns. GitOps is often positioned best for fleet (many clusters) management for uniformity and its simplicity at scale; a more manual (via deployment pipelines) bootstrapping is common on small instance-count AKS deployments. Either process can work with either cluster topologies. Use a bootstrapping process that aligns with your desired objectives and constraints found within your organization and team.

### Next step

:arrow_forward: [Prepare for the workload by installing its prerequisites](./08-workload-prerequisites.md)

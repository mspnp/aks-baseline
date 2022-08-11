# Validate your cluster is bootstrapped and enrolled in GitOps

Now that [the AKS cluster](./06-aks-cluster.md) has been deployed, the next step to validate that your cluster has been placed under a GitOps management solution, Flux in this case.

## Steps

GitOps allows a team to author Kubernetes manifest files, persist them in their git repo, and have them automatically apply to their cluster as changes occur. This reference implementation is focused on the baseline cluster, so Flux is managing cluster-level concerns. This is distinct from workload-level concerns, which would be possible as well to manage via Flux, and would typically be done by additional Flux configuration in the cluster. The namespace `cluster-baseline-settings` will be used to provide a logical division of the cluster bootstrap configuration from workload configuration. Examples of manifests that are applied:

* Cluster Role Bindings for the AKS-managed Azure AD integration
* AAD Pod Identity
* the workload's namespace named `a0008`

1. Install `kubectl` 1.24 or newer. (`kubectl` supports ±1 Kubernetes version.)

   ```bash
   sudo az aks install-cli
   kubectl version --client
   ```

   > Starting with `kubectl` 1.24, you must also have the `kubelogin` credential (exec) plugin available for Azure AD authentication. Installing `kubectl` via `az aks install-cli` does this already, but if you install `kubectl` in a different way, please make sure `kubelogin` is [installed](https://github.com/Azure/kubelogin#getting-started).

1. Get the cluster name.

   ```bash
   AKS_CLUSTER_NAME=$(az aks list -g rg-bu0001a0008 --query '[0].name' -o tsv)
   echo AKS_CLUSTER_NAME: $AKS_CLUSTER_NAME
   ```

1. Get AKS `kubectl` credentials.

   > In the [Azure Active Directory Integration](03-aad.md) step, we placed our cluster under AAD group-backed RBAC. This is the first time we are seeing this used. `az aks get-credentials` sets your `kubectl` context so that you can issue commands against your cluster. Even when you have enabled Azure AD integration with your AKS cluster, an Azure user has sufficient permissions on the cluster resource can still access your AKS cluster by using the `--admin` switch to this command. Using this switch _bypasses_ Azure AD and uses client certificate authentication instead; that isn't what we want to happen. So in order to prevent that practice, local account access (e.g. `clusterAdmin` or `clusterMonitoringUser`) is expressly disabled.
   >
   > In a following step, you'll log in with a user that has been added to the Azure AD security group used to back the Kubernetes RBAC admin role. Executing the first `kubectl` command below will invoke the AAD login process to authorize the _user of your choice_, which will then be authenticated against Kubernetes RBAC to perform the action. The user you choose to log in with _must be a member of the AAD group bound_ to the `cluster-admin` ClusterRole. For simplicity you could either use the "break-glass" admin user created in [Azure Active Directory Integration](03-aad.md) (`bu0001a0008-admin`) or any user you assigned to the `cluster-admin` group assignment in your [`cluster-rbac.yaml`](cluster-manifests/cluster-rbac.yaml) file.

   ```bash
   az aks get-credentials -g rg-bu0001a0008 -n $AKS_CLUSTER_NAME
   ```

   :warning: At this point two important steps are happening:

      * The `az aks get-credentials` command will be fetch a `kubeconfig` containing references to the AKS cluster you have created earlier.
      * To _actually_ use the cluster you will need to authenticate. For that, run any `kubectl` commands which at this stage will prompt you to authenticate against Azure Active Directory. For example, run the following command:

   ```bash
   kubectl get nodes
   ```

   Once the authentication happens successfully, some new items will be added to your `kubeconfig` file such as an `access-token` with an expiration period. For more information on how this process works in Kubernetes please refer to [the related documentation](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#openid-connect-tokens).

1. Validate your cluster is bootstrapped.

   The bootstrapping process that already happened due to the usage of the Flux extension for AKS has set up the following, amoung other things

   * AAD Pod Identity
   * the workload's namespace named `a0008`
   * Installed kured

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

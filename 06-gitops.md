# Place the Cluster Under GitOps Management

Now that [the AKS cluster](./05-aks-cluster.md) has been deployed, the next step to configure a GitOps management solution on our cluster, Flux in this case.

## Steps

GitOps allows a team to author Kubernetes manifest files, persist them in their git repo, and have them automatically apply to their cluster as changes occur.  This reference implementation is focused on the baseline cluster, so Flux is managing cluster-level concerns. This is distinct from workload-level concerns, which would be possible as well to manage via Flux, and would typically be done by additional Flux operators in the cluster. The namespace `cluster-baseline-settings` will be used to provide a logical division of the cluster bootstrap configuration from workload configuration.  Examples of manifests that are applied:

* Cluster Role Bindings for the AKS-managed Azure AD integration
* AAD Pod Identity
* CSI driver and Azure KeyVault CSI Provider
* the workload's namespace named `a0008`

1. Install `kubectl` 1.20 or newer. (`kubctl` supports +/-1 Kubernetes version.)

   ```bash
   sudo az aks install-cli
   kubectl version --client
   ```

1. Get the cluster name.

   ```bash
   AKS_CLUSTER_NAME=$(az deployment group show -g rg-bu0001a0008 -n cluster-stamp --query properties.outputs.aksClusterName.value -o tsv)
   ```

1. Get AKS `kubectl` credentials.

   > In the [Azure Active Directory Integration](03-aad.md) step, we placed our cluster under AAD group-backed RBAC. This is the first time we are seeing this used. `az aks get-credentials` allows you to use `kubectl` commands against your cluster. Without the AAD integration, you'd have to use `--admin` here, which isn't what we want to happen. In a following step, you'll log in with a user that has been added to the Azure AD security group used to back the Kubernetes RBAC admin role. Executing the first `kubectl` command below will invoke the AAD login process to auth the _user of your choice_, which will then be checked against Kubernetes RBAC to perform the action. The user you choose to log in with _must be a member of the AAD group bound_ to the `cluster-admin` ClusterRole. For simplicity you could either use the "break-glass" admin user created in [Azure Active Directory Integration](03-aad.md) (`bu0001a0008-admin`) or any user you assigned to the `cluster-admin` group assignment in your [`cluster-rbac.yaml`](cluster-manifests/cluster-rbac.yaml) file. If you skipped those steps you can use `--admin` to proceed, but proper AAD group-based RBAC access is a critical security function that you should invest time in setting up.

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

1. Import cluster management images to your container registry.

   > Public container registries are subject to faults such as outages (no SLA) or request throttling. Interruptions like these can be crippling for a system that needs to pull an image _right now_. To minimize the risks of using public registries, store all applicable container images in a registry that you control, such as the SLA-backed Azure Container Registry.

   ```bash
   # Get your ACR cluster name
   ACR_NAME=$(az deployment group show -g rg-bu0001a0008 -n cluster-stamp --query properties.outputs.containerRegistryName.value -o tsv)

   # Import cluster management images hosted in public container registries
   az acr import --source docker.io/library/memcached:1.5.20 -n $ACR_NAME
   az acr import --source docker.io/fluxcd/flux:1.21.1 -n $ACR_NAME
   az acr import --source docker.io/weaveworks/kured:1.6.1 -n $ACR_NAME
   ```

1. Create the cluster baseline settings namespace.

   ```bash
   # Verify the user you logged in with has the appropriate permissions. This should result in a 
   # "yes" response. If you receive "no" to this command, check which user you authenticated as
   # and ensure they are assigned to the Azure AD Group you designated for cluster admins.
   kubectl auth can-i create namespace -A

   kubectl create namespace cluster-baseline-settings
   ```

1. Deploy Flux.

   > If you used your own fork of this GitHub repo, update the [`flux.yaml`](./cluster-manifests/cluster-baseline-settings/flux.yaml) file to **reference your own repo and change the URL below** to point to yours as well. Also, since Flux will begin processing the manifests in [`cluster-manifests/`](./cluster-manifests/) now would be the right time push the following changes to your fork:
   >
   > * Update three `image` references to use your container registry instead of public container registries. See the comment in each file for instructions.
   >   * update the two `image:` values in [`flux.yaml`](./cluster-manifests/cluster-baseline-settings/flux.yaml).
   >   * update the one `image:` values in [`kured.yaml`](./cluster-manifests/cluster-baseline-settings/kured.yaml).

   :warning: Deploying the flux configuration using the `flux.yaml` file unmodified from this repo will be deploying your cluster to take dependencies on public container registries. This is generally okay for exploratory/testing, but not suitable for production. Before going to production, ensure _all_ image references you bring to your cluster are from _your_ container registry (as imported in the prior step) or another that you feel confident relying on.

   ```bash
   kubectl create -f https://raw.githubusercontent.com/mspnp/aks-secure-baseline/main/cluster-manifests/cluster-baseline-settings/flux.yaml
   ```

1. Wait for Flux to be ready before proceeding.

   ```bash
   kubectl wait -n cluster-baseline-settings --for=condition=ready pod --selector=app.kubernetes.io/name=flux --timeout=90s
   ```

Generally speaking, this will be the last time you should need to use `kubectl` for day-to-day configuration operations on this cluster (outside of break-fix situations). Between ARM for Azure Resource definitions and the application of manifests via Flux, all normal configuration activities can be performed without the need to use `kubectl`. You will however see us use it for the upcoming workload deployment. This is because the SDLC component of workloads are not in scope for this reference implementation, as this is focused the infrastructure and baseline configuration.

### Next step

:arrow_forward: [Prepare for the workload by installing its prerequisites](./07-workload-prerequisites.md)

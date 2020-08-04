# Place the Cluster Under GitOps Management

Now that [the AKS cluster](./05-aks-cluster) has been deployed, the next step to configure a GitOps management solution on our cluster, Flux in this case.

## Steps

GitOps allows a team to author Kubernetes manifest files, persist them in their git repo, and have them automatically apply to their cluster as changes occur.  This reference implementation is focused on the baseline cluster, so Flux is managing cluster-level concerns . This is distinct from workload-level concerns, which would be possible as well to manage via Flux, and would typically be done by additional Flux operators in the cluster. The namespace `cluster-baseline-settings` will be used to provide a logical division of the cluster configuration from workload configuration.  Examples of manifests that are applied:

* Cluster Role Bindings for the AKS-managed Azure AD integration
* AAD Pod Identity
* CSI driver and Azure KeyVault CSI Provider
* the workload's namespace named `a0008`

1. Install `kubectl` 1.18 or newer. (`kubctl` supports +/-1 Kubernetes version.)

   ```bash
   sudo az aks install-cli
   kubectl version --client
   ```

1. Get the cluster name.

   ```bash
   export AKS_CLUSTER_NAME=$(az deployment group show --resource-group rg-bu0001a0008 -n cluster-stamp --query properties.outputs.aksClusterName.value -o tsv)
   ```

1. Get AKS `kubectl` credentials (as a user that has admin permissions to the cluster).

   > In the [Azure Active Directory Integration](03-aad.md) step, we placed our cluster under AAD group-backed RBAC. This is the first time we are seeing this used. `az aks get-credentials` allows you to use `kubectl` commands against your cluster. Without the AAD integration, you'd have to use `--admin` here, which isn't what we want to happen. Here, you'll log in with a user that has been added to the Azure AD security group used to back the Kubernetes RBAC admin role. Executing the command below will invoke the AAD login process to auth the _user of your choice_, which will then be checked against Kubernets RBAC to perform the action. The user you choose to log in with _must be a member of the AAD group bound_ to the `cluster-admin` ClusterRole. For simplicity could either use the "break-glass" admin user created in [Azure Active Directory Integration](03-aad.md) (`bu0001a0008-admin`) or any user you assign to the `cluster-admin` group assignment in your [`user-facing-cluster-role-aad-group.yaml`](cluster-baseline-settings/user-facing-cluster-role-aad-group.yaml) file. If you skipped those steps you can use `--admin` to proceed, but proper AAD group-based RBAC access is a critical security function that you should invest time in setting up.

   ```bash
   az aks get-credentials -g rg-bu0001a0008 -n $AKS_CLUSTER_NAME
   ```

1. Create the cluster baseline settings namespace.

   ```bash
   # Verify the user you logged in with has the appropriate permissions, should result in a "yes" response.
   # If you receive "yes" to this command, check which user you authenticated as and ensure they are
   # assigned to the Azure AD Group you designated for cluster admins.
   kubectl auth can-i create namespace -A
   
   kubectl create namespace cluster-baseline-settings
   ```

1. Deploy Flux.

   > If you used your own fork of this GitHub repo, consider updating this [`flux.yaml`](./cluster-baseline-settings/flux.yaml) file to include reference to your own repo and change the URL below to point to yours as well. Also, since Flux will begin processing the manifests in [`cluster-baseline-settings/`](./cluster-baseline-settings/) now would be a good time to update the `<replace-with-an-aad-group-object-id-for-this-cluster-role-binding>` placeholder in [`user-facing-cluster-role-aad-group.yaml`](./cluster-baseline-settings/user-facing-cluster-role-aad-group.yaml) with the Object IDs for the Azure AD Group(s) you created for management purposes. If you don't, the manifest will still apply, but AAD integration will not be mapped to your specific AAD configuration.

   ```bash
   kubectl apply -f https://raw.githubusercontent.com/mspnp/aks-secure-baseline/main/cluster-baseline-settings/flux.yaml
   ```

1. Wait for Flux to be ready before proceeding.

   ```bash
   kubectl wait --namespace cluster-baseline-settings --for=condition=ready pod --selector=app.kubernetes.io/name=flux --timeout=90s
   ```

Generally speaking, this will be the last time you should need to use `kubectl` for day-to-day configuration operations on this cluster (outside of break-fix situations). Between ARM for Azure Resource definitions and the application of manifests via Flux, all normal configuration activities can be performed without the need to use `kubectl`. You will however see us use it for the upcoming workload deployment. This is because the SDLC component of workloads are not in scope for this reference implementation, as this is focused the infrastructure and baseline configuration.

### Next step

:arrow_forward: [Prepare for the workload by installing its prerequisites](./07-workload-prerequisites.md)

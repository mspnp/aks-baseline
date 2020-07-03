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

   ```bash
   az aks get-credentials -n $AKS_CLUSTER_NAME -g rg-bu0001a0008 --admin
   ```

1. Create the cluster baseline settings namespace.

   ```bash
   kubectl create namespace cluster-baseline-settings
   ```

1. Deploy Flux.

   > If you used your own fork of this GitHub repo, consider updating this `flux.yaml` file to include reference to your own repo and change the URL above to point to yours as well.

   ```bash
   kubectl apply -f https://raw.githubusercontent.com/mspnp/reference-architectures/master/aks/secure-baseline/cluster-baseline-settings/flux.yaml
   ```

1. Wait for Flux to be ready before proceeding.

   ```bash
   kubectl wait --namespace cluster-baseline-settings --for=condition=ready pod --selector=app.kubernetes.io/name=flux --timeout=90s
   ```

Generally speaking, this will be the last time you should need to use `kubectl` for day-to-day configuration operations on this cluster (outside of break-fix situations). Between ARM for Azure Resource definitions and the application of manifests via Flux, all normal configuration activities can be performed without the need to use `kubectl`. You will however see us use it for the upcoming workload deployment. This is because the SDLC component of workloads are not in scope for this reference implementation, as this is focused the infrastructure and baseline configuration.

### Next step

:arrow_forward: [Prepare for the workload by installing its prerequisites](./07-workload-prerequisites.md)

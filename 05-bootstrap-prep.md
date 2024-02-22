# Prep for cluster bootstrapping

Now that the [hub-spoke network is provisioned](./04-networking.md), the next step in the [AKS baseline reference implementation](./) is preparing what your AKS cluster should be bootstrapped with.

## Expected results

Container registries often have a lifecycle that extends beyond the scope of a single cluster. They can be scoped broadly at organizational or business unit levels, or can be scoped at workload levels, but usually are not directly tied to the lifecycle of any specific cluster instance. For example, you may do blue/green *cluster instance* deployments, both using the same container registry. Even though clusters came and went, the registry stays intact.

- Azure Container Registry is deployed, and exposed as a private endpoint.
- Azure Container Registry is populated with images your cluster will need as part of its bootstrapping process.
- Log Analytics is deployed and Azure Container Registry platform logging is configured. This workspace will be used by your cluster as well.

The role of this pre-existing Azure Container Registry instance is made more prominent when we think about cluster bootstrapping. That is the process that happens after Azure resource deployment of the cluster, but before your first workload lands in the cluster. The cluster will be bootstrapped *immediately and automatically* after resource deployment, which means you'll need Azure Container Registry in place to act as your official OCI artifact repository for required images and Helm charts used in that bootstrapping process.

### Bootstrapping method

We'll be bootstrapping this cluster with the Flux GitOps agent as installed as an AKS extension. This specific choice does not imply that Flux, or GitOps in general, is the only approach to bootstrapping. Consider your organizational familiarity and acceptance of tooling like this and decide whether cluster bootstrapping should be performed with GitOps or via your deployment pipelines. If you are running a fleet of clusters, a GitOps approach is highly recommended for uniformity and easier governance. When running only a few clusters, GitOps might be seen as "too much" and you might instead opt for integrating that process into one or more deployment pipelines to ensure bootstrapping takes place. No matter which way you go, you'll need your bootstrapping artifacts ready to go before you start your cluster deployment so that you can minimize the time between cluster deployment and bootstrapping. Using the Flux AKS extension allows your cluster to start already bootstrapped and sets you up with a solid management foundation going forward.

### Additional resources

In addition to Azure Container Registry being deployed to support bootstrapping, this is where any other resources that are considered not tied to the lifecycle of an individual cluster is deployed. Azure Container Registry is one example as talked about above. Another example could be an AKS Backup Vault and backup artifacts storage account which likely would exist prior to and after any individual AKS cluster's existence. When designing your pipelines, ensure to isolate components by their lifecycle watch for singletons in an architecture. These are typically resources like regional logging sinks, supporting global routing infrastructure, and so on. This is in contrast with potentially transient/replaceable components, like the AKS cluster itself. *This implementation does not represent a complete separation of stamp vs regional resources, but is fairly close. Deviations are strictly for ease of deployment in this walkthrough instead of as examples of guidance.*

## Steps

1. Create the AKS cluster resource group.

   > :book: The app team working on behalf of business unit 0001 (BU001) is looking to create an AKS cluster of the app they are creating (Application ID: 0008). They have worked with the organization's networking team and have been provisioned a spoke network in which to lay their cluster and network-aware external resources into (such as Application Gateway). They took that information and added it to their [`acr-stamp.json`](./acr-stamp.json), [`cluster-stamp.json`](./cluster-stamp.json), and [`azuredeploy.parameters.prod.json`](./azuredeploy.parameters.prod.json) files.
   >
   > They create this resource group to be the parent group for the application.

   ```bash
   # [This takes less than one minute.]
   az group create --name rg-bu0001a0008 --location $LOCATION_AKS_BASELINE
   ```

1. Get the AKS cluster spoke Virtual Network resource ID.

   > :book: The app team will be deploying to a spoke Virtual Network, that was already provisioned by the network team.

   ```bash
   export RESOURCEID_VNET_CLUSTERSPOKE_AKS_BASELINE=$(az deployment group show -g rg-enterprise-networking-spokes-${LOCATION_AKS_BASELINE} -n spoke-BU0001A0008 --query properties.outputs.clusterVnetResourceId.value -o tsv)
   echo RESOURCEID_VNET_CLUSTERSPOKE_AKS_BASELINE: $RESOURCEID_VNET_CLUSTERSPOKE_AKS_BASELINE
   ```

1. Deploy the container registry and non-stamp resources template.

   ```bash
   # [This takes about four minutes.]
   az deployment group create -g rg-bu0001a0008 -f acr-stamp.bicep -p targetVnetResourceId=${RESOURCEID_VNET_CLUSTERSPOKE_AKS_BASELINE}
   ```

1. Import cluster management images to your container registry.

   > Public container registries are subject to faults such as outages or request throttling. Interruptions like these can be crippling for a system that needs to pull an image *right now*. To minimize the risks of using public registries, store all applicable container images in a registry that you control, such as the SLA-backed Azure Container Registry.

   ```bash
   # Get your ACR instance name
   export ACR_NAME_AKS_BASELINE=$(az deployment group show -g rg-bu0001a0008 -n acr-stamp --query properties.outputs.containerRegistryName.value -o tsv)
   echo ACR_NAME_AKS_BASELINE: $ACR_NAME_AKS_BASELINE
   ```

### Save your work in-progress

```bash
# run the saveenv.sh script at any time to save environment variables created above to aks_baseline.env
./saveenv.sh

# if your terminal session gets reset, you can source the file to reload the environment variables
# source aks_baseline.env
```

### Next step

:arrow_forward: [Deploy the AKS cluster](./06-aks-cluster.md)

# Prepare for cluster bootstrapping

Now that the [hub-spoke network is provisioned](./04-networking.md), the next step in the [AKS baseline reference implementation](../../) is preparing what the resources that help to bootstrap your AKS cluster. In this example we deploy a container registry, but there are other resources you might deploy in your scenario too.

## Expected results

Container registries often have a lifecycle that extends beyond the scope of a single cluster. They can be scoped broadly at organizational or business unit levels, or can be scoped at workload levels, but usually are not directly tied to the lifecycle of any specific cluster instance. For example, you may do blue/green *cluster instance* deployments, both using the same container registry. Even though clusters come and go, the registry stays intact.

- Azure Container Registry is deployed and exposed by using a private endpoint.
- Azure Container Registry is populated with images your cluster will need as part of its bootstrapping process.
- Log Analytics is deployed and Azure Container Registry platform logging is configured. This workspace will be used by your cluster as well.

The role of this pre-existing Azure Container Registry instance is made more prominent when we think about cluster bootstrapping. That is the process that happens after Azure resource deployment of the cluster, but before your first workload lands in the cluster. The cluster will be bootstrapped *immediately and automatically* after resource deployment, which means you'll need Azure Container Registry in place to act as your official OCI artifact repository for required images and Helm charts used in that bootstrapping process.

### Bootstrapping method

We'll be bootstrapping this cluster with the Flux GitOps agent installed as an AKS extension. This specific choice does not imply that Flux, or GitOps in general, is the only approach to bootstrapping. Consider your organizational familiarity and acceptance of tooling like this and decide whether cluster bootstrapping should be performed with GitOps or via your deployment pipelines. If you are running a fleet of clusters, a GitOps approach is highly recommended for uniformity and easier governance. When running only a few clusters, GitOps might be seen as "too much" and you might instead opt for integrating that process into one or more deployment pipelines to ensure bootstrapping takes place.

Whichever tooling choice you make, you'll need your bootstrapping artifacts ready to go before you start your cluster deployment so that you can minimize the time between cluster deployment and bootstrapping. Using the Flux AKS extension allows your cluster to start already bootstrapped and sets you up with a solid management foundation to build upon.

### Additional resources

In addition to Azure Container Registry being deployed to support bootstrapping, this is where any other resources that are considered not tied to the lifecycle of an individual cluster is deployed. Another example could be an AKS Backup Vault, and a backup artifacts storage account, which likely would exist prior to and after any individual AKS cluster's existence.

When designing your pipelines, be sure to isolate components by their lifecycle. Identify singletons in an architecture. Singletons are typically resources like regional logging sinks, global routing infrastructure, and so on. This is in contrast with potentially transient/replaceable components, like the AKS cluster itself.

*This implementation does not represent a complete separation of stamp resources from regional resources, but is fairly close. Deviations are strictly for ease of deployment in this walkthrough instead of as examples of guidance.*

## Steps

1. Create the AKS cluster resource group.

   > :book: The workload team working on behalf of business unit 0001 (BU001) is looking to create an AKS cluster of the app they are creating (Application ID: 0008). They have worked with the organization's networking team and have been provisioned a spoke network in which to lay their cluster and network-aware external resources into (such as Application Gateway). They took that information and added it to their [`acr-stamp.bicep`](../../workload-team/acr-stamp.bicep), [`cluster-stamp.bicep`](../../workload-team/cluster-stamp.bicep), and [`azuredeploy.parameters.prod.bicepparam`](../../workload-team/azuredeploy.parameters.prod.bicepparam) files.
   >
   > They create this resource group to be the parent group for the application.

   ```bash
   # [This takes less than one minute.]
   az group create --name rg-bu0001a0008 --location $LOCATION_AKS_BASELINE
   ```

1. Get the AKS cluster spoke virtual network's resource ID, which was emitted as an output in a previous step.

   > :book: The workload team will be deploying to a spoke virtual network, which was already provisioned by the network team.

   ```bash
   export RESOURCEID_VNET_CLUSTERSPOKE_AKS_BASELINE=$(az deployment group show -g rg-enterprise-networking-spokes-${LOCATION_AKS_BASELINE} -n spoke-BU0001A0008 --query properties.outputs.clusterVnetResourceId.value -o tsv)
   echo RESOURCEID_VNET_CLUSTERSPOKE_AKS_BASELINE: $RESOURCEID_VNET_CLUSTERSPOKE_AKS_BASELINE
   ```

1. Deploy the container registry and non-stamp resources template.

   ```bash
   # [This takes about four minutes.]
   az deployment group create -g rg-bu0001a0008 -f workload-team/acr-stamp.bicep -p targetVnetResourceId=${RESOURCEID_VNET_CLUSTERSPOKE_AKS_BASELINE}
   ```

   The container registry deployment emits the following output:

      - `containerRegistryName` - which you'll use in future steps when connecting the cluster to the container registry.

1. Capture the output from the container registry that will be required in later steps.

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

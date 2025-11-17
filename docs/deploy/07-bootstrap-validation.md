# Validate your cluster is bootstrapped and enrolled in GitOps

Now that the [AKS cluster](./06-aks-cluster.md) has been deployed, the next step to validate that your cluster has been placed under a GitOps management solution, Flux in this case.

## Expected results

### Jump box access is validated

Because the cluster is private, your cluster cannot be directly accessed locally. You'll validate controlled jump box access for direct ops against the cluster if needed.

## Steps

GitOps allows a team to author Kubernetes manifest files, persist them in their Git repo, and have them automatically apply to their cluster as changes occur. This reference implementation is focused on the baseline cluster, so Flux is managing cluster-level concerns. This is distinct from workload-level concerns, which would be possible as well to manage via Flux and would typically be done by additional Flux configuration in the cluster. The namespace `cluster-baseline-settings` will be used to provide a logical division of the cluster bootstrap configuration from workload configuration. Examples of manifests that are applied:

- Cluster role bindings for the AKS-managed Microsoft Entra ID integration
- Cluster-wide configuration of Azure Monitor for Containers
- The workload's namespace named `a0008`

1. Connect to a jump box node via Azure Bastion.

   If this is the first time you've used Azure Bastion, here is a detailed walk through of this process.

   1. Open the Azure Portal.
   1. Navigate to the ***rg-bu0001a0008** resource group.
   1. Click on the virtual machine Scale Set resource named **vmss-jumpboxes**.
   1. Click Instances.
   1. Click the name of any of the two listed instances. Such as **vmss-jumpboxes_0**
   1. Click **Connect** -> **Bastion** -> **Use Bastion**.
   1. Fill in the username field with the user you passed as argument when deploying the cluster. By default it is **vmadmin**
   1. Use the password you entered when deploying the cluster.
   1. Click **Connect**.
   1. For enhanced "copy-on-select" & "paste-on-right-click" support, your browser may request your permission to support those features. It's recommended that you **Allow** that feature. If you don't, you'll have to use the **>>** flyout on the screen to perform copy and paste actions.
   1. Welcome to your jump box!

      > :warning: The jump box deployed in this walkthrough has only ephemeral disks attached, in which content written to disk will not survive planned or unplanned restarts of the host. Never store anything of value on these jump boxes. They are expected to be fully ephemeral in nature, and in fact could be scaled-to-zero when not in use.

1. *From your Azure Bastion connection*, install prequisites to install az-cli

   ```bash
   sudo apt-get update && sudo apt-get install -y libssl-dev libffi-dev python3-dev build-essential
   ```

1. *From your Azure Bastion connection*, install latest [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli?view=azure-cli-latest) (must be at least 2.40).

1. *From your Azure Bastion connection*, install `kubectl` 1.33 or newer. (`kubectl` supports ±1 Kubernetes version.)

   ```bash
   sudo -E env "PATH=$PATH" az aks install-cli
   kubectl version --client
   ```

   > Starting with `kubectl` 1.24, you must also have the `kubelogin` credential (exec) plug-in available for Microsoft Entra ID authentication. Installing `kubectl` via `az aks install-cli` does this already, but if you install `kubectl` in a different way, make sure `kubelogin` is [installed](https://github.com/Azure/kubelogin#getting-started).

1. *From your Azure Bastion connection*, sign in to your Azure RBAC tenant and select your subscription.

   The following command will perform a device login. Ensure you're logging in with the Microsoft Entra user that has access to your AKS resources (that is, the one you did your deployment with.)

   ```bash
   az login
   # This will give you a link to https://microsoft.com/devicelogin where you can enter
   # the provided code and perform authentication.

   # Ensure you're on the correct subscription
   az account show

   # If not, select the correct subscription
   # az account set -s <subscription name or id>
   ```

   > :warning: Your organization may have a conditional access policies in place that forbids access to Azure resources [from non corporate-managed devices](https://learn.microsoft.com/entra/identity/conditional-access/concept-conditional-access-grant). This jump box as deployed in these steps might trigger that policy. If that is the case, you'll need to work with your IT Security organization to provide an alterative access mechanism or temporary solution.

1. *From your Azure Bastion connection*, get the cluster name.

   ```bash
   AKS_CLUSTER_NAME=$(az aks list -g rg-bu0001a0008 --query '[0].name' -o tsv)
   echo AKS_CLUSTER_NAME: $AKS_CLUSTER_NAME
   ```

1. *From your Azure Bastion connection*, validate there are no available image upgrades. As this AKS cluster was recently deployed, it's unlikely that new images are available. Only a race condition between publication of new available images and the deployment image fetch could result into a different state.

   ```bash
   az aks nodepool get-upgrades -n npuser01 --cluster-name $AKS_CLUSTER_NAME -g rg-bu0001a0008 && \
   az aks nodepool show -n npuser01 --cluster-name $AKS_CLUSTER_NAME -g rg-bu0001a0008 --query nodeImageVersion
   ```

   > Typically, base node images don't contain a suffix with a date (i.e. `AKSUbuntu-2204gen2containerd`). If the `nodeImageVersion` value looks like `AKSUbuntu-2204gen2containerd-202402.26.0` a SecurityPatch or NodeImage upgrade has been applied to the AKS node.

   > The AKS nodes are configured to receive weekly updates automatically which include security patches, kernel updates, and node images updates. The AKS cluster version won't be updated automatically since production clusters should be updated manually after testing in lower environments.

   > Node image updates are shipped on a weekly cadence by default. This AKS cluster is configured to have its maintenance window for node image updates every Tuesday at 9PM. If a node image is released outside of this maintenance window, the nodes will be updated on the next scheduled occurrence. For AKS nodes that require more frequent updates, consider changing the auto-upgrade channel to `SecurityPatch` and configuring a daily maintenance window.

1. *From your Azure Bastion connection*, get AKS `kubectl` credentials.

   > In the [Microsoft Entra ID Integration](03-microsoft-entra-id.md) step, we placed our cluster under Microsoft Entra group-backed RBAC. This is the first time we are seeing this configuration being used. The `az aks get-credentials` command sets your `kubectl` context so that you can issue commands against your cluster. Even when you have enabled Microsoft Entra ID integration with your AKS cluster, an Azure user has sufficient permissions on the cluster resource can still access your AKS cluster by using the `--admin` switch to this command. Using this switch *bypasses* Microsoft Entra ID and uses client certificate authentication instead; that isn't what we want to happen. So in order to prevent that practice, local account access such as `clusterAdmin` or `clusterMonitoringUser`) is expressly disabled.
   >
   > In a following step, you'll log in with a user that has been added to the Microsoft Entra security group used to back the Kubernetes RBAC admin role. Executing the first `kubectl` command below will invoke the Microsoft Entra ID login process to authorize the *user of your choice*, which will then be authenticated against Kubernetes RBAC to perform the action. The user you choose to log in with *must be a member of the Microsoft Entra group bound* to the `cluster-admin` ClusterRole. For simplicity you could either use the "break-glass" admin user created in [Microsoft Entra ID Integration](03-microsoft-entra-id.md) (`bu0001a0008-admin`) or any user you assigned to the `cluster-admin` group assignment in your [`cluster-rbac.yaml`](../../cluster-manifests/cluster-rbac.yaml) file.

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

1. *From your Azure Bastion connection*, validate your cluster is bootstrapped. The Flux extension for AKS has already run the bootstrapping process. Among other things, it's created the workload's namespace named `a0008`:

   ```bash
   kubectl get namespaces
   ```

   This command shows you results that were due to the automatic bootstrapping process your cluster experienced due to the Flux GitOps extension. This content mirrors the content found in [`cluster-manifests`](../../cluster-manifests), and commits made there will reflect in your cluster within minutes of making the change.

The result is that `kubectl` was not required for any part of the bootstrapping process of a cluster. The usage of `kubectl`-based access should be reserved for emergency break-fix situations and not for day-to-day configuration operations on this cluster. By using Bicep files for Azure resource definitions, and the bootstrapping of manifests via the GitOps extension, all normal configuration activities can be performed without the need to use `kubectl`. You will however see us use it for the upcoming workload deployment. This is because the SDLC component of workloads are not in scope for this reference implementation, as this reference architecture is focused the infrastructure and baseline configuration.

## Alternatives

Using the AKS extension for Flux gives you a seamless bootstrapping process that applies immediately after the cluster resource is created in Azure. It also supports the inclusion of that bootstrapping as resource templates to align with your IaC strategy. Alternatively you could apply bootstrapping as a secondary step after the cluster is deployed and manage that process external to the lifecycle of the cluster. Doing so will open your cluster up to a prolonged window between the cluster being deployed and your bootstrapping being applied.

Furthermore, Flux doesn't need to be installed as an extension and instead the GitOps operator of your choice (such as ArgoCD) could be installed as part of your external bootstrapping process.

## Recommendations

You should have a clearly defined bootstrapping process, which occurs as close as practicable to the actual cluster deployment for immediate enrollment of your cluster into your internal processes and tooling. GitOps lends itself well to this desired outcome, and we encourage you to explore its usage for your cluster bootstrapping processes, and optionally also workload-level concerns. GitOps is often positioned best for managements of *fleet* (multiple clusters), because it enables uniformity and simplicity at scale. A more manual bootstrapping process (via deployment pipelines) is common on small instance-count AKS deployments. Either process can work with both cluster topologies. Use a bootstrapping process that aligns with your desired objectives and constraints found within your organization and team.

### Next step

:arrow_forward: [Prepare for the workload by installing its prerequisites](./08-workload-prerequisites.md)

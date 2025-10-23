# Prepare for cluster bootstrapping

Now that the [hub-spoke network is provisioned](./04-networking.md), the next step in the [AKS baseline reference implementation](../../) is preparing what the resources that help to bootstrap your AKS cluster. In this example we deploy a container registry, but there are other resources you might deploy in your scenario too. For instance, from this section we need to take a quick detour to plan and talk about cluster control plane access as well as bootstrapping methods.

## Expected results

Container registries often have a lifecycle that extends beyond the scope of a single cluster. They can be scoped broadly at organizational or business unit levels, or can be scoped at workload levels, but usually are not directly tied to the lifecycle of any specific cluster instance. For example, you may do blue/green *cluster instance* deployments, both using the same container registry. Even though clusters come and go, the registry stays intact.

- Azure Container Registry is deployed and exposed by using a private endpoint.
- Azure Container Registry is populated with images your cluster will need as part of its bootstrapping process.
- Log Analytics is deployed and Azure Container Registry platform logging is configured. This workspace will be used by your cluster as well.

The role of this pre-existing Azure Container Registry instance is made more prominent when we think about cluster bootstrapping. That is the process that happens after Azure resource deployment of the cluster, but before your first workload lands in the cluster. The cluster will be bootstrapped *immediately and automatically* after resource deployment, which means you'll need Azure Container Registry in place to act as your official OCI artifact repository for required images and Helm charts used in that bootstrapping process.

Addtionally you are going to be using Azure Image Builder to generate a Kubernetes-specific jump box image. The image construction will be performed in a dedicated network spoke with limited Internet exposure. These steps below will deploy a new dedicated image-building spoke, connected through our hub to sequester network traffic throughout the process. It will then deploy an image template and all infrastructure components for Azure Image Builder to operate. Finally you will build an image to use for your jump box.

- The network spoke will be called `rg-enterprise-networking-spokes-jumboxes-<region>` and have a range of `10.241.0.0/28`.
- The hub's firewall will be updated to allow only the necessary outbound traffic from this spoke to complete the operation.
- The final image will be placed into the workload's resource group.

After getting out image built, you follow some extra steps to end up with an SSH public-key-based solution that uses [cloud-init](https://learn.microsoft.com/azure/virtual-machines/linux/using-cloud-init). The results will be captured in jumpBoxCloudInit.yml which you will later convert to Base64 for use in your cluster's ARM template.

### Planning access to your cluster's control plane

Your cluster's control plane (Kubernetes API Server) will not be accessible to the Internet as the cluster you'll deploy is a Private Cluster. In order to perform Kubernetes management operations against the cluster, you'll need to access the Kubernetes API Server from a designated subnet (`snet-management-ops` in the cluster's Virtual Network `rg-enterprise-networking-spokes-jumboxes-<region>` in this implementation). You have options on how to go about originating your ops traffic from this specific subnet.

- You could establish a VPN connection to that subnet such that you source an IP from that subnet. This would allow you to manage the cluster from any place that you can establish the VPN connection from.
- You could use Azure Shell's feature that [allows Azure Shell to be subnet-connected](https://learn.microsoft.com/azure/cloud-shell/private-vnet).
- You could deploy compute resources into that subnet and use that as your ops workstation.
- You could use the [AKS Run Command](https://learn.microsoft.com/azure/aks/private-clusters#aks-run-command-preview).

Never use the AKS nodes (or OpenSSH containers running on them) as your access points (that is, using Azure Bastion to SSH into nodes); as this would be using the management target system as the management tool, which is not as reliable. Always prefer a dedicated solution external to your cluster. Consider this guidance when evaluating if AKS Run Command is appropriate to use in your specific deployment, as this creates a transient pod within your cluster for proxied access.

This reference implementation will be using the "compute resource in subnet" option above, typically known as a jump box. Even within this option, you have additional choices.

- Use Azure Container Instances and a custom [OpenSSH host](https://docs.linuxserver.io/images/docker-openssh-server) container
- Use [Azure Virtual Desktop (AVD)](https://learn.microsoft.com/azure/virtual-desktop/overview) or [Windows RDS](https://learn.microsoft.com/windows-server/remote/remote-desktop-services/welcome-to-rds)
- Use stand-alone, persistent VMs in an availability set
- Use small instance count, non-autoscaling Virtual Machine Scale Set

In all cases, you'll likely be building a "golden image" (container or VM image) to use as the base of your jump box. A jump box image should contain all the required operations tooling necessary for ops engineers to perform their duties (both routine and break-fix). You're welcome to bring your own image to this reference implementation if you have one. If you do not have one, the following steps will help you build one as an example.

#### :closed_lock_with_key: Jumpbox Security

The jump box image you are building as part of the following steps is considered general purpose; its creation process and supply chain has not been hardened. For example, the jump box image is built on a public base image, and is pulling OS package updates from Ubuntu and Microsoft public servers. Additionally tooling such as the Azure CLI, Helm, Flux, and Terraform are installed straight from the Internet. Ensure processes like these adhere to your organizational policies; pulling updates from your organization's patch servers, and storing well-known third-party dependencies in trusted locations that are available from your builder's subnet. If all necessary resources have been brought "network-local", the NSG and Azure Firewall allowances should be made even tighter. Also apply all standard OS hardening procedures your organization requires for privileged access machines such as these. Finally, ensure all desired security and logging agents are installed and configured. All jump boxes (or similar access solutions) should be *hardened and monitored*, as they span two distinct security zones. **Both the jump box and its image/container are attack vectors that needs to be considered when evaluating cluster access solutions**;

#### Pipelines and other considerations

Image building using Azure Image Builder lends itself well to having a secured, auditable, and transient image building infrastructure. Consider building pipelines around the generation of hardened and approved images to create a repeatably compliant output. Also we recommend pushing these images to your organization's [Azure Shared Image Gallery](https://learn.microsoft.com/azure/virtual-machines/shared-image-galleries) for geo-distribution and added management capabilities. These features were skipped for this reference implementation to avoid added illustrative complexity.

### Bootstrapping method

We'll be bootstrapping this cluster with the Flux GitOps agent installed as an AKS extension. This specific choice does not imply that Flux, or GitOps in general, is the only approach to bootstrapping. Consider your organizational familiarity and acceptance of tooling like this and decide whether cluster bootstrapping should be performed with GitOps or via your deployment pipelines. If you are running a fleet of clusters, a GitOps approach is highly recommended for uniformity and easier governance. When running only a few clusters, GitOps might be seen as "too much" and you might instead opt for integrating that process into one or more deployment pipelines to ensure bootstrapping takes place.

Whichever tooling choice you make, you'll need your bootstrapping artifacts ready to go before you start your cluster deployment so that you can minimize the time between cluster deployment and bootstrapping. Using the Flux AKS extension allows your cluster to start already bootstrapped and sets you up with a solid management foundation to build upon.

### Additional resources

In addition to Azure Container Registry being deployed to support bootstrapping, this is where any other resources that are considered not tied to the lifecycle of an individual cluster is deployed. Another example could be Azure Image Builder, an AKS Backup Vault, and a backup artifacts storage account, which likely would exist prior to and after any individual AKS cluster's existence.

When designing your pipelines, be sure to isolate components by their lifecycle. Identify singletons in an architecture. Singletons are typically resources like regional logging sinks, global routing infrastructure, and so on. This is in contrast with potentially transient/replaceable components, like the AKS cluster itself.

*This implementation does not represent a complete separation of stamp resources from regional resources, but is fairly close. Deviations are strictly for ease of deployment in this walkthrough instead of as examples of guidance.*

## Steps

### Deploy the spoke for your jump box image

1. Create the AKS jump box image builder network spoke.

   ```bash
   # [This takes about one minute to run.]
   az deployment group create -g rg-enterprise-networking-spokes-${LOCATION_AKS_BASELINE} -f network-team/spoke-BU0001A0008-01.bicep -p hubVnetResourceId="${RESOURCEID_VNET_HUB}"
   ```

1. Update the regional hub deployment to account for the requirements of the spoke.

   Now that the second spoke network is created, the hub network's firewall needs to be updated to support the Azure Image Builder process that will execute in there. The hub firewall does NOT have any default permissive egress rules, and as such, each needed egress endpoint needs to be specifically allowed. This deployment builds on the prior with the added allowances in the firewall.

   ```bash
   RESOURCEID_SUBNET_AIB=$(az deployment group show -g rg-enterprise-networking-spokes-${LOCATION_AKS_BASELINE} -n spoke-BU0001A0008-01 --query properties.outputs.imageBuilderSubnetResourceId.value -o tsv)

   # [This takes about five minutes to run.]
   az deployment group create -g rg-enterprise-networking-hubs-${LOCATION_AKS_BASELINE} -f network-team/hub-regionA.v2.bicep -p aksImageBuilderSubnetResourceId="${RESOURCEID_SUBNET_AIB}"
   ```

### Build and deploy the jump box image

Now that we have our image building network created, egressing through our hub, and all NSG/firewall rules applied, it's time to build and deploy our jump box image. We are using a general purpose AKS jump box image which comes with baked-in tooling such as the Azure CLI, kubectl, Helm, flux, and so on. The network rules applied in the prior steps support its specific build-time requirements. If you use this infrastructure to build a modified version of this image template, you may need to add additional network allowances or remove unneeded allowances.

1. Deploy custom Azure RBAC roles.

   Azure Image Builder requires permissions to be granted to its runtime identity. The following deploys two *custom* Azure RBAC roles that encapsulate those exact permissions necessary. If you do not have permissions to create Azure RBAC roles in your subscription, you can skip this step. However, in the next step below, you'll then be required to apply existing built-in Azure RBAC roles to the service's identity, which are more permissive than necessary, but would be fine to use for this walkthrough.

   ```bash
   # [This takes about one minute to run.]
   az deployment sub create -f jumpbox/createsubscriptionroles.bicep -l ${LOCATION_AKS_BASELINE} -n DeployAibRbacRoles
   ```

1. Create the AKS cluster resource group.

   > :book: The workload team working on behalf of business unit 0001 (BU001) is looking to create an AKS cluster of the app they are creating (Application ID: 0008). They have worked with the organization's networking team and have been provisioned a spoke network in which to lay their cluster and network-aware external resources into (such as Application Gateway). They took that information and added it to their [`acr-stamp.bicep`](../../workload-team/acr-stamp.bicep), [`cluster-stamp.bicep`](../../workload-team/cluster-stamp.bicep), and [`azuredeploy.parameters.prod.bicepparam`](../../workload-team/azuredeploy.parameters.prod.bicepparam) files.
   >
   > They create this resource group to be the parent group for the application.

   ```bash
   # [This takes less than one minute.]
   az group create --name rg-bu0001a0008 --location $LOCATION_AKS_BASELINE
   ```

1. Create the AKS jump box image template.

   Next you are going to deploy the image template and Azure Image Builders's managed identity. This is being done directly into our workload resource group for simplicity. You can choose to deploy this to a separate resource group if you wish
. This "golden image" generation process would typically happen out-of-band to the cluster management.

   ```bash
   ROLEID_NETWORKING=$(az deployment sub show -n DeployAibRbacRoles --query 'properties.outputs.roleResourceIds.value.customImageBuilderNetworkingRole.guid' -o tsv)
   ROLEID_IMGDEPLOY=$(az deployment sub show -n DeployAibRbacRoles --query 'properties.outputs.roleResourceIds.value.customImageBuilderImageCreationRole.guid' -o tsv)

   # [This takes about one minute to run.]
   az deployment group create -g rg-bu0001a0008 -f jumpbox/azuredeploy.bicep -p buildInSubnetResourceId=${RESOURCEID_SUBNET_AIB} imageBuilderNetworkingRoleGuid="${ROLEID_NETWORKING}" imageBuilderImageCreationRoleGuid="${ROLEID_IMGDEPLOY}" -n CreateJumpBoxImageTemplate
   ```

1. Build the general-purpose AKS jump box image.

   Now you'll build the actual VM golden image you will use for your jump box. This uses the image template created in the prior step and is executed by Azure Image Builder under the authority of the managed identity (and its role assignments) also created in the prior step.

   ```bash
   IMAGE_TEMPLATE_NAME=$(az deployment group show -g rg-bu0001a0008 -n CreateJumpBoxImageTemplate --query 'properties.outputs.imageTemplateName.value' -o tsv)

   # [This takes about >> 30 minutes << to run.]
   az image builder run -n $IMAGE_TEMPLATE_NAME -g rg-bu0001a0008
   ```

   > A successful run of the command above is typically shown with no output or a success message. An error state will be typically be presented if there was an error. To see whether your image was built successfully, you can go to the **rg-bu0001a0008** resource group in the portal and look for a created VM Image resource. It will have the same name as the Image Template resource created in Step 2.

   :coffee: This does take a significant amount of time to run. While the image building is happening, feel free to read ahead, but you should not proceed until this is complete. If you need to perform this reference implementation walk through multiple times, we suggest you create this image in a place that can survive the deleting and re-creating of this reference implementation to save yourself this time in a future execution of this guide.

1. Delete image building resources. *Optional.*

   Image building can be seen as a transient process, and as such, you may wish to remove all temporary resources used as part of the process. At this point, if you are happy with your generated image, you can delete the **Image Template** (*not Image!*) in `rg-bu0001a0008`, AIB user managed identity (`mi-aks-jumpbox-imagebuilder-…`) and its role assignments. See instructions to do so in the [AKS Jump Box Image Builder guidance](https://github.com/mspnp/aks-jumpbox-imagebuilder#broom-clean-up-resources) for more details.

### Generate your SSH public key and capture the details

1. Open `jumpBoxCloudInit.yml` in your preferred editor.

1. Inspect the two users examples in that file. You need **one** user defined in this file to complete this walk through (*more than one user is fine*, but not necessary). 🛑
   1. `name:` set to whatever you login account name you wish. (You'll need to remember this later.)
   1. `sudo:` - Suggested to leave at `False`. This means the user cannot `sudo`. If this user needs sudo access, use [sudo rule strings](https://cloudinit.readthedocs.io/en/latest/topics/examples.html?highlight=sudo#including-users-and-groups) to restrict what sudo access is allowed.
   1. `lock_passwd:` - Leave at `True`. This disables password login, and as such the user can only connect via an SSH authorized key. Your jump box should enforce this as well on its SSH daemon. If you deployed using the image builder in the prior step, it does this enforcement there as well.
   1. In `ssh-authorized-keys` replace the `<public-ssh-rsa-for-...>` placeholder with an actual public ssh public key for the user. This must be an RSA key of at least 2048 bits and **must be secured with a passphrase**. This key will be added to that user's `~/.ssh/authorized_keys` file on the jump box via the cloud-init bootstrap process.

1. Generate an SSH key pair to use in this walkthrough.

   ```bash
   ssh-keygen -t rsa -b 4096 -f opsuser01.key
   ```

   **Enter a passphrase when requested** (*do not leave empty*) and note where the public and private key file was saved. The *public* key file *contents* (`opsuser01.key.pub` in the example above) will be used in the `jumpBoxCloudInit.yml` file. You'll need the username, the private key file (`opsuser01.key`), and passphrase later in this walkthrough.

   > On Windows, as an alternative to Bash in WSL, you can use a solution like PuTTYGen found in the [PuTTY installer](https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html).
   >
   > Azure also has an SSH Public Key resources type that allows you to [generate SSH keys](https://learn.microsoft.com/azure/virtual-machines/ssh-keys-portal) and keep public keys available as a managed resource.

1. Run the following command to overwrite the `jumpBoxCloudInit.yml` file with a new user configuration that uses the SSH key you generated:

   ```bash
   cat <<EOF > jumpBoxCloudInit.yml -
   #cloud-config
   users:
     - default
     - name: opsuser01
       sudo: False
       lock_passwd: True
       ssh-authorized-keys:
         - $(cat opsuser01.key.pub)
   EOF
   ```

   > Alternatively, you can manually modify the existing `jumpBoxCloudInit.yml` file to add/remove users and ssh authorized keys.

1. *Optional 🛑.* Remove the `- default` line to remove the default admin user from the jump box.

   If you leave the `- default` line in the file, then the default admin user (defined in the cluster's ARM template as pseudo-random name to discourage usage) will also exist on this jump box. We do not provide any instructions on setting up this default user to be a valid user you can access, and as such you might wish to simply remove it from the jump box. That user has unrestricted sudo access, by default. Unfortunately, you cannot directly deploy the jump box infrastructure with this user removed, so removing it via cloud-init is a common resolution -- by not including `- default` in this file.

1. You can commit this file change if you wish, as the only values in here are public keys, which are not secrets. **Never commit any private SSH keys.**

### Deploy the Cluster container registry

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

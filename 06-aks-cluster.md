# Deploy the AKS cluster

Now that your [ACR instance is deployed and ready to support cluster bootstrapping](./05-bootstrap-prep.md), the next step in the [AKS baseline reference implementation](./) is deploying the AKS cluster and its remaining adjacent Azure resources.

## Steps

1. Indicate your bootstrapping repo.

   > If you cloned this repo, then the value will be the original mspnp GitHub organization's repo, which will mean that your cluster will be bootstraped using public container images. If instead you forked this repo, then the GitOps repo will be your own repo, and your cluster will be bootstrapped using container images references based on the values in your repo's manifest files. On the prior instruction page you had the opportunity to update those manifests to use your ACR instance. For guidance on using a private bootstrapping repo, see [Private bootstrapping repository](./cluster-manifests/README.md#private-bootstrapping-repository).

   ```bash
   GITOPS_REPOURL=$(git config --get remote.origin.url)
   echo GITOPS_REPOURL: $GITOPS_REPOURL

   GITOPS_CURRENT_BRANCH_NAME=$(git branch --show-current)
   echo GITOPS_CURRENT_BRANCH_NAME: $GITOPS_CURRENT_BRANCH_NAME
   ```

1. Deploy the cluster ARM template.
  :exclamation: By default, this deployment will allow unrestricted access to your cluster's API Server. You can limit access to the API Server to a set of well-known IP addresses (i.,e. a jump box subnet (connected to by Azure Bastion), build agents, or any other networks you'll administer the cluster from) by setting the `clusterAuthorizedIPRanges` parameter in all deployment options. This setting will also impact traffic originating from within the cluster trying to use the API server, so you will also need to include _all_ of the public IPs used by your egress Azure Firewall. For more information, see [Secure access to the API server using authorized IP address ranges](https://learn.microsoft.com/azure/aks/api-server-authorized-ip-ranges#create-an-aks-cluster-with-api-server-authorized-ip-ranges-enabled).

   ```bash
   # [This takes about 18 minutes.]
   az deployment group create -g rg-bu0001a0008 -f cluster-stamp.bicep -p targetVnetResourceId=${RESOURCEID_VNET_CLUSTERSPOKE_AKS_BASELINE} clusterAdminAadGroupObjectId=${AADOBJECTID_GROUP_CLUSTERADMIN_AKS_BASELINE} a0008NamespaceReaderAadGroupObjectId=${AADOBJECTID_GROUP_A0008_READER_AKS_BASELINE} k8sControlPlaneAuthorizationTenantId=${TENANTID_K8SRBAC_AKS_BASELINE} appGatewayListenerCertificate=${APP_GATEWAY_LISTENER_CERTIFICATE_AKS_BASELINE} aksIngressControllerCertificate=${AKS_INGRESS_CONTROLLER_CERTIFICATE_BASE64_AKS_BASELINE} domainName=${DOMAIN_NAME_AKS_BASELINE} gitOpsBootstrappingRepoHttpsUrl=${GITOPS_REPOURL} gitOpsBootstrappingRepoBranch=${GITOPS_CURRENT_BRANCH_NAME} location=eastus2
   ```

   > Alteratively, you could have updated the [`azuredeploy.parameters.prod.json`](./azuredeploy.parameters.prod.json) file and deployed as above, using `-p "@azuredeploy.parameters.prod.json"` instead of providing the individual key-value pairs.

## Container registry note

:warning: To aid in ease of deployment of this cluster and your experimentation with workloads, Azure Policy and Azure Firewall are currently configured to allow your cluster to pull images from _public container registries_ such as Docker Hub. For a production system, you'll want to update Azure Policy parameter named `allowedContainerImagesRegex` in your `cluster-stamp.bicep` file to only list those container registries that you are willing to take a dependency on and what namespaces those policies apply to, and make Azure Firewall allowances for the same. This will protect your cluster from unapproved registries being used, which may prevent issues while trying to pull images from a registry which doesn't provide SLA guarantees for your deployment.

This deployment creates an SLA-backed Azure Container Registry for your cluster's needs. Your organization may have a central container registry for you to use, or your registry may be tied specifically to your application's infrastructure (as demonstrated in this implementation). **Only use container registries that satisfy the security and availability needs of your application.**

## Application Gateway placement

Azure Application Gateway, for this reference implementation, is placed in the same virtual network as the cluster nodes (isolated by subnets and related NSGs). This facilitates direct network line-of-sight from Application Gateway to the cluster's private load balancer and still allows for strong network boundary control. More importantly, this aligns with cluster operator team owning the point of ingress. Some organizations may instead leverage a perimeter network in which Application Gateway is managed centrally which resides in an entirely separated virtual network. That topology is also fine, but you'll need to ensure there is secure and limited routing between that perimeter network and your internal private load balancer for your cluster. Also, there will be additional coordination necessary between the cluster/workload operators and the team owning the Application Gateway.

### Next step

:arrow_forward: [Validate your cluster is bootstrapped](./07-bootstrap-validation.md)

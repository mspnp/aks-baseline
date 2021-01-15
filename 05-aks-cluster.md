# Deploy the AKS Cluster

Now that the [hub-spoke network is provisioned](./04-networking.md), the next step in the [AKS secure Baseline reference implementation](./) is deploying the AKS clusters and its adjacent Azure resources.

## Steps

1. Create the first AKS cluster resource group.

   > :book: The app team working on behalf of business unit 0001 (BU001) is looking to create the two AKS cluster for the app instances they are creating (Application ID: 0042 | Instance IDs: 03 and 04). They have worked with the organization's networking team and have been provisioned the spoke networks in which to lay their clusters and network-aware external resources into (such as Application Gateway). They took that information and added it to their [`cluster-stamp.json`](./cluster-stamp.json) and [`azuredeploy.parameters.prod.json`](./azuredeploy.parameters.prod.json) files.
   >
   > They create these resource groups to be the parent group for the application instances with separted infrastructure resources.

   ```bash
   # [This takes less than one minute.]
   az group create --name rg-bu0001a0042-03 --location eastus2
   az group create --name rg-bu0001a0042-04 --location eastus2
   ```

1. Get the corresponding AKS cluster spoke VNet resource IDs for the app team working on the application A0042.

   > :book: The app team will be deploying to a spoke VNet, that was already provisioned by the network team.

   ```bash
   export TARGET_VNET_RESOURCE_ID_BU0001A0042_03=$(az deployment group show -g rg-enterprise-networking-spokes -n spoke-BU0001A0042-03 --query properties.outputs.clusterVnetResourceId.value -o tsv)
   export TARGET_VNET_RESOURCE_ID_BU0001A0042_04=$(az deployment group show -g rg-enterprise-networking-spokes -n spoke-BU0001A0042-04 --query properties.outputs.clusterVnetResourceId.value -o tsv)
   ```

1. Deploy the two AKS clusters.
  :exclamation: By default, this deployment will allow unrestricted access to your cluster's API Server.  You can limit access to the API Server to a set of well-known IP addresses (i.e. your hub firewall IP, bastion subnet, build agents, or any other networks you'll administer the cluster from) by setting the `clusterAuthorizedIPRanges` parameter in all deployment options.

   ```bash
   # [This takes about 30 minutes.]
   az deployment group create --resource-group rg-bu0001a0042-03 --template-file cluster-stamp.json --parameters targetVnetResourceId=$TARGET_VNET_RESOURCE_ID_BU0001A0042_03 k8sRbacAadProfileAdminGroupObjectID=$K8S_RBAC_AAD_PROFILE_ADMIN_GROUP_OBJECTID k8sRbacAadProfileTenantId=$K8S_RBAC_AAD_PROFILE_TENANTID appGatewayListenerCertificate=$APP_GATEWAY_LISTENER_CERTIFICATE aksIngressControllerCertificate=$AKS_INGRESS_CONTROLLER_CERTIFICATE_BASE64 appInstanceId="03" clusterInternalLoadBalancerIpAddress="10.243.4.4"
   az deployment group create --resource-group rg-bu0001a0042-04 --template-file cluster-stamp.json --parameters targetVnetResourceId=$TARGET_VNET_RESOURCE_ID_BU0001A0042_04 k8sRbacAadProfileAdminGroupObjectID=$K8S_RBAC_AAD_PROFILE_ADMIN_GROUP_OBJECTID k8sRbacAadProfileTenantId=$K8S_RBAC_AAD_PROFILE_TENANTID appGatewayListenerCertificate=$APP_GATEWAY_LISTENER_CERTIFICATE aksIngressControllerCertificate=$AKS_INGRESS_CONTROLLER_CERTIFICATE_BASE64 appInstanceId="04" clusterInternalLoadBalancerIpAddress="10.244.4.4"
   ```

## Container registry note

:warning: To aid in ease of deployment of this cluster and your experimentation with workloads, Azure Policy is currently configured to allow your cluster to pull images from _public container registries_ such as Docker Hub and Quay. For a production system, you'll want to update the Azure Policy named `pa-allowed-registries-images` in your `cluster-stamp-bu0001a0008.json` file to only list those container registries that you are willing to take a dependency on and what namespaces those policies apply to. This will protect your cluster from unapproved registries being used, which may prevent issues while trying to pull images from a registry which doesn't provide SLA guarantees for your deployment.

This deployment creates an SLA-backed Azure Container Registry for your cluster's needs. Your organization may have a central container registry for you to use, or your registry may be tied specifically to your application's infrastructure (as demonstrated in this implementation). **Only use container registries that satisfy the availability needs of your application.**

### Next step

:arrow_forward: [Place the cluster under GitOps management](./06-gitops.md)

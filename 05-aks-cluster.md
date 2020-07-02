# Create the Secure AKS cluster

Previously you have provisioned [the hub and spoke vnets](./04-networking). Now it is time to create
the AKS cluster.

---

## Deploy - Option 1 Azure Portal

use the deploy to azure button to create the cluster from the Azure Portal

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmspnp%2Freference-architectures%2Ffcp%2Faks-baseline%2Faks%2Fsecure-baseline%2Fcluster-stamp.json)

---
Next Step: [GitOps](./06-gitops.md)

## Deploy - Option 2 CLI

1. Create the AKS cluster resource group
   > The app team working on behalf of business unit 0001 (BU001) is looking to create an AKS cluster
   > of the app they are creating (Application ID: 0008). They have worked with the organization's
   > networking team and have been provisioned a spoke network in which to lay their cluster and
   > network-aware external resources into (such as Application Gateway). They took that information
   > and added it to their cluster-stamp.json and parameters file.

   > They create this resource group to be the parent group for the application

   ```bash
   # [This takes less than one minute.]
   az group create --name rg-bu0001a0008 --location eastus2
   ```

1. Get the AKS cluster spoke vnet id

   > the app team will bring its own vNet. This is the spoke vnet that had been already
   > provisioned by the network team

   ```bash
   TARGET_VNET_RESOURCE_ID=$(az deployment group show -g rg-enterprise-networking-spokes -n spoke-BU0001A0008 --query properties.outputs.clusterVnetResourceId.value -o tsv)
   ```
1. Create the AKS cluster
   > And then deploy the cluster into it.

   ```bash
   # [This takes about 15 minutes.]
   az deployment group create --resource-group rg-bu0001a0008 --template-file cluster-stamp.json --parameters targetVnetResourceId=$TARGET_VNET_RESOURCE_ID k8sRbacAadProfileAdminGroupObjectID=$K8S_RBAC_AAD_ADMIN_GROUP_OBJECTID k8sRbacAadProfileTenantId=$K8S_RBAC_AAD_PROFILE_TENANTID appGatewayListernerCertificate=$APP_GATEWAY_LISTERNER_CERTIFICATE
   ```

---
Next Step: [GitOps](./06-gitops.md)

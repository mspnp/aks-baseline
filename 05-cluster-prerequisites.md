# Deploy the AKS cluster prerequisites and shared services

In the prior step, you [generated the user-facing TLS certificate](./04-ca-certificates.md); now follow the next step in the [AKS secure Baseline reference implementation](./) is deploying the shared service instances.

## Expected results

Following the steps below will result in the provisioning of the shared Azure resources needed for an AKS multi cluster solution.

| Object                        | Purpose                                                                                                                                                                         |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Azure Container Registry      | A single Azure Container Registry instance for those container images shared across multiple clusters                                                                           |
| Azure Private Dns Zone        | The Private Dns Zone for the Azure Container Registry. Later cluster can link their vNets to it                                                                                 |
| Azure Log Analytics Workspace | A Centralized Log Analytics workspace where all the logs are collected                                                                                                          |
| Azure Front Door              | Azure Front Door always routes traffic to the fastest and available (healthy) backend. The Azure Application Gateway of each AKS Cluster will be each Azure Front Door backend. |

## Steps

1. Create the shared services resource group for your AKS clusters.

   > :book: The app team working on behalf of business unit 0001 (BU001) is about to deploy a new app (Application Id: 0042). This application needs to be deployed in a multiregion cluster infrastructure. But first the app team is required to assess the services that could be shared across the multiple clusters they are planning to create. To do this they are looking at global or regional but geo replicated services that are not cluster but workload specific.
   >
   > They create a new resource group to be one grouping all shared infrastructure resources.

   ```bash
   # [This takes less than one minute.]
   az group create --name rg-bu0001a0042-shared --location centralus
   ```

1. Read the FQDN values will have each Azure Application Gateway, the public ip DNS name already deployed

   ```bash
   APPGW_FQDN_BU0001A0042_03=$(az deployment group show --resource-group rg-enterprise-networking-spokes -n spoke-BU0001A0042-03 --query properties.outputs.appGwFqdn.value -o tsv)
   APPGW_FQDN_BU0001A0042_04=$(az deployment group show --resource-group rg-enterprise-networking-spokes -n spoke-BU0001A0042-04 --query properties.outputs.appGwFqdn.value -o tsv)
   ```

1. Deploy the AKS cluster prerequisites and shared services.

   > :book: The app team is provisioning an Azure Container Registry instance that is shared by their AKS clusters and Azure Front Door. Each client of our application around the world will be served for the closet AKS Cluster, and in case of some failure in one of the instance, the user will be served for another.

   ```bash
   az deployment group create -g rg-bu0001a0042-shared -f shared-svcs-stamp.json -p location=eastus2  fontDoorBackend="['${APPGW_FQDN_BU0001A0042_03}','${APPGW_FQDN_BU0001A0042_04}']"
   ```

### Next step

:arrow_forward: [Deploy the AKS cluster](./06-aks-cluster.md)

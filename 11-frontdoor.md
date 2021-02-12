# Azure Front Door

Now that you have a workload deployed, the [ASP.NET Core Docker sample web app](./10-workload.md), you can follow the steps below to create Azure Front Door.
Azure Front Door always routes traffic to the fastest and available (healthy) backend. The Azure Application Gateway of each AKS Cluster will be each Azure Front Door backend.
We will reach two goals:

1. your traffic to your closest service backend
1. if some app fails, then the others instances works as backup.

## Steps

1. Read the FQDN values from each Azure Application Gateway

   ```bash
   APPGW_FQDN_BU0001A0042_03=$(az deployment group show --resource-group rg-enterprise-networking-spokes -n spoke-BU0001A0042-03 --query properties.outputs.appGwFqdn.value -o tsv)
   APPGW_FQDN_BU0001A0042_04=$(az deployment group show --resource-group rg-enterprise-networking-spokes -n spoke-BU0001A0042-04 --query properties.outputs.appGwFqdn.value -o tsv)
   ```

1. Create resource group in order to deploy Azure Front Door

   ```bash
   az group create --name rg-bu0001a0042-global --location centralus
   ```

1. Deploy Azure Front Door

   > :book: Each client of our application around the world will be served for the closet AKS Cluster, and in case of some failure in one of the instance, the user will be serve for another.

   ```bash
   az deployment group create -g rg-bu0001a0042-global -f frontdoor-stamp.json -p backendNames="['${APPGW_FQDN_BU0001A0042_03}','${APPGW_FQDN_BU0001A0042_04}']"
   ```

### Next step

:arrow_forward: [End to End Validation](./12-validation.md)

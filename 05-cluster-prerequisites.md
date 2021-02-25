# Deploy the AKS cluster prerequisites and shared services

In the prior step, you [generated the user-facing TLS certificate](./04-ca-certificates.md); now follow the next step in the [AKS secure Baseline reference implementation](./) is deploying the AKS cluster prerequisites and shared Azure service instances.

## Steps

1. Create the shared services resource group for your AKS clusters.

   > :book: The app team working on behalf of business unit 0001 (BU001) is aboyt to deploy a new app (Application Id: 0042). This application needs to be deployed in a multiregion cluster infrastructure. But first the app team is required to assess the services that could be shared across the multiple clusters they are planning to create. To do this they are looking at global or regional but geo replicated services that are not cluster but worklod specific.
   >
   > They create a new resource group to be one grouping all shared infrastructure resources.

   ```bash
   # [This takes less than one minute.]
   az group create --name rg-bu0001a0042-shared --location centralus
   ```

1. Deploy the AKS cluster prerequisites and shared services.

   > :book: The app team is provisioning an Azure Container Registry instance that is shared by their AKS clusters.

   ```bash
   az deployment group create -g rg-bu0001a0042-shared -f shared-svcs-stamp.json -p location=eastus2
   ```

### Next step

:arrow_forward: [Deploy the AKS cluster](./06-aks-cluster.md)

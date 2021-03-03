# Deploy the Network Topology

The prerequisites for the [AKS secure baseline cluster](./) are now completed with [Azure AD group and user work](./03-aad.md) performed in the prior steps. Now we will start with our first Azure resource deployment, the network resources.

## Subscription and resource group topology

This reference implementation is split across several resource groups in a single subscription. This is to replicate the fact that many organizations will split certain responsibilities into specialized subscriptions (e.g. regional hubs/vwan in a _Connectivity_ subscription and workloads in landing zone subscriptions). We expect you to explore this reference implementation within a single subscription, but when you implement this cluster at your organization, you will need to take what you've learned here and apply it to your expected subscription and resource group topology (such as those [offered by the Cloud Adoption Framework](https://docs.microsoft.com/azure/cloud-adoption-framework/decision-guides/subscriptions/).) This single subscription, multiple resource group model is for simplicity of demonstration purposes only.

## Expected results

### Resource Groups

The following resource group will be created and populated with networking resources in the steps below.

| Name                            | Purpose                                   |
|---------------------------------|-------------------------------------------|
| rg-enterprise-networking        | Contains all of your organization's regional spokes and related networking resources

### Resources

* VNET for the Cluster
* Network Security Groups for all subnets that support them

## Steps

1. Login into the Azure subscription that you'll be deploying into.

   > :book: The networking team logins into the Azure subscription that will contain the regional hub. At Contoso Bicycle, all of their regional hubs are in the same, centrally-managed subscription.

   ```bash
   az login -t $TENANTID_AZURERBAC
   ```

1. Create the networking spokes resource group.

   > :book: The networking team also keeps all of their spokes in a centrally-managed resource group. The location of this group does not matter and will not factor into where our network will live.

   ```bash
   # [This takes less than one minute to run.]
   az group create -n rg-enterprise-networking -l centralus
   ```

1. Create the vnet that will be home to the AKS cluster and its adjacent resources.


   ```bash

   # [This takes about five minutes to run.]
   az deployment group create -g rg-enterprise-networking -f networking/vnet.json -p location=eastus2 -p namePrefix=aname
   ```

   The vnet creation will emit the following:

     * `appGwPublicIpAddress` - The Public IP address of the Azure Application Gateway (WAF) that will receive traffic for your workload.
     * `clusterVnetResourceId` - The resource ID of the VNet that the cluster will land in. E.g. `/subscriptions/[subscription id]/resourceGroups/rg-enterprise-networking/providers/Microsoft.Network/virtualNetworks/vnet`
     * `nodepoolSubnetResourceIds` - An array containing the subnet resource IDs of the AKS node pools in the vnet. E.g. `["/subscriptions/[subscription id]/resourceGroups/rg-enterprise-networking-spokes/providers/Microsoft.Network/virtualNetworks/vnet/subnets/snet-clusternodes"]`


### Next step

:arrow_forward: [Deploy the AKS cluster](./05-aks-cluster.md)

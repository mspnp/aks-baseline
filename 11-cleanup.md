# Clean up

After you are done exploring your deployed [AKS secure baseline cluster](./), you'll want to delete the created Azure resources to prevent undesired costs from accruing. Follow these steps to delete all resources created as part of this reference implementation.

## Steps

1. Delete the resource groups as a way to delete all contained Azure resources.

   > To delete all Azure resources associated with this reference implementation, you'll need to delete the three resource groups created.

   :warning: Ensure you are using the correct subscription, and validate that the only resources that exist in these groups are ones you're okay deleting.

   ```bash
   az group delete -n rg-bu0001a0042-03
   az group delete -n rg-bu0001a0042-04
   az group delete -n rg-bu0001a0042-shared
   az group delete -n rg-enterprise-networking-spokes
   az group delete -n rg-enterprise-networking-hubs
   ```

1. Purge Azure Key Vault

   > Because this reference implementation enables soft delete on Key Vault, execute a purge so your next deployment of this implementation doesn't run into a naming conflict.

   ```bash
   az keyvault purge -n $KEYVAULT_NAME_BU0001A0042_03
   az keyvault purge -n $KEYVAULT_NAME_BU0001A0042_04
   ```

1. [Remove the Azure Policy assignments](https://portal.azure.com/#blade/Microsoft_Azure_Policy/PolicyMenuBlade/Compliance) scoped to the cluster's resource group. To identify those created by this implementation, look for ones that are prefixed with `[your-cluster-name] `. Alternatively you could execute the following commmand:

   ```bash
   for p in $(az policy assignment list --disable-scope-strict-match --query "[?resourceGroup=='rg-bu0001a0042-03'].name" -o tsv); do az policy assignment delete --name ${p} --resource-group rg-bu0001a0042-03; done
   for p in $(az policy assignment list --disable-scope-strict-match --query "[?resourceGroup=='rg-bu0001a0042-04'].name" -o tsv); do az policy assignment delete --name ${p} --resource-group rg-bu0001a0042-04; done
   ```

1. If any temporary changes were made to Azure AD or Azure RBAC permissions consider removing those as well.

### Next step

:arrow_forward: [Review additional information in the main README](./README.md#broom-clean-up-resources)

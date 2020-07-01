# Clean up

Previously you have [validated an end-to-end case scenario](./09-validation). You can follow these steps to
delete all resources.

---

To delete all Azure resources associated with this reference implementation, you'll need to delete the three resource groups created. Also if any temporary changes were made to Azure AD or Azure RBAC permissions consider removing those as well.

1. Delete the resource groups as a way to delete all Azure resources

   ```bash
   az group delete -n rg-bu0001a0008 --yes
   az group delete -n rg-enterprise-networking-spokes --yes
   az group delete -n rg-enterprise-networking-hubs --yes
   ```

1. Purge Azure KeyVault

   > Because this reference implementation enables soft delete, execute purge so your next
   > test deployment of this implementation doesn't run into a naming conflict.

   ```bash
   az keyvault purge --name ${KEYVAULT_NAME} --location eastus2 --yes
   ```
---
End: [back to main](./README.md#getting-started)

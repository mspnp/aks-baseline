# Clean up

After you are done exploring your deployed [AKS baseline cluster](../../), you'll want to delete the created Azure resources to prevent undesired costs from accruing. Follow these steps to delete all resources created as part of this reference implementation.

## Steps

1. Delete the resource groups as a way to delete all contained Azure resources.

   > To delete all Azure resources associated with this reference implementation, you'll need to delete the three resource groups created.

   :warning: Ensure you are using the correct subscription, and validate that the only resources that exist in these groups are ones you're okay deleting.

   ```bash
   az group delete -n rg-bu0001a0008
   az group delete -n rg-enterprise-networking-spokes-${LOCATION_AKS_BASELINE}
   az group delete -n rg-enterprise-networking-hubs-${LOCATION_AKS_BASELINE}
   ```

1. Purge Azure Key Vault

   > Because this reference implementation enables soft delete on Key Vault, execute a purge so your next deployment of this implementation doesn't run into a naming conflict.

   ```bash
   az keyvault purge -n $KEYVAULT_NAME_AKS_BASELINE
   ```

1. If any temporary changes were made to Microsoft Entra ID or Azure RBAC permissions consider removing those as well.

1. [Remove the Azure Policy assignments](https://portal.azure.com/#blade/Microsoft_Azure_Policy/PolicyMenuBlade/Compliance) scoped to the cluster's resource group. To identify those created by this implementation, look for ones that are prefixed with `[your-cluster-name] `.

## Automation

Before you can automate a process, it's important to experience the process in a bit more raw form as was presented here. That experience allows you to understand the various steps, inner- & cross-team dependencies, and failure points along the way. However, the steps provided in this walkthrough are not specifically designed with automation in mind. It does present a perspective on some common separation of duties often encountered in organizations, but that might not align with your organization.

Now that you understand the components involved and have identified the shared responsibilities between your team and your greater organization, you are encouraged to build repeatable deployment processes around your final infrastructure and cluster bootstrapping. Refer to the [AKS baseline automation guidance](https://github.com/Azure/aks-baseline-automation#aks-baseline-automation) to learn how GitHub Actions combined with Infrastructure as Code can be used to facilitate this automation. That guidance is based on the same architecture foundations you've walked through here.

> Note: The [AKS baseline automation guidance](https://github.com/Azure/aks-baseline-automation#aks-baseline-automation) implementation strives to stay in sync with this repo, but may slightly deviate in various decisions made, may introduce new features, or not yet have a feature that is used in this repo. They are functionally aligned by design, but not necessarily identical. Use that repo to explore the automation potential, while this repo is used for the core architectural guidance.

### Next step

:arrow_forward: [Review additional information in the main README](./README.md#broom-clean-up-resources)

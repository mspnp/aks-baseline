# Prerequisites

This is the starting point for the instructions on deploying the [AKS Secure Baseline reference implementation](./). There is required access and tooling you'll need in order to accomplish this. Follow the instructions below and on the subsequent pages so that you can get your environment ready to proceed with the AKS cluster creation.

## Steps

1. An Azure subscription. If you don't have an Azure subscription, you can create a [free account](https://azure.microsoft.com/free).

   > Important: the user or service principal initiating the deployment process must have the following minimal set of Azure Role-Based Access Control (RBAC) roles and Azure AD permissions assigned:
   >
   > * [Contributor role](https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#contributor) is required at the subscription level to have the ability to create resource groups and perform deployments.
   > * [User Access Administrator role](https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#user-access-administrator) is required at the subscription level since you'll be granting least-privilege RBAC access to resources as well as assigning built-in policy definitions to your AKS cluster.
   >   * One such example is detailed in the [Container Insights documentation](https://docs.microsoft.com/azure/azure-monitor/insights/container-insights-troubleshoot#authorization-error-during-onboarding-or-update-operation).
   > * Azure AD [User Administrator](https://docs.microsoft.com/azure/active-directory/users-groups-roles/directory-assign-admin-roles#user-administrator-permissions).
   >   * If you are not part of the User Administrator group in the tenant associated to your Azure subscription, please consider [creating a new tenant](https://docs.microsoft.com/azure/active-directory/fundamentals/active-directory-access-create-new-tenant#create-a-new-tenant-for-your-organization) to use while evaluating this implementation.

1. Latest [Azure CLI installed](https://docs.microsoft.com/cli/azure/install-azure-cli?view=azure-cli-latest) or you can perform this from Azure Cloud Shell by clicking below.

   [![Launch Azure Cloud Shell](https://docs.microsoft.com/azure/includes/media/cloud-shell-try-it/launchcloudshell.png)](https://shell.azure.com)
1. While the following features are still in _preview_, please enable them manually in your subscription.
   1. [Register the AAD-V2 feature for AKS-managed Azure AD](https://docs.microsoft.com/azure/aks/managed-aad#before-you-begin).
   1. [Register the required Azure Policy features for AKS](https://docs.microsoft.com/en-us/azure/governance/policy/concepts/policy-for-kubernetes#install-azure-policy-add-on-for-aks).
1. Clone/download this repo locally, or even better fork this repository.

   > :twisted_rightwards_arrows: If you have forked this reference implementation repo, you'll be able to customize some of the files and commands for a more personalized experience; also ensure references to repos mentioned are updated to use your own (e.g. the following `GITHUB_REPO`).

   ```bash
   export GITHUB_REPO=https://github.com/mspnp/aks-secure-baseline.git
   git clone $GITHUB_REPO
   ```

   > :bulb: The steps shown here and elsewhere in the reference implementation use Bash shell commands. On Windows, you can use the [Windows Subsystem for Linux](https://docs.microsoft.com/windows/wsl/about#what-is-wsl-2) to run Bash.

1. Ensure [OpenSSL is installed](https://github.com/openssl/openssl#download) in order to generate self-signed certs used in this implementation.

### Next step

:arrow_forward: [Generate your client-facing TLS certificate](./02-ca-certificates.md)

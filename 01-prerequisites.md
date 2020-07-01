# Prerequisites

the required tooling minimun requirements are getting installed from this sections.
Follow the instructions to get your environment ready to proceed with the AKS cluster
creation.

---

1. An Azure subscription. If you don't have an Azure subscription, you can create a [free account](https://azure.microsoft.com/free).

   > Important: the user initiating the deployment process must have the following minimal set of roles:
   >
   > * [Contributor role](https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#contributor) is required at the subscription level to have the ability to create resource groups and perform deployments.
   > * [User Access Administrator role](https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#user-access-administrator) is required at the subscription level since granting RBAC access to resources will be required.
   >   * One such example is detailed in the [Container Insights documentation](https://docs.microsoft.com/azure/azure-monitor/insights/container-insights-troubleshoot#authorization-error-during-onboarding-or-update-operation).
   > * Azure AD [User Administrator](https://docs.microsoft.com/azure/active-directory/users-groups-roles/directory-assign-admin-roles#user-administrator-permissions).
   >   * If you are not part of the User Administrator group in the tenant associated to your Azure subscription, please consider [creating a new tenant](https://docs.microsoft.com/azure/active-directory/fundamentals/active-directory-access-create-new-tenant#create-a-new-tenant-for-your-organization) to use while evaluating this implementation.

1. [Azure CLI installed](https://docs.microsoft.com/cli/azure/install-azure-cli?view=azure-cli-latest) or try from Azure Cloud Shell by clicking below.

   [![Launch Azure Cloud Shell](https://docs.microsoft.com/azure/includes/media/cloud-shell-try-it/launchcloudshell.png)](https://shell.azure.com)
1. [Register the AAD-V2 feature for AKS-managed Azure AD](https://docs.microsoft.com/azure/aks/managed-aad#before-you-begin) in your subscription.
1. Clone, download this repo locally or even better Fork this repository

   > :twisted_rightwards_arrows: Fork: if you have made the call to fork the
   > AKS Baseline Reference Implementation repo, first of all congratulations
   > and also please consider replacing the `GITHUB_REPO` env var value with
   > your own repository url

   ```bash
   export GITHUB_REPO=https://github.com/mspnp/reference-architectures.git
   git clone $GITHUB_REPO
   cd reference-architectures/aks/secure-baseline
   ```

   > :bulb: Tip: The deployment steps shown here use Bash shell commands. On Windows, you can use the [Windows Subsystem for Linux](https://docs.microsoft.com/en-us/windows/wsl/about#what-is-wsl-2) to run Bash.

1. [OpenSSL](https://github.com/openssl/openssl#download) to generate self-signed certs used in this implementation.
---
Next Step: [Azure Active Directory Integration](./02-aad.md)

# Prerequisites

This is the starting point for the instructions on deploying the [AKS baseline multi cluster reference implementation](/README.md). There is required access and tooling you'll need in order to accomplish this. Follow the instructions below and on the subsequent pages so that you can get your environment ready to proceed with the creation of the AKS clusters.

## Steps

1. Login into your Azure subscription, and save your Azure subscription's tenant id.

   > :warning: The user or service principal initiating the deployment process _must_ have the following minimal set of Azure Role-Based Access Control (RBAC) roles:
   >
   > - [Contributor role](https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#contributor) is _required_ at the subscription level to have the ability to create resource groups and perform deployments.
   > - [User Access Administrator role](https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#user-access-administrator) is _required_ at the subscription level since you'll be performing role assignments to managed identities across various resource groups.

   ```bash
   az login
   TENANTID_AZURERBAC=$(az account show --query tenantId -o tsv)
   TENANTS=$(az rest --method get --url https://management.azure.com/tenants?api-version=2020-01-01 --query 'value[].{TenantId:tenantId,Name:displayName}' -o table)
   ```

   :bulb: If you don't have an Azure subscription, you can create a [free account](https://azure.microsoft.com/free).

1. Validate your saved Azure subscription's tenant id is correct

   ```bash
   echo "${TENANTS}" | grep -z ${TENANTID_AZURERBAC}
   ```

   :warning: Do not procced if the tenant highlighted in red is not correct. Start over by `az login` into the proper Azure subscription

1. From the list printed in the previous step, select an Azure AD tenant to associate your Kubernetes RBAC Cluster API authentication and login into.

   > :warning: The user or service principal initiating the deployment process _must_ have the following minimal set of Azure AD permissions assigned:
   >
   > - Azure AD [User Administrator](https://docs.microsoft.com/azure/active-directory/users-groups-roles/directory-assign-admin-roles#user-administrator-permissions) is _required_ to create a "break glass" AKS admin Active Directory Security Group and User. Alternatively, you could get your Azure AD admin to create this for you when instructed to do so.
   >   - If you are not part of the User Administrator group in the tenant associated to your Azure subscription, please consider [creating a new tenant](https://docs.microsoft.com/azure/active-directory/fundamentals/active-directory-access-create-new-tenant#create-a-new-tenant-for-your-organization) to use while evaluating this implementation. The Azure AD tenant backing your Cluster's API RBAC does NOT need to be the same tenant associated with your Azure subscription.

   ```bash
   az login --allow-no-subscriptions -t <Replace-With-ClusterApi-AzureAD-TenantId>
   ```

1. Validate that the new saved tenant id is correct one for Kubernetes Cluster API authorization

   ```bash
   TENANTID_K8SRBAC=$(az account show --query tenantId -o tsv)
   echo "${TENANTS}" | grep -z ${TENANTID_K8SRBAC}
   ```

   :warning: If the tenant highlighted in red is not correct, start over by login into the proper Azure Directory Tenant for Kubernetes Cluster API authorization.

1. Latest [Azure CLI installed](https://docs.microsoft.com/cli/azure/install-azure-cli?view=azure-cli-latest) or you can perform this from Azure Cloud Shell by clicking below.

   [![Launch Azure Cloud Shell](https://docs.microsoft.com/azure/includes/media/cloud-shell-try-it/launchcloudshell.png)](https://shell.azure.com)

1. Install [GitHub CLI](https://github.com/cli/cli/#installation)

1. Login GitHub Cli

   ```bash
   gh auth login -s "repo,admin:org"
   ```

1. Fork the repository first, and clone it

   ```bash
   gh repo fork mspnp/aks-baseline-multi-region --clone=true --remote=false
   cd aks-baseline-multi-region
   git remote remove upstream
   ```

   > :bulb: The steps shown here and elsewhere in the reference implementation use Bash shell commands. On Windows, you can use the [Windows Subsystem for Linux](https://docs.microsoft.com/windows/wsl/about#what-is-wsl-2) to run Bash.

1. Get your GitHub user name

   ```bash
   GITHUB_USER_NAME=$(echo $(gh auth status 2>&1) | sed "s#.*as \(.*\) (.*#\1#")
   ```

1. Ensure the following tooling is also installed:
   1. [OpenSSL](https://github.com/openssl/openssl#download) in order to generate self-signed certs used in this implementation.
   1. [Certbot](https://certbot.eff.org/). Certbot is a free, open source software tool for automatically using Let’s Encrypt certificates on manually-administrated websites to enable HTTPS.

### Next step

:arrow_forward: [Prep for Azure Active Directory integration](./02-aad.md)

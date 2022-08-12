# Prerequisites

This is the starting point for the instructions on deploying the [AKS Baseline reference implementation](./README.md). There is required access and tooling you'll need in order to accomplish this. Follow the instructions below and on the subsequent pages so that you can get your environment ready to proceed with the AKS cluster creation.

## Steps

1. An Azure subscription.

   The subscription used in this deployment cannot be a [free account](https://azure.microsoft.com/free); it must be a standard EA, pay-as-you-go, or Visual Studio benefit subscription. This is because the resources deployed here are beyond the quotas of free subscriptions.

   > :warning: The user or service principal initiating the deployment process _must_ have the following minimal set of Azure Role-Based Access Control (RBAC) roles:
   >
   > * [Contributor role](https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#contributor) is _required_ at the subscription level to have the ability to create resource groups and perform deployments.
   > * [User Access Administrator role](https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#user-access-administrator) is _required_ at the subscription level since you'll be performing role assignments to managed identities across various resource groups.

1. An Azure AD tenant to associate your Kubernetes RBAC Cluster API authentication to.

   > :warning: The user or service principal initiating the deployment process _must_ have the following minimal set of Azure AD permissions assigned:
   >
   > * Azure AD [User Administrator](https://docs.microsoft.com/azure/active-directory/users-groups-roles/directory-assign-admin-roles#user-administrator-permissions) is _required_ to create a "break glass" AKS admin Active Directory Security Group and User. Alternatively, you could get your Azure AD admin to create this for you when instructed to do so.
   >   * If you are not part of the User Administrator group in the tenant associated to your Azure subscription, please consider [creating a new tenant](https://docs.microsoft.com/azure/active-directory/fundamentals/active-directory-access-create-new-tenant#create-a-new-tenant-for-your-organization) to use while evaluating this implementation. The Azure AD tenant backing your cluster's API RBAC does NOT need to be the same tenant associated with your Azure subscription.

1. Latest [Azure CLI installed](https://docs.microsoft.com/cli/azure/install-azure-cli?view=azure-cli-latest) (must be at least 2.37), or you can perform this from Azure Cloud Shell by clicking below.

   [![Launch Azure Cloud Shell](https://docs.microsoft.com/azure/includes/media/cloud-shell-try-it/launchcloudshell.png)](https://shell.azure.com)

1. While the following feature(s) are still in _preview_, please enable them in your target subscription.

   1. [Register the Azure Event Grid preview feature - `EventgridPreview`](https://docs.microsoft.com/azure/aks/quickstart-event-grid#register-the-eventgridpreview-preview-feature)

   1. [Register the OIDC Issuer preview feature = `EnableOIDCIssuerPreview`](https://docs.microsoft.com/azure/aks/cluster-configuration#oidc-issuer-preview)

   ```bash
   az feature register --namespace "Microsoft.ContainerService" -n "EventgridPreview"
   az feature register --namespace "Microsoft.ContainerService" -n "AKS-ExtensionManager"
   az feature register --namespace "Microsoft.ContainerService" -n "EnableOIDCIssuerPreview"
   az feature register --namespace "Microsoft.ContainerService" -n "AKS-AzureDefender"

   # Keep running until all say "Registered." (This may take up to 20 minutes.)
   az feature list -o table --query "[?name=='Microsoft.ContainerService/EventgridPreview' || name=='Microsoft.ContainerService/AKS-ExtensionManager' || name=='Microsoft.ContainerService/EnableOIDCIssuerPreview' || name=='Microsoft.ContainerService/AKS-AzureDefender' ].{Name:name,State:properties.state}"

   # When all say "Registered" then re-register the AKS and related resource providers
   az provider register --namespace Microsoft.ContainerService
   az provider register --namespace Microsoft.KubernetesConfiguration
   ```

1. Clone/download this repo locally, or even better fork this repository.

   > :twisted_rightwards_arrows: If you have forked this reference implementation repo, you'll be able to customize some of the files and commands for a more personalized and production-like experience; ensure references to this git repository mentioned throughout the walk-through are updated to use your own fork.

   > Make sure you use HTTPS (and not SSH) to clone the repository. (The remote URL will later be used to configure GitOps using Flux which requires an HTTPS endpoint to work properly.)

   ```bash
   git clone https://github.com/mspnp/aks-baseline.git
   cd aks-baseline
   ```

   > :bulb: The steps shown here and elsewhere in the reference implementation use Bash shell commands. On Windows, you can use the [Windows Subsystem for Linux](https://docs.microsoft.com/windows/wsl/about) to run Bash.

1. Ensure [OpenSSL is installed](https://github.com/openssl/openssl#download) in order to generate self-signed certs used in this implementation. _OpenSSL is already installed in Azure Cloud Shell._

   > :warning: Some shells may have the `openssl` command aliased for LibreSSL. LibreSSL will not work with the instructions found here. You can check this by running `openssl version` and you should see output that says `OpenSSL <version>` and not `LibreSSL <version>`.

### Next step

:arrow_forward: [Generate your client-facing TLS certificate](./02-ca-certificates.md)

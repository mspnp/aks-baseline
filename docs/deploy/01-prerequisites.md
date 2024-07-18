# Prerequisites

This is the starting point for the instructions on deploying the [AKS baseline reference implementation](./README.md). There is required access and tooling you'll need in order to accomplish this deployment. Follow the instructions here and on the subsequent pages so that you can get your environment ready to proceed with the AKS cluster creation.

| :clock10: | These steps are intentionally verbose, intermixed with context, narrative, and guidance. The deployments are all conducted via [Bicep templates](https://learn.microsoft.com/azure/azure-resource-manager/bicep/overview), but they are executed manually via `az cli` commands. We strongly encourage you to dedicate time to walk through these instructions, with a focus on learning. We do not provide any "one click" method to complete all deployments.<br><br>Once you understand the components involved and have identified the shared responsibilities between your team and your greater organization, you are encouraged to build suitable, repeatable deployment processes around your final infrastructure and cluster bootstrapping. The [AKS baseline automation guidance](https://github.com/Azure/aks-baseline-automation#aks-baseline-automation) is a great place to learn how to build your own automation pipelines. That guidance is based on the same architecture foundations presented here in the AKS baseline, and illustrates GitHub Actions-based deployments for all components, including workloads. |
|-----------|:--------------------------|

## Steps

1. An Azure subscription.

   The subscription used in this deployment cannot be a [free account](https://azure.microsoft.com/free); it must be a standard EA, pay-as-you-go, or Visual Studio benefit subscription. This is because the resources deployed here are beyond the quotas of free subscriptions.

   > :warning: The user or service principal initiating the deployment process *must* have the following minimal set of Azure role-based access control (RBAC) roles:
   >
   > - [Contributor role](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#contributor) is *required* at the subscription level to have the ability to create resource groups and perform deployments.
   > - [User Access Administrator role](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#user-access-administrator) is *required* at the subscription level since you'll be performing role assignments to managed identities across various resource groups.
   > - [Resource Policy Contributor role](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#resource-policy-contributor) is *required* at the subscription level since you'll be creating custom Azure Policy definitions to govern resources in your AKS cluster.

1. A Microsoft Entra ID tenant to associate your Kubernetes RBAC Cluster API authentication to.

   > :warning: The user or service principal initiating the deployment process *must* have the following minimal set of Microsoft Entra ID permissions assigned:
   >
   > - Microsoft Entra ID [User Administrator](https://learn.microsoft.com/azure/active-directory/users-groups-roles/directory-assign-admin-roles#user-administrator-permissions) is *required* to create a "break glass" AKS admin Microsoft Entra security group and user. Alternatively, you could get your Microsoft Entra ID admin to create this for you when instructed to do so.
   >   - If you are not part of the User Administrator group in the tenant associated to your Azure subscription, consider [creating a new tenant](https://learn.microsoft.com/azure/active-directory/fundamentals/active-directory-access-create-new-tenant#create-a-new-tenant-for-your-organization) to use while evaluating this implementation. The Microsoft Entra ID tenant backing your cluster's API RBAC does NOT need to be the same tenant associated with your Azure subscription.

1. Latest [Azure CLI installed](https://learn.microsoft.com/cli/azure/install-azure-cli?view=azure-cli-latest) (must be at least 2.40), or you can perform this from Azure Cloud Shell by clicking below.

   [![Launch Azure Cloud Shell](https://learn.microsoft.com/azure/includes/media/cloud-shell-try-it/launchcloudshell.png)](https://shell.azure.com)

1. Clone/download this repo locally, or even better fork this repository.

   > :twisted_rightwards_arrows: If you have forked this reference implementation repo, you'll be able to customize some of the files and commands for a more personalized and production-like experience; ensure references to this Git repository mentioned throughout the walk-through are updated to use your own fork.
   >
   > Make sure you use HTTPS (and not SSH) to clone the repository. (The remote URL will later be used to configure GitOps using Flux which requires an HTTPS endpoint to work properly.)

   ```bash
   git clone https://github.com/mspnp/aks-baseline.git
   cd aks-baseline
   ```

   > :bulb: The steps shown here and elsewhere in the reference implementation use Bash shell commands. On Windows, you can use the [Windows Subsystem for Linux](https://learn.microsoft.com/windows/wsl/about) to run Bash.

1. Ensure [OpenSSL is installed](https://github.com/openssl/openssl#download) in order to generate self-signed certs used in this implementation. *OpenSSL is already installed in Azure Cloud Shell.*

   > :warning: Some shells may have the `openssl` command aliased for LibreSSL. LibreSSL will not work with the instructions found here. You can check this by running `openssl version` and you should see output that says `OpenSSL <version>` and not `LibreSSL <version>`.

### Next step

:arrow_forward: [Generate your client-facing TLS certificate](./02-ca-certificates.md)

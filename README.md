# Azure Kubernetes Service (AKS) Baseline Reference Implementation

This reference implementation demonstrates the _recommended_ infrastructure architecture for hosting applications on an [AKS cluster](https://azure.microsoft.com/services/kubernetes-service).

This is meant to guide an interdisciplinary team or multiple teams like networking, security and development through the process of getting this secure baseline infrastructure deployed.

## Guidance

This project has a companion set of articles that describe challenges, design patterns, and best practices for a secure AKS cluster. You can find this article on the Azure Architecture Center:

[Baseline architecture for a secure AKS cluster](https://docs.microsoft.com/azure/architecture/reference-architectures/containers/aks/secure-baseline/)

## Architecture

This architecture is infrastructure focused, more so than workload. It mainly concentrates on the AKS cluster itself, including identity, post-deployment configuration, secret management, and network considerations.

The implementation presented here is the minimum recommended _baseline_ for expanded growth any AKS cluster. This implementation integrates with Azure services that will deliver observability, provide a network topology that will support multi-regional growth, and keep the in-cluster traffic secure as well.

We recommend customers strongly consider adopting a GitOps process for cluster management. An implementation of this is demonstrated in this reference, using [Flux](https://fluxcd.io).

Contoso Bicycle is a fictional small and fast-growing startup that provides online web services to its clientele in the west coast of North America. They have no on-premises data centers and all their containerized line of business applications are now about to be orchestrated by secure, enterprise-ready AKS clusters.

This implementation uses the [ASPNET Core Docker sample web app](https://github.com/dotnet/dotnet-docker/tree/master/samples/aspnetapp) as an example workload. This workload purposefully uninteresting, as it is here exclusively to help you experience the baseline infrastructure.

### Core components that compose this baseline

#### Azure platform

* AKS v1.17
  * System and User nodepool separation
  * AKS-managed Azure AD integration
  * Managed Identities
  * Azure CNI
  * Azure Monitor for Containers
* Azure Virtual Networks (hub-spoke)
* Azure Application Gateway (WAF)
* AKS-managed Internal Load Balancers
* Azure Firewall

#### In-cluster OSS components

* [Flux GitOps Operator](https://fluxcd.io)
* [Traefik Ingress Controller](https://docs.microsoft.com/azure/dev-spaces/how-to/ingress-https-traefik)
* [Azure AD Pod Identity](https://github.com/Azure/aad-pod-identity)
* [Azure KeyVault Secret Store CSI Provider](https://github.com/Azure/secrets-store-csi-driver-provider-azure)
* [Kured](https://docs.microsoft.com/azure/aks/node-updates-kured)

![TODO, Apply Description](https://docs.microsoft.com/azure/architecture/reference-architectures/containers/aks/secure-baseline/images/baseline-network-topology.png)

## Getting Started

### Prerequisites

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
1. Clone or download this repo locally.

   ```bash
   git clone https://github.com/mspnp/reference-architectures.git
   cd reference-architectures/aks/secure-baseline
   ```

   > :bulb: Tip: The deployment steps shown here use Bash shell commands. On Windows, you can use the [Windows Subsystem for Linux](https://docs.microsoft.com/en-us/windows/wsl/about#what-is-wsl-2) to run Bash.

1. [OpenSSL](https://github.com/openssl/openssl#download) to generate self-signed certs used in this implementation.

### Acquire the CA certificates

1. Generate a CA self-signed TLS cert

   > Contoso Bicycle needs to buy CA certificates, their preference is to use two different TLS certificates. The first one is going to be a user-facing EV cert to serve in front of the Azure Application Gateway and another one a standard cert at the Ingress Controller level which will not be user facing.

   > :warning: Do not use the certificates created by these scripts for actual deployments. The self-signed certificates are provided for ease of illustration purposes only. For your cluster, use your organization's requirements for procurement and lifetime management of TLS certificates, even for development purposes.

   Cluster Ingress Controller Wildcard Certificate: `*.aks-ingress.contoso.com`

   ```bash
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 -out traefik-ingress-internal-aks-ingress-contoso-com-tls.crt -keyout traefik-ingress-internal-aks-ingress-contoso-com-tls.key -subj "/CN=*.aks-ingress.contoso.com/O=Contoso Aks Ingress"
   rootCertWilcardIngressController=$(cat traefik-ingress-internal-aks-ingress-contoso-com-tls.crt | base64 -w 0)
   ```

   Azure Application Gateway Certificate: `bicycle.contoso.com`

   ```bash
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 -out appgw.crt -keyout appgw.key -subj "/CN=bicycle.contoso.com/O=Contoso Bicycle"
   openssl pkcs12 -export -out appgw.pfx -in appgw.crt -inkey appgw.key -passout pass:
   appGatewayListernerCertificate=$(cat appgw.pfx | base64 -w 0)
   ```

### Create the Secure AKS cluster

1. Query your tenant id

   ```bash
   export TENANT_ID=$(az account show --query tenantId --output tsv)

   # Login into the tenant where you are a User Administrator. Re-use the TENANT_ID
   # env var if your are User Administrator from the Azure subscription tenant
   az login --tenant <tenant-id-with-user-admin-permissions> --allow-no-subscriptions

   export K8S_RBAC_AAD_PROFILE_TENANTID=$(az account show --query tenantId --output tsv)
   ```

1. Create a [new AAD user and group](./deploy/azcli/aad/aad.azcli) for Kubernetes RBAC purposes
   > :bulb: You can execute `.azcli` files from Visual Studio Code.
1. Provision [a regional hub and spoke virtual network](./deploy/azcli/network-deploy.azcli)
1. Create [the baseline AKS cluster](./deploy/azcli/cluster-deploy.azcli)

### Flux as the GitOps solution

GitOps allows a team to author Kubernetes manifest files, persist them in their git repo, and have them automatically apply to their cluster as changes occur.  This reference implementation is focused on the baseline cluster, so Flux is managing cluster-level concerns (distinct from workload-level concerns, which would be possible, and can be done by additional Flux operators). The namespace `cluster-baseline-settings` will be used to provide a logical division of the cluster configuration from workload configuration.  Examples of manifests that are applied:

* Cluster Role Bindings for the AKS-managed Azure AD integration
* AAD Pod Identity
* CSI driver and Azure KeyVault CSI Provider
* the App team (Application ID: 0008) namespace named a0008

1. Install kubectl 1.18 or newer (`kubctl` supports +/-1 kubernetes version)

   ```bash
   sudo az aks install-cli
   kubectl version --client
   ```

1. Get the cluster name

   ```bash
   export AKS_CLUSTER_NAME=$(az deployment group show --resource-group rg-bu0001a0008 -n cluster-stamp --query properties.outputs.aksClusterName.value -o tsv)
   ```

1. Get AKS kubectl credentials

   ```bash
   az aks get-credentials -n $AKS_CLUSTER_NAME -g rg-bu0001a0008 --admin
   ```

1. Deploy Flux

   ```bash
   kubectl create namespace cluster-baseline-settings
   kubectl apply -f https://raw.githubusercontent.com/mspnp/reference-architectures/master/aks/secure-baseline/cluster-baseline-settings/flux.yaml
   kubectl wait --namespace cluster-baseline-settings --for=condition=ready pod --selector=app.kubernetes.io/name=flux --timeout=90s
   ```

### Traefik Ingress Controller with Azure KeyVault CSI integration

The application is designed to be exposed outside of their AKS cluster. Therefore, an Ingress Controller must be deployed, and Traefik is selected. Since the ingress controller will be exposing a TLS certificate, they use the Azure KeyVault CSI Provider to mount their TLS certificate managed and stored in Azure KeyVault so Traefik can use it.

```bash
# Get the AKS Ingress Controller Managed Identity details
export TRAEFIK_USER_ASSIGNED_IDENTITY_RESOURCE_ID=$(az deployment group show --resource-group rg-bu0001a0008 -n cluster-stamp --query properties.outputs.aksIngressControllerUserManageIdentityResourceId.value -o tsv)
export TRAEFIK_USER_ASSIGNED_IDENTITY_CLIENT_ID=$(az deployment group show --resource-group rg-bu0001a0008 -n cluster-stamp --query properties.outputs.aksIngressControllerUserManageIdentityClientId.value -o tsv)

# Get Azure KeyVault name
export KEYVAULT_NAME=$(az deployment group show --resource-group rg-bu0001a0008 -n cluster-stamp --query properties.outputs.keyVaultName.value -o tsv)

# Ensure Flux has created the following namespace and then press Ctrl-C
kubectl get ns a0008 -w

# Create the Traefik Azure Identity and the Azure Identity Binding to let
# Azure Active Directory Pod Identity to get tokens on behalf of the Traefik's User Assigned
# Identity and later on assign them to the Traefik's pod
cat <<EOF | kubectl apply -f -
apiVersion: "aadpodidentity.k8s.io/v1"
kind: AzureIdentity
metadata:
  name: aksic-to-keyvault-identity
  namespace: a0008
spec:
  type: 0
  resourceID: $TRAEFIK_USER_ASSIGNED_IDENTITY_RESOURCE_ID
  clientID: $TRAEFIK_USER_ASSIGNED_IDENTITY_CLIENT_ID
---
apiVersion: "aadpodidentity.k8s.io/v1"
kind: AzureIdentityBinding
metadata:
  name: aksic-to-keyvault-identity-binding
  namespace: a0008
spec:
  azureIdentity: aksic-to-keyvault-identity
  selector: traefik-ingress-controller
EOF

# Create a SecretProviderClasses resource with with your Azure KeyVault parameters
# for the Secrets Store CSI driver.
cat <<EOF | kubectl apply -f -
apiVersion: secrets-store.csi.x-k8s.io/v1alpha1
kind: SecretProviderClass
metadata:
  name: aks-ingress-contoso-com-tls-secret-csi-akv
  namespace: a0008
spec:
  provider: azure
  parameters:
    usePodIdentity: "true"
    keyvaultName: "${KEYVAULT_NAME}"
    objects:  |
      array:
        - |
          objectName: traefik-ingress-internal-aks-ingress-contoso-com-tls
          objectAlias: tls.crt
          objectType: cert
        - |
          objectName: traefik-ingress-internal-aks-ingress-contoso-com-tls
          objectAlias: tls.key
          objectType: secret
    tenantId: "${TENANT_ID}"
EOF

# Install Traefik ingress controller with Azure CSI Provider to obtain
# the TLS certificates as the in-cluster secret management solution.

kubectl apply -f https://raw.githubusercontent.com/mspnp/reference-architectures/master/aks/workload/traefik.yaml

# Wait for Traefik to be ready
# During the Traefik's pod creation time, aad-pod-identity will need to retrieve token for Azure KeyVault. This process can take time to complete and it's possible for the pod volume mount to fail during this time but the volume mount will eventually succeed. For more information, please refer to https://github.com/Azure/secrets-store-csi-driver-provider-azure/blob/master/docs/pod-identity-mode.md

kubectl wait --namespace a0008 --for=condition=ready pod --selector=app.kubernetes.io/name=traefik-ingress-ilb --timeout=90s
```

### The ASP.NET Core Docker sample web app

The Contoso app team is about to conclude this journey, but they need an app to test their new infrastructure. For this task they picked out the venerable [ASP.NET Core Docker sample web app](https://github.com/dotnet/dotnet-docker/tree/master/samples/aspnetapp). Additionally, they will include as part of the desired configuration for it some of the following concepts:

* Ingress resource object
* Network Policy to allow Ingress Controller establish connection with the app

```bash
kubectl apply -f https://raw.githubusercontent.com/mspnp/reference-architectures/master/aks/secure-baseline/workload/aspnetapp.yaml

# The ASP.NET Core Docker sample web app is all setup. Wait until is ready to process requests running:
kubectl wait --namespace a0008 --for=condition=ready pod --selector=app.kubernetes.io/name=aspnetapp --timeout=90s

# In this momment your Ingress Controller (Traefik) is reading your Ingress
# resource object configuration, updating its status and creating a router to
# fulfill the new exposed workloads route.
# Please take a look at this and notice that the Address is set with the Internal Load Balancer Ip from
# the configured subnet
kubectl get ingress aspnetapp-ingress -n a0008

# Validate the router to the workload is configured, SSL offloading and allowing only known Ips
# Please notice only the Azure Application Gateway is whitelisted as known client for
# the workload's router. Therefore, please expect a Http 403 response
# as a way to probe the router has been properly configured
kubectl -n a0008 run -i --rm --tty curl --image=curlimages/curl -- sh
curl --insecure -k -I --resolve bu0001a0008-00.aks-ingress.contoso.com:443:10.240.4.4 https://bu0001a0008-00.aks-ingress.contoso.com
exit 0
```

### Test the web app

The app team conducts a final acceptance test to be sure that traffic is flowing end-to-end as expected, so they place a request against the Azure Application Gateway endpoint.

```bash
# query the Azure Application Gateway Public Ip
export APPGW_PUBLIC_IP=$(az deployment group show --resource-group rg-enterprise-networking-spokes -n spoke-BU0001A0008 --query properties.outputs.appGwPublicIpAddress.value -o tsv)
```

1. Map the Azure Application Gateway public ip address to the application domain name. To do that, please open your hosts file (`C:\windows\system32\drivers\etc\hosts` or `/etc/hosts`) and add the following record in local host file:
`${APPGW_PUBLIC_IP} bicycle.contoso.com`

1. In your browser, go to <https://bicycle.contoso.com>. A TLS warning will be present, due to using a self-signed cert.

## Clean up

To delete all Azure resources associated with this reference implementation, you'll need to delete the three resource groups created. Also if any temporary changes were made to Azure AD or Azure RBAC permissions consider removing those as well.

```bash
az group delete -n rg-bu0001a0008 --yes
az group delete -n rg-enterprise-networking-spokes --yes
az group delete -n rg-enterprise-networking-hubs --yes

# Because this reference implementation enables soft delete, execute purge so your next
# test deployment of this implementation doesn't run into a naming conflict.
az keyvault purge --name ${KEYVAULT_NAME} --location eastus2 --yes
```

## GitHub Actions

For your reference, a [starter GitHub Actions pipeline](./GitHubAction/AKS-deploy.yml) has been built for your team to consider as part of your IaC solution.

## Deployment Alternatives

We have also provided some sample deployment scripts that you could adapt for your own purposes while doing a POC/spike on this.  Those scripts are found in the [deploy directory](./deploy). They include some additional considerations, and include some additional narrative as well. Consider checking them out.

## Next Steps

* [Azure Kubernetes Service Documentation](https://docs.microsoft.com/azure/aks/)
* [Microsoft Azure Well-Architected Framework](https://docs.microsoft.com/azure/architecture/framework/)
* [Microservices architecture on AKS](https://docs.microsoft.com/azure/architecture/reference-architectures/microservices/aks)

# Configure AKS Ingress Controller with Azure Key Vault integration

Previously you have configured [workload prerequisites](./07-workload-prerequisites.md). These steps configure Traefik, the AKS ingress solution used in this reference implementation, so that it can securely expose the web app to your Application Gateway.

## Steps

1. Get the AKS Ingress Controller Managed Identity details.

   ```bash
   export TRAEFIK_USER_ASSIGNED_IDENTITY_RESOURCE_ID=$(az deployment group show --resource-group rg-bu0001a0008 -n cluster-stamp --query properties.outputs.aksIngressControllerPodManagedIdentityResourceId.value -o tsv)
   export TRAEFIK_USER_ASSIGNED_IDENTITY_CLIENT_ID=$(az deployment group show --resource-group rg-bu0001a0008 -n cluster-stamp --query properties.outputs.aksIngressControllerPodManagedIdentityClientId.value -o tsv)
   ```

1. Ensure Flux has created the following namespace.

   ```bash
   # press Ctrl-C once you receive a successful response
   kubectl get ns a0008 -w
   ```

1. Create Traefik's Azure Managed Identity binding.

   > Create the Traefik Azure Identity and the Azure Identity Binding to let Azure Active Directory Pod Identity to get tokens on behalf of the Traefik's User Assigned Identity and later on assign them to the Traefik's pod.

   ```bash
   cat <<EOF | kubectl create -f -
   apiVersion: aadpodidentity.k8s.io/v1
   kind: AzureIdentity
   metadata:
     name: podmi-ingress-controller-identity
     namespace: a0008
   spec:
     type: 0
     resourceID: $TRAEFIK_USER_ASSIGNED_IDENTITY_RESOURCE_ID
     clientID: $TRAEFIK_USER_ASSIGNED_IDENTITY_CLIENT_ID
   ---
   apiVersion: aadpodidentity.k8s.io/v1
   kind: AzureIdentityBinding
   metadata:
     name: podmi-ingress-controller-binding
     namespace: a0008
   spec:
     azureIdentity: podmi-ingress-controller-identity
     selector: podmi-ingress-controller
   EOF
   ```

1. Create the Traefik's Secret Provider Class resource.

   > The Ingress Controller will be exposing the wildcard TLS certificate you created in a prior step. It uses the Azure Key Vault CSI Provider to mount the certificate which is managed and stored in Azure Key Vault. Once mounted, Traefik can use it.
   >
   > Create a `SecretProviderClass` resource with with your Azure Key Vault parameters for the [Azure Key Vault Provider for Secrets Store CSI driver](https://github.com/Azure/secrets-store-csi-driver-provider-azure).

   ```bash
   KEYVAULT_NAME=$(az deployment group show --resource-group rg-bu0001a0008 -n cluster-stamp --query properties.outputs.keyVaultName.value -o tsv)

   cat <<EOF | kubectl create -f -
   apiVersion: secrets-store.csi.x-k8s.io/v1alpha1
   kind: SecretProviderClass
   metadata:
     name: aks-ingress-contoso-com-tls-secret-csi-akv
     namespace: a0008
   spec:
     provider: azure
     parameters:
       usePodIdentity: "true"
       keyvaultName: $KEYVAULT_NAME
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
       tenantId: $TENANTID_AZURERBAC
   EOF
   ```

1. Import the Traefik container image to your container registry.

   > Public container registries are subject to faults such as outages (no SLA) or request throttling. Interruptions like these can be crippling for an application that needs to pull an image _right now_. To minimize the risks of using public registries, store all applicable container images in a registry that you control, such as the SLA-backed Azure Container Registry.

   ```bash
   # Get your ACR cluster name
   ACR_NAME=$(az deployment group show -g rg-bu0001a0008 -n cluster-stamp --query properties.outputs.containerRegistryName.value -o tsv)

   # Import ingress controller image hosted in public container registries
   az acr import --source docker.io/library/traefik:v2.4.8 -n $ACR_NAME
   ```

1. Install the Traefik Ingress Controller.

   > Install the Traefik Ingress Controller; it will use the mounted TLS certificate provided by the CSI driver, which is the in-cluster secret management solution.

   > If you used your own fork of this GitHub repo, update the one `image:` value in [`traefik.yaml`](./workload/traefik.yaml) to reference your container registry instead of the default public container registry and change the URL below to point to yours as well.

   :warning: Deploying the traefik `traefik.yaml` file unmodified from this repo will be deploying your workload to take dependencies on a public container registry. This is generally okay for learning/testing, but not suitable for production. Before going to production, ensure _all_ image references are from _your_ container registry or another that you feel confident relying on.

   ```bash
   kubectl create -f https://raw.githubusercontent.com/mspnp/aks-secure-baseline/main/workload/traefik.yaml
   ```

1. Wait for Traefik to be ready.

   > During Traefik's pod creation process, AAD Pod Identity will need to retrieve token for Azure Key Vault. This process can take time to complete and it's possible for the pod volume mount to fail during this time but the volume mount will eventually succeed. For more information, please refer to the [Pod Identity documentation](https://github.com/Azure/secrets-store-csi-driver-provider-azure/blob/master/docs/pod-identity-mode.md).

   ```bash
   kubectl wait -n a0008 --for=condition=ready pod --selector=app.kubernetes.io/name=traefik-ingress-ilb --timeout=90s
   ```

### Next step

:arrow_forward: [Deploy the Workload](./09-workload.md)

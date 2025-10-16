# Configure AKS ingress controller with Azure Key Vault integration

Previously you have configured [workload prerequisites](./08-workload-prerequisites.md). The following steps configure Traefik, the AKS ingress solution used in this reference implementation, so that it can securely expose the web app to your Application Gateway.

## Steps

1. Get the AKS Ingress Controller managed identity details.

   ```bash
   INGRESS_CONTROLLER_WORKLOAD_IDENTITY_CLIENT_ID=$(az deployment group show --resource-group rg-bu0001a0008 -n cluster-stamp --query properties.outputs.aksIngressControllerPodManagedIdentityClientId.value -o tsv)
   echo INGRESS_CONTROLLER_WORKLOAD_IDENTITY_CLIENT_ID: $INGRESS_CONTROLLER_WORKLOAD_IDENTITY_CLIENT_ID
   ```

1. Ensure your bootstrapping process has created the following namespace.

   ```bash
   # press Ctrl-C once you receive a successful response
   kubectl get ns a0008 -w
   ```

1. Create the ingress controller's Secret Provider Class resource.

   > The ingress controller will be exposing the wildcard TLS certificate you created in a prior step. It uses the Azure Key Vault CSI Provider to mount the certificate which is managed and stored in Azure Key Vault. Once mounted, Traefik can use it.
   >
   > Create a `SecretProviderClass` resource with your federated identity and Azure Key Vault parameters for the [Azure Key Vault Provider for Secrets Store CSI Driver](https://github.com/Azure/secrets-store-csi-driver-provider-azure).

   ```bash
   cat <<EOF | kubectl create -f -
   apiVersion: secrets-store.csi.x-k8s.io/v1
   kind: SecretProviderClass
   metadata:
     name: aks-ingress-tls-secret-csi-akv
     namespace: a0008
   spec:
     provider: azure
     parameters:
       clientID: $INGRESS_CONTROLLER_WORKLOAD_IDENTITY_CLIENT_ID
       usePodIdentity: "false"
       useVMManagedIdentity: "false"
       keyvaultName: $KEYVAULT_NAME_AKS_BASELINE
       objects:  |
         array:
           - |
             objectName: traefik-ingress-internal-aks-ingress-tls
             objectAlias: tls.crt
             objectType: cert
           - |
             objectName: traefik-ingress-internal-aks-ingress-tls
             objectAlias: tls.key
             objectType: secret
       tenantID: $TENANTID_AZURERBAC_AKS_BASELINE
   EOF
   ```

### Next step

:arrow_forward: [Deploy the Workload](./10-workload.md)

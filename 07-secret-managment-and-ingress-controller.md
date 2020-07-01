# Traefik Ingress Controller with Azure KeyVault CSI integration

Previously you have configured [all the Workload Prerequisites](./06-workload-prerequisites). Following this steps the AKS
cluter can expose its backend services outside the cluster.

---

1. Get the AKS Ingress Controller Managed Identity details

   ```bash
   export TRAEFIK_USER_ASSIGNED_IDENTITY_RESOURCE_ID=$(az deployment group show --resource-group rg-bu0001a0008 -n cluster-stamp --query properties.outputs.aksIngressControllerUserManageIdentityResourceId.value -o tsv)
   export TRAEFIK_USER_ASSIGNED_IDENTITY_CLIENT_ID=$(az deployment group show --resource-group rg-bu0001a0008 -n cluster-stamp --query properties.outputs.aksIngressControllerUserManageIdentityClientId.value -o tsv)
   ```
1. Ensure Flux has created the following namespace and then press Ctrl-C

   ```bash
   kubectl get ns a0008 -w
   ```

1. Create the Traefik's Azure Indentity
   > Create the Traefik Azure Identity and the Azure Identity Binding to let
   > Azure Active Directory Pod Identity to get tokens on behalf of the Traefik's User Assigned
   > Identity and later on assign them to the Traefik's pod

   ```bash
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
   ```

1. Create the Traefik's Secret Provider Class resource

   > Since the ingress controller will be exposing a TLS certificate, they use the Azure KeyVault CSI Provider to mount their TLS certificate managed and stored in Azure KeyVault so Traefik can use it.
   > Create a SecretProviderClass resource with with your Azure KeyVault parameters
   > for the [Azure Key Vault Provider for Secrets Store CSI driver](https://github.com/Azure/secrets-store-csi-driver-provider-azure).

   ```bash
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
   ```

1. Install Traefik ingress controller

   > The application is designed to be exposed outside of their AKS cluster. Therefore, an Ingress Controller must be deployed, and Traefik is the one selected to fulfill this assignment.
   > Install Traefik ingress controller, it will mount the the TLS certificates  with Volumes using the CSI driver as the in-cluster secret management solution.

   ```bash
   kubectl apply -f https://raw.githubusercontent.com/mspnp/reference-architectures/master/aks/workload/traefik.yaml
   ```

1. Wait for Traefik to be ready

   > During the Traefik's pod creation time, aad-pod-identity will need to retrieve token for Azure KeyVault. This process can take time to complete and it's possible for the pod volume mount to fail during this time but the volume mount will eventually succeed. For more information, please refer to https://github.com/Azure/secrets-store-csi-driver-provider-azure/blob/master/docs/pod-identity-mode.md

   ```bash
   kubectl wait --namespace a0008 --for=condition=ready pod --selector=app.kubernetes.io/name=traefik-ingress-ilb --timeout=90s
   ```

---
Next Step: [Workload](./08-workload.md)

# This script might take about 10 minutes

# Cluster Parameters.
# Copy from pre-cluster-stump.sh output
AKS_ENDUSER_NAME=
AKS_ENDUSER_PASSWORD=
CLUSTER_VNET_RESOURCE_ID=
RGNAMECLUSTER=
RGLOCATION=
k8sRbacAadProfileAdminGroupObjectID=
k8sRbacAadProfileTenantId=
RGNAMESPOKES=
tenant_guid=
main_subscription=

# Used for services that support native geo-redundancy (Azure Container Registry)
# Ideally should be the paired region of $RGLOCATION
GEOREDUNDANCY_LOCATION=centralus

APPGW_APP_URL=bicycle.contoso.com

az login
az account set -s $main_subscription

echo ""
echo "# Deploying AKS Cluster"
echo ""

# App Gateway Certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -out appgw.crt \
        -keyout appgw.key \
        -subj "/CN=bicycle.contoso.com/O=Contoso Bicycle"
openssl pkcs12 -export -out appgw.pfx -in appgw.crt -inkey appgw.key -passout pass:
APPGW_CERT_DATA=$(cat appgw.pfx | base64 -w 0)

#AKS Cluster Creation. Advance Networking. AAD identity integration. This might take about 10 minutes
az deployment group create --resource-group "${RGNAMECLUSTER}" --template-file "../../cluster-stamp.json" --name "cluster-0001" --parameters \
               location=$RGLOCATION \
               geoRedundancyLocation=$GEOREDUNDANCY_LOCATION \
               targetVnetResourceId=$CLUSTER_VNET_RESOURCE_ID \
               k8sRbacAadProfileAdminGroupObjectID=$k8sRbacAadProfileAdminGroupObjectID \
               k8sRbacAadProfileTenantId=$k8sRbacAadProfileTenantId \
               appGatewayListernerCertificate=$APPGW_CERT_DATA 

AKS_CLUSTER_NAME=$(az deployment group show -g $RGNAMECLUSTER -n cluster-0001 --query properties.outputs.aksClusterName.value -o tsv)
TRAEFIK_USER_ASSIGNED_IDENTITY_RESOURCE_ID=$(az deployment group show -g $RGNAMECLUSTER -n cluster-0001  --query properties.outputs.aksIngressControllerUserManageIdentityResourceId.value -o tsv)
TRAEFIK_USER_ASSIGNED_IDENTITY_CLIENT_ID=$(az deployment group show -g $RGNAMECLUSTER -n cluster-0001  --query properties.outputs.aksIngressControllerUserManageIdentityClientId.value -o tsv)
KEYVAULT_NAME=$(az deployment group show -g $RGNAMECLUSTER -n cluster-0001  --query properties.outputs.keyVaultName.value -o tsv) 
APPGW_PUBLIC_IP=$(az deployment group show -g $RGNAMESPOKES -n  spoke-0001 --query properties.outputs.appGwPublicIpAddress.value -o tsv)

az keyvault set-policy --certificate-permissions create get -n $KEYVAULT_NAME --upn $(az account show --query user.name -o tsv) 

cat <<EOF | az keyvault certificate create --vault-name $KEYVAULT_NAME -n traefik-ingress-internal-aks-ingress-contoso-com-tls -p @-
{
  "issuerParameters": {
    "certificateTransparency": null,
    "name": "Self"
  },
  "keyProperties": {
    "curve": null,
    "exportable": true,
    "keySize": 2048,
    "keyType": "RSA",
    "reuseKey": true
  },
  "lifetimeActions": [
    {
      "action": {
        "actionType": "AutoRenew"
      },
      "trigger": {
        "daysBeforeExpiry": 90
      }
    }
  ],
  "secretProperties": {
    "contentType": "application/x-pkcs12"
  },
  "x509CertificateProperties": {
    "keyUsage": [
      "cRLSign",
      "dataEncipherment",
      "digitalSignature",
      "keyEncipherment",
      "keyAgreement",
      "keyCertSign"
    ],
    "subject": "O=Contoso Aks Ingress, CN=*.aks-ingress.contoso.com",
    "validityInMonths": 12
  }
}
EOF

APP_GATEWAY_NAME=$(az deployment group show -g $RGNAMECLUSTER -n cluster-0001 --query properties.outputs.agwName.value -o tsv)
az network application-gateway root-cert create -g $RGNAMECLUSTER --gateway-name $APP_GATEWAY_NAME --name root-cert-wildcard-aks-ingress-contoso --keyvault-secret 'https://kv-aks-cunypcamxe7pa.vault.azure.net/secrets/sslcert/ce4b294428f243ac941fa78b1c0646cc'
az network application-gateway http-settings update -g $RGNAMECLUSTER --gateway-name $APP_GATEWAY_NAME -n aks-ingress-contoso-backendpool-httpsettings --root-certs root-cert-wildcard-aks-ingress-contoso --protocol Https --KeyVaultSecretId

echo ""
echo "# Creating AAD Groups and users for the created cluster"
echo ""

# We are going to use a the new tenant which manage the cluster identity
az login --allow-no-subscriptions -t $tenant_guid

#Creating AAD groups which will be associated to k8s out of the box cluster roles
k8sClusterAdminAadGroupName="k8s-cluster-admin-clusterrole-${AKS_CLUSTER_NAME}"
k8sClusterAdminAadGroup=$(az ad group create --display-name ${k8sClusterAdminAadGroupName} --mail-nickname ${k8sClusterAdminAadGroupName} --query objectId -o tsv)
k8sAdminAadGroupName="k8s-admin-clusterrole-${AKS_CLUSTER_NAME}"
k8sAdminAadGroup=$(az ad group create --display-name ${k8sAdminAadGroupName} --mail-nickname ${k8sAdminAadGroupName} --query objectId -o tsv)
k8sEditAadGroupName="k8s-edit-clusterrole-${AKS_CLUSTER_NAME}"
k8sEditAadGroup=$(az ad group create --display-name ${k8sEditAadGroupName} --mail-nickname ${k8sEditAadGroupName} --query objectId -o tsv)
k8sViewAadGroupName="k8s-view-clusterrole-${AKS_CLUSTER_NAME}"
k8sViewAadGroup=$(az ad group create --display-name ${k8sViewAadGroupName} --mail-nickname ${k8sViewAadGroupName} --query objectId -o tsv)

#EXAMPLE of an User in View Group
AKS_ENDUSR_OBJECTID=$(az ad user create --display-name $AKS_ENDUSER_NAME --user-principal-name $AKS_ENDUSER_NAME --password $AKS_ENDUSER_PASSWORD --query objectId -o tsv)
az ad group member add --group k8s-view-clusterrole --member-id $AKS_ENDUSR_OBJECTID

# Deploy application

az login
az account set -s  $main_subscription

az aks get-credentials -n ${AKS_CLUSTER_NAME} -g ${RGNAMECLUSTER} --admin
kubectl create namespace a0008
kubectl create namespace cluster-baseline-settings

kubectl apply -f ../../cluster-baseline-settings/flux.yaml
kubectl wait --namespace cluster-baseline-settings --for=condition=ready pod --selector=app.kubernetes.io/name=flux --timeout=90s

kubectl apply -f ../../cluster-baseline-settings/aad-pod-identity/aad-pod-identity.yaml
kubectl apply -f ../../cluster-baseline-settings/aad-pod-identity/exceptions/aad-pod-identity-exceptions.yaml


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

kubectl apply -f ../../cluster-baseline-settings/akv-secrets-store-csi.yaml

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
    tenantId: "${tenant_guid}"
EOF

kubectl apply -f ../../cluster-baseline-settings/ingress-network-policy.yaml
kubectl apply -f ../../cluster-baseline-settings/container-azm-ms-agentconfig.yaml
kubectl apply -f ../../cluster-baseline-settings/kured-1.4.0-dockerhub.yaml

kubectl apply -f ../../workload/traefik.yaml
kubectl apply -f ../../workload/aspnetapp.yaml

echo 'the ASPNET Core webapp sample is all setup. Wait until is ready to process requests running'
kubectl wait --namespace a0008 \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=aspnetapp \
  --timeout=90s
echo 'you must see the EXTERNAL-IP 10.240.4.4, please wait till it is ready. It takes a some minutes, then cntr+c'
kubectl get svc -n traefik --watch  -n a0008

rm appgw.crt appgw.key appgw.pfx
rm traefik-ingress-internal-aks-ingress-contoso-com-tls.crt traefik-ingress-internal-aks-ingress-contoso-com-tls.key traefik-ingress-internal-aks-ingress-contoso-com-tls.pem

cat << EOF

NEXT STEPS
---- -----

1) Map the Azure Application Gateway public ip address to the application domain names. To do that, please open your hosts file (C:\windows\system32\drivers\etc\hosts or /etc/hosts) and add the following record in local host file:
    ${APPGW_PUBLIC_IP} ${APPGW_APP_URL}

2) In your browser navigate the site anyway (A warning will be present)
 https://${APPGW_APP_URL}


# Temporary section. It is going to be deleted in the future. Testing k8sRBAC-AAD Groups

k8s-cluster-admin-clusterrole ${k8sClusterAdminAadGroup}
k8s-admin-clusterrole ${k8sAdminAadGroup}
k8s-edit-clusterrole ${k8sEditAadGroup}
k8s-view-clusterrole ${k8sViewAadGroup}
User Name:${AKS_ENDUSER_NAME} Pass:${AKS_ENDUSER_PASSWORD} objectId:${AKS_ENDUSR_OBJECTID}

Testing role after update yaml file (cluster-settings/user-facing-cluster-role-aad-group.yaml). Execute:

kubectl apply -f ../../cluster-settings/user-facing-cluster-role-aad-group.yaml
az aks get-credentials -n ${AKS_CLUSTER_NAME} -g ${RGNAMECLUSTER} --overwrite-existing
kubectl get all

->Kubernetes will ask you to login. You will need to use the ${AKS_ENDUSER_NAME} user

# Clean up resources. Execute:

deleteResourceGroups.sh

EOF


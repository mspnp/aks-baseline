#!/usr/bin/env bash
set -e

# This script might take about 10 minutes

# Cluster Parameters.
LOCATION=$1
RGNAMECLUSTER_BU0001A0042_03=$2
RGNAMECLUSTER_BU0001A0042_04=$3
RGNAMESPOKES=$4
TENANTID_AZURERBAC=$5
MAIN_SUBSCRIPTION=$6
TARGET_VNET_RESOURCE_ID_BU0001A0042_03=$7
TARGET_VNET_RESOURCE_ID_BU0001A0042_04=$8
K8S_RBAC_AAD_ADMIN_GROUP_OBJECTID=$9
K8S_RBAC_AAD_PROFILE_TENANTID=${10}
AKS_ENDUSER_NAME=${11}
AKS_ENDUSER_PASSWORD=${12}
RGNAME_FRONT_DOOR=${13}
CLUSTER_SUBDOMAIN1=${14}
CLUSTER_SUBDOMAIN2=${15}

# Used for services that support native geo-redundancy (Azure Container Registry)
# Ideally should be the paired region of $LOCATION
GEOREDUNDANCY_LOCATION=centralus

az login
az account set -s $MAIN_SUBSCRIPTION

echo ""
echo "# Deploying AKS Cluster"
echo ""

# App Gateway Certificate. These files should be provided in advance. 
# The App Gateway and Key Vault integration support only password-less certificates
# Front Door does not support self sign certificates.
APP_GATEWAY_LISTENER_CERTIFICATE3=$(cat ${CLUSTER_SUBDOMAIN1}.pfx | base64 | tr -d '\n')
APP_GATEWAY_LISTENER_CERTIFICATE4=$(cat ${CLUSTER_SUBDOMAIN2}.pfx | base64 | tr -d '\n')


# AKS Ingress Controller Certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -out traefik-ingress-internal-aks-ingress-contoso-com-tls.crt \
        -keyout traefik-ingress-internal-aks-ingress-contoso-com-tls.key \
        -subj "/CN=*.aks-ingress.contoso.com/O=Contoso Aks Ingress"
AKS_INGRESS_CONTROLLER_CERTIFICATE_BASE64=$(cat traefik-ingress-internal-aks-ingress-contoso-com-tls.crt | base64 | tr -d '\n')

# AKS Cluster Creation. Advance Networking. AAD identity integration. This might take about 10 minutes
# Note: By default, this deployment will allow unrestricted access to your cluster's API Server.
#   You should limit access to the API Server to a set of well-known IP addresses (i.,e. your hub firewall IP, bastion subnet, build agents, or any other networks you'll administer the cluster from),
#   and can do so by adding a `clusterAuthorizedIPRanges=['range1', 'range2', 'AzureFirewallIP/32']` parameter below.
az deployment group create -g "${RGNAMECLUSTER_BU0001A0042_03}" -f "../../cluster-stamp.json" -n "cluster-BU0001A0042_03" -p \
               location=$LOCATION \
               geoRedundancyLocation=$GEOREDUNDANCY_LOCATION \
               targetVnetResourceId=$TARGET_VNET_RESOURCE_ID_BU0001A0042_03 \
               clusterAdminAadGroupObjectId=$K8S_RBAC_AAD_ADMIN_GROUP_OBJECTID \
               k8sControlPlaneAuthorizationTenantId=$K8S_RBAC_AAD_PROFILE_TENANTID \
               appGatewayListenerCertificate=$APP_GATEWAY_LISTENER_CERTIFICATE3 \
               aksIngressControllerCertificate=$AKS_INGRESS_CONTROLLER_CERTIFICATE_BASE64 \
               appInstanceId="03" \
               clusterInternalLoadBalancerIpAddress="10.243.4.4" \
               subdomainName=${CLUSTER_SUBDOMAIN1}

AKS_CLUSTER_NAME_BU0001A0042_03=$(az deployment group show -g $RGNAMECLUSTER_BU0001A0042_03 -n cluster-BU0001A0042_03 --query properties.outputs.aksClusterName.value -o tsv)
TRAEFIK_USER_ASSIGNED_IDENTITY_RESOURCE_ID_BU0001A0042_03=$(az deployment group show -g $RGNAMECLUSTER_BU0001A0042_03 -n cluster-BU0001A0042_03  --query properties.outputs.aksIngressControllerPodManagedIdentityResourceId.value -o tsv)
TRAEFIK_USER_ASSIGNED_IDENTITY_CLIENT_ID_BU0001A0042_03=$(az deployment group show -g $RGNAMECLUSTER_BU0001A0042_03 -n cluster-BU0001A0042_03  --query properties.outputs.aksIngressControllerPodManagedIdentityClientId.value -o tsv)
KEYVAULT_NAME_BU0001A0042_03=$(az deployment group show -g $RGNAMECLUSTER_BU0001A0042_03 -n cluster-BU0001A0042_03  --query properties.outputs.keyVaultName.value -o tsv)
APPGW_FQDN_BU0001A0042_03=$(az deployment group show -g $RGNAMESPOKES -n  spoke-BU0001A0042-03 --query properties.outputs.appGwFqdn.value -o tsv)
ACR_NAME_BU0001A0042_03=$(az deployment group show --resource-group $RGNAMECLUSTER_BU0001A0042_03 -n cluster-BU0001A0042_03 --query properties.outputs.containerRegistryName.value -o tsv)
az acr import --source docker.io/library/traefik:2.2.1 -n $ACR_NAME_BU0001A0042_03

az deployment group create -g "${RGNAMECLUSTER_BU0001A0042_04}" -f "../../cluster-stamp.json" -n "cluster-BU0001A0042_04" -p \
               location=$LOCATION \
               geoRedundancyLocation=$GEOREDUNDANCY_LOCATION \
               targetVnetResourceId=$TARGET_VNET_RESOURCE_ID_BU0001A0042_04 \
               clusterAdminAadGroupObjectId=$K8S_RBAC_AAD_ADMIN_GROUP_OBJECTID \
               k8sControlPlaneAuthorizationTenantId=$K8S_RBAC_AAD_PROFILE_TENANTID \
               appGatewayListenerCertificate=$APP_GATEWAY_LISTENER_CERTIFICATE4 \
               aksIngressControllerCertificate=$AKS_INGRESS_CONTROLLER_CERTIFICATE_BASE64 \
               appInstanceId="04" \
               clusterInternalLoadBalancerIpAddress="10.244.4.4" \
               subdomainName=${CLUSTER_SUBDOMAIN2}

AKS_CLUSTER_NAME_BU0001A0042_04=$(az deployment group show -g $RGNAMECLUSTER_BU0001A0042_04 -n cluster-BU0001A0042_04 --query properties.outputs.aksClusterName.value -o tsv)
TRAEFIK_USER_ASSIGNED_IDENTITY_RESOURCE_ID_BU0001A0042_04=$(az deployment group show -g $RGNAMECLUSTER_BU0001A0042_04 -n cluster-BU0001A0042_04  --query properties.outputs.aksIngressControllerPodManagedIdentityResourceId.value -o tsv)
TRAEFIK_USER_ASSIGNED_IDENTITY_CLIENT_ID_BU0001A0042_04=$(az deployment group show -g $RGNAMECLUSTER_BU0001A0042_04 -n cluster-BU0001A0042_04  --query properties.outputs.aksIngressControllerPodManagedIdentityClientId.value -o tsv)
KEYVAULT_NAME_BU0001A0042_04=$(az deployment group show -g $RGNAMECLUSTER_BU0001A0042_04 -n cluster-BU0001A0042_04  --query properties.outputs.keyVaultName.value -o tsv)
APPGW_FQDN_BU0001A0042_04=$(az deployment group show -g $RGNAMESPOKES -n  spoke-BU0001A0042-04 --query properties.outputs.appGwFqdn.value -o tsv)
ACR_NAME_BU0001A0042_04=$(az deployment group show --resource-group $RGNAMECLUSTER_BU0001A0042_04 -n cluster-BU0001A0042_04 --query properties.outputs.containerRegistryName.value -o tsv)
az acr import --source docker.io/library/traefik:2.2.1 -n $ACR_NAME_BU0001A0042_04

az keyvault set-policy --certificate-permissions import get -n $KEYVAULT_NAME_BU0001A0042_03 --upn $(az account show --query user.name -o tsv)
az keyvault set-policy --certificate-permissions import get -n $KEYVAULT_NAME_BU0001A0042_04 --upn $(az account show --query user.name -o tsv)

cat traefik-ingress-internal-aks-ingress-contoso-com-tls.crt traefik-ingress-internal-aks-ingress-contoso-com-tls.key > traefik-ingress-internal-aks-ingress-contoso-com-tls.pem
az keyvault certificate import --vault-name $KEYVAULT_NAME_BU0001A0042_03 -f traefik-ingress-internal-aks-ingress-contoso-com-tls.pem -n traefik-ingress-internal-aks-ingress-contoso-com-tls
az keyvault certificate import --vault-name $KEYVAULT_NAME_BU0001A0042_04 -f traefik-ingress-internal-aks-ingress-contoso-com-tls.pem -n traefik-ingress-internal-aks-ingress-contoso-com-tls

az keyvault delete-policy --upn $(az account show --query user.name -o tsv) -n $KEYVAULT_NAME_BU0001A0042_03
az keyvault delete-policy --upn $(az account show --query user.name -o tsv) -n $KEYVAULT_NAME_BU0001A0042_04

#Cluster 03
az aks get-credentials -n ${AKS_CLUSTER_NAME_BU0001A0042_03} -g ${RGNAMECLUSTER_BU0001A0042_03} --admin
kubectl get constrainttemplate --context ${AKS_CLUSTER_NAME_BU0001A0042_03}-admin
kubectl create namespace cluster-baseline-settings --context ${AKS_CLUSTER_NAME_BU0001A0042_03}-admin
kubectl create -f ../../cluster-manifests/cluster-baseline-settings/flux.yaml --context ${AKS_CLUSTER_NAME_BU0001A0042_03}-admin
kubectl wait --namespace cluster-baseline-settings --for=condition=ready pod --selector=app.kubernetes.io/name=flux --timeout=90s --context ${AKS_CLUSTER_NAME_BU0001A0042_03}-admin

# Deploy application

# unset errexit as per https://github.com/mspnp/aks-secure-baseline/issues/69
set +e
echo $'Ensure Flux has created the following namespace and then press Ctrl-C'
kubectl get ns a0042 -w  --context ${AKS_CLUSTER_NAME_BU0001A0042_03}-admin


cat <<EOF | kubectl create --context ${AKS_CLUSTER_NAME_BU0001A0042_03}-admin -f -
apiVersion: "aadpodidentity.k8s.io/v1"
kind: AzureIdentity
metadata:
  name: podmi-ingress-controller-identity
  namespace: a0042
spec:
  type: 0
  resourceID: $TRAEFIK_USER_ASSIGNED_IDENTITY_RESOURCE_ID_BU0001A0042_03
  clientID: $TRAEFIK_USER_ASSIGNED_IDENTITY_CLIENT_ID_BU0001A0042_03
---
apiVersion: aadpodidentity.k8s.io/v1
kind: AzureIdentityBinding
metadata:
  name: podmi-ingress-controller-binding
  namespace: a0042
spec:
  azureIdentity: podmi-ingress-controller-identity
  selector: podmi-ingress-controller
EOF

cat <<EOF | kubectl create --context ${AKS_CLUSTER_NAME_BU0001A0042_03}-admin -f -
apiVersion: secrets-store.csi.x-k8s.io/v1alpha1
kind: SecretProviderClass
metadata:
  name: aks-ingress-contoso-com-tls-secret-csi-akv
  namespace: a0042
spec:
  provider: azure
  parameters:
    usePodIdentity: "true"
    keyvaultName: $KEYVAULT_NAME_BU0001A0042_03
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

kubectl create -f ../../workload/traefik-03.yaml --context ${AKS_CLUSTER_NAME_BU0001A0042_03}-admin
kubectl create -f ../../workload/aspnetapp.yaml --context ${AKS_CLUSTER_NAME_BU0001A0042_03}-admin

echo 'the ASPNET Core webapp sample is all setup. Wait until is ready to process requests running'
kubectl wait --namespace a0042 \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=aspnetapp \
  --timeout=90s \
  --context ${AKS_CLUSTER_NAME_BU0001A0042_03}-admin

echo 'you must see the EXTERNAL-IP 10.243.4.4, please wait till it is ready. It takes a some minutes, then cntr+c'
kubectl get svc -n traefik --watch  -n a0042 --context ${AKS_CLUSTER_NAME_BU0001A0042_03}-admin

#Cluster 04
az aks get-credentials -n ${AKS_CLUSTER_NAME_BU0001A0042_04} -g ${RGNAMECLUSTER_BU0001A0042_04} --admin
kubectl get constrainttemplate --context ${AKS_CLUSTER_NAME_BU0001A0042_04}-admin
kubectl create namespace cluster-baseline-settings --context ${AKS_CLUSTER_NAME_BU0001A0042_04}-admin
kubectl create -f ../../cluster-manifests/cluster-baseline-settings/flux.yaml --context ${AKS_CLUSTER_NAME_BU0001A0042_04}-admin
kubectl wait --namespace cluster-baseline-settings --for=condition=ready pod --selector=app.kubernetes.io/name=flux --timeout=90s --context ${AKS_CLUSTER_NAME_BU0001A0042_04}-admin

# Deploy application

# unset errexit as per https://github.com/mspnp/aks-secure-baseline/issues/69
set +e
echo $'Ensure Flux has created the following namespace and then press Ctrl-C'
kubectl get ns a0042 -w --context ${AKS_CLUSTER_NAME_BU0001A0042_04}-admin

cat <<EOF | kubectl create --context ${AKS_CLUSTER_NAME_BU0001A0042_04}-admin -f -
apiVersion: "aadpodidentity.k8s.io/v1"
kind: AzureIdentity
metadata:
  name: podmi-ingress-controller-identity
  namespace: a0042
spec:
  type: 0
  resourceID: $TRAEFIK_USER_ASSIGNED_IDENTITY_RESOURCE_ID_BU0001A0042_04
  clientID: $TRAEFIK_USER_ASSIGNED_IDENTITY_CLIENT_ID_BU0001A0042_04
---
apiVersion: aadpodidentity.k8s.io/v1
kind: AzureIdentityBinding
metadata:
  name: podmi-ingress-controller-binding
  namespace: a0042
spec:
  azureIdentity: podmi-ingress-controller-identity
  selector: podmi-ingress-controller
EOF

cat <<EOF | kubectl create --context ${AKS_CLUSTER_NAME_BU0001A0042_04}-admin -f -
apiVersion: secrets-store.csi.x-k8s.io/v1alpha1
kind: SecretProviderClass
metadata:
  name: aks-ingress-contoso-com-tls-secret-csi-akv
  namespace: a0042
spec:
  provider: azure
  parameters:
    usePodIdentity: "true"
    keyvaultName: $KEYVAULT_NAME_BU0001A0042_04
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

kubectl create -f ../../workload/traefik-04.yaml --context ${AKS_CLUSTER_NAME_BU0001A0042_04}-admin
kubectl create -f ../../workload/aspnetapp.yaml --context ${AKS_CLUSTER_NAME_BU0001A0042_04}-admin

echo 'the ASPNET Core webapp sample is all setup. Wait until is ready to process requests running'
kubectl wait --namespace a0042 \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=aspnetapp \
  --timeout=90s \
  --context ${AKS_CLUSTER_NAME_BU0001A0042_04}-admin

echo 'you must see the EXTERNAL-IP 10.244.4.4, please wait till it is ready. It takes a some minutes, then cntr+c'
kubectl get svc -n traefik --watch  -n a0042 --context ${AKS_CLUSTER_NAME_BU0001A0042_04}-admin

echo ""
echo "# Deploy Front Door"
echo ""
az group create --name ${RGNAME_FRONT_DOOR} --location ${LOCATION}
az deployment group  create --resource-group ${RGNAME_FRONT_DOOR} --template-file "../../frontdoor-stamp.json"  --name "fd-001" --parameters backendNames="['${APPGW_FQDN_BU0001A0042_03}','${APPGW_FQDN_BU0001A0042_04}']"

FRONTDOOR_FQDN=($(az deployment group show -g $RGNAME_FRONT_DOOR -n fd-001  --query properties.outputs.fqdn.value -o tsv))

echo ""
echo "# Creating AAD Groups and users for the created cluster"
echo ""

# We are going to use a the new tenant which manage the cluster identity
az login --allow-no-subscriptions -t $K8S_RBAC_AAD_PROFILE_TENANTID

#Creating AAD groups which will be associated to k8s out of the box cluster roles
k8sClusterAdminAadGroupName_BU0001A0042_03="k8s-cluster-admin-clusterrole-${AKS_CLUSTER_NAME_BU0001A0042_03}"
k8sClusterAdminAadGroup_BU0001A0042_03=$(az ad group create --display-name ${k8sClusterAdminAadGroupName_BU0001A0042_03} --mail-nickname ${k8sClusterAdminAadGroupName_BU0001A0042_03} --query objectId -o tsv)
k8sAdminAadGroupName_BU0001A0042_03="k8s-admin-clusterrole-${AKS_CLUSTER_NAME_BU0001A0042_03}"
k8sAdminAadGroup_BU0001A0042_03=$(az ad group create --display-name ${k8sAdminAadGroupName_BU0001A0042_03} --mail-nickname ${k8sAdminAadGroupName_BU0001A0042_03} --query objectId -o tsv)
k8sEditAadGroupName_BU0001A0042_03="k8s-edit-clusterrole-${AKS_CLUSTER_NAME_BU0001A0042_03}"
k8sEditAadGroup_BU0001A0042_03=$(az ad group create --display-name ${k8sEditAadGroupName_BU0001A0042_03} --mail-nickname ${k8sEditAadGroupName_BU0001A0042_03} --query objectId -o tsv)
k8sViewAadGroupName_BU0001A0042_03="k8s-view-clusterrole-${AKS_CLUSTER_NAME_BU0001A0042_03}"
k8sViewAadGroup_BU0001A0042_03=$(az ad group create --display-name ${k8sViewAadGroupName_BU0001A0042_03} --mail-nickname ${k8sViewAadGroupName_BU0001A0042_03} --query objectId -o tsv)

#EXAMPLE of an User in View Group
AKS_ENDUSR_OBJECTID=$(az ad user create --display-name $AKS_ENDUSER_NAME --user-principal-name $AKS_ENDUSER_NAME --force-change-password-next-login --password $AKS_ENDUSER_PASSWORD --query objectId -o tsv)
az ad group member add --group ${k8sViewAadGroupName_BU0001A0042_03} --member-id $AKS_ENDUSR_OBJECTID

#Creating AAD groups which will be associated to k8s out of the box cluster roles
k8sClusterAdminAadGroupName_BU0001A0042_04="k8s-cluster-admin-clusterrole-${AKS_CLUSTER_NAME_BU0001A0042_04}"
k8sClusterAdminAadGroup_BU0001A0042_04=$(az ad group create --display-name ${k8sClusterAdminAadGroupName_BU0001A0042_04} --mail-nickname ${k8sClusterAdminAadGroupName_BU0001A0042_04} --query objectId -o tsv)
k8sAdminAadGroupName_BU0001A0042_04="k8s-admin-clusterrole-${AKS_CLUSTER_NAME_BU0001A0042_04}"
k8sAdminAadGroup_BU0001A0042_04=$(az ad group create --display-name ${k8sAdminAadGroupName_BU0001A0042_04} --mail-nickname ${k8sAdminAadGroupName_BU0001A0042_04} --query objectId -o tsv)
k8sEditAadGroupName_BU0001A0042_04="k8s-edit-clusterrole-${AKS_CLUSTER_NAME_BU0001A0042_04}"
k8sEditAadGroup_BU0001A0042_04=$(az ad group create --display-name ${k8sEditAadGroupName_BU0001A0042_04} --mail-nickname ${k8sEditAadGroupName_BU0001A0042_04} --query objectId -o tsv)
k8sViewAadGroupName_BU0001A0042_04="k8s-view-clusterrole-${AKS_CLUSTER_NAME_BU0001A0042_04}"
k8sViewAadGroup_BU0001A0042_04=$(az ad group create --display-name ${k8sViewAadGroupName_BU0001A0042_04} --mail-nickname ${k8sViewAadGroupName_BU0001A0042_04} --query objectId -o tsv)

#EXAMPLE of an User in View Group
az ad group member add --group ${k8sViewAadGroup_BU0001A0042_04} --member-id $AKS_ENDUSR_OBJECTID

cat << EOF

NEXT STEPS
---- -----

1) In your browser navigate the site (front door endpoint)
https://${FRONTDOOR_FQDN}

# Clean up resources. Execute:

deleteResourceGroups.sh

EOF


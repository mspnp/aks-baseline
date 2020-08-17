## Create certificates

Seed a few values

```
export TENANT_ID=72f988bf-86f1-41af-91ab-2d7cd011db47
export K8S_RBAC_AAD_PROFILE_TENANTID=79467b11-2733-49a5-9736-ca6af9507c59
export K8S_RBAC_AAD_PROFILE_ADMIN_GROUP_OBJECTID=54066ee9-f552-4b41-869a-02dea1fb8263
export K8S_RBAC_AAD_PROFILE_TENANT_DOMAIN_NAME=nepeters.onmicrosoft.com

```

Create certificates, base64 encode, and store in environment variables

```
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -out appgw.crt -keyout appgw.key -subj "/CN=bicycle.contoso.com/O=Contoso Bicycle"
openssl pkcs12 -export -out appgw.pfx -in appgw.crt -inkey appgw.key -passout pass:
export APP_GATEWAY_LISTENER_CERTIFICATE=$(cat appgw.pfx | base64)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -out traefik-ingress-internal-aks-ingress-contoso-com-tls.crt -keyout traefik-ingress-internal-aks-ingress-contoso-com-tls.key -subj "/CN=*.aks-ingress.contoso.com/O=Contoso Aks Ingress"
export AKS_INGRESS_CONTROLLER_CERTIFICATE_BASE64=$(cat traefik-ingress-internal-aks-ingress-contoso-com-tls.crt | base64)
```

## Azure Active Directory Integration

Get tenant and AAD tenant IDs and store in environment variables.

```
export TENANT_ID=$(az account show --query tenantId --output tsv)
az login --tenant 79467b11-2733-49a5-9736-ca6af9507c59 --allow-no-subscriptions
export K8S_RBAC_AAD_PROFILE_TENANTID=$(az account show --query tenantId --output tsv)
```

Create cluster admin AAD group.

```
K8S_RBAC_AAD_PROFILE_ADMIN_GROUP_OBJECTID=$(az ad group create --display-name aad-to-bu0001a000800-cluster-admin --mail-nickname aad-to-bu0001a000800-cluster-admin --query objectId -o tsv)
```

Get current AAD FQDN, create an adming user, and store user object ID in an environment variable. Add AAD user to cluster admin group.

```
K8S_RBAC_AAD_PROFILE_TENANT_DOMAIN_NAME=$(az ad signed-in-user show --query 'userPrincipalName' | cut -d '@' -f 2 | sed 's/\"//')
AKS_ADMIN_OBJECTID=$(az ad user create --display-name=bu0001a0008-admin --user-principal-name bu0001a0008-admin@${K8S_RBAC_AAD_PROFILE_TENANT_DOMAIN_NAME} --force-change-password-next-login --password ChangeMebu0001a0008AdminChangeMe --query objectId -o tsv)
az ad group member add --group aad-to-bu0001a000800-cluster-admin --member-id $AKS_ADMIN_OBJECTID
```

## Create hub and spoke network typology

After logging back into proper tenant / subscription for cluster.

Create resource group for networking hubs and spokes (doc states that these would allready exsist).

```
az group create --name rg-enterprise-networking-hubs-014 --location eastus
az group create --name rg-enterprise-networking-spokes-014 --location eastus
az deployment group create --resource-group rg-enterprise-networking-hubs-014 --template-file networking/hub-default.json --parameters location=eastus
HUB_VNET_ID=$(az deployment group show -g rg-enterprise-networking-hubs-014 -n hub-default --query properties.outputs.hubVnetId.value -o tsv)
az deployment group create --resource-group rg-enterprise-networking-spokes-014 --template-file networking/spoke-BU0001A0008.json --parameters location=eastus hubVnetResourceId="${HUB_VNET_ID}"

# NOT NEEDED FOR DEMO, BUT DOCUMENTED, seems like it updates the hub template with the spoke
NODEPOOL_SUBNET_RESOURCEIDS=$(az deployment group show -g rg-enterprise-networking-spokes-014 -n spoke-BU0001A0008 --query properties.outputs.nodepoolSubnetResourceIds.value -o tsv)
az deployment group create --resource-group rg-enterprise-networking-hubs-014 --template-file networking/hub-regionA.json
```

## Create AKS cluster

```
az group create --name aks-014 --location eastus
TARGET_VNET_RESOURCE_ID=$(az deployment group show -g rg-enterprise-networking-spokes-014 -n spoke-BU0001A0008 --query properties.outputs.clusterVnetResourceId.value -o tsv)
az deployment group create --resource-group aks-014 --template-file cluster-stamp.json --parameters targetVnetResourceId=$TARGET_VNET_RESOURCE_ID k8sRbacAadProfileAdminGroupObjectID=$K8S_RBAC_AAD_PROFILE_ADMIN_GROUP_OBJECTID k8sRbacAadProfileTenantId=$K8S_RBAC_AAD_PROFILE_TENANTID appGatewayListenerCertificate=$APP_GATEWAY_LISTENER_CERTIFICATE aksIngressControllerCertificate=$AKS_INGRESS_CONTROLLER_CERTIFICATE_BASE64
```
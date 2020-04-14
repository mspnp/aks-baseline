# Source: https://docs.microsoft.com/en-us/azure/aks/azure-ad-integration-cli

aksName=cluster01
runDate=$(date +%S%N)
spName=${aksName}-sp-${runDate}
serverAppName=${aksName}-server-${runDate}
clientAppName=${aksName}-kubectl-${runDate}
tenant_guid=**Your tenant guid for identities**

#We are going to use a new tenant to provide identity
az login  --allow-no-subscriptions -t $tenant_guid

# Create the Azure AD application
k8sRbacAadProfileServerAppId=$(az ad app create --display-name "$serverAppName" --identifier-uris "https://${serverAppName}" --query appId -o tsv)

# Update the application group memebership claims
az ad app update --id $k8sRbacAadProfileServerAppId --set groupMembershipClaims=All

# Create a service principal for the Azure AD application
az ad sp create --id $k8sRbacAadProfileServerAppId

# Get the service principal secret
k8sRbacAadProfileServerAppSecret=$(az ad sp credential reset --name $k8sRbacAadProfileServerAppId  --credential-description "AKSClientSecret" --query password -o tsv)

az ad app permission add \
    --id $k8sRbacAadProfileServerAppId \
    --api 00000003-0000-0000-c000-000000000000 \
    --api-permissions e1fe6dd8-ba31-4d61-89e7-88639da4683d=Scope 06da0dbc-49e2-44d2-8312-53f166ab848a=Scope 7ab1d382-f21e-4acd-a863-ba3e13f7da61=Role
az ad app permission grant --id $k8sRbacAadProfileServerAppId --api 00000003-0000-0000-c000-000000000000
az ad app permission admin-consent --id  $k8sRbacAadProfileServerAppId

k8sRbacAadProfileClientAppId=$(az ad app create \
    --display-name "${clientAppName}" \
    --native-app \
    --reply-urls "https://${clientAppName}" \
    --query appId -o tsv)

az ad sp create --id $k8sRbacAadProfileClientAppId

oAuthPermissionId=$(az ad app show --id $k8sRbacAadProfileServerAppId --query "oauth2Permissions[0].id" -o tsv)
az ad app permission add --id $k8sRbacAadProfileClientAppId --api $k8sRbacAadProfileServerAppId --api-permissions ${oAuthPermissionId}=Scope
az ad app permission grant --id $k8sRbacAadProfileClientAppId --api $k8sRbacAadProfileServerAppId

k8sRbacAadProfileTennetId=$(az account show --query tenantId -o tsv)

# Outputs
echo "k8sRbacAadProfileServerAppId=${k8sRbacAadProfileServerAppId}"
echo "k8sRbacAadProfileClientAppId=${k8sRbacAadProfileClientAppId}"
echo "k8sRbacAadProfileServerAppSecret=${k8sRbacAadProfileServerAppSecret}"
echo "k8sRbacAadProfileTennetId=${k8sRbacAadProfileTennetId}"

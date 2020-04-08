# Source: https://docs.microsoft.com/en-us/azure/aks/azure-ad-integration-cli

aksName="cluster01"
runDate=$(date +%S%N)
spName=${aksName}-sp-${runDate}
serverAppName=${aksName}-server-${runDate}
clientAppName=${aksName}-kubectl-${runDate}

# First Identity is the Service Principal that AKS will use when
# managing Azure resources (those that cannot be managed via managed identity)
# Such things are monitoring, virtual nodes, azure policy
az ad sp create-for-rbac --skip-assignment --name ${spName}

# Next for interaction with the cluster itself, we need to create two
# additional identities.  One respresents the Cluster API, one represents
# kubectl (and other management clients)
serverApplicationId=$(az ad app create --display-name "$serverAppName" \
                                       --identifier-uris "https://${serverAppName}"
                                       --query appId \
                                       -o tsv)

# Update the application group membership claims to include
# all groups in the claim ticket  (note this could be a large number)
az ad app update --id $serverApplicationId --set groupMembershipClaims=All

# Get the SP secret (note: this expires in 1 year)
serverApplicationSecret=$(az ad sp credential reset --name "$serverApplicationId" \
                                                    --credential-description "AKSClientSecret" \
                                                    --query password \
                                                    -o tsv)

# Needs permissions to read directory data and sign in and read user profile
az ad app permission add --id $serverApplicationId \
                         --api 00000003-0000-0000-c000-000000000000 \
                         --api-permissions e1fe6dd8-ba31-4d61-89e7-88639da4683d=Scope

# 06da0dbc-49e2-44d2-8312-53f166ab848a=Scope 7ab1d382-f21e-4acd-a863-ba3e13f7da61=Role

#az ad app permission grant --id $serverApplicationId --api 00000003-0000-0000-c000-000000000000
# az ad app permissions admin-consent --id $serverApplicationId




# kubectl client app registration
# TODO: probably should make one Just for Azure Monitor Live -- as this here doesn't actually work.
clientApplicationId=$(az ad app create --display-name "${aksName}-Client" --reply-urls "https://${aksName}-Client https://afd.hosting.portal.azure.net/monitoring/Content/iframe/infrainsights.app/web/base-libs/auth/auth.html https://monitoring.hosting.portal.azure.net/monitoring/Content/iframe/infrainsights.app/web/base-libs/auth/auth.html" --query appId -o tsv)

# create a service principal for client application
az ad sp create --id $clientApplicationId

#get the oAuth Permission ID for the server app
oAuthPermissionId=$(az ad app show --id $serverApplicationId --query "oauth2Permissions[0].id" -o tsv)

# add permission
az ad app permission add --id $clientApplicationId --api $serverApplicationId --api-permissions "${oAuthPermissionId}=Scope"

# Do we need to?
# az ad app permission grant --id $clientApplicationId --api $serverApplicationId

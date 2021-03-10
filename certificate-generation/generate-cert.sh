LOCATION=$1
SUBDOMAIN=$2
FQDN=$3
IP_RESOURCE_ID=$4

RGNAME="rg-cert-let-encrypt-${LOCATION}"
echo $LOCATION
echo $RGNAME
echo $SUBDOMAIN
echo $FQDN
echo $IP_RESOURCE_ID

az group create --name ${RGNAME} --location ${LOCATION}

az deployment group create -g "${RGNAME}" --template-file "./certificate-generation/resources-stamp.json"  --name "cert-0001" --parameters location=$LOCATION subdomainName=$SUBDOMAIN ipResourceId=$IP_RESOURCE_ID

STORAGE_ACCOUNT_NAME=$(az deployment group show -g $RGNAME -n cert-0001 --query properties.outputs.storageAccountName.value -o tsv)
az storage container create --account-name $STORAGE_ACCOUNT_NAME --name verificationdata --auth-mode login --public-access container
STORAGE_CONNECTION_STRING=$(az storage account show-connection-string -g $RGNAME -n $STORAGE_ACCOUNT_NAME --query "connectionString")

echo Storage Account: $STORAGE_ACCOUNT_NAME
echo Storage Account - connectionString: $STORAGE_CONNECTION_STRING

echo Microsoft>test.txt

az storage blob upload \
 --connection-string $STORAGE_CONNECTION_STRING \
 --account-name $STORAGE_ACCOUNT_NAME \
 --container-name verificationdata \
 --name test.txt \
 --file ./test.txt \
 --auth-mode key

echo https://$STORAGE_ACCOUNT_NAME.blob.core.windows.net/verificationdata/test.txt
echo http://$FQDN/verificationdata/test.txt
echo http://$FQDN/.well-known/acme-challenge/test

sudo certbot certonly --manual --manual-auth-hook "./certificate-generation/authenticator.sh $STORAGE_ACCOUNT_NAME $STORAGE_CONNECTION_STRING" -d $FQDN

sudo cp /etc/letsencrypt/live/$FQDN/privkey.pem .
sudo cp /etc/letsencrypt/live/$FQDN/cert.pem .
sudo cp /etc/letsencrypt/live/$FQDN/chain.pem .
openssl pkcs12 -export -out $SUBDOMAIN.pfx -inkey privkey.pem -in cert.pem -certfile chain.pem -passout pass:

echo "Deleting resources"
az group delete -n $RGNAME --yes
rm test.txt
rm privkey.pem
rm cert.pem
rm chain.pem
echo "Check you have $SUBDOMAIN.pfx in the directory"
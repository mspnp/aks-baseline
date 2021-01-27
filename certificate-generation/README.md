//generate narrative

1- Log in in your account and select the subscription
MAIN_SUBSCRIPTION=XXXX
az login
az account set -s $MAIN_SUBSCRIPTION

2- Create the Azure resources

RGNAME=rg-certscript
LOCATION=eastus2
DOMAIN_NAME=myname

az group create --name "${RGNAME}" --location "${LOCATION}"
az deployment group create -g "${RGNAME}" --template-file "resources-stamp.json"  --name "cert-0001" --parameters location=$LOCATION domain_name=$DOMAIN_NAME
FQDN=$(az deployment group show -g $RGNAME -n cert-0001 --query properties.outputs.fqdn.value -o tsv)

3- Add a container and a file on azure blob
az storage container create --account-name $DOMAIN_NAME --name verificationdata --auth-mode login --public-access container

echo Microsoft>test.txt

az storage blob upload \
 --account-name $DOMAIN_NAME \
 --container-name verificationdata \
 --name test.txt \
 --file ./test.txt \
 --auth-mode key

4- Checking it is working

//the file is on the blob
echo https://$DOMAIN_NAME.blob.core.windows.net/verificationdata/test.txt
	
//the app gateway is serving the blob storage
echo http://$FQDN/verificationdata/test.txt

//the rewrite rule is working
echo http://$FQDN/.well-known/acme-challenge/test

5- Generate certificate base on Cerbot (https://certbot.eff.org/)
Certbot is a free, open source software tool for automatically using Let’s Encrypt certificates on manually-administrated websites to enable HTTPS.

--Install cerbot, if you don't have. These instruction are for linux but exist the windows option too
sudo apt-get install certbot

--execute command, administration privilege required
sudo certbot certonly --email your@mail.com -d $FQDN --agree-tos --manual

//follow instruction presenting by cerbot.
// create a file with that name and content
//upload de file , for example
az storage blob upload \
 --account-name $DOMAIN_NAME \
 --container-name verificationdata \
 --name yuV9ui3A1LEdSMpMmxhkapiKRctuL-C0RUp444QjDfs \
 --file ./yuV9ui3A1LEdSMpMmxhkapiKRctuL-C0RUp444QjDfs \
 --auth-mode key

//testing
http://myname.eastus2.cloudapp.azure.com/.well-known/acme-challenge/yuV9ui3A1LEdSMpMmxhkapiKRctuL-C0RUp444QjDfs

presse enter

you should see the message that the cert is already generated

6- Generate pfx needed

mkdir files
sudo cp /etc/letsencrypt/live/$FQDN/privkey.pem ./files
sudo cp /etc/letsencrypt/live/$FQDN/cert.pem ./files
sudo cp /etc/letsencrypt/live/$FQDN/chain.pem ./files
cd files

sudo openssl pkcs12 -export -out $DOMAIN_NAME.pfx -inkey privkey.pem -in cert.pem -certfile chain.pem
//add password

You will have your pfx on the directory

az group delete -n $RGNAME --yes

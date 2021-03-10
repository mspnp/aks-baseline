STORAGE_ACCOUNT_NAME=$1
STORAGE_CONNECTION_STRING=$2

echo $CERTBOT_VALIDATION>$CERTBOT_TOKEN.txt

az storage blob upload \
 --connection-string $STORAGE_CONNECTION_STRING \
 --account-name $STORAGE_ACCOUNT_NAME \
 --container-name verificationdata \
 --name $CERTBOT_TOKEN.txt \
 --file ./$CERTBOT_TOKEN.txt \
 --auth-mode key

rm $CERTBOT_TOKEN.txt
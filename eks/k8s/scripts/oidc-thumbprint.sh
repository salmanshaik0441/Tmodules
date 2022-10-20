THUMBPRINT=$(echo $(echo QUIT | openssl s_client -connect oidc.eks.${1}.amazonaws.com:443 2>&- | openssl x509 -fingerprint -noout | sed 's/://g' | awk -F= '{print tolower($2)}'))
#THUMBPRINT_JSON=$(jq -n --arg thumbprint "$(echo ${THUMBPRINT} | tr -d '\r')" '{"thumbprint":$thumbprint}')
#echo ${THUMBPRINT_JSON}
echo '{"thumbprint":"'${THUMBPRINT}'"}' | tr -d '\r'

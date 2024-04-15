#!/bin/bash
SCRIPT=`realpath "$0"`
SCRIPTPATH=`dirname "${SCRIPT}"`
SCRIPTNAME=`basename "${SCRIPT}"`

usage() {
   echo "Usage: $0 <Region Code>">&2
   exit 2
}

if [ "$#" -gt "2" -o "$#" -lt "1" ]; then
   usage
fi

# Required.
DEPLOY_REGION=$1

# Hidden parameter.  (Used when developing outside of CloudShell.)
if [ "$#" -eq "2" ]; then
   PROFILE=$2
else
   PROFILE="default"
fi

# Requires DEPLOY_REGION and (if running outside of CloudShell) PROFILE.
source ${SCRIPTPATH}/constants.sh

# Get the default VPC for this Region.
VPC_ID=`aws ec2 describe-vpcs --region ${DEPLOY_REGION} ${PROFILE_OPTION} --output json \
   --filters Name=is-default,Values=true | jq -r '.Vpcs[0].VpcId'`

# Get the VPC's default Security Group.
SG_ID=`aws ec2 describe-security-groups --region ${DEPLOY_REGION} ${PROFILE_OPTION} --output json \
   --filters Name=vpc-id,Values=${VPC_ID} Name=group-name,Values=default | jq -r '.SecurityGroups[0].GroupId'`

# Arbitrarily pick one of the VPC's available Subnets.
SUBNET_ID=`aws ec2 describe-subnets --region ${DEPLOY_REGION} ${PROFILE_OPTION} --output json \
   --filters Name=vpc-id,Values=${VPC_ID} | jq -r '.Subnets[0].SubnetId'`

# Record various configuration for the Region setup, and store it in S3.
cat <<EOF > config.json
{
   "VpcId": "${VPC_ID}",
   "VpcIsDefault": true,
   "SecurityGroupId": "${SG_ID}",
   "SubnetId": "${SUBNET_ID}",
   "ManualAcmCertificateUpload": true
}
EOF
aws s3 cp config.json ${S3_REGION_DIR_URI}/config.json \
   --region ${DEPLOY_REGION} ${PROFILE_OPTION} \
   --output json > /dev/null
rm config.json

# Generate the SSL certificates.
if [ -d "easy-rsa" ]; then
   cd easy-rsa
   git pull > /dev/null
   cd ..
else
   git clone https://github.com/OpenVPN/easy-rsa.git > /dev/null
fi
rm -rf pki
export EASYRSA_BATCH=1
./easy-rsa/easyrsa3/easyrsa init-pki > /dev/null
./easy-rsa/easyrsa3/easyrsa build-ca nopass --days ${MAX_SSL_CERT_DAYS} > /dev/null 2> /dev/null
./easy-rsa/easyrsa3/easyrsa --san=DNS:easy-aws-privacy-vpn.server build-server-full server.easy-aws-privacy-vpn \
   nopass --days ${MAX_SSL_CERT_DAYS} > /dev/null 2> /dev/null
./easy-rsa/easyrsa3/easyrsa build-client-full client.easy-aws-privacy-vpn nopass --days ${MAX_SSL_CERT_DAYS} > /dev/null 2> /dev/null
# Note: Unfortunately the SSL output get sent to stderr.  These commands aren't likely to produce actual errors
# though, so suppressing stderr shouldn't be a problem.

# Import the ACM Certificates manually, since there's doesn't seem to be a way to do it using CloudFormation...
# https://docs.aws.amazon.com/acm/latest/userguide/import-certificate-api-cli.html
ACM_SERVER_IMPORT_OUTPUT=`aws acm import-certificate \
   --certificate fileb://pki/issued/server.easy-aws-privacy-vpn.crt \
   --private-key fileb://pki/private/server.easy-aws-privacy-vpn.key \
   --certificate-chain fileb://pki/ca.crt \
   --tags "Key"="Name","Value"="Server - Easy AWS Privacy VPN" \
   --region ${DEPLOY_REGION} ${PROFILE_OPTION} --output json`
RESULT=$?
if [ $RESULT -ne 0 ]; then
   echo "ERROR: Import server certificate failed." >&2
   exit $RESULT
fi
ACM_SERVER_ARN=`echo ${ACM_SERVER_IMPORT_OUTPUT} | jq -r '.CertificateArn'`
ACM_CLIENT_IMPORT_OUTPUT=`aws acm import-certificate \
   --certificate fileb://pki/issued/client.easy-aws-privacy-vpn.crt \
   --private-key fileb://pki/private/client.easy-aws-privacy-vpn.key \
   --certificate-chain fileb://pki/ca.crt \
   --tags "Key"="Name","Value"="Client - Easy AWS Privacy VPN" \
   --region ${DEPLOY_REGION} ${PROFILE_OPTION} --output json`
RESULT=$?
if [ $RESULT -ne 0 ]; then
   echo "ERROR: Import client certificate failed." >&2
   exit $RESULT
fi
ACM_CLIENT_ARN=`echo ${ACM_CLIENT_IMPORT_OUTPUT} | jq -r '.CertificateArn'`

pushd ${SCRIPTPATH}/../CloudFormation/ > /dev/null
aws cloudformation create-stack --stack-name ${REGION_CONFIG_STACK_NAME} \
   --template-body "file://./PerRegion.yml" \
   --parameters \
      ParameterKey=ServerCertificateArn,ParameterValue="${ACM_SERVER_ARN}" \
      ParameterKey=ClientCertificateArn,ParameterValue="${ACM_CLIENT_ARN}" \
      ParameterKey=VpcId,ParameterValue="${VPC_ID}" \
      ParameterKey=SecurityGroupId,ParameterValue="${SG_ID}" \
   --region ${DEPLOY_REGION} ${PROFILE_OPTION} --output json > /dev/null
check_create_stack_status_and_wait $? ${REGION_CONFIG_STACK_NAME}
popd > /dev/null

CLIENT_VPN_ENDPOINT_ID=`aws cloudformation describe-stacks --stack-name ${REGION_CONFIG_STACK_NAME} \
   ${PROFILE_OPTION} --region ${DEPLOY_REGION} --output json \
   | jq -r '.Stacks[0].Outputs[] | select(.OutputKey=="ClientVpnEndpointId") | .OutputValue'`

S3_BUCKET_REGION=`aws s3api get-bucket-location --bucket ${S3_BUCKET_NAME} \
   ${PROFILE_OPTION} --region ${DEPLOY_REGION} --output json \
   | jq -r '.LocationConstraint'`

# Create the client backend scripts.
cp script_templates/eapv-REGION-aws-backend.sh ../eapv-${DEPLOY_REGION}-aws-backend.sh
cp script_templates/eapv-REGION-aws-backend.bat ../eapv-${DEPLOY_REGION}-aws-backend.bat
client_script_files=("../eapv-${DEPLOY_REGION}-aws-backend.sh" "../eapv-${DEPLOY_REGION}-aws-backend.bat")
for client_script_file in "${client_script_files[@]}" ; do
   sed -i.bak -e "s/SUB_DEPLOY_REGION/${DEPLOY_REGION}/g" "$client_script_file"
   sed -i.bak -e "s/SUB_VPC_ID/${VPC_ID}/g" "$client_script_file"
   sed -i.bak -e "s/SUB_SUBNET_ID/${SUBNET_ID}/g" "$client_script_file"
   sed -i.bak -e "s/SUB_CLIENT_VPN_ENDPOINT_ID/${CLIENT_VPN_ENDPOINT_ID}/g" "$client_script_file"
   sed -i.bak -e "s/SUB_CLIENT_PROFILE_NAME/${CLIENT_PROFILE_NAME}/g" "$client_script_file"
   sed -i.bak -e "s/SUB_REGION_ACTIVE_STACK_NAME/${REGION_ACTIVE_STACK_NAME}/g" "$client_script_file"
   sed -i.bak -e "s/SUB_S3_BUCKET_NAME/${S3_BUCKET_NAME}/g" "$client_script_file"
   sed -i.bak -e "s/SUB_S3_BUCKET_REGION/${S3_BUCKET_REGION}/g" "$client_script_file"
done
rm -f *.bak

# Create the OVPN configuration file.
aws ec2 export-client-vpn-client-configuration --client-vpn-endpoint-id ${CLIENT_VPN_ENDPOINT_ID} \
   ${PROFILE_OPTION} --region ${DEPLOY_REGION} \
   --output text > eapv-${DEPLOY_REGION}.ovpn
RESULT=$?
if [ $RESULT -ne 0 ]; then
   echo "ERROR: Export VPN client configuration failed." >&2
   exit $RESULT
fi
echo "" >> eapv-${DEPLOY_REGION}.ovpn
echo "<cert>" >> eapv-${DEPLOY_REGION}.ovpn
cat pki/issued/client.easy-aws-privacy-vpn.crt >> eapv-${DEPLOY_REGION}.ovpn
echo "</cert>" >> eapv-${DEPLOY_REGION}.ovpn
echo "" >> eapv-${DEPLOY_REGION}.ovpn
echo "<key>" >> eapv-${DEPLOY_REGION}.ovpn
cat pki/private/client.easy-aws-privacy-vpn.key >> eapv-${DEPLOY_REGION}.ovpn
echo "</key>" >> eapv-${DEPLOY_REGION}.ovpn

echo ""
echo "Success!  Download:"
echo "   - eapv-${DEPLOY_REGION}.ovpn"
echo "   - eapv-${DEPLOY_REGION}-aws-backend.sh (Mac/Linux) *or* eapv-${DEPLOY_REGION}-aws-backend.bat (Windows)"
echo ""

echo "Success!"

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

# Requires DEPLOY_REGION and PROFILE.
source ${SCRIPTPATH}/constants.sh

# Ensure there's no "Active" stack.  (Otherwise the main Region stack can't be deleted because the VPN Client Endpoint has a target subnet associated.)
aws cloudformation delete-stack --stack-name ${REGION_ACTIVE_STACK_NAME} --region ${DEPLOY_REGION} --profile ${PROFILE} --output json > /dev/null
RESULT=$?
if [ $RESULT -eq 0 ]; then
   # Wait for the delation to complete, otherwise the next deletion will fail.
   wait_stack_delete_complete ${REGION_ACTIVE_STACK_NAME}
fi

# Delete the Region configuration stack, and wait for it to complete.  (Otherwise the certs can't be deleted, because they're in use.)
aws cloudformation delete-stack --stack-name ${REGION_CONFIG_STACK_NAME} --region ${DEPLOY_REGION} --profile ${PROFILE} --output json > /dev/null
check_delete_stack_status_and_wait $? ${REGION_CONFIG_STACK_NAME}

# Remove the ACM certificates.
delete_acm_certificate_by_name server.easy-aws-privacy-vpn
delete_acm_certificate_by_name client.easy-aws-privacy-vpn

# Remove the S3 content.
aws s3 rm ${S3_REGION_DIR_URI}/config.json --region ${DEPLOY_REGION} --profile ${PROFILE} > /dev/null

echo "Success!"

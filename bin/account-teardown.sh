#!/bin/bash
SCRIPT=`realpath "$0"`
SCRIPTPATH=`dirname "${SCRIPT}"`
SCRIPTNAME=`basename "${SCRIPT}"`

# Hidden parameter #1.  (Used when developing outside of CloudShell.)
if [ "$#" -gt "0" ]; then
    DEPLOY_REGION=$1
else
    DEPLOY_REGION=${AWS_REGION}
fi

# Hidden parameter #2.  (Used when developing outside of CloudShell.)
if [ "$#" -eq "2" ]; then
    PROFILE=$2
else
    PROFILE="default"
fi

# Requires DEPLOY_REGION and PROFILE.
source ${SCRIPTPATH}/constants.sh

aws s3 rm ${S3_BUCKET_URI}/RegionVpnActivate.yml --region ${DEPLOY_REGION} --profile ${PROFILE} > /dev/null

aws cloudformation delete-stack --stack-name ${ACCOUNT_CONFIG_STACK_NAME} --output json --profile ${PROFILE} --region ${DEPLOY_REGION}
wait_stack_delete_complete ${ACCOUNT_CONFIG_STACK_NAME}

echo "Success!"

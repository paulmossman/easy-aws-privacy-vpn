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

pushd ${SCRIPTPATH}/../CloudFormation/ > /dev/null
aws cloudformation create-stack --stack-name ${ACCOUNT_CONFIG_STACK_NAME} \
    --template-body "file://./PerAccount.yml" \
    --capabilities CAPABILITY_NAMED_IAM \
    --profile ${PROFILE} --region ${DEPLOY_REGION} --output json > /dev/null
check_create_stack_status_and_wait $? ${ACCOUNT_CONFIG_STACK_NAME} ${REGION}

# Store the "Active" stack template in S3, so it doesn't need to be downloaded.
aws s3 cp RegionVpnActivate.yml ${S3_BUCKET_URI}/RegionVpnActivate.yml \
    --region ${DEPLOY_REGION} --profile ${PROFILE} \
    --output json > /dev/null

echo "Success!"

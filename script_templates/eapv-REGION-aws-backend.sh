#!/bin/bash

# This script is logically identical to the one with the same name, but different suffix.
# i.e. Keep the two in sync.

DEPLOY_REGION=SUB_DEPLOY_REGION
VPC_ID=SUB_VPC_ID
SUBNET_ID=SUB_SUBNET_ID
CLIENT_VPN_ENDPOINT_ID=SUB_CLIENT_VPN_ENDPOINT_ID
CLIENT_PROFILE_NAME=SUB_CLIENT_PROFILE_NAME
REGION_ACTIVE_STACK_NAME=SUB_REGION_ACTIVE_STACK_NAME
S3_BUCKET_NAME=SUB_S3_BUCKET_NAME
S3_BUCKET_REGION=SUB_S3_BUCKET_REGION

SCRIPT=`realpath "$0"`
SCRIPTPATH=`dirname "${SCRIPT}"`
SCRIPTNAME=`basename "${SCRIPT}"`

START_TIME=`date +%R`

# Ensure the AWS CLI is installed.
aws help > /dev/null 2>&1
RESULT=$?
if [ $RESULT -ne 0 ]; then
   echo "ERROR: You need to install the AWS CLI software first.  (If you already have, then close this terminal and open a new one.)" >&2
   exit $RESULT
fi

# Ensure the EAPV AWS profile exists.
aws configure list --profile ${CLIENT_PROFILE_NAME} > /dev/null 2>&1
RESULT=$?
if [ $RESULT -ne 0 ]; then
   echo "ERROR: You need to run \"aws configure --profile ${CLIENT_PROFILE_NAME}\" first." >&2
   exit $RESULT
fi

usage() {
   echo "Usage: ${SCRIPTNAME} <start|stop|status>">&2
   exit 2
}

# Display the status of the AWS backend.
status() {
   
   STATUS=`aws cloudformation describe-stacks --stack-name ${REGION_ACTIVE_STACK_NAME} \
      --profile ${CLIENT_PROFILE_NAME} --region ${DEPLOY_REGION} \
      --output json --query "Stacks[0].StackStatus" 2> /dev/null`
   if [ $? -ne 0 ]; then
      STATUS="Not running"
   fi
   echo Stack \'${REGION_ACTIVE_STACK_NAME}\' in Region ${DEPLOY_REGION} status: ${STATUS}
}

# Start the process of stopping the AWS backend, but don't wait for it to finish.
stop() {

   aws cloudformation delete-stack --stack-name ${REGION_ACTIVE_STACK_NAME} \
      --region ${DEPLOY_REGION} --profile ${CLIENT_PROFILE_NAME} --output json
   RESULT=$?
   if [ $RESULT -ne 0 ]; then
      echo "ERROR: Failed '${REGION_ACTIVE_STACK_NAME}' delete-stack, code=${RESULT}." >&2
      exit $RESULT
   fi
   echo ""
   echo "The AWS Backend is now stopping, but it will take some time."
   echo "You can monitor the status with '${SCRIPTNAME} status'."
   echo ""
}

# Start the process of stopping the AWS backend, and wait for it to finish.
stopwait() {

   stop

   echo Waiting...
   aws cloudformation wait stack-delete-complete --stack-name ${REGION_ACTIVE_STACK_NAME} \
      --profile ${CLIENT_PROFILE_NAME} --region ${DEPLOY_REGION} --output json
   WAIT_STATUS=$?
   if [ $WAIT_STATUS -ne 0 ]; then
      echo "ERROR: Failed '${REGION_ACTIVE_STACK_NAME}' stack wait stack-delete-complete" >&2
      exit $WAIT_STATUS
   fi
   echo "Stopped."
   echo ""
}

# Start the AWS backend, and wait for it to be ready.
start () {

   aws cloudformation create-stack --stack-name ${REGION_ACTIVE_STACK_NAME} \
      --template-url "https://${S3_BUCKET_NAME}.s3.${S3_BUCKET_REGION}.amazonaws.com/RegionVpnActivate.yml" \
      --parameters \
         ParameterKey=VpcId,ParameterValue="${VPC_ID}" \
         ParameterKey=SubnetId,ParameterValue="${SUBNET_ID}" \
         ParameterKey=ClientVpnEndpointId,ParameterValue="${CLIENT_VPN_ENDPOINT_ID}" \
      --region ${DEPLOY_REGION} --profile ${CLIENT_PROFILE_NAME} --output json  > /dev/null
   RESULT=$?
   if [ $RESULT -ne 0 ]; then
      echo "ERROR: Failed '${REGION_ACTIVE_STACK_NAME}' create-stack, code=${RESULT}." >&2
      exit $RESULT
   fi

   echo Waiting...
   aws cloudformation wait stack-create-complete --stack-name ${REGION_ACTIVE_STACK_NAME} --region ${DEPLOY_REGION} --profile ${CLIENT_PROFILE_NAME} --output json
   RESULT=$?
   if [ $RESULT -ne 0 ]; then
      echo "ERROR: Failed '${REGION_ACTIVE_STACK_NAME}' stack wait stack-create-complete" >&2
      exit $RESULT
   fi

   echo ""
   echo "Your Easy AWS Privacy VPN AWS backend in the ${DEPLOY_REGION} Region is ready to use!"
   echo "Remember to run './${SCRIPTNAME} stop' when you're done!"
   echo ""

   END_TIME=`date +%R`
   # echo "Start: ${START_TIME}"
   # echo "End  : ${END_TIME}"
}

# Parse the command-line parameter.
if [ "$#" -ne "1" ]; then
   usage
fi
if [[ "$1" = "start" ]]; then
   start
elif [[ "$1" = "stop" ]]; then
   stop
elif [[ "$1" = "status" ]]; then
   status
elif [[ "$1" = "stopwait" ]]; then
   # Hidden option.  (Used when developing outside of CloudShell.)
   stopwait
else
   # If no match...
   usage
fi

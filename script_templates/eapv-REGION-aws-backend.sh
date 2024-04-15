#!/bin/bash
SCRIPT=`realpath "$0"`
SCRIPTPATH=`dirname "${SCRIPT}"`
SCRIPTNAME=`basename "${SCRIPT}"`

DEPLOY_REGION=SUB_DEPLOY_REGION
VPC_ID=SUB_VPC_ID
SUBNET_ID=SUB_SUBNET_ID
CLIENT_VPN_ENDPOINT_ID=SUB_CLIENT_VPN_ENDPOINT_ID
CLIENT_PROFILE_NAME=SUB_CLIENT_PROFILE_NAME
REGION_ACTIVE_STACK_NAME=SUB_REGION_ACTIVE_STACK_NAME
S3_BUCKET_NAME=SUB_S3_BUCKET_NAME
S3_BUCKET_REGION=SUB_S3_BUCKET_REGION

START_DATE=`date`

usage() {
   echo "Usage: ${SCRIPTNAME} <start|stop|status>">&2
   exit 2
}

 help > /dev/null 2>&1
RESULT=$?
if [ $RESULT -ne 0 ]; then
   echo "ERROR: You need to install the AWS CLI software first.  (If you already have, then close this terminal and open a new one.)" >&2
   exit $RESULT
fi

# Ensure that the EAPV AWS profile exists!
aws configure list --profile ${CLIENT_PROFILE_NAME} > /dev/null 2>&1
RESULT=$?
if [ $RESULT -ne 0 ]; then
   echo "ERROR: You need to run \"aws configure --profile ${CLIENT_PROFILE_NAME}\" first." >&2
   exit $RESULT
fi

status() {
   
   OUTPUT=`aws cloudformation describe-stacks --stack-name ${REGION_ACTIVE_STACK_NAME} \
      --profile ${CLIENT_PROFILE_NAME} --region ${DEPLOY_REGION} \
      --output json 2> /dev/null`
   if [ $? -ne 0 ]; then
      STATUS="Not running"
   else
      STATUS=`echo ${OUTPUT} | jq -r ".Stacks[0].StackStatus"`
   fi

   echo -n "Stack '${REGION_ACTIVE_STACK_NAME}' status: "
   echo ${STATUS}
}

stop() {

   aws cloudformation delete-stack --stack-name ${REGION_ACTIVE_STACK_NAME} \
      --region ${DEPLOY_REGION} --profile ${CLIENT_PROFILE_NAME} --output json 
   RESULT=$?
   if [ $RESULT -ne 0 ]; then
      echo "ERROR: Failed '${REGION_ACTIVE_STACK_NAME}' delete-stack, code=${RESULT}." >&2
      exit $RESULT
   fi
}

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
   echo "Your Easy AWS Privacy VPN backend in the ${DEPLOY_REGION} Region is ready to use!"
   echo "Remember to run './${SCRIPTNAME} stop' when you're done!"
   echo ""

   END_DATE=`date`
   # echo "Start: ${START_DATE}"
   # echo "End  : ${END_DATE}"
}

# Parse the command-line parameter.
if [ "$#" -ne "1" ]; then
   usage
fi
if [[ "$1" = "start" ]]; then
   start
elif [[ "$1" = "stop" ]]; then
   stop
   echo "You can monitor the AWS Backend status with \"${SCRIPTNAME} status\"."
elif [[ "$1" = "status" ]]; then
   status
elif [[ "$1" = "stopwait" ]]; then
   # Hidden option.  (Used when developing outside of CloudShell.)
   stopwait
else
   usage
fi
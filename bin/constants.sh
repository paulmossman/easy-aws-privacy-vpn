# Exit if the profile isn't set up.
aws configure list-profiles | grep ${PROFILE} > /dev/null
RESULT=$?
if [ ${RESULT} != "0" ]; then
   echo "AWS Profile '${PROFILE}' is not set up.">&2 
   exit 1
fi

# Exit if the Region doesn't exist.
aws account get-region-opt-status --profile ${PROFILE} --region-name ${DEPLOY_REGION} --output json > /dev/null
RESULT=$?
if [ ${RESULT} != "0" ]; then
   exit ${RESULT}
fi

# Exit if the Region isn't enabled.
REGION_STATUS=`aws account get-region-opt-status --profile ${PROFILE} --region-name ${DEPLOY_REGION} --output json | jq -r '.RegionOptStatus'`
if [[ "$REGION_STATUS" != *ENABLED* ]]
then
   echo "You must enable this Region first.  (See "AWS Regions" at https://us-east-1.console.aws.amazon.com/billing/home#/account)">&2 
   exit 1
fi

export MAX_SSL_CERT_DAYS=825

export ACCOUNT_CONFIG_STACK_NAME=eapv-account-configuration
export REGION_CONFIG_STACK_NAME=eapv-region-configuration
export REGION_ACTIVE_STACK_NAME=eapv-region-active

# The name of the AWS Profile to be created on the client machine.
export CLIENT_PROFILE_NAME=easy-aws-privacy-vpn

export ACCOUNT_ID=`aws sts get-caller-identity --profile ${PROFILE} --region ${DEPLOY_REGION} --output json | jq -r ".Account"`

export S3_BUCKET_NAME="easy-aws-privacy-vpn-"${ACCOUNT_ID}
export S3_BUCKET_URI="s3://"${S3_BUCKET_NAME}
export S3_REGION_DIR_URI=${S3_BUCKET_URI}/${DEPLOY_REGION}

wait_stack_create_complete () {

    PARAM_STACK_NAME=$1

    echo Waiting...

    aws cloudformation wait stack-create-complete --stack-name ${PARAM_STACK_NAME} --profile ${PROFILE} --region ${DEPLOY_REGION} --output json
    WAIT_STATUS=$?
    if [ $WAIT_STATUS -ne 0 ]; then
        echo "ERROR: Failed '${PARAM_STACK_NAME}' wait" >&2
        exit $WAIT_STATUS
    fi

    aws cloudformation describe-stacks --stack-name ${PARAM_STACK_NAME} --profile ${PROFILE} --region ${DEPLOY_REGION} \
        --output json | jq -r ".Stacks[0].StackStatus"
}

check_create_stack_status_and_wait () {

    CREATE_STATUS=$1
    PARAM_STACK_NAME=$2

    if [ $CREATE_STATUS -ne 0 ]; then
        echo "ERROR: Failed to create stack '${PARAM_STACK_NAME}'" >&2
        exit $CREATE_STATUS
    fi

    wait_stack_create_complete ${PARAM_STACK_NAME}
}

check_delete_stack_status_and_wait () {

    DELETE_STATUS=$1
    PARAM_STACK_NAME=$2

    if [ $DELETE_STATUS -ne 0 ]; then
        echo "ERROR: Failed to delete stack '${PARAM_STACK_NAME}'" >&2
        exit $DELETE_STATUS
    fi

    wait_stack_delete_complete ${PARAM_STACK_NAME}
}

wait_stack_delete_complete () {

    PARAM_STACK_NAME=$1

    echo Waiting...

    aws cloudformation wait stack-delete-complete --stack-name ${PARAM_STACK_NAME} --profile ${PROFILE} --region ${DEPLOY_REGION} --output json
    WAIT_STATUS=$?
    if [ $WAIT_STATUS -ne 0 ]; then
        echo "ERROR: Failed '${PARAM_STACK_NAME}' wait" >&2
        exit $WAIT_STATUS
    fi
}

delete_acm_certificate_by_name () {

    CERT_NAME=$1

    CERT_ARN_OUTPUT=`aws acm list-certificates --query "CertificateSummaryList[?DomainName=='${CERT_NAME}'].CertificateArn" --region ${DEPLOY_REGION} --profile ${PROFILE} --output json`
    
    echo ${CERT_ARN_OUTPUT} | grep "\[\]" > /dev/null
    RESULT=$?
    if [[ "$RESULT" == "0" ]]; then
        echo "ERROR: Failed to find an ACM certificate named: ${CERT_NAME}" >&2
    else
        CERT_ARN=`echo ${CERT_ARN_OUTPUT} | jq -r '.[0]'`
        aws acm delete-certificate --certificate-arn ${CERT_ARN} --region ${DEPLOY_REGION}  --profile ${PROFILE} --output json
        RESULT=$?
        if [ ${RESULT} != "0" ]; then
            echo "ERROR: Failed to delete ACM certificate: ${CERT_ARN}" >&2
        fi
    fi
}

@echo off

set DEPLOY_REGION=SUB_DEPLOY_REGION
set VPC_ID=SUB_VPC_ID
set SUBNET_ID=SUB_SUBNET_ID
set CLIENT_VPN_ENDPOINT_ID=SUB_CLIENT_VPN_ENDPOINT_ID
set CLIENT_PROFILE_NAME=SUB_CLIENT_PROFILE_NAME
set REGION_ACTIVE_STACK_NAME=SUB_REGION_ACTIVE_STACK_NAME
set S3_BUCKET_NAME=SUB_S3_BUCKET_NAME
set S3_BUCKET_REGION=SUB_S3_BUCKET_REGION

if "%1" == "" goto usage
if NOT "%2" == "" goto usage

if "%1" == "start" goto start

if "%1" == "stop" goto stop

if "%1" == "status" goto status

:: If no match...
goto usage

:start

   aws cloudformation create-stack --stack-name %REGION_ACTIVE_STACK_NAME% ^
      --template-url "https://%S3_BUCKET_NAME%.s3.%S3_BUCKET_REGION%.amazonaws.com/RegionVpnActivate.yml" ^
      --parameters ^
         ParameterKey=VpcId,ParameterValue="%VPC_ID%" ^
         ParameterKey=SubnetId,ParameterValue="%SUBNET_ID%" ^
         ParameterKey=ClientVpnEndpointId,ParameterValue="%CLIENT_VPN_ENDPOINT_ID%" ^
      --region %DEPLOY_REGION% --profile %CLIENT_PROFILE_NAME% --output json  > nul
:: TODO: Check result

   echo Waiting...
   aws cloudformation wait stack-create-complete --stack-name %REGION_ACTIVE_STACK_NAME% ^
      --region %DEPLOY_REGION% --profile %CLIENT_PROFILE_NAME% --output json
:: TODO check result

   echo ""
   echo "Your Easy AWS Privacy VPN AWS backend in the %DEPLOY_REGION% Region is ready to use!"
   echo "Remember to run <script> stop' when you're done!"
   echo ""

:: Done start
exit /b


:stop

   aws cloudformation delete-stack --stack-name %REGION_ACTIVE_STACK_NAME% ^
      --region %DEPLOY_REGION% --profile %CLIENT_PROFILE_NAME% --output json
:: TODO check result

:: Done stop
exit /b


:status

   aws cloudformation describe-stacks --stack-name %REGION_ACTIVE_STACK_NAME% ^
      --profile %CLIENT_PROFILE_NAME% --region %DEPLOY_REGION% ^
      --output text 
:: TODO check result

:: Done status
exit /b


:usage
echo "Usage: %0 <start|stop|status>""
exit /b 1

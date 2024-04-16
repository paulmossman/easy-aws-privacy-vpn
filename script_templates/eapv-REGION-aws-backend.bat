@echo off

echo "Coming soon!"

set DEPLOY_REGION=SUB_DEPLOY_REGION
set VPC_ID=SUB_VPC_ID
set SUBNET_ID=SUB_SUBNET_ID
set CLIENT_VPN_ENDPOINT_ID=SUB_CLIENT_VPN_ENDPOINT_ID
set CLIENT_PROFILE_NAME=SUB_CLIENT_PROFILE_NAME
set REGION_ACTIVE_STACK_NAME=SUB_REGION_ACTIVE_STACK_NAME
set S3_BUCKET_NAME=SUB_S3_BUCKET_NAME
set S3_BUCKET_REGION=SUB_S3_BUCKET_REGION

echo VPC_ID: %VPC_ID%

if "%1" == "" goto usage
if "%2" != "" goto usage


:: TODO start



:: TODO stop



:: TODO status



:: TODO stopwait



:: Done
exit /b

:usage
echo "Usage: %0 <start|stop|status>""
exit /b 1

@echo off

:: This script is logically identical to the one with the same name, but different suffix.
:: i.e. Keep the two in sync.

set DEPLOY_REGION=SUB_DEPLOY_REGION
set VPC_ID=SUB_VPC_ID
set SUBNET_ID=SUB_SUBNET_ID
set CLIENT_VPN_ENDPOINT_ID=SUB_CLIENT_VPN_ENDPOINT_ID
set CLIENT_PROFILE_NAME=SUB_CLIENT_PROFILE_NAME
set REGION_ACTIVE_STACK_NAME=SUB_REGION_ACTIVE_STACK_NAME
set S3_BUCKET_NAME=SUB_S3_BUCKET_NAME
set S3_BUCKET_REGION=SUB_S3_BUCKET_REGION

set SCRIPTNAME=%0

set START_TIME=%TIME%

:: Ensure the AWS CLI is installed.
aws help > NUL 2> NUL
set RESULT=%ERRORLEVEL%
if %RESULT% NEQ 0 (
    echo ERROR: You need to install the AWS CLI software first.  If you already have, then close this terminal and open a new one. >&2
    exit /b %RESULT%
)

:: Ensure the EAPV AWS profile exists.
aws configure list --profile %CLIENT_PROFILE_NAME% > NUL 2> NUL
set RESULT=%ERRORLEVEL%
if %RESULT% NEQ 0 (
    echo ERROR: You need to run 'aws configure --profile %CLIENT_PROFILE_NAME%' first. >&2
    exit /b %RESULT%
)

:: Parse the command-line parameter.
if "%1" == "" (
    call :usage
    exit /b %ERRORLEVEL%
) else (
    if NOT "%2" == "" (
        call :usage
        exit /b %ERRORLEVEL%
    ) else (
        if "%1" == "start" (
            call :start
            exit /b %ERRORLEVEL%
        ) else (
            if "%1" == "stop" (
                call :stop
                exit /b %ERRORLEVEL%
            ) else (
                if "%1" == "status" (
                    call :status
                    exit /b %ERRORLEVEL%
                ) else (
                    if "%1" == "stopwait" (
                        :: Hidden option.  (Used when developing outside of CloudShell.)
                        call :stopwait
                        exit /b %ERRORLEVEL%
                    ) else (
                        :: If no match...
                        call :usage
                        exit /b %ERRORLEVEL%
                    )
                )
            )
        )
    )
)

:usage
    echo "Usage: %0 <start|stop|status>"
    exit /b 2

:: Display the status of the AWS backend.
:status
    :: First just see if the stack is running.
    aws cloudformation describe-stacks --stack-name %REGION_ACTIVE_STACK_NAME% ^
        --profile %CLIENT_PROFILE_NAME% --region %DEPLOY_REGION% ^
        --output text > NUL 2> NUL
    if %ERRORLEVEL% NEQ 0 (
        set STATUS="Not running"
    ) else (
        :: It's running, so this time capture the status.
        FOR /F "tokens=* USEBACKQ" %%F IN (`aws cloudformation describe-stacks --stack-name %REGION_ACTIVE_STACK_NAME% ^
            --profile %CLIENT_PROFILE_NAME% --region %DEPLOY_REGION% ^
            --output text --query "Stacks[0].StackStatus"`) DO (
        SET STATUS=%%F
        )
    )

    echo Stack '%REGION_ACTIVE_STACK_NAME%' in Region %DEPLOY_REGION% status: %STATUS%

    exit /b 0

:: Start the process of stopping the AWS backend, but don't wait for it to finish.
:stop

    aws cloudformation delete-stack --stack-name %REGION_ACTIVE_STACK_NAME% ^
        --region %DEPLOY_REGION% --profile %CLIENT_PROFILE_NAME% --output json
    set RESULT=%ERRORLEVEL%
    if %RESULT% NEQ 0 (
        echo ERROR: Failed '%REGION_ACTIVE_STACK_NAME%' delete-stack, code=%RESULT%. >&2
        exit /b %RESULT%
    )
    echo.
    echo The AWS Backend is now stopping, but it will take some time.
    echo You can monitor the status with '%SCRIPTNAME% status'.
    echo.

    exit /b 0

:: Start the process of stopping the AWS backend, and wait for it to finish.
:stopwait
    call :stop

    echo Waiting...
    aws cloudformation wait stack-delete-complete --stack-name %REGION_ACTIVE_STACK_NAME% ^
        --region %DEPLOY_REGION% --profile %CLIENT_PROFILE_NAME% --output json
    set RESULT=%ERRORLEVEL%
    if %RESULT% NEQ 0 (
        echo ERROR: Failed '%REGION_ACTIVE_STACK_NAME%' stack wait stack-delete-complete >&2
        exit /b %RESULT%
    )
    echo Stopped.
    echo.
    exit /b 0

:: Start the AWS backend, and wait for it to be ready.
:start
    aws cloudformation create-stack --stack-name %REGION_ACTIVE_STACK_NAME% ^
        --template-url "https://%S3_BUCKET_NAME%.s3.%S3_BUCKET_REGION%.amazonaws.com/RegionVpnActivate.yml" ^
        --parameters ^
            ParameterKey=VpcId,ParameterValue="%VPC_ID%" ^
            ParameterKey=SubnetId,ParameterValue="%SUBNET_ID%" ^
            ParameterKey=ClientVpnEndpointId,ParameterValue="%CLIENT_VPN_ENDPOINT_ID%" ^
        --region %DEPLOY_REGION% --profile %CLIENT_PROFILE_NAME% --output json  > nul
    set RESULT=%ERRORLEVEL%
    if %RESULT% NEQ 0 (
        echo ERROR: Failed '%REGION_ACTIVE_STACK_NAME%' create-stack, code=%RESULT%. >&2
        exit /b %RESULT%
    )
    
    echo Waiting...
    aws cloudformation wait stack-create-complete --stack-name %REGION_ACTIVE_STACK_NAME% ^
        --region %DEPLOY_REGION% --profile %CLIENT_PROFILE_NAME% --output json
    set RESULT=%ERRORLEVEL%
    if %RESULT% NEQ 0 (
        echo ERROR: Failed '%REGION_ACTIVE_STACK_NAME%' stack wait stack-create-complete >&2
        exit /b %RESULT%
    )

    echo.
    echo Your Easy AWS Privacy VPN AWS backend in the %DEPLOY_REGION% Region is ready to use!
    echo Remember to run '%SCRIPTNAME% stop' when you're done!
    echo.

    set END_TIME=%TIME%
    :: echo Start: %START_TIME%
    :: echo End  : %END_TIME%
    exit /b 0

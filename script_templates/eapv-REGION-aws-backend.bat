@echo off

echo "Coming soon!"

set VPC_ID=SUB_VPC_ID
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

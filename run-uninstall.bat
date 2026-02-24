@echo off
echo ============================================
echo   FG Sync - Uninstall Background Task
echo ============================================
echo.

:: List FG-Sync tasks
echo Looking for FG-Sync scheduled tasks...
echo.
schtasks /query /fo TABLE | findstr /i "FG-Sync"
echo.

if %ERRORLEVEL% NEQ 0 (
    echo No FG-Sync tasks found.
    echo.
    pause
    exit /b
)

set /p TASKNAME="Enter the task name to remove (copy from above): "

if "%TASKNAME%"=="" (
    echo No task name entered. Exiting.
    pause
    exit /b
)

echo.
echo Stopping task: %TASKNAME%
schtasks /end /tn "%TASKNAME%" >nul 2>&1

echo Removing task: %TASKNAME%
schtasks /delete /tn "%TASKNAME%" /f

if %ERRORLEVEL% EQU 0 (
    echo.
    echo Task removed successfully!
) else (
    echo.
    echo Failed to remove task. Try running this as Administrator.
)

echo.
pause

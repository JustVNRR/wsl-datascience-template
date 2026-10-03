@echo off
rem Stand-in for wsl.exe, for the lifecycle suites: every call goes into the
rem log FAKE_WSL_LOG names, and the answers are read back from it - a
rem distribution counts as running once a boot command has gone through. The
rem name it answers with comes from FAKE_WSL_INSTANCE; the suite sets both.
if not "%FAKE_WSL_LOG%"=="" echo %* >> "%FAKE_WSL_LOG%"

rem The tool builds its lists as "--list --quiet [--running]", and that branch
rem is all there is: everything else - a boot (--exec), a --terminate -
rem answers zero and changes nothing. Nothing here is real.
if /i "%1"=="--list" (
    if /i "%3"=="--running" (
        findstr /c:"--exec" "%FAKE_WSL_LOG%" >nul 2>&1
        if errorlevel 1 exit /b 0
    )
    if not "%FAKE_WSL_INSTANCE%"=="" echo %FAKE_WSL_INSTANCE%
)
exit /b 0

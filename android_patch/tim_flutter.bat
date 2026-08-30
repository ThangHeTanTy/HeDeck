@echo off
rem Tim Flutter va them vao PATH cua phien lam viec hien tai.
rem Cac script khac goi file nay truoc khi dung lenh flutter.
rem Dat FLUTTER_OK=1 neu tim thay.

set FLUTTER_OK=

where flutter >nul 2>nul
if not errorlevel 1 (
    set FLUTTER_OK=1
    goto :eof
)

rem Cac vi tri hay gap
for %%D in (
    "C:\flutter"
    "C:\src\flutter"
    "C:\tools\flutter"
    "D:\flutter"
    "D:\src\flutter"
    "%USERPROFILE%\flutter"
    "%USERPROFILE%\Documents\flutter"
    "%USERPROFILE%\Downloads\flutter"
    "%LOCALAPPDATA%\flutter"
    "%LOCALAPPDATA%\Pub\Cache\flutter"
) do (
    if exist "%%~D\bin\flutter.bat" (
        set "PATH=%%~D\bin;%PATH%"
        set FLUTTER_OK=1
        echo   Tim thay Flutter tai %%~D
        goto :eof
    )
)

rem Quet sau hon trong cac o dia, cham hon nen de sau cung
for %%R in (C D E) do (
    if exist "%%R:\" (
        for /f "delims=" %%F in ('dir /b /s "%%R:\flutter.bat" 2^>nul') do (
            echo %%F | find "\bin\flutter.bat" >nul && (
                for %%P in ("%%~dpF") do set "PATH=%%~P;%PATH%"
                set FLUTTER_OK=1
                echo   Tim thay Flutter tai %%~dpF
                goto :eof
            )
        )
    )
)

@echo off
:: ============================================================
:: NAVAJA-SUIZA - Lanzador automatico
:: Descarga y ejecuta el script como Administrador
:: ============================================================

:: Verificar si ya somos administrador
net session >nul 2>&1
if %errorLevel% == 0 goto :EJECUTAR

:: Si no somos admin, relanzar el bat como administrador (UAC)
echo Solicitando permisos de Administrador...
powershell -Command "Start-Process cmd -ArgumentList '/c \"%~f0\"' -Verb RunAs"
exit /b

:EJECUTAR
cls
echo ==========================================================
echo    NAVAJA-SUIZA - Descargando script...
echo ==========================================================
echo.

:: Descargar el script a una carpeta temporal
set "SCRIPT_URL=https://raw.githubusercontent.com/Ale-debug-29/NAVAJA-SUIZA/main/ScriptPrueba.ps1"
set "SCRIPT_PATH=%TEMP%\NavajaScript_%RANDOM%.ps1"

powershell -NoProfile -Command "Invoke-WebRequest -Uri '%SCRIPT_URL%' -OutFile '%SCRIPT_PATH%' -UseBasicParsing"

:: Comprobar que la descarga fue bien
if not exist "%SCRIPT_PATH%" (
    echo.
    echo  ERROR: No se pudo descargar el script.
    echo  Comprueba tu conexion a internet.
    echo.
    pause
    exit /b 1
)

:: Desbloquear el archivo (elimina la marca de "descargado de internet")
powershell -NoProfile -Command "Unblock-File -Path '%SCRIPT_PATH%'"

:: Ejecutar el script con Bypass para evitar problemas de ExecutionPolicy
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_PATH%"

:: Borrar el script temporal al salir
if exist "%SCRIPT_PATH%" del /f /q "%SCRIPT_PATH%"

exit /b

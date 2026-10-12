@echo off
cd /d "%~dp0"
echo === Henter SSB-tabeller ===
python extract\hent_ssb.py
if errorlevel 1 (echo FEIL i uttrekk & pause & exit /b 1)
echo.
echo Ferdig. Neste: 2_BYGG.bat
pause

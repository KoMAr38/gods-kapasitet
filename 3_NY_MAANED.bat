@echo off
cd /d "%~dp0"
set MND=%1
if "%MND%"=="" set MND=2026-07
echo === 1/4 Ny maaned: %MND% (bare endrede partisjoner skrives) ===
python src\generer_turer.py --til %MND%
if errorlevel 1 (echo FEIL i generator & pause & exit /b 1)
echo.
echo === 2/4 dbt run (inkrementell - bare fact_etappe og det som avhenger av den) ===
call dbt run --select fact_etappe+ dim_dato
if errorlevel 1 (echo FEIL i dbt run & pause & exit /b 1)
echo.
echo === 3/4 dbt test ===
call dbt test
echo.
echo === 4/4 Eksport (bare endrede partisjoner) ===
python src\eksport.py
if errorlevel 1 (echo FEIL i eksport & pause & exit /b 1)
echo.
echo Ferdig. Kjor 2_BYGG.bat for aa gaa tilbake til utgangspunktet.
pause

@echo off
cd /d "%~dp0"
echo === 1/5 Genererer Nordvare (2023-01 til 2026-06) ===
python src\generer_turer.py
if errorlevel 1 (echo FEIL i generator & pause & exit /b 1)
echo.
echo === 2/5 dbt seed ===
call dbt seed
if errorlevel 1 (echo FEIL i dbt seed & pause & exit /b 1)
echo.
echo === 3/5 dbt run --full-refresh ===
call dbt run --full-refresh
if errorlevel 1 (echo FEIL i dbt run & pause & exit /b 1)
echo.
echo === 4/5 dbt test  (forventet: PASS=62 WARN=1 ERROR=0) ===
call dbt test
echo.
echo === 5/5 Eksport til data\mart ===
python src\eksport.py
if errorlevel 1 (echo FEIL i eksport & pause & exit /b 1)
echo.
echo Ferdig.
pause

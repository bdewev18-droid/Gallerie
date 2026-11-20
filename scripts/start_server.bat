@echo off
title Lightroom Gallery & Drive Server
cd /d "%~dp0\.."
echo ========================================================
echo   Lightroom Gallery & Drive Explorer
echo ========================================================
echo.
echo Demarrage du serveur local sur http://localhost:8000 ...
echo Appuyez sur Ctrl+C pour arreter le serveur.
echo.
python -m uvicorn backend.main:app --host 0.0.0.0 --port 8000
pause

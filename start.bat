@echo off
chcp 65001 >nul
title Кинжал
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0server.ps1"

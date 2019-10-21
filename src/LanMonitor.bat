@echo off
cd /d "%~dp0"
title LanMonitor
chcp 1251 1>nul 2>nul
lanmonitor.exe "C:\lanminitor" >>LanMonitor.txt


@echo off
REM Tek tikla GitHub senkronu: degisiklikleri commit edip gonderir.
chcp 65001 >nul
cd /d "%~dp0"
set G="C:\Program Files\Git\cmd\git.exe"
%G% add -A
%G% commit -m "Guncelleme" 2>nul || echo Degisiklik yok ya da zaten kayitli.
%G% pull --rebase origin main || echo Cekme sirasinda sorun oldu, mesaja bakin.
%G% push origin main
echo.
echo ----------------------------------------
echo Bitti. GitHub Pages linkini telefonda yenileyin (Ctrl+F5 / sayfayi yenile).
echo ----------------------------------------
pause

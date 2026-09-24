@echo off
REM Blog sayfalarini gunceller: blog.html + blog/*.html
REM Kullanim: bu dosyaya cift tiklayin.
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0tools\gen_blog.ps1"
echo.
echo ----------------------------------------
echo Tamamlandi. blog.html tarayicida yenileyin (Ctrl+F5).
echo ----------------------------------------
pause

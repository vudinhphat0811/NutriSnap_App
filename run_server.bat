@echo off
chcp 65001 >nul
title NutriSnap AI Server Launcher
color 0A

echo =====================================================================
echo           🥗 NUTRISNAP AI SERVER - KHỞI ĐỘNG HỆ THỐNG
echo =====================================================================
echo.
echo  [LƯU Ý]: Hãy đảm bảo bạn đã mở LM Studio và bấm "Start Server"!
echo           (Model: qwen2.5-vl-3b-instruct tại cổng 1234)
echo.
echo  [1/2] Đang khởi động Backend .NET 8 trên cổng 5065...
start "NutriSnap .NET 8 Backend" cmd /k "dotnet run --project backend\NutriSnap\NutriSnap\NutriSnap.csproj --launch-profile http"

echo  Đợi Backend khởi tạo (4 giây)...
timeout /t 4 /nobreak >nul

echo  [2/2] Đang mở đường hầm Ngrok cố định...
start "NutriSnap Ngrok Tunnel" cmd /k ".\ngrok.exe http --url=entity-graded-lunar.ngrok-free.dev 5065"

echo.
echo =====================================================================
echo  ✅ TẤT CẢ ĐÃ KHỞI ĐỘNG XONG!
echo  🌐 Domain cố định của bạn: https://entity-graded-lunar.ngrok-free.dev
echo  📱 Mọi thiết bị (điện thoại 4G, máy ngoài) đã có thể gọi AI!
echo =====================================================================
echo.
pause

@echo off
chcp 65001 >nul
title NutriSnap AI Server Stopper
color 0C

echo =====================================================================
echo           🛑 NUTRISNAP AI SERVER - DỪNG HỆ THỐNG
echo =====================================================================
echo.
echo  Đang tắt tiến trình Ngrok Tunnel...
taskkill /F /IM ngrok.exe 2>nul

echo  Đang tắt tiến trình Backend .NET 8...
taskkill /F /IM NutriSnap.exe 2>nul
taskkill /F /FI "WINDOWTITLE eq NutriSnap*" 2>nul

echo.
echo =====================================================================
echo  ✅ ĐÃ TẮT SẠCH SẼ TẤT CẢ SERVER VÀ ĐƯỜNG HẦM NGROK!
echo  (Nhớ bấm "Stop Server" trên LM Studio để giải phóng VRAM card đồ họa)
echo =====================================================================
echo.
timeout /t 3 >nul

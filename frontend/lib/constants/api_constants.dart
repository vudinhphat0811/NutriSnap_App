import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConstants {
  // Địa chỉ IP của máy tính trong mạng Wi-Fi (đã tự động nhận diện: 192.168.1.16)
  static const String localHostIp = '192.168.1.16';

  // Đặt true nếu cắm cáp USB và đã chạy lệnh `adb reverse tcp:5065 tcp:5065`
  // Đặt false (mặc định) nếu điện thoại và máy tính kết nối chung mạng Wi-Fi
  static const bool useAdbReverse = false;

  // Cổng HTTP backend ASP.NET Core đang chạy
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5065';
    }
    if (Platform.isAndroid) {
      if (useAdbReverse) {
        return 'http://localhost:5065';
      }
      // Dành cho điện thoại thật kết nối chung mạng Wi-Fi (192.168.1.16:5065)
      return 'http://$localHostIp:5065';
    }
    return 'http://localhost:5065';
  }

  static String get login => '$baseUrl/api/auth/login';
  static String get register => '$baseUrl/api/auth/register';
  static String get forgotPassword => '$baseUrl/api/auth/forgot-password-otp';
  static String get resetPassword => '$baseUrl/api/auth/reset-password-otp';
  static String get profile => '$baseUrl/api/user/profile';
}
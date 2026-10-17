import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';

class ApiConstants {
  // Địa chỉ máy chủ Cloud Production (Render + Supabase PostgreSQL)
  static const String cloudBaseUrl = 'https://nutrisnap-app.onrender.com';

  // Đặt true để sử dụng máy chủ đám mây Render 24/7 (Khuyên dùng khi build APK)
  // Đặt false nếu muốn chạy thử nghiệm với backend cục bộ trên máy tính
  static const bool useCloudApi = true;

  // Địa chỉ IP của máy tính trong mạng Wi-Fi (cho trường hợp test local)
  static const String localHostIp = '192.168.1.16';

  // Đặt true nếu cắm cáp USB và đã chạy lệnh `adb reverse tcp:5065 tcp:5065`
  static const bool useAdbReverse = false;

  // URL API Backend chính thức của ứng dụng
  static String get baseUrl {
    if (useCloudApi) {
      return cloudBaseUrl;
    }
    if (kIsWeb) {
      return 'http://localhost:5065';
    }
    if (Platform.isAndroid) {
      if (useAdbReverse) {
        return 'http://localhost:5065';
      }
      return 'http://$localHostIp:5065';
    }
    return 'http://localhost:5065';
  }

  static String get login => '$baseUrl/api/auth/login';
  static String get register => '$baseUrl/api/auth/register';
  static String get forgotPassword => '$baseUrl/api/auth/forgot-password-otp';
  static String get resetPassword => '$baseUrl/api/auth/reset-password-otp';
  static String get profile => '$baseUrl/api/user/profile';

  // Cấu hình OAuth 2.0 Bên thứ ba (Google)
  // Web Client ID từ Google Cloud Console (nếu có dùng Web OAuth)
  static String googleServerClientId = '';

  /// Nạp các cấu hình OAuth được lưu trong SharedPreferences (nếu có)
  static Future<void> loadSocialConfigs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedGg = prefs.getString('custom_google_client_id');
      if (savedGg != null && savedGg.trim().isNotEmpty) {
        googleServerClientId = savedGg.trim();
      }
    } catch (_) {}
  }

  /// Lưu Google Web Client ID vào SharedPreferences
  static Future<void> saveGoogleClientId(String id) async {
    googleServerClientId = id.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('custom_google_client_id', googleServerClientId);
    } catch (_) {}
  }
}
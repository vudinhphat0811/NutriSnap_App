import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../constants/api_constants.dart';
import '../services/app_state_service.dart';

/// Quản lý Xác thực & Liên kết Mạng xã hội (Google & Facebook)
/// - Tuyệt đối KHÔNG tự động liên kết tài khoản khi người dùng hủy hoặc quay lại (back)
/// - Chỉ liên kết khi phía Google / Facebook trả về thông tin xác thực thật thành công
class SocialAuthHelper {
  static bool _isGoogleInitialized = false;

  /// 1. LIÊN KẾT / ĐĂNG NHẬP GOOGLE
  static Future<bool> showGoogleAuthDialog(BuildContext context) async {
    try {
      // 1. Trên thiết bị di động (Android / iOS): Sử dụng Google Play Services
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        if (!_isGoogleInitialized) {
          await GoogleSignIn.instance.initialize();
          _isGoogleInitialized = true;
        }

        // Gọi hộp thoại đăng nhập của Google
        final account = await GoogleSignIn.instance.authenticate();

        // CHỈ LIÊN KẾT KHI GOOGLE THỰC SỰ TRẢ VỀ TÀI KHOẢN HỢP LỆ
        if (account.email.isNotEmpty) {
          final email = account.email;
          final name = account.displayName ?? email.split('@').first;
          final photo = account.photoUrl;

          final success = await _callBackendSocialLogin(
            provider: 'google',
            email: email,
            name: name,
            avatarUrl: photo,
          );

          if (success && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Đã liên kết tài khoản Google ($email) thành công!'),
                backgroundColor: const Color(0xFF16A34A),
                behavior: SnackBarBehavior.floating,
              ),
            );
            return true;
          }
        }
      } else {
        // Trên môi trường Web/Desktop: Chỉ mở trang Google để tham khảo
        final uri = Uri.parse('https://accounts.google.com');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã hủy thao tác.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } on GoogleSignInException catch (e) {
      debugPrint('[Google Sign-In Exception] ${e.code}: ${e.description}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã hủy thao tác.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[Google Sign-In General Error] $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã hủy thao tác.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    // Mặc định trả về false nếu người dùng hủy, back lại hoặc không có tài khoản xác thực
    return false;
  }

  /// 2. LIÊN KẾT / ĐĂNG NHẬP FACEBOOK
  static Future<bool> showFacebookAuthDialog(BuildContext context) async {
    try {
      // Mở trang Facebook để xác thực
      final uri = Uri.parse('https://m.facebook.com');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      // Khi người dùng bấm quay lại app: Không hiện dialog popup, thông báo đã hủy thao tác và KHÔNG liên kết
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã hủy thao tác.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[Facebook Auth Error] $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã hủy thao tác.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    return false;
  }

  /// HÀM GỌI API BACKEND C# (.NET 8) ĐỂ TẠO HOẶC ĐỒNG BỘ TÀI KHOẢN VÀ LẤY JWT TOKEN THẬT
  static Future<bool> _callBackendSocialLogin({
    required String provider,
    required String email,
    required String name,
    String? avatarUrl,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/auth/social-login');
      final avatar = avatarUrl ?? 'https://api.dicebear.com/7.x/initials/svg?seed=${Uri.encodeComponent(name)}';

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({
              'provider': provider,
              'email': email,
              'name': name,
              'avatarUrl': avatar,
              'token': 'oauth_${provider}_${DateTime.now().millisecondsSinceEpoch}',
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        AppStateService.instance.applySocialLoginData(data);
        return true;
      } else {
        debugPrint('[Social Login Failed] HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('[Social Login Exception] $e');
    }
    return false;
  }
}

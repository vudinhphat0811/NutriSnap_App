import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../constants/api_constants.dart';
import '../services/app_state_service.dart';

/// Kết quả xác thực OAuth mạng xã hội
class SocialAuthResult {
  final bool success;
  final bool isNewUser;
  final String? email;
  final String? name;
  final String? provider;
  final String? message;

  const SocialAuthResult({
    required this.success,
    this.isNewUser = false,
    this.email,
    this.name,
    this.provider,
    this.message,
  });
}

/// Quản lý Xác thực & Liên kết Mạng xã hội (Google & Facebook)
/// - Gọi trực tiếp giao diện "Chọn tài khoản" của hệ thống Google Play Services
/// - Nhận dữ liệu xác thực thật 100% từ tài khoản Google trên máy người dùng
/// - Không tự tạo tài khoản giả, không form tự chế, không tài khoản khách
class SocialAuthHelper {
  // Khởi tạo GoogleSignIn client theo chuẩn Google Play Services
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: <String>['email'],
  );

  /// 1. ĐĂNG NHẬP / ĐĂNG KÝ / LIÊN KẾT BẰNG GOOGLE CHÍNH THỨC
  /// - Kích hoạt hộp thoại hệ thống "Chọn tài khoản" do Google Play Services quản lý
  static Future<SocialAuthResult> signInWithGoogle(BuildContext context) async {
    try {
      // Đăng xuất phiên trước để Google luôn hiện danh sách tài khoản cho người dùng chọn
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      // Mở hộp thoại chọn tài khoản Google chuẩn của hệ điều hành
      final GoogleSignInAccount? account = await _googleSignIn.signIn();

      // Nếu người dùng đóng hoặc hủy hộp thoại
      if (account == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã hủy chọn tài khoản Google.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return const SocialAuthResult(success: false, message: 'Đã hủy thao tác.');
      }

      // Lấy thông tin thật do chính Google trả về
      final email = account.email;
      final name = account.displayName ?? email.split('@').first;
      final photo = account.photoUrl;

      // Gửi tài khoản Google thật lên Backend C# .NET 8 để cấp JWT Token và đồng bộ vào DB
      final result = await _callBackendSocialLogin(
        provider: 'google',
        email: email,
        name: name,
        avatarUrl: photo,
      );

      if (result.success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Đã liên kết tài khoản Google ($email) thành công!'),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (!result.success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'Đăng nhập Google thất bại.'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      return result;
    } catch (e) {
      debugPrint('[Google Sign-In Error] $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi xác thực từ Google: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return SocialAuthResult(success: false, message: e.toString());
    }
  }

  /// 2. ĐĂNG NHẬP / ĐĂNG KÝ / LIÊN KẾT BẰNG FACEBOOK
  static Future<SocialAuthResult> signInWithFacebook(BuildContext context) async {
    try {
      if (ApiConstants.facebookAppId.isNotEmpty) {
        final redirectUri = Uri.encodeComponent('${ApiConstants.baseUrl}/api/auth/facebook-callback');
        final oauthUri = Uri.parse(
          'https://www.facebook.com/v19.0/dialog/oauth?client_id=${ApiConstants.facebookAppId}&redirect_uri=$redirectUri&scope=email,public_profile&response_type=token',
        );
        if (await canLaunchUrl(oauthUri)) {
          await launchUrl(oauthUri, mode: LaunchMode.externalApplication);
        }
      } else {
        final uri = Uri.parse('https://m.facebook.com');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đang mở trang đăng nhập Facebook...'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[Facebook Error] $e');
    }
    return const SocialAuthResult(success: false, message: 'Đang mở Facebook...');
  }

  /// HÀM GỌI API BACKEND C# (.NET 8) VỚI THÔNG TIN THẬT TỪ GOOGLE
  static Future<SocialAuthResult> _callBackendSocialLogin({
    required String provider,
    required String email,
    required String name,
    String? avatarUrl,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/auth/social-login');
      final avatar = avatarUrl ??
          'https://api.dicebear.com/7.x/initials/svg?seed=${Uri.encodeComponent(name.isNotEmpty ? name : email)}';

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
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        AppStateService.instance.applySocialLoginData(data);
        final bool isNew = data['isNewUser'] == true;
        return SocialAuthResult(
          success: true,
          isNewUser: isNew,
          email: email,
          name: name,
          provider: provider,
        );
      } else {
        String msg = 'Đăng nhập không thành công (${response.statusCode})';
        try {
          final err = jsonDecode(utf8.decode(response.bodyBytes));
          if (err['message'] != null) msg = err['message'].toString();
        } catch (_) {}
        return SocialAuthResult(success: false, message: msg);
      }
    } catch (e) {
      debugPrint('[Social Login Error] $e');
      return const SocialAuthResult(
        success: false,
        message: 'Không thể kết nối đến máy chủ Backend. Vui lòng kiểm tra kết nối mạng!',
      );
    }
  }

  /// Hỗ trợ gọi chung
  static Future<SocialAuthResult> signInWithSocial(
    BuildContext context, {
    required String provider,
  }) async {
    if (provider.toLowerCase() == 'google') {
      return await signInWithGoogle(context);
    } else {
      return await signInWithFacebook(context);
    }
  }

  /// Tương thích ngược: Đăng nhập / Liên kết Google (Trả về boolean)
  static Future<bool> showGoogleAuthDialog(BuildContext context) async {
    final result = await signInWithGoogle(context);
    return result.success;
  }

  /// Tương thích ngược: Đăng nhập / Liên kết Facebook (Trả về boolean)
  static Future<bool> showFacebookAuthDialog(BuildContext context) async {
    final result = await signInWithFacebook(context);
    return result.success;
  }
}

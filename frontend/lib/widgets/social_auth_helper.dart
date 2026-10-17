import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../constants/api_constants.dart';
import '../constants/app_colors.dart';
import '../services/app_state_service.dart';
import 'facebook_oauth_screen.dart';

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
/// - Mở WebView chính thức của Facebook để người dùng nhấn nút Xác nhận / Cấp quyền
/// - Không tự tạo tài khoản giả, không form tự chế, không tài khoản khách
class SocialAuthHelper {
  // Thông tin chữ ký APK và Package Name chuẩn của ứng dụng
  static const String appPackageName = 'com.example.flutter_application_1';
  static const String appDebugSha1 = '40:38:D1:57:31:7E:A4:92:4F:18:43:76:93:92:C5:2C:D1:2F:38:92';
  static const String appDebugSha256 = 'C8:8B:88:C7:4D:40:F9:06:30:4A:B2:C2:93:B0:8F:EA:30:A2:C6:87:CD:83:C4:4E:45:65:EE:33:7C:99:3C:2C';

  // Khởi tạo GoogleSignIn client theo chuẩn Google Play Services
  static GoogleSignIn _getGoogleSignIn() {
    return GoogleSignIn(
      scopes: <String>['email'],
      serverClientId: ApiConstants.googleServerClientId.isNotEmpty ? ApiConstants.googleServerClientId : null,
    );
  }

  /// =========================================================================
  /// 1. ĐĂNG NHẬP / ĐĂNG KÝ / LIÊN KẾT BẰNG GOOGLE CHÍNH THỨC
  /// =========================================================================
  static Future<SocialAuthResult> signInWithGoogle(BuildContext context) async {
    final googleSignIn = _getGoogleSignIn();

    try {
      // Đăng xuất phiên cũ để Google luôn hiện hộp thoại hệ thống cho người dùng chọn tài khoản
      try {
        await googleSignIn.signOut();
      } catch (_) {}

      // Mở hộp thoại chọn tài khoản Google chuẩn của hệ điều hành Android
      final GoogleSignInAccount? account = await googleSignIn.signIn();

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

      // Lấy thông tin thật do chính Google cấp
      final email = account.email;
      final name = account.displayName ?? email.split('@').first;
      final photo = account.photoUrl;

      // Gửi tài khoản Google thật lên Backend C# .NET 8 để cấp JWT Token và lưu DB
      final result = await _callBackendSocialLogin(
        provider: 'google',
        email: email,
        name: name,
        avatarUrl: photo,
      );

      if (result.success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Đã đăng nhập tài khoản Google ($email) thành công!'),
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
      final errorStr = e.toString().toLowerCase();

      // Kiểm tra lỗi 10 (DEVELOPER_ERROR) từ Google Play Services
      final bool isDevError10 = errorStr.contains(' 10:') ||
          errorStr.contains('code: 10') ||
          errorStr.contains('developer_error') ||
          (errorStr.contains('sign_in_failed') && errorStr.contains('10'));

      if (isDevError10 && context.mounted) {
        await _showGoogleDevErrorDialog(context);
        return const SocialAuthResult(
          success: false,
          message: 'Mã lỗi 10: Cần thêm chữ ký SHA-1 của APK vào Google Cloud Console.',
        );
      }

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

  /// =========================================================================
  /// 2. ĐĂNG NHẬP / ĐĂNG KÝ / LIÊN KẾT BẰNG FACEBOOK CHÍNH THỨC (IN-APP WEBVIEW)
  /// =========================================================================
  static Future<SocialAuthResult> signInWithFacebook(BuildContext context) async {
    try {
      // 1. Nếu chưa có Meta App ID, hiển thị dialog hướng dẫn & nhập ID
      if (ApiConstants.facebookAppId.isEmpty) {
        final bool shouldProceed = await _showFacebookConfigDialog(context);
        if (!shouldProceed || ApiConstants.facebookAppId.isEmpty) {
          return const SocialAuthResult(
            success: false,
            message: 'Cần nhập Facebook App ID để tiến hành đăng nhập.',
          );
        }
      }

      if (!context.mounted) {
        return const SocialAuthResult(success: false, message: 'Đã hủy thao tác.');
      }

      // 2. Mở WebView đăng nhập Facebook chính thức có màn hình xác nhận / cấp quyền
      final FacebookAuthResponse? response = await Navigator.of(context).push<FacebookAuthResponse>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => FacebookOAuthScreen(appId: ApiConstants.facebookAppId),
        ),
      );

      // Nếu người dùng đóng hoặc hủy
      if (response == null || !response.success) {
        final msg = response?.message ?? 'Đã hủy đăng nhập Facebook.';
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return SocialAuthResult(success: false, message: msg);
      }

      // 3. Người dùng đã bấm "Xác nhận / Tiếp tục" trên Facebook thành công!
      // Gửi thông tin thật từ Facebook lên Backend C# .NET 8 để cấp JWT Token
      final result = await _callBackendSocialLogin(
        provider: 'facebook',
        email: response.email!,
        name: response.name!,
        avatarUrl: response.avatarUrl,
      );

      if (result.success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Đã đăng nhập tài khoản Facebook (${response.name}) thành công!'),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (!result.success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'Đăng nhập Facebook thất bại.'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      return result;
    } catch (e) {
      debugPrint('[Facebook Error] $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi đăng nhập Facebook: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return SocialAuthResult(success: false, message: e.toString());
    }
  }

  /// =========================================================================
  /// HỘP THOẠI HƯỚNG DẪN GIẢI QUYẾT LỖI GOOGLE CODE 10 (DEVELOPER_ERROR)
  /// =========================================================================
  static Future<void> _showGoogleDevErrorDialog(BuildContext context) async {
    final serverIdController = TextEditingController(text: ApiConstants.googleServerClientId);

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cần Cấu Hình Google Cloud',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Mã lỗi hệ thống: 10 (DEVELOPER_ERROR)',
                        style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thông báo giải thích nguyên nhân
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Text(
                      'Google Play Services từ chối cấp token vì chữ ký SHA-1 của file APK chưa được khai báo trong Google Cloud Console của dự án.',
                      style: TextStyle(fontSize: 11.5, height: 1.4, color: Color(0xFF92400E)),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text(
                    'THÔNG TIN CẦN KHAI BÁO:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textGray),
                  ),
                  const SizedBox(height: 8),

                  // Box 1: Package Name
                  _buildCopyField(
                    context,
                    label: 'Tên gói (Package Name)',
                    value: appPackageName,
                  ),
                  const SizedBox(height: 8),

                  // Box 2: SHA-1
                  _buildCopyField(
                    context,
                    label: 'Mã vân tay chứng chỉ (SHA-1)',
                    value: appDebugSha1,
                  ),
                  const SizedBox(height: 12),

                  // Nút sao chép toàn bộ
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        const fullInfo = 'Package Name: $appPackageName\nSHA-1: $appDebugSha1\nSHA-256: $appDebugSha256';
                        Clipboard.setData(ClipboardData(text: fullInfo));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Đã sao chép Package Name & SHA-1 vào bộ nhớ tạm!'),
                            backgroundColor: Color(0xFF16A34A),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Sao Chép Toàn Bộ (Package + SHA-1)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Hướng dẫn 3 bước
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('👉 3 Bước Kích Hoạt Trong 1 Phút:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
                        SizedBox(height: 6),
                        Text('1. Truy cập console.cloud.google.com/apis/credentials', style: TextStyle(fontSize: 11, color: Color(0xFF334155))),
                        SizedBox(height: 4),
                        Text('2. Bấm "Create Credentials" -> Chọn "OAuth client ID" -> Loại "Android"', style: TextStyle(fontSize: 11, color: Color(0xFF334155))),
                        SizedBox(height: 4),
                        Text('3. Dán Package Name và SHA-1 ở trên vào rồi bấm Create.', style: TextStyle(fontSize: 11, color: Color(0xFF334155))),
                        SizedBox(height: 6),
                        Text('✨ Sau khi lưu, bấm lại nút Đăng nhập Google là được ngay, KHÔNG CẦN build lại APK!', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Tùy chọn: Web Client ID
                  TextField(
                    controller: serverIdController,
                    decoration: InputDecoration(
                      labelText: 'Web Client ID (serverClientId - Tùy chọn)',
                      labelStyle: const TextStyle(fontSize: 11),
                      hintText: 'Nhập Web Client ID nếu có',
                      hintStyle: const TextStyle(fontSize: 11),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  final uri = Uri.parse('https://console.cloud.google.com/apis/credentials');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: const Text('Mở Google Cloud Console', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newServerId = serverIdController.text.trim();
                  if (newServerId != ApiConstants.googleServerClientId) {
                    await ApiConstants.saveGoogleClientId(newServerId);
                  }
                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Đã Hiểu & Đóng', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  /// =========================================================================
  /// HỘP THOẠI CẤU HÌNH FACEBOOK APP ID
  /// =========================================================================
  static Future<bool> _showFacebookConfigDialog(BuildContext context) async {
    final appIdController = TextEditingController(text: ApiConstants.facebookAppId);
    bool confirmed = false;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.facebook, color: Color(0xFF1877F2), size: 26),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cấu Hình Facebook Login',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Yêu cầu Meta App ID để hiện màn hình xác nhận',
                    style: TextStyle(fontSize: 11, color: AppColors.textGray),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F7FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Text(
                  'Facebook OAuth 2.0 bắt buộc phải có App ID để hiển thị giao diện Xác nhận ([Tiếp tục dưới tên bạn]) và cấp quyền truy cập vào NutriSnap.',
                  style: TextStyle(fontSize: 11.5, height: 1.4, color: Color(0xFF1E40AF)),
                ),
              ),
              const SizedBox(height: 14),

              const Text(
                'NHẬP FACEBOOK APP ID:',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textGray),
              ),
              const SizedBox(height: 6),

              TextField(
                controller: appIdController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Ví dụ: 104829182371928',
                  prefixIcon: const Icon(Icons.vpn_key_rounded, size: 20, color: Color(0xFF1877F2)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),

              // Hướng dẫn lấy App ID
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('👉 Cách lấy Facebook App ID (Miễn phí):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
                    SizedBox(height: 6),
                    Text('1. Truy cập developers.facebook.com/apps', style: TextStyle(fontSize: 11, color: Color(0xFF334155))),
                    SizedBox(height: 4),
                    Text('2. Tạo ứng dụng mới -> Chọn loại "Consumer / Xác thực"', style: TextStyle(fontSize: 11, color: Color(0xFF334155))),
                    SizedBox(height: 4),
                    Text('3. Bật sản phẩm "Facebook Login" -> Sao chép App ID dán vào ô trên.', style: TextStyle(fontSize: 11, color: Color(0xFF334155))),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final uri = Uri.parse('https://developers.facebook.com/apps/');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('Mở developers.facebook.com', style: TextStyle(fontSize: 12)),
          ),
          ElevatedButton(
            onPressed: () async {
              final id = appIdController.text.trim();
              if (id.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vui lòng nhập Facebook App ID!'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              await ApiConstants.saveFacebookAppId(id);
              confirmed = true;
              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1877F2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Lưu & Mở Màn Hình Xác Nhận', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    return confirmed;
  }

  /// Widget dòng thông tin kèm nút sao chép tiện lợi
  static Widget _buildCopyField(BuildContext context, {required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textGray)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textBlack),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primaryDark),
            visualDensity: VisualDensity.compact,
            tooltip: 'Sao chép',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ Đã sao chép $label!'),
                  backgroundColor: const Color(0xFF16A34A),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// =========================================================================
  /// HÀM GỌI API BACKEND C# (.NET 8) VỚI THÔNG TIN THẬT TỪ MẠNG XÃ HỘI
  /// =========================================================================
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

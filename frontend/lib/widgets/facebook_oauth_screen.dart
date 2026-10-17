import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import '../constants/app_colors.dart';

/// Kết quả trả về sau khi xác thực Facebook OAuth
class FacebookAuthResponse {
  final bool success;
  final String? email;
  final String? name;
  final String? avatarUrl;
  final String? token;
  final String? message;

  const FacebookAuthResponse({
    required this.success,
    this.email,
    this.name,
    this.avatarUrl,
    this.token,
    this.message,
  });
}

/// Màn hình WebView nhúng Facebook OAuth 2.0 chính thức
/// - Mở trực tiếp trang đăng nhập & cấp quyền xác nhận của Facebook
/// - Người dùng bấm nút "Tiếp tục dưới tên [Tên người dùng]" để xác nhận
/// - Ứng dụng tự động bắt access_token trả về từ redirect_uri
/// - Lấy thông tin thật từ Facebook Graph API và hoàn tất đăng nhập
class FacebookOAuthScreen extends StatefulWidget {
  final String appId;

  const FacebookOAuthScreen({super.key, required this.appId});

  @override
  State<FacebookOAuthScreen> createState() => _FacebookOAuthScreenState();
}

class _FacebookOAuthScreenState extends State<FacebookOAuthScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isSyncing = false;
  double _progress = 0;
  bool _isHandled = false;

  static const String _redirectSuccessUrl = 'https://www.facebook.com/connect/login_success.html';

  @override
  void initState() {
    super.initState();

    final oauthUrl = 'https://www.facebook.com/v19.0/dialog/oauth?'
        'client_id=${widget.appId}'
        '&redirect_uri=$_redirectSuccessUrl'
        '&response_type=token'
        '&scope=email,public_profile'
        '&display=touch';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() => _progress = progress / 100);
            }
          },
          onPageStarted: (String url) {
            if (mounted) setState(() => _isLoading = true);
            _inspectUrl(url);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _isLoading = false);
            _inspectUrl(url);
          },
          onNavigationRequest: (NavigationRequest request) {
            if (_inspectUrl(request.url)) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(oauthUrl));
  }

  /// Kiểm tra URL để bắt access_token hoặc lỗi từ Facebook
  bool _inspectUrl(String url) {
    if (_isHandled) return true;

    if (url.startsWith(_redirectSuccessUrl) || url.contains('access_token=') || url.contains('login_success.html')) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        String? token;

        // Facebook trả token trong URL Fragment (#access_token=...)
        if (uri.fragment.isNotEmpty) {
          final fragParams = Uri.splitQueryString(uri.fragment);
          token = fragParams['access_token'];
        }
        // Trường hợp trả trong query param (?access_token=...)
        token ??= uri.queryParameters['access_token'];

        if (token != null && token.isNotEmpty) {
          _isHandled = true;
          _fetchUserProfile(token);
          return true;
        }

        // Kiểm tra nếu người dùng bấm Hủy / Từ chối cấp quyền
        final error = uri.queryParameters['error'] ??
            (uri.fragment.isNotEmpty ? Uri.splitQueryString(uri.fragment)['error'] : null);
        if (error != null) {
          _isHandled = true;
          if (mounted) {
            Navigator.of(context).pop(
              const FacebookAuthResponse(
                success: false,
                message: 'Bạn đã hủy yêu cầu cấp quyền Facebook.',
              ),
            );
          }
          return true;
        }
      }
    }
    return false;
  }

  /// Lấy thông tin thật của người dùng từ Facebook Graph API
  Future<void> _fetchUserProfile(String token) async {
    if (mounted) {
      setState(() => _isSyncing = true);
    }

    try {
      final graphUri = Uri.parse(
        'https://graph.facebook.com/v19.0/me?fields=id,name,email,picture.width(400).height(400)&access_token=$token',
      );

      final response = await http.get(graphUri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        final String id = data['id']?.toString() ?? '';
        final String name = data['name']?.toString() ?? 'Người dùng Facebook';
        // Nếu người dùng đăng ký Facebook bằng SĐT và không công khai email, tạo email định danh
        final String email = data['email']?.toString() ?? 'fb_$id@facebook.nutrisnap.com';
        String? avatarUrl;
        if (data['picture'] != null && data['picture']['data'] != null) {
          avatarUrl = data['picture']['data']['url']?.toString();
        }

        if (mounted) {
          Navigator.of(context).pop(
            FacebookAuthResponse(
              success: true,
              email: email,
              name: name,
              avatarUrl: avatarUrl,
              token: token,
            ),
          );
        }
      } else {
        if (mounted) {
          Navigator.of(context).pop(
            FacebookAuthResponse(
              success: false,
              message: 'Lỗi phản hồi từ Facebook Graph API (${response.statusCode})',
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(
          FacebookAuthResponse(
            success: false,
            message: 'Không thể kết nối đến Facebook Graph: $e',
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1877F2),
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
          onPressed: () {
            Navigator.of(context).pop(
              const FacebookAuthResponse(success: false, message: 'Đã hủy thao tác đăng nhập Facebook.'),
            );
          },
        ),
        title: const Row(
          children: [
            Icon(Icons.facebook, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text(
              'Đăng nhập với Facebook',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
            onPressed: () => _controller.reload(),
          ),
        ],
        bottom: _isLoading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3.0),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  backgroundColor: Colors.blue.shade300,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 3,
                ),
              )
            : null,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),

          // Lớp hiển thị trạng thái đang đồng bộ thông tin tài khoản Facebook
          if (_isSyncing)
            Container(
              color: Colors.black.withValues(alpha: 0.6),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1877F2)),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Đã nhận xác nhận từ Facebook!',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Đang đồng bộ hồ sơ và đăng nhập vào NutriSnap...',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: AppColors.textGray),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

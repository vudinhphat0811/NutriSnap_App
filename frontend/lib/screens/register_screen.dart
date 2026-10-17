import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../constants/app_colors.dart';
import '../services/app_state_service.dart';
import '../widgets/app_popup_dialog.dart';
import 'onboarding_profile_screen.dart';
import '../widgets/social_auth_helper.dart';
import '../main.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  // Không gán chữ sẵn - người dùng gõ được ngay mà không cần xóa
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      final response = await http
          .post(
            Uri.parse(ApiConstants.register),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 10));

      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['token'] != null) {
          AppStateService.instance.authToken = data['token'].toString();
        }
        AppStateService.instance.userProfile.email = email;
        await AppStateService.instance.saveToLocalStorage();

        if (!mounted) return;
        await AppPopupDialog.show(
          context: context,
          title: 'Đăng ký thành công',
          message: 'Tài khoản của bạn đã được tạo! Hãy cùng thiết lập các chỉ số sức khỏe ban đầu nhé.',
          type: PopupType.success,
          buttonText: 'Bắt đầu ngay',
        );

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OnboardingProfileScreen(initialEmail: email),
          ),
        );
      } else {
        if (!mounted) return;
        String errorMsg = 'Đăng ký thất bại. Vui lòng thử lại!';
        try {
          final errData = jsonDecode(utf8.decode(response.bodyBytes));
          if (errData['message'] != null) {
            errorMsg = errData['message'].toString();
          } else if (response.body.isNotEmpty) {
            errorMsg = response.body;
          }
        } catch (_) {}

        AppPopupDialog.show(
          context: context,
          title: 'Đăng ký thất bại',
          message: errorMsg,
          type: PopupType.error,
          buttonText: 'Thử lại',
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      AppPopupDialog.show(
        context: context,
        title: 'Lỗi kết nối máy chủ',
        message: 'Không thể kết nối đến máy chủ Backend tại ${ApiConstants.baseUrl}. Vui lòng thử lại!',
        type: PopupType.error,
        buttonText: 'Đã hiểu',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textBlack, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon biểu tượng
                Center(
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: AppColors.accentMint,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.person_add_rounded, color: AppColors.primary, size: 34),
                  ),
                ),
                const SizedBox(height: 14),
                const Center(
                  child: Text(
                    'Tạo Tài Khoản Mới',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textBlack,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Center(
                  child: Text(
                    'Đăng ký để đồng bộ thực đơn và nhận diện dinh dưỡng',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.textGray),
                  ),
                ),
                const SizedBox(height: 28),

                // Card Đăng ký
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Email
                      _buildInputField(
                        controller: _emailController,
                        label: 'Địa chỉ Email',
                        hintText: 'Nhập email của bạn (vd: ban@gmail.com)',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Vui lòng nhập email';
                          }
                          if (!value.contains('@')) {
                            return 'Email không hợp lệ';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Mật khẩu
                      _buildInputField(
                        controller: _passwordController,
                        label: 'Mật khẩu',
                        hintText: 'Nhập mật khẩu (tối thiểu 6 ký tự)',
                        icon: Icons.lock_outline,
                        isPassword: true,
                        obscureText: _obscurePassword,
                        onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
                        validator: (value) {
                          if (value == null || value.length < 6) {
                            return 'Mật khẩu phải từ 6 ký tự trở lên';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Nhập lại mật khẩu
                      _buildInputField(
                        controller: _confirmPasswordController,
                        label: 'Xác nhận mật khẩu',
                        hintText: 'Nhập lại mật khẩu của bạn',
                        icon: Icons.lock_reset_rounded,
                        isPassword: true,
                        obscureText: _obscureConfirmPassword,
                        onToggleVisibility: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        validator: (value) {
                          if (value != _passwordController.text) {
                            return 'Mật khẩu xác nhận không khớp!';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Nút Đăng ký
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text(
                                  'Đăng Ký & Điền Số Liệu ➔',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              'Hoặc đăng ký nhanh bằng',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            ),
                          ),
                          const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Nút Social Google & Facebook
                      Row(
                        children: [
                          // Nút Google
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final ok = await SocialAuthHelper.showGoogleAuthDialog(context);
                                if (ok && context.mounted) {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (_) => const MobileWrapper(child: MainShellScreen())),
                                  );
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                backgroundColor: const Color(0xFFF8FAFC),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.network(
                                    'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/480px-Google_%22G%22_logo.svg.png',
                                    width: 18,
                                    height: 18,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata_rounded, color: Colors.red, size: 22),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Google', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Nút Facebook
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final ok = await SocialAuthHelper.showFacebookAuthDialog(context);
                                if (ok && context.mounted) {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (_) => const MobileWrapper(child: MainShellScreen())),
                                  );
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: const BorderSide(color: Color(0xFFBFDBFE)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                backgroundColor: const Color(0xFFF0F7FF),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.facebook, color: Color(0xFF1877F2), size: 20),
                                  SizedBox(width: 8),
                                  Text('Facebook', style: TextStyle(color: Color(0xFF1877F2), fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Chuyển sang Đăng nhập
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Đã có tài khoản? ', style: TextStyle(color: AppColors.textGray, fontSize: 13)),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        'Đăng nhập ngay',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textBlack),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: const TextStyle(fontSize: 14, color: AppColors.textBlack),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(fontSize: 13, color: AppColors.textLightGray),
            prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscureText ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.textLightGray,
                      size: 20,
                    ),
                    onPressed: onToggleVisibility,
                  )
                : null,
            filled: true,
            fillColor: const Color(0xFFF1F5F9),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}
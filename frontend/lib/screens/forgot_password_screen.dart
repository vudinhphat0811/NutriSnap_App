import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../constants/app_colors.dart';
import '../widgets/app_popup_dialog.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // Không gán chữ sẵn - người dùng gõ được ngay mà không cần xóa
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _isCodeSent = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendResetCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập địa chỉ email hợp lệ!'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.forgotPassword),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        setState(() => _isCodeSent = true);
        if (!mounted) return;
        AppPopupDialog.show(
          context: context,
          title: 'Đã gửi mã xác thực',
          message: 'Mã xác thực 4 số đã được gửi về Gmail của bạn. Vui lòng kiểm tra hộp thư đến (hoặc hòm thư Spam)!',
          type: PopupType.success,
          buttonText: 'Tiếp tục',
        );
      } else {
        if (!mounted) return;
        AppPopupDialog.show(
          context: context,
          title: 'Gửi mã thất bại',
          message: 'Không thể gửi mã xác thực. Vui lòng kiểm tra lại địa chỉ email của bạn!',
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

  Future<void> _resetPassword() async {
    final code = _codeController.text.trim();
    final newPassword = _newPasswordController.text;

    if (code.isEmpty || newPassword.length < 6) {
      AppPopupDialog.show(
        context: context,
        title: 'Thiếu thông tin',
        message: 'Vui lòng nhập đầy đủ mã xác thực và mật khẩu mới (tối thiểu 6 ký tự)!',
        type: PopupType.warning,
        buttonText: 'Đã hiểu',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.forgotPassword),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'code': code,
          'newPassword': newPassword,
        }),
      );

      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        if (!mounted) return;
        await AppPopupDialog.show(
          context: context,
          title: 'Thành công',
          message: 'Mật khẩu của bạn đã được đặt lại thành công! Hãy đăng nhập bằng mật khẩu mới nhé.',
          type: PopupType.success,
          buttonText: 'Đăng nhập ngay',
        );
        if (!mounted) return;
        Navigator.pop(context);
      } else {
        if (!mounted) return;
        AppPopupDialog.show(
          context: context,
          title: 'Xác thực thất bại',
          message: 'Mã xác thực không chính xác hoặc đã hết hạn. Vui lòng kiểm tra lại!',
          type: PopupType.error,
          buttonText: 'Thử lại',
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      AppPopupDialog.show(
        context: context,
        title: 'Lỗi kết nối',
        message: 'Không thể kết nối đến máy chủ Backend. Vui lòng thử lại sau!',
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icon Header
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
                  child: const Icon(Icons.lock_reset_rounded, color: AppColors.primary, size: 36),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Khôi Phục Mật Khẩu',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textBlack,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isCodeSent
                    ? 'Nhập mã 4 số được gửi đến email và đặt mật khẩu mới'
                    : 'Nhập email đã đăng ký để nhận mã xác thực khôi phục',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.textGray),
              ),
              const SizedBox(height: 28),

              // Card Nhập liệu
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
                    _buildField(
                      controller: _emailController,
                      label: 'Địa chỉ Email',
                      hintText: 'Nhập email đã đăng ký của bạn',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !_isCodeSent,
                    ),

                    if (_isCodeSent) ...[
                      const SizedBox(height: 16),
                      // Mã xác thực
                      _buildField(
                        controller: _codeController,
                        label: 'Mã xác thực (OTP 4 số)',
                        hintText: 'VD: 1234',
                        icon: Icons.pin_outlined,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      // Mật khẩu mới
                      _buildField(
                        controller: _newPasswordController,
                        label: 'Mật khẩu mới',
                        hintText: 'Nhập mật khẩu mới (tối thiểu 6 ký tự)',
                        icon: Icons.vpn_key_outlined,
                        isPassword: true,
                        obscureText: _obscurePassword,
                        onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Nút hành động
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : (_isCodeSent ? _resetPassword : _sendResetCode),
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
                            : Text(
                                _isCodeSent ? 'XÁC NHẬN ĐỔI MẬT KHẨU' : 'GỬI MÃ XÁC THỰC ➔',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Quay lại đăng nhập
              Center(
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, size: 16, color: AppColors.textGray),
                  label: const Text(
                    'Quay lại Đăng nhập',
                    style: TextStyle(color: AppColors.textGray, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    bool obscureText = false,
    bool enabled = true,
    VoidCallback? onToggleVisibility,
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
          enabled: enabled,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: TextStyle(fontSize: 14, color: enabled ? AppColors.textBlack : AppColors.textGray),
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
            fillColor: enabled ? const Color(0xFFF1F5F9) : const Color(0xFFE2E8F0),
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
        ),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/app_state_service.dart';
import '../screens/login_screen.dart';
import 'social_auth_helper.dart';

class GuestTrialBarrierModal extends StatelessWidget {
  const GuestTrialBarrierModal({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateService.instance;
    final days = appState.guestUsageDays;

    return PopScope(
      canPop: false, // Không cho phép bấm nút back Android để bỏ qua
      child: Material(
        color: Colors.black.withValues(alpha: 0.75),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon đồng hồ cát nổi bật
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFDE68A), width: 2),
                  ),
                  child: const Center(
                    child: Icon(Icons.hourglass_bottom_rounded, size: 38, color: Color(0xFFD97706)),
                  ),
                ),
                const SizedBox(height: 16),

                // Tiêu đề
                const Text(
                  'Hết Hạn Trải Nghiệm Khách',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textBlack,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Nội dung giải thích
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: Text(
                    'Đã dùng: $days / 7 ngày thử nghiệm',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                const Text(
                  'Bạn đã đồng hành cùng NutriSnap trong 7 ngày với tư cách Khách. Để bảo vệ dữ liệu nhật ký bữa ăn, chỉ số calo và tiếp tục sử dụng ứng dụng, vui lòng liên kết tài khoản ngay:',
                  style: TextStyle(fontSize: 13, height: 1.45, color: AppColors.textGray),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),

                // Nút Liên kết Google
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () async {
                      final ok = await SocialAuthHelper.showGoogleAuthDialog(context);
                      if (ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Đã liên kết tài khoản Google thành công!'),
                            backgroundColor: AppColors.primaryDark,
                          ),
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.network(
                          'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/480px-Google_%22G%22_logo.svg.png',
                          width: 20,
                          height: 20,
                          errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata_rounded, color: Colors.red, size: 24),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Tiếp tục với Google',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Nút Liên kết Facebook
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final ok = await SocialAuthHelper.showFacebookAuthDialog(context);
                      if (ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Đã liên kết tài khoản Facebook thành công!'),
                            backgroundColor: Color(0xFF1877F2),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1877F2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.facebook, size: 22),
                    label: const Text(
                      'Tiếp tục với Facebook',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Nút Đăng ký / Đăng nhập Email
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary, width: 1.2),
                      foregroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.mail_outline_rounded, size: 20),
                    label: const Text(
                      'Đăng ký / Đăng nhập bằng Email',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Dành cho kiểm thử (Demo Test Switcher)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Kiểm thử:', style: TextStyle(fontSize: 11, color: AppColors.textGray)),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => appState.setTestGuestDays(1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Mở khóa (Ngày 1)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => appState.setTestGuestDays(7),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Khóa (Ngày 7)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum PopupType { success, error, warning, info }

class AppPopupDialog extends StatelessWidget {
  final String title;
  final String message;
  final PopupType type;
  final String buttonText;
  final VoidCallback? onConfirm;

  const AppPopupDialog({
    super.key,
    required this.title,
    required this.message,
    this.type = PopupType.error,
    this.buttonText = 'Đã hiểu',
    this.onConfirm,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    required String message,
    PopupType type = PopupType.error,
    String buttonText = 'Đã hiểu',
    VoidCallback? onConfirm,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'NutriSnapDialog',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) => const SizedBox(),
      transitionBuilder: (ctx, anim, secondaryAnim, child) {
        final curvedValue = Curves.easeOutBack.transform(anim.value);
        return Transform.scale(
          scale: curvedValue,
          child: Opacity(
            opacity: anim.value.clamp(0.0, 1.0),
            child: AppPopupDialog(
              title: title,
              message: message,
              type: type,
              buttonText: buttonText,
              onConfirm: onConfirm,
            ),
          ),
        );
      },
    );
  }

  Color get _primaryColor {
    switch (type) {
      case PopupType.success:
        return AppColors.primary;
      case PopupType.error:
        return const Color(0xFFEF4444);
      case PopupType.warning:
        return const Color(0xFFF59E0B);
      case PopupType.info:
        return const Color(0xFF3B82F6);
    }
  }

  Color get _bgCircleColor {
    switch (type) {
      case PopupType.success:
        return AppColors.primary.withValues(alpha: 0.12);
      case PopupType.error:
        return const Color(0xFFFEE2E2);
      case PopupType.warning:
        return const Color(0xFFFEF3C7);
      case PopupType.info:
        return const Color(0xFFDBEAFE);
    }
  }

  IconData get _icon {
    switch (type) {
      case PopupType.success:
        return Icons.check_circle_rounded;
      case PopupType.error:
        return Icons.error_rounded;
      case PopupType.warning:
        return Icons.warning_rounded;
      case PopupType.info:
        return Icons.info_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      elevation: 16,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon Badge
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _bgCircleColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _primaryColor.withValues(alpha: 0.25),
                  width: 2,
                ),
              ),
              child: Icon(
                _icon,
                color: _primaryColor,
                size: 38,
              ),
            ),
            const SizedBox(height: 18),

            // Tiêu đề
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: AppColors.textBlack,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),

            // Nội dung
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 24),

            // Nút bấm xác nhận
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context, rootNavigator: true).pop();
                  if (onConfirm != null) {
                    onConfirm!();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  buttonText,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

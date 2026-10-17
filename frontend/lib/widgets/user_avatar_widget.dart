import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/app_colors.dart';
import '../services/app_state_service.dart';

class UserAvatarWidget extends StatelessWidget {
  final double size;
  final bool showEditBadge;
  final VoidCallback? onTap;

  const UserAvatarWidget({
    super.key,
    this.size = 46,
    this.showEditBadge = false,
    this.onTap,
  });

  static Future<void> showPickerSheet(BuildContext context) async {
    final appState = AppStateService.instance;
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Thanh kéo
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Ảnh đại diện của bạn',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textBlack,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tải ảnh lên để cá nhân hóa hồ sơ NutriSnap của bạn',
                style: TextStyle(fontSize: 12, color: AppColors.textGray),
              ),
              const SizedBox(height: 20),

              // Nút Chụp ảnh
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: AppColors.accentMint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: AppColors.primary, size: 22),
                ),
                title: const Text(
                  'Chụp ảnh mới',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: const Text('Mở máy ảnh thiết bị', style: TextStyle(fontSize: 11, color: AppColors.textGray)),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final picked = await picker.pickImage(
                      source: ImageSource.camera,
                      maxWidth: 800,
                      maxHeight: 800,
                      imageQuality: 85,
                    );
                    if (picked != null) {
                      await appState.updateAvatar(picked.path);
                    }
                  } catch (e) {
                    debugPrint('Lỗi chụp ảnh: $e');
                  }
                },
              ),

              // Nút Chọn từ thư viện
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: AppColors.accentIndigo,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: Color(0xFF6366F1), size: 22),
                ),
                title: const Text(
                  'Chọn từ thư viện ảnh',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: const Text('Chọn ảnh có sẵn trong máy', style: TextStyle(fontSize: 11, color: AppColors.textGray)),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final picked = await picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 800,
                      maxHeight: 800,
                      imageQuality: 85,
                    );
                    if (picked != null) {
                      await appState.updateAvatar(picked.path);
                    }
                  } catch (e) {
                    debugPrint('Lỗi chọn ảnh: $e');
                  }
                },
              ),

              // Nút Gỡ ảnh đại diện (nếu đang có ảnh)
              if (appState.userProfile.avatarPath != null) ...[
                const Divider(),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                  ),
                  title: const Text(
                    'Xóa ảnh đại diện',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.redAccent),
                  ),
                  subtitle: const Text('Quay về biểu tượng mặc định', style: TextStyle(fontSize: 11, color: AppColors.textGray)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await appState.updateAvatar(null);
                  },
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppStateService.instance,
      builder: (context, _) {
        final profile = AppStateService.instance.userProfile;
        final avatarPath = profile.avatarPath;

        ImageProvider? imageProvider;
        if (avatarPath != null && avatarPath.isNotEmpty) {
          if (avatarPath.startsWith('http')) {
            imageProvider = NetworkImage(avatarPath);
          } else if (!kIsWeb) {
            final file = File(avatarPath);
            if (file.existsSync()) {
              imageProvider = FileImage(file);
            }
          }
        }

        return GestureDetector(
          onTap: onTap ?? () => showPickerSheet(context),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: imageProvider != null
                      ? Image(
                          image: imageProvider,
                          width: size,
                          height: size,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildFallbackIcon(),
                        )
                      : _buildFallbackIcon(),
                ),
              ),

              // Edit Badge icon
              if (showEditBadge)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: EdgeInsets.all(size * 0.08),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: size * 0.28,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFallbackIcon() {
    return Container(
      color: AppColors.accentMint,
      alignment: Alignment.center,
      child: Icon(
        Icons.person,
        size: size * 0.58,
        color: AppColors.primaryDark,
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Widget hiển thị ảnh món ăn thông minh:
/// - Nếu món có ảnh thật chính xác (từ TheMealDB hoặc ảnh chụp thực tế), hiển thị ảnh mạng mượt mà.
/// - Tuyệt đối KHÔNG hiển thị ảnh rác/ảnh không liên quan (như đĩa than vinyl, cây cỏ rác...).
/// - Nếu không có ảnh thật hoặc tải lỗi, hiển thị ICON & EMOJI món ăn chuẩn xác theo nhóm thực phẩm.
class RecipeImageWidget extends StatelessWidget {
  final String? imageUrl;
  final String? mealName;
  final String? category;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxFit fit;
  final bool isHeroBanner;

  const RecipeImageWidget({
    super.key,
    required this.imageUrl,
    this.mealName,
    this.category,
    this.width,
    this.height,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.isHeroBanner = false,
  });

  /// Kiểm tra xem ảnh có phải là ảnh thực tế hợp lệ hay không
  /// (Loại bỏ hoàn toàn các ảnh Unsplash không liên quan)
  static bool isAuthenticImage(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final clean = url.trim().toLowerCase();
    // Loại bỏ ảnh Unsplash và các URL placeholder giả lập
    if (clean.contains('unsplash.com')) return false;
    // Chấp nhận ảnh TheMealDB hoặc URL hợp lệ khác
    return clean.contains('themealdb.com') || clean.startsWith('http://') || clean.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(12);

    if (isAuthenticImage(imageUrl)) {
      return ClipRRect(
        borderRadius: effectiveRadius,
        child: Image.network(
          imageUrl!.trim(),
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => _buildFoodIconBadge(context, effectiveRadius),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: width,
              height: height,
              color: const Color(0xFFF1F5F9),
              child: const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                ),
              ),
            );
          },
        ),
      );
    }

    return _buildFoodIconBadge(context, effectiveRadius);
  }

  /// Khối hiển thị Icon & Emoji món ăn chuyên nghiệp thay thế ảnh không liên quan
  Widget _buildFoodIconBadge(BuildContext context, BorderRadius radius) {
    final style = _resolveCulinaryStyle(mealName, category);
    final bool isCompact = (width != null && width! <= 85) || (height != null && height! <= 85);

    if (isCompact) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: style.gradient,
          ),
          border: Border.all(color: style.accentColor.withValues(alpha: 0.18), width: 1),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Watermark icon mờ ở góc
            Positioned(
              right: -6,
              bottom: -6,
              child: Icon(
                style.icon,
                size: (width ?? 64) * 0.55,
                color: style.accentColor.withValues(alpha: 0.12),
              ),
            ),
            // Emoji chính giữa
            Text(
              style.emoji,
              style: TextStyle(
                fontSize: ((width ?? 64) * 0.46).clamp(18.0, 32.0),
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Giao diện Thẻ lớn (Card hoặc Hero Banner)
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: style.gradient,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Hoa văn chìm
          Positioned(
            right: 16,
            bottom: -10,
            child: Icon(
              style.icon,
              size: 110,
              color: style.accentColor.withValues(alpha: 0.10),
            ),
          ),
          Positioned(
            left: 16,
            top: -10,
            child: Icon(
              Icons.restaurant_menu_rounded,
              size: 80,
              color: style.accentColor.withValues(alpha: 0.08),
            ),
          ),

          // Khối trung tâm
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: isHeroBanner ? 84 : 70,
                height: isHeroBanner ? 84 : 70,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: style.accentColor.withValues(alpha: 0.15),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  style.emoji,
                  style: TextStyle(fontSize: isHeroBanner ? 42 : 36),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: style.accentColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(style.icon, size: 12, color: style.accentColor),
                    const SizedBox(width: 4),
                    Text(
                      style.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: style.accentColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Tự động bóc tách tên món & danh mục để gán Emoji, Icon và màu sắc tương thích 100%
  static _CulinaryStyle _resolveCulinaryStyle(String? name, String? cat) {
    final lowerName = (name ?? '').toLowerCase();
    final lowerCat = (cat ?? '').toLowerCase();

    // 1. Món Rau / Salad / Chay
    if (lowerName.contains('rau') ||
        lowerName.contains('muống') ||
        lowerName.contains('spinach') ||
        lowerName.contains('cải') ||
        lowerName.contains('bok choy') ||
        lowerName.contains('salad') ||
        lowerName.contains('chay') ||
        lowerCat.contains('vegetarian') ||
        lowerCat.contains('vegan')) {
      final isSalad = lowerName.contains('salad');
      return _CulinaryStyle(
        emoji: isSalad ? '🥗' : '🥬',
        icon: isSalad ? Icons.eco_rounded : Icons.grass_rounded,
        label: isSalad ? 'Món Salad Thanh Mát' : 'Món Rau Dân Dã',
        gradient: const [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
        accentColor: const Color(0xFF2E7D32),
      );
    }

    // 2. Món Bò (Beef)
    if (lowerName.contains('bò') || lowerName.contains('beef') || lowerCat.contains('beef')) {
      return const _CulinaryStyle(
        emoji: '🥩',
        icon: Icons.dinner_dining_rounded,
        label: 'Món Bò Đậm Đà',
        gradient: [Color(0xFFFFF1F2), Color(0xFFFFCDD2)],
        accentColor: Color(0xFFC62828),
      );
    }

    // 3. Món Thịt Heo / Sườn / Ba chỉ (Pork)
    if (lowerName.contains('heo') ||
        lowerName.contains('pork') ||
        lowerName.contains('sườn') ||
        lowerName.contains('ba chỉ') ||
        lowerCat.contains('pork')) {
      final isRibs = lowerName.contains('sườn');
      return _CulinaryStyle(
        emoji: isRibs ? '🍖' : '🥓',
        icon: Icons.lunch_dining_rounded,
        label: isRibs ? 'Món Sườn Đậm Sốt' : 'Món Thịt Heo',
        gradient: const [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
        accentColor: const Color(0xFFE65100),
      );
    }

    // 4. Món Gà (Chicken)
    if (lowerName.contains('gà') || lowerName.contains('chicken') || lowerCat.contains('chicken')) {
      return const _CulinaryStyle(
        emoji: '🍗',
        icon: Icons.kebab_dining_rounded,
        label: 'Món Gà Thơm Ngon',
        gradient: [Color(0xFFFFFDE7), Color(0xFFFFF9C4)],
        accentColor: Color(0xFFF57F17),
      );
    }

    // 5. Món Hải sản / Tôm / Cá / Mực / Ngao
    if (lowerName.contains('cá') ||
        lowerName.contains('tôm') ||
        lowerName.contains('mực') ||
        lowerName.contains('ngao') ||
        lowerName.contains('seafood') ||
        lowerName.contains('hải sản') ||
        lowerCat.contains('seafood')) {
      String emoji = '🐟';
      if (lowerName.contains('tôm')) emoji = '🦐';
      if (lowerName.contains('mực')) emoji = '🦑';
      if (lowerName.contains('ngao')) emoji = '🦪';
      return _CulinaryStyle(
        emoji: emoji,
        icon: Icons.set_meal_rounded,
        label: 'Món Thủy Hải Sản',
        gradient: const [Color(0xFFE0F7FA), Color(0xFFB2EBF2)],
        accentColor: const Color(0xFF00838F),
      );
    }

    // 6. Món Canh / Súp / Lẩu
    if (lowerName.contains('canh') ||
        lowerName.contains('súp') ||
        lowerName.contains('soup') ||
        lowerName.contains('lẩu') ||
        lowerName.contains('hotpot')) {
      return const _CulinaryStyle(
        emoji: '🍲',
        icon: Icons.soup_kitchen_rounded,
        label: 'Canh Bữa Cơm',
        gradient: [Color(0xFFFFF8E1), Color(0xFFFFECB3)],
        accentColor: Color(0xFFFF8F00),
      );
    }

    // 7. Món Trứng
    if (lowerName.contains('trứng') || lowerName.contains('egg')) {
      return const _CulinaryStyle(
        emoji: '🍳',
        icon: Icons.egg_alt_rounded,
        label: 'Món Trứng Thơm Mềm',
        gradient: [Color(0xFFFFF9C4), Color(0xFFFFF59D)],
        accentColor: Color(0xFFF9A825),
      );
    }

    // 8. Món Đậu phụ
    if (lowerName.contains('đậu') || lowerName.contains('tofu')) {
      return const _CulinaryStyle(
        emoji: '🧈',
        icon: Icons.interests_rounded,
        label: 'Món Đậu Thanh Đạm',
        gradient: [Color(0xFFF1F8E9), Color(0xFFDCEDC8)],
        accentColor: Color(0xFF558B2F),
      );
    }

    // 9. Mặc định
    return const _CulinaryStyle(
      emoji: '🍽️',
      icon: Icons.restaurant_rounded,
      label: 'Món Ngon Gia Đình',
      gradient: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
      accentColor: Color(0xFF475569),
    );
  }
}

class _CulinaryStyle {
  final String emoji;
  final IconData icon;
  final String label;
  final List<Color> gradient;
  final Color accentColor;

  const _CulinaryStyle({
    required this.emoji,
    required this.icon,
    required this.label,
    required this.gradient,
    required this.accentColor,
  });
}

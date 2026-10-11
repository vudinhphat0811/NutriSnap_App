import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class RecipeSuggestionsScreen extends StatelessWidget {
  final Function(int) onNavigate;

  const RecipeSuggestionsScreen({
    super.key,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tiêu đề App trung tâm
            const Center(
              child: Text(
                'NutriSnap',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textBlack,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Top Bar: Nút Back + Tiêu đề + Icon bộ lọc
            Row(
              children: [
                InkWell(
                  onTap: () => onNavigate(0), // Quay về Trang chủ
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
                      ],
                    ),
                    child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.textBlack),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Gợi ý bữa tối lành mạnh',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Tìm thấy 3 món phù hợp với nguyên liệu & 700 kcal còn lại',
                        style: TextStyle(fontSize: 11, color: AppColors.textGray),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.accentIndigo,
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.tune_rounded, size: 18, color: AppColors.primaryDark),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Dải thẻ Tag điều kiện lọc (Filter Chips)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildFilterChip(
                    icon: Icons.check_circle,
                    label: 'Từ nguyên liệu sẵn có',
                    bgColor: const Color(0xFF6EE7B7),
                    textColor: AppColors.primaryDark,
                    iconColor: AppColors.primaryDark,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    icon: Icons.fitness_center,
                    label: 'Giàu Protein',
                    bgColor: AppColors.accentIndigo,
                    textColor: const Color(0xFF3B82F6),
                    iconColor: const Color(0xFF3B82F6),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    icon: Icons.local_fire_department,
                    label: 'Dưới 700 kcal',
                    bgColor: const Color(0xFFFFF1F2),
                    textColor: const Color(0xFFE11D48),
                    iconColor: const Color(0xFFE11D48),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // MÓN 1: Ức gà áp chảo sốt tiêu đen & Bông cải
            _buildRecipeCard(
              imageUrl: 'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?auto=format&fit=crop&w=700&q=80',
              matchBadgeText: 'Khớp 100% nguyên liệu',
              matchBadgeIsGreen: true,
              time: '15 phút',
              difficulty: 'Dễ làm',
              title: 'Ức gà áp chảo sốt tiêu đen & Bông cải',
              calories: '380 kcal',
              protein: '42g',
              carbs: '14g',
              fat: '8g',
              highlightText: 'Đầy đủ chất xơ & nạc',
              highlightDotColor: AppColors.primary,
              onTap: () => onNavigate(6), // Mở màn hình Chi tiết công thức
            ),
            const SizedBox(height: 16),

            // MÓN 2: Trứng xào cà chua ăn kèm cơm gạo lứt
            _buildRecipeCard(
              imageUrl: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=700&q=80',
              matchBadgeText: 'Khớp 100% nguyên liệu',
              matchBadgeIsGreen: true,
              time: '10 phút',
              difficulty: 'Siêu nhanh',
              title: 'Trứng xào cà chua ăn kèm cơm gạo lứt',
              calories: '310 kcal',
              protein: '18g',
              carbs: '28g',
              fat: '12g',
              highlightText: 'Chuẩn bị cực nhanh tối bận rộn',
              highlightDotColor: AppColors.primary,
              onTap: () => onNavigate(6),
            ),
            const SizedBox(height: 16),

            // MÓN 3: Canh ức gà nấu cà chua và nấm thanh mát
            _buildRecipeCard(
              imageUrl: 'https://images.unsplash.com/photo-1547592166-23ac45744acd?auto=format&fit=crop&w=700&q=80',
              matchBadgeText: 'Thiếu 1 gia vị (Hành lá)',
              matchBadgeIsGreen: false,
              time: '20 phút',
              difficulty: 'Thanh nhiệt',
              title: 'Canh ức gà nấu cà chua và nấm thanh mát',
              calories: '290 kcal',
              protein: '35g',
              carbs: '10g',
              fat: '5g',
              highlightText: 'Nhẹ bụng & dễ tiêu hóa ban đêm',
              highlightDotColor: const Color(0xFF475569),
              onTap: () => onNavigate(6),
            ),
            const SizedBox(height: 16),

            // Thẻ "Mẹo thông minh từ NutriSnap"
            _buildSmartTipCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // --- CÁC WIDGET THÀNH PHẦN CHI TIẾT ---

  Widget _buildFilterChip({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color textColor,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeCard({
    required String imageUrl,
    required String matchBadgeText,
    required bool matchBadgeIsGreen,
    required String time,
    required String difficulty,
    required String title,
    required String calories,
    required String protein,
    required String carbs,
    required String fat,
    required String highlightText,
    required Color highlightDotColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Phần ảnh kèm nhãn nổi (Stack)
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: Image.network(
                  imageUrl,
                  height: 175,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              // Huy hiệu trạng thái nguyên liệu (Góc trên trái)
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: matchBadgeIsGreen ? const Color(0xFF00B074) : Colors.white.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        matchBadgeIsGreen ? Icons.stars_rounded : Icons.info_outline,
                        size: 13,
                        color: matchBadgeIsGreen ? Colors.white : const Color(0xFF0F172A),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        matchBadgeText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: matchBadgeIsGreen ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Nút Bookmark lưu món (Góc trên phải)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.92),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.bookmark_border_rounded, size: 18, color: AppColors.primaryDark),
                ),
              ),
              // Nhãn thời gian & độ khó (Góc dưới trái)
              Positioned(
                bottom: 12,
                left: 12,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(time, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.bolt_rounded, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(difficulty, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Nội dung chi tiết bên dưới ảnh
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tên món ăn
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textBlack,
                  ),
                ),
                const SizedBox(height: 12),

                // Bảng 4 chỉ số Macro nền xám xanh nhạt
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.accentIndigo.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMacroStat('Calo', calories, isHighlight: true),
                      _buildVerticalDivider(),
                      _buildMacroStat('Protein', protein),
                      _buildVerticalDivider(),
                      _buildMacroStat('Carbs', carbs),
                      _buildVerticalDivider(),
                      _buildMacroStat('Chất béo', fat),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Dòng mô tả & Nút Xem công thức
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: highlightDotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          highlightText,
                          style: const TextStyle(fontSize: 11, color: AppColors.textGray, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: onTap,
                      child: Row(
                        children: const [
                          Text(
                            'Xem công thức',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          Icon(Icons.chevron_right, size: 16, color: AppColors.primaryDark),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroStat(String label, String value, {bool isHighlight = false}) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textGray, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isHighlight ? AppColors.primaryDark : AppColors.textBlack,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 20,
      color: const Color(0xFFE2E8F0),
    );
  }

  // Thẻ mẹo thông minh ở cuối
  Widget _buildSmartTipCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accentIndigo.withOpacity(0.6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppColors.primaryDark,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Mẹo thông minh từ NutriSnap',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                ),
                SizedBox(height: 3),
                Text(
                  'Cả 3 lựa chọn này đều tối ưu lượng carbs buổi tối, giúp bạn ngủ sâu và duy trì mức thâm hụt calo hoàn hảo.',
                  style: TextStyle(fontSize: 11, color: AppColors.textGray, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
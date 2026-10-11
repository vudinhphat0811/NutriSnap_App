import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class ShakeRecipeScreen extends StatefulWidget {
  final Function(int) onNavigate;

  const ShakeRecipeScreen({
    super.key,
    required this.onNavigate,
  });

  @override
  State<ShakeRecipeScreen> createState() => _ShakeRecipeScreenState();
}

class _ShakeRecipeScreenState extends State<ShakeRecipeScreen> {
  bool _vibrationEnabled = true;
  int _selectedSourceIndex = 0; // 0: Từ tủ lạnh (4), 1: Đi chợ nhanh

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tiêu đề app
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

            // Top Bar: Nút Back + Tiêu đề trạng thái AI + Công tắc Rung
            Row(
              children: [
                InkWell(
                  onTap: () => widget.onNavigate(0), // Quay về Trang chủ
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
                    children: [
                      const Text(
                        'Lắc Chọn Món',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: const [
                          Icon(Icons.circle, size: 6, color: AppColors.primary),
                          SizedBox(width: 4),
                          Text(
                            'AI Sẵn Sàng',
                            style: TextStyle(fontSize: 11, color: AppColors.primaryDark, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accentIndigo,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.vibration_rounded, size: 16, color: AppColors.primaryDark),
                      const SizedBox(width: 4),
                      const Text(
                        'Rung',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                      ),
                      const SizedBox(width: 4),
                      Transform.scale(
                        scale: 0.7,
                        child: Switch(
                          value: _vibrationEnabled,
                          activeColor: AppColors.primary,
                          onChanged: (val) => setState(() => _vibrationEnabled = val),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Tabs chọn nguồn: Từ tủ lạnh (4) / Đi chợ nhanh
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.accentIndigo.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  _buildSourceTab(0, Icons.kitchen_outlined, 'Từ tủ lạnh (4)'),
                  _buildSourceTab(1, Icons.storefront_outlined, 'Đi chợ nhanh'),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Thông tin kho tủ lạnh vừa quét
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.inventory_2_outlined, size: 15, color: AppColors.primaryDark),
                    SizedBox(width: 6),
                    Text(
                      'Kho tủ lạnh vừa quét:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accentIndigo,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '4 món sẵn có',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Dải Chip điều kiện lọc
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildConditionChip(Icons.timer_outlined, 'Dưới 15 phút', const Color(0xFF6EE7B7), AppColors.primaryDark),
                  const SizedBox(width: 8),
                  _buildConditionChip(Icons.local_fire_department, 'Dưới 500 kcal', const Color(0xFF6EE7B7), AppColors.primaryDark),
                  const SizedBox(width: 8),
                  _buildConditionChip(Icons.fitness_center, 'Tối đa Protein', AppColors.accentIndigo, const Color(0xFFEAB308)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Khối thẻ Tương tác Lắc điện thoại với Xúc xắc & 4 nguyên liệu
            _buildInteractiveShakeCard(),
            const SizedBox(height: 20),

            // Thẻ "KHẢ THI NHẤT HÔM NAY"
            _buildTopMatchCard(),
            const SizedBox(height: 20),

            // Tiêu đề: Ý tưởng khác từ tủ lạnh
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'Ý tưởng khác từ tủ lạnh',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                ),
                Text(
                  'Xem tất cả',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Lưới 2 món gợi ý thêm
            Row(
              children: [
                Expanded(
                  child: _buildSmallRecipeCard(
                    imageUrl: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=500&q=80',
                    time: '10 phút',
                    title: 'Trứng Xào Súp Lơ & Cà Chua',
                    calorieNutri: '320 kcal • 18g đạm',
                    onTap: () => widget.onNavigate(6),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSmallRecipeCard(
                    imageUrl: 'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?auto=format&fit=crop&w=500&q=80',
                    time: '15 phút',
                    title: 'Ức Gà Hấp Súp Lơ Sốt Tiêu',
                    calorieNutri: '380 kcal • 42g đạm',
                    onTap: () => widget.onNavigate(6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // --- CÁC HÀM XÂY DỰNG WIDGET CON ---

  Widget _buildSourceTab(int index, IconData icon, String label) {
    final bool isSelected = _selectedSourceIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedSourceIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)] : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? AppColors.primaryDark : AppColors.textGray),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppColors.primaryDark : AppColors.textGray,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConditionChip(IconData icon, String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
          ),
        ],
      ),
    );
  }

  // Khối thẻ xúc xắc trung tâm
  Widget _buildInteractiveShakeCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFEFF6FF),
            Color(0xFFE6FFFA),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          // Khu vực vòng sóng và xúc xắc + 4 tag nguyên liệu xung quanh
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Vòng sóng tỏa ngoài
                Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5EEAD4).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                ),
                // Vòng sóng tỏa giữa
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5EEAD4).withOpacity(0.35),
                    shape: BoxShape.circle,
                  ),
                ),
                // Khối xúc xắc trung tâm
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.waves, size: 18, color: Color(0xFF00B074)),
                    const SizedBox(width: 4),
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00B074),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00B074).withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.casino_outlined, size: 42, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.waves, size: 18, color: Color(0xFF00B074)),
                  ],
                ),

                // 4 Tag nguyên liệu vệ tinh xung quanh
                Positioned(
                  top: 8,
                  left: 20,
                  child: _buildSatelliteTag('🍗 Ức gà'),
                ),
                Positioned(
                  top: 8,
                  right: 20,
                  child: _buildSatelliteTag('🥦 Súp lơ'),
                ),
                Positioned(
                  bottom: 8,
                  left: 24,
                  child: _buildSatelliteTag('🥚 2 Quả trứng'),
                ),
                Positioned(
                  bottom: 8,
                  right: 24,
                  child: _buildSatelliteTag('🍅 Cà chua bi'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Tag "Phối hợp thông minh AI"
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF6EE7B7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt_rounded, size: 13, color: AppColors.primaryDark),
                SizedBox(width: 2),
                Text(
                  'Phối hợp thông minh AI',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Tiêu đề & mô tả
          const Text(
            'Lắc nhẹ điện thoại nào! 📱✨',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textBlack),
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.0),
            child: Text(
              'AI đang xáo trộn công thức chuẩn dưới 500 kcal từ 4 nguyên liệu có sẵn trong tủ lạnh của bạn.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textGray, height: 1.35),
            ),
          ),
          const SizedBox(height: 16),

          // Nút bấm "Lắc Ngay 🎲 (Khám phá món)"
          Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryDark.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => widget.onNavigate(6), // Mở màn hình Chi tiết công thức
                borderRadius: BorderRadius.circular(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.shuffle_rounded, size: 18, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Lắc Ngay 🎲 (Khám phá món)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
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

  Widget _buildSatelliteTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textBlack),
      ),
    );
  }

  // Thẻ "KHẢ THI NHẤT HÔM NAY"
  Widget _buildTopMatchCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.accentIndigo,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.restaurant, color: AppColors.primaryDark, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Text(
                      'KHẢ THI NHẤT HÔM NAY',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                    ),
                    SizedBox(width: 6),
                    Text(
                      '98% trùng khớp',
                      style: TextStyle(fontSize: 10, color: AppColors.textLightGray),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  'Salad Ức Gà Áp Chảo & Trứng Lòng Đào',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: const [
                    Icon(Icons.access_time_rounded, size: 12, color: AppColors.textLightGray),
                    SizedBox(width: 2),
                    Text('12 phút', style: TextStyle(fontSize: 10, color: AppColors.textGray)),
                    SizedBox(width: 8),
                    Icon(Icons.local_fire_department, size: 12, color: AppColors.textLightGray),
                    SizedBox(width: 2),
                    Text('410 kcal', style: TextStyle(fontSize: 10, color: AppColors.textGray)),
                    SizedBox(width: 8),
                    Icon(Icons.fitness_center, size: 12, color: AppColors.textLightGray),
                    SizedBox(width: 2),
                    Text('38g Protein', style: TextStyle(fontSize: 10, color: AppColors.textGray)),
                  ],
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => widget.onNavigate(6),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5FD),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textGray),
            ),
          ),
        ],
      ),
    );
  }

  // Thẻ món ăn nhỏ dạng lưới
  Widget _buildSmallRecipeCard({
    required String imageUrl,
    required String time,
    required String title,
    required String calorieNutri,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  child: Image.network(
                    imageUrl,
                    height: 105,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      time,
                      style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    calorieNutri,
                    style: const TextStyle(fontSize: 10, color: AppColors.textGray, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
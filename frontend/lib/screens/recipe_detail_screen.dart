import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class RecipeDetailScreen extends StatelessWidget {
  final Function(int) onNavigate;

  const RecipeDetailScreen({
    super.key,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top App Bar tùy biến
            _buildTopAppBar(context),

            // 2. Nội dung cuộn chính
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner ảnh lớn kèm tên món & tag
                    _buildHeroBanner(),
                    const SizedBox(height: 16),

                    // Thẻ Năng lượng khẩu phần & Macro
                    _buildNutritionCard(),
                    const SizedBox(height: 24),

                    // Khối: Nguyên liệu cần chuẩn bị
                    _buildIngredientsSection(),
                    const SizedBox(height: 24),

                    // Khối: Hướng dẫn chế biến
                    _buildCookingStepsSection(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // 3. Nút cố định ở đáy: "Đã nấu xong & Thêm vào nhật ký"
            _buildBottomCta(),
          ],
        ),
      ),
    );
  }

  // --- 1. TOP APP BAR ---
  Widget _buildTopAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () => onNavigate(2), // Quay lại màn hình Thực đơn gợi ý (Index 2)
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(8),
              child: const Icon(Icons.arrow_back, color: AppColors.textBlack, size: 22),
            ),
          ),
          const Text(
            'Chi Tiet Cong Thuc',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textBlack,
            ),
          ),
          Row(
            children: const [
              Icon(Icons.bookmark_border_rounded, color: AppColors.textBlack, size: 22),
              SizedBox(width: 14),
              Icon(Icons.share_outlined, color: AppColors.textBlack, size: 20),
            ],
          ),
        ],
      ),
    );
  }

  // --- 2. BANNER ẢNH & TIÊU ĐỀ NỔI BẬT ---
  Widget _buildHeroBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          // Ảnh món ăn
          Image.network(
            'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?auto=format&fit=crop&w=800&q=80',
            height: 250,
            width: double.infinity,
            fit: BoxFit.cover,
          ),

          // Lớp phủ Gradient tối màu dần về đáy để nổi chữ
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.0),
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.85),
                  ],
                  stops: const [0.3, 0.6, 1.0],
                ),
              ),
            ),
          ),

          // Tag "Khớp 100% nguyên liệu" ở góc trên trái
          Positioned(
            top: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.92),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.auto_awesome, size: 13, color: AppColors.primaryDark),
                  SizedBox(width: 4),
                  Text(
                    'Khớp 100% nguyên liệu',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Cụm thông tin & Tên món ăn ở góc dưới
          Positioned(
            bottom: 14,
            left: 14,
            right: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00B074),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Giàu Protein',
                        style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.access_time, size: 11, color: AppColors.textBlack),
                          SizedBox(width: 3),
                          Text('15 Phút', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.speed, size: 11, color: AppColors.textBlack),
                          SizedBox(width: 3),
                          Text('Độ khó: Dễ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ức gà Áp chảo Sốt tiêu đen & Bông cải',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. THẺ NĂNG LƯỢNG & CHỈ SỐ MACRO ---
  Widget _buildNutritionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
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
          // Calo & Biểu tượng
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'NĂNG LƯỢNG KHẨU PHẦN',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textGray),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: const [
                      Text(
                        '380',
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'kcal / suất',
                        style: TextStyle(fontSize: 12, color: AppColors.textGray, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5FD),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.apple_outlined, color: AppColors.primaryDark, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3 Hộp Macro
          Row(
            children: [
              Expanded(child: _buildMacroBox('Đạm (Protein)', '42g', 0.8, const Color(0xFF00B074))),
              const SizedBox(width: 8),
              Expanded(child: _buildMacroBox('Tinh bột', '14g', 0.35, const Color(0xFF64748B))),
              const SizedBox(width: 8),
              Expanded(child: _buildMacroBox('Chất béo', '8g', 0.25, const Color(0xFF94A3B8))),
            ],
          ),
          const SizedBox(height: 14),

          // Banner thông điệp xanh ngọc
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: const [
                Icon(Icons.check_circle, size: 16, color: Color(0xFF16A34A)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tuyệt vời cho mục tiêu: Đáp ứng 75% lượng protein bạn còn thiếu cho bữa tối hôm nay.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF15803D),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroBox(String label, String value, double progress, Color barColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.accentIndigo.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textGray)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textBlack),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ],
      ),
    );
  }

  // --- 4. KHỐI NGUYÊN LIỆU CẦN CHUẨN BỊ ---
  Widget _buildIngredientsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              'Nguyên liệu cần chuẩn bị',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textBlack),
            ),
            Text(
              '7 món',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Thẻ 1: Đã quét từ tủ lạnh
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.kitchen_outlined, size: 16, color: AppColors.primaryDark),
                      SizedBox(width: 6),
                      Text('Đã quét từ tủ lạnh', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('Khớp 100%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildIngredientRow('Ức gà phi lê không da', '200g'),
              _buildIngredientRow('Búp súp lơ xanh tươi', '150g'),
              _buildIngredientRow('Cà chua bi mọng nước', '6 quả'),
              _buildIngredientRow('Trứng gà ta (dùng cho sốt)', '1 quả', isLast: true),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Thẻ 2: Gia vị tủ bếp có sẵn
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Row(
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.textGray),
                      SizedBox(width: 6),
                      Text('Gia vị tủ bếp có sẵn', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
                    ],
                  ),
                  Text('3 món', style: TextStyle(fontSize: 11, color: AppColors.textLightGray)),
                ],
              ),
              const SizedBox(height: 12),
              _buildIngredientRow('Dầu ô liu nguyên chất', '1 muỗng cafe'),
              _buildIngredientRow('Muối biển & tiêu đen xay vỡ', '1 nhúm'),
              _buildIngredientRow('Tỏi & gừng băm nhuyễn', '10g', isLast: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientRow(String name, String quantity, {bool isLast = false}) {
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: const Color(0xFF00B074),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.check, size: 12, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textBlack),
            ),
          ),
          Text(
            quantity,
            style: const TextStyle(fontSize: 11, color: AppColors.textGray, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // --- 5. KHỐI HƯỚNG DẪN CHẾ BIẾN ---
  Widget _buildCookingStepsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hướng dẫn chế biến',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textBlack),
        ),
        const SizedBox(height: 12),

        // Bước 1
        _buildCookingStepCard(
          stepNumber: '1',
          title: 'Sơ chế & Ướp ức gà',
          time: '5 phút',
          description:
              'Rửa sạch ức gà, dùng khăn giấy thấm thật ráo nước. Khía các đường chéo nhẹ lên bề mặt rồi ướp cùng tỏi băm, một nhúm nhỏ muối biển và tiêu đen vỡ để ngấm vị.',
          tipText: 'Mẹo nhỏ: Ướp ít muối giúp thịt giữ độ ngọt tự nhiên và không tích nước.',
        ),
        const SizedBox(height: 12),

        // Bước 2
        _buildCookingStepCard(
          stepNumber: '2',
          title: 'Áp chảo vàng mọng nước',
          time: '6 phút',
          description:
              'Làm nóng chảo chống dính với 1 muỗng dầu ô liu. Đặt ức gà vào áp chảo lửa vừa mỗi mặt 3 phút cho đến khi vỏ ngoài vàng óng, phần thịt bên trong mềm mọng.',
        ),
        const SizedBox(height: 12),

        // Bước 3
        _buildCookingStepCard(
          stepNumber: '3',
          title: 'Hấp bông cải & Cà chua bi',
          time: '4 phút',
          description:
              'Tách bông cải thành từng búp vừa ăn, hấp cách thủy cùng cà chua bi trong 4 phút để giữ trọn vẹn màu xanh tươi và vitamin C. Bày ra đĩa cùng ức gà thái lát.',
        ),
      ],
    );
  }

  Widget _buildCookingStepCard({
    required String stepNumber,
    required String title,
    required String time,
    required String description,
    String? tipText,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: AppColors.primaryDark,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    stepNumber,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                ),
              ),
              Text(
                time,
                style: const TextStyle(fontSize: 10, color: AppColors.textLightGray),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.4),
          ),
          if (tipText != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accentIndigo.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, size: 14, color: AppColors.primaryDark),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tipText,
                      style: const TextStyle(fontSize: 11, color: AppColors.textGray, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- 6. NÚT ĐÁY CTA ---
  Widget _buildBottomCta() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00B074),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
          onPressed: () {
            // Quay về màn hình Trang chủ (Index 0) sau khi ghi nhận
            onNavigate(0);
          },
          icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
          label: const Text(
            'Đã nấu xong & Thêm vào nhật ký (+380 kcal)',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
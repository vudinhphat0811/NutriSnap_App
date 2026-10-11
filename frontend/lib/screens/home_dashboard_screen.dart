import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../widgets/calorie_ring_painter.dart';

class HomeDashboardScreen extends StatelessWidget {
  final Function(int) onNavigate;
  const HomeDashboardScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                'NutriSnap',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textBlack),
              ),
            ),
            const SizedBox(height: 16),
            _buildHeader(),
            const SizedBox(height: 16),
            _buildCalorieCard(),
            const SizedBox(height: 16),
            _buildQuickActions(),
            const SizedBox(height: 16),
            _buildWaterTracker(),
            const SizedBox(height: 20),
            _buildMealLogSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Chào Bạn 👋', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
              SizedBox(height: 2),
              Text('Hôm nay ăn gì để chuẩn dáng?', style: TextStyle(fontSize: 12, color: AppColors.textGray)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: AppColors.accentIndigo, borderRadius: BorderRadius.circular(20)),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_fire_department, size: 14, color: AppColors.textGray),
              SizedBox(width: 4),
              Text('5 ngày', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.notifications_none_rounded, size: 20, color: AppColors.textBlack),
            ),
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCalorieCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('HẤP THU HÔM NAY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textGray)),
                  const SizedBox(height: 2),
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(text: '1.250 ', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
                        TextSpan(text: '/ 1.950 kcal', style: TextStyle(fontSize: 13, color: AppColors.textLightGray)),
                      ],
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: AppColors.accentIndigo, borderRadius: BorderRadius.circular(16)),
                child: const Text('Mục tiêu giảm mỡ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 125,
                    height: 125,
                    child: CustomPaint(painter: CalorieRingPainter(progress: 0.64)),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text('700', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                      Text('kcal còn lại', style: TextStyle(fontSize: 11, color: AppColors.textGray)),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    _buildNutriRow('Tinh bột', '135/210g', 135 / 210, const Color(0xFF5EEAD4)),
                    const SizedBox(height: 10),
                    _buildNutriRow('Đạm', '88/120g', 88 / 120, AppColors.primary),
                    const SizedBox(height: 10),
                    _buildNutriRow('Chất béo', '32/55g', 32 / 55, const Color(0xFF475569)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => onNavigate(2), // Dẫn sang trang Gợi ý bữa tối
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: AppColors.accentIndigo.withOpacity(0.5), borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: const [
                  Icon(Icons.restaurant, size: 18, color: AppColors.primaryDark),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Còn đủ 700 kcal cho một bữa tối giàu đạm!', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textBlack)),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: AppColors.textGray),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutriRow(String name, String value, double progress, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textBlack)),
            const Spacer(),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textGray)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: AppColors.accentIndigo,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => onNavigate(4), // Dẫn sang quét tủ lạnh
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.primaryDark, borderRadius: BorderRadius.circular(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 18),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                        child: const Text('AI SCAN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Quét Tủ Lạnh', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 2),
                  const Text('Gợi ý từ đồ sẵn có', style: TextStyle(fontSize: 11, color: Colors.white70)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Quét ngay', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.white),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: () => onNavigate(5), // Dẫn sang lắc món ăn
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.accentIndigo, borderRadius: BorderRadius.circular(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
                        ),
                        child: const Icon(Icons.casino_outlined, color: Colors.black87, size: 18),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFFD6E4FC), borderRadius: BorderRadius.circular(8)),
                        child: const Text('< 700 kcal', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Lắc Chọn Món', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
                  const SizedBox(height: 2),
                  const Text('Lọc nguyên liệu & lắc!', style: TextStyle(fontSize: 11, color: AppColors.textGray)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Lắc ngay', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                        SizedBox(width: 4),
                        Icon(Icons.shuffle_rounded, size: 12, color: AppColors.primaryDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWaterTracker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(color: AppColors.accentIndigo, shape: BoxShape.circle),
            child: const Icon(Icons.water_drop_outlined, size: 18, color: AppColors.primaryDark),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Nước hôm nay', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: AppColors.accentMint, borderRadius: BorderRadius.circular(10)),
                      child: const Text('1.5 / 2.0L', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(
                    value: 1.5 / 2.0,
                    minHeight: 5,
                    backgroundColor: AppColors.accentIndigo,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(color: AppColors.accentIndigo, shape: BoxShape.circle),
            child: const Icon(Icons.add, size: 18, color: AppColors.primaryDark),
          ),
        ],
      ),
    );
  }

  Widget _buildMealLogSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Nhật ký bữa ăn', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
            InkWell(
              onTap: () => onNavigate(1), // Dẫn sang tab Nhật ký
              child: const Text('Chi tiết', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildMealCard(
          'BỮA SÁNG',
          'Yến mạch & Sữa chua Hy Lạp',
          '08:15 • 380 kcal',
          '380 kcal',
          'https://images.unsplash.com/photo-1517673400267-0251440c45dc?auto=format&fit=crop&w=400&q=80',
        ),
        const SizedBox(height: 10),
        _buildMealCard(
          'BỮA TRƯA',
          'Cơm ức gà áp chảo sốt tiêu',
          '12:30 • 520 kcal',
          '520 kcal',
          'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=400&q=80',
        ),
        const SizedBox(height: 10),
        _buildDinnerPendingCard(),
      ],
    );
  }

  Widget _buildMealCard(String session, String title, String timeCal, String calories, String img) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(img, width: 50, height: 50, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(session, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textGray)),
                    const SizedBox(width: 4),
                    const Icon(Icons.check_circle_outline, size: 12, color: AppColors.primary),
                  ],
                ),
                const SizedBox(height: 3),
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
                const SizedBox(height: 2),
                Text(timeCal, style: const TextStyle(fontSize: 11, color: AppColors.textLightGray)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: AppColors.accentIndigo, borderRadius: BorderRadius.circular(10)),
            child: Text(calories, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
          ),
        ],
      ),
    );
  }

  Widget _buildDinnerPendingCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accentIndigo.withOpacity(0.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: const [
              Icon(Icons.circle, size: 8, color: AppColors.primaryDark),
              SizedBox(width: 6),
              Text('BỮA TỐI • ĐANG CHỜ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
              Spacer(),
              Text('Mục tiêu: 700 kcal', style: TextStyle(fontSize: 11, color: AppColors.textGray)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.dinner_dining, color: AppColors.primaryDark, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Chưa ghi nhận món tối', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
                    Text('Quét nguyên liệu hoặc Lắc để gợi ý thực đơn thích hợp', style: TextStyle(fontSize: 11, color: AppColors.textGray)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => onNavigate(4), // Quét nguyên liệu
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(color: AppColors.primaryDark, borderRadius: BorderRadius.circular(12)),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text('Chụp nguyên liệu', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: const Row(
                  children: [
                    Icon(Icons.add, color: AppColors.primaryDark, size: 16),
                    SizedBox(width: 4),
                    Text('Ghi nhanh', style: TextStyle(color: AppColors.primaryDark, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
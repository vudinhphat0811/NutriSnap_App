import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class IngredientScanScreen extends StatefulWidget {
  final Function(int) onNavigate;

  const IngredientScanScreen({
    super.key,
    required this.onNavigate,
  });

  @override
  State<IngredientScanScreen> createState() => _IngredientScanScreenState();
}

class _IngredientScanScreenState extends State<IngredientScanScreen> {
  int _selectedGoalIndex = 0;
  final List<String> _goals = ['Giàu Protein', 'Ít Calo (<400 kcal)', 'Nấu nhanh (<15p)'];
  final List<String> _spices = ['Tiêu đen xay', 'Dầu oliu', 'Muối biển'];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tiêu đề đầu trang
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

            // Top Bar: Nút Back + Tiêu đề + Nút Chụp lại
            _buildTopBar(),
            const SizedBox(height: 16),

            // Khung hiển thị ảnh chụp nguyên liệu kèm nhãn AI Scan
            _buildCapturedImageBanner(),
            const SizedBox(height: 20),

            // Mục tiêu dinh dưỡng (Tags)
            _buildNutritionGoalsSection(),
            const SizedBox(height: 20),

            // Danh sách nguyên liệu cốt lõi (Grid 2x2)
            _buildCoreIngredientsSection(),
            const SizedBox(height: 16),

            // Ô nhập thêm gia vị tủ bếp & Danh sách tag gia vị
            _buildSpiceSection(),
            const SizedBox(height: 16),

            // Thẻ phân tích AI: Tối ưu calo thông minh & Độ cân bằng vi chất
            _buildAiInsightCard(),
            const SizedBox(height: 20),

            // Nút hành động chính: Chuyển sang màn hình Gợi ý món ăn (Index 2)
            _buildCtaButton(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // --- CÁC THÀNH PHẦN GIAO DIỆN ---

  Widget _buildTopBar() {
    return Row(
      children: [
        InkWell(
          onTap: () => widget.onNavigate(0), // Quay về Trang chủ (Index 0)
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
                'Nguyên liệu nhận diện',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textBlack),
              ),
              Text(
                'Phân tích thị giác AI',
                style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.accentIndigo,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.camera_alt_outlined, size: 14, color: AppColors.primaryDark),
              SizedBox(width: 4),
              Text(
                'Chụp lại',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCapturedImageBanner() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.network(
            'https://images.unsplash.com/photo-1543339308-43e59d6b73a6?auto=format&fit=crop&w=800&q=80',
            height: 190,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          left: 12,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.92),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 11, color: Color(0xFF334155)),
                    children: [
                      TextSpan(text: 'NutriVision AI • Đã tìm thấy '),
                      TextSpan(
                        text: '4 nguyên liệu',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                      ),
                      TextSpan(text: ' (98%)'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.fullscreen_rounded, size: 20, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildNutritionGoalsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              'Mục tiêu dinh dưỡng',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textGray),
            ),
            Text(
              '⚙ Tùy chỉnh',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: List.generate(_goals.length, (index) {
              final isSelected = _selectedGoalIndex == index;
              return GestureDetector(
                onTap: () => setState(() => _selectedGoalIndex = index),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF6EE7B7) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected ? Colors.transparent : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected) ...[
                        const Icon(Icons.check_circle, size: 14, color: AppColors.primaryDark),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        _goals[index],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? AppColors.primaryDark : const Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildCoreIngredientsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              'Nguyên liệu cốt lõi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textBlack),
            ),
            Text(
              'Nhấn ✕ để bỏ bớt',
              style: TextStyle(fontSize: 11, color: AppColors.textLightGray),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildIngredientCard(
                icon: Icons.set_meal_outlined,
                name: 'Ức gà tươi',
                weight: '~250g',
                metricLabel: 'Chỉ số',
                metricValue: '41g Protein',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildIngredientCard(
                icon: Icons.eco_outlined,
                name: 'Bông cải xanh',
                weight: '~180g',
                metricLabel: 'Chỉ số',
                metricValue: 'Giàu chất xơ',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildIngredientCard(
                icon: Icons.egg_outlined,
                name: '2 Trứng gà',
                weight: '~110g',
                metricLabel: 'Năng lượng',
                metricValue: '140 kcal',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildIngredientCard(
                icon: Icons.circle_outlined,
                name: 'Cà chua bi',
                weight: '~90g',
                metricLabel: 'Dưỡng chất',
                metricValue: 'Vitamin C',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIngredientCard({
    required IconData icon,
    required String name,
    required String weight,
    required String metricLabel,
    required String metricValue,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.accentIndigo,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppColors.primaryDark),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
                    Text(weight, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ],
                ),
              ),
              InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                  child: const Icon(Icons.close, size: 12, color: AppColors.textGray),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(metricLabel, style: const TextStyle(fontSize: 11, color: AppColors.textGray)),
                Text(metricValue, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpiceSection() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.accentIndigo.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.soup_kitchen_outlined, size: 18, color: AppColors.textGray),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Thêm gia vị tủ bếp (dầu hào, tiêu, tỏi...)',
                  style: TextStyle(fontSize: 12, color: AppColors.textLightGray),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add, size: 16, color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: _spices.map((spice) {
            return Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.accentIndigo,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    spice,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.close, size: 12, color: AppColors.textGray),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAiInsightCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentIndigo.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tối ưu hóa Calo thông minh',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Nhóm nguyên liệu này hoàn hảo cho ngân sách 700 kcal còn lại của bạn trong ngày.',
                      style: TextStyle(fontSize: 11, color: AppColors.textGray, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 38,
                  height: 38,
                  child: Stack(
                    alignment: Alignment.center,
                    children: const [
                      CircularProgressIndicator(
                        value: 0.68,
                        strokeWidth: 4,
                        backgroundColor: AppColors.accentIndigo,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                      Text('68%', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Độ cân bằng vi chất', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
                      Text('Đạt chuẩn bữa ăn phục hồi cơ', style: TextStyle(fontSize: 10, color: AppColors.textGray)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6EE7B7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Tối ưu', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCtaButton() {
    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onNavigate(2), // Nhấn nút sẽ chuyển sang tab Thực đơn gợi ý (Index 2)
          borderRadius: BorderRadius.circular(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text(
                'Gợi ý danh sách món ăn phù hợp (AI)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              SizedBox(width: 6),
              Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
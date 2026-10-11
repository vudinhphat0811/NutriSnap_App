import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _shakeSensitivity = 1; // 0: Nhẹ, 1: Vừa, 2: Mạnh
  bool _waterReminder = true;

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

            // Header: Tiêu đề màn hình & nút sửa
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Hồ sơ cá nhân',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textBlack,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Quản lý thể trạng & cài đặt gợi ý AI',
                      style: TextStyle(fontSize: 12, color: AppColors.textGray),
                    ),
                  ],
                ),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.accentIndigo,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primaryDark),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Card thông tin tài khoản & Gói Pro
            _buildUserAccountCard(),
            const SizedBox(height: 20),

            // Mục: Chỉ số thể trạng
            _buildSectionTitle('Chỉ số thể trạng', 'Cập nhật 2 ngày trước'),
            const SizedBox(height: 10),
            _buildBodyMetricsGrid(),
            const SizedBox(height: 20),

            // Mục: Thiết lập dinh dưỡng & AI
            const Text(
              'Thiết lập dinh dưỡng & AI',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textBlack),
            ),
            const SizedBox(height: 10),
            _buildNutritionAISettings(),
            const SizedBox(height: 20),

            // Mục: Tiện ích & Ứng dụng
            const Text(
              'Tiện ích & Ứng dụng',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textBlack),
            ),
            const SizedBox(height: 10),
            _buildUtilitySettings(),
            const SizedBox(height: 20),

            // Nút Đăng xuất
            Container(
              width: double.infinity,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEB),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {},
                  borderRadius: BorderRadius.circular(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.logout_rounded, size: 18, color: Color(0xFFDC2626)),
                      SizedBox(width: 6),
                      Text(
                        'Đăng xuất',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Footer bản quyền & phiên bản
            Center(
              child: Column(
                children: const [
                  Text(
                    'NutriSnap v1.0.2 • Dữ liệu mã hóa an toàn',
                    style: TextStyle(fontSize: 10, color: AppColors.textLightGray),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Tuân thủ tiêu chuẩn bảo mật y tế cá nhân',
                    style: TextStyle(fontSize: 10, color: AppColors.textLightGray),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // 1. Thẻ tài khoản & Nâng cấp Pro
  Widget _buildUserAccountCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Nguyễn Văn A',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accentIndigo,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Free Plan',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'abc@example.com',
                      style: TextStyle(fontSize: 11, color: AppColors.textLightGray),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.local_fire_department, size: 12, color: Color(0xFFE11D48)),
                          SizedBox(width: 3),
                          Text(
                            'Chuỗi 18 ngày kiên trì',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFE11D48)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.accentIndigo.withOpacity(0.6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: const [
                Icon(Icons.stars_rounded, size: 18, color: AppColors.primaryDark),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Mở khóa NutriSnap AI Pro',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: AppColors.textGray),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 2. Lưới 4 chỉ số thể trạng
  Widget _buildBodyMetricsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'CÂN NẶNG',
                icon: Icons.scale_outlined,
                value: '68.0',
                unit: 'kg',
                subText: 'Mục tiêu: 65.0 kg (-3kg)',
                badgeText: null,
                badgeColor: null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                title: 'CHIỀU CAO',
                icon: Icons.height_rounded,
                value: '175',
                unit: 'cm',
                subText: 'Vóc dáng: cân đối',
                badgeText: null,
                badgeColor: null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'CHỈ SỐ BMI',
                icon: Icons.speed_rounded,
                value: '22.2',
                unit: '',
                subText: '',
                badgeText: 'Chuẩn dáng',
                badgeColor: const Color(0xFF6EE7B7),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                title: 'NẠP MỖI NGÀY',
                icon: Icons.donut_large_rounded,
                value: '1.950',
                unit: 'kcal',
                subText: 'Duy trì trao đổi chất',
                badgeText: null,
                badgeColor: null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required IconData icon,
    required String value,
    required String unit,
    required String subText,
    String? badgeText,
    Color? badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textGray)),
              Icon(icon, size: 14, color: AppColors.primaryDark),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textBlack),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 3),
                Text(unit, style: const TextStyle(fontSize: 10, color: AppColors.textGray)),
              ],
            ],
          ),
          const SizedBox(height: 4),
          if (badgeText != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(8)),
              child: Text(
                badgeText,
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
              ),
            )
          else
            Text(subText, style: const TextStyle(fontSize: 10, color: AppColors.textLightGray)),
        ],
      ),
    );
  }

  // 3. Khối thiết lập dinh dưỡng & AI
  Widget _buildNutritionAISettings() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          _buildActionItem(
            icon: Icons.open_with_rounded,
            iconBg: const Color(0xFFE0F2FE),
            iconColor: const Color(0xFF0284C7),
            title: 'Mục tiêu sức khỏe',
            subtitle: 'Tăng cơ & Giảm mỡ',
            trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textGray),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEDD5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.restaurant, size: 16, color: Color(0xFFEA580C)),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dị ứng thực phẩm', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
                          Text('AI tự động loại trừ khỏi bữa ăn', style: TextStyle(fontSize: 10, color: AppColors.textLightGray)),
                        ],
                      ),
                    ),
                    const Text('+ Thêm', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildChip('Đậu phộng ✕'),
                    const SizedBox(width: 6),
                    _buildChip('Hải sản có vỏ ✕'),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          _buildActionItem(
            icon: Icons.thumb_down_outlined,
            iconBg: AppColors.accentIndigo,
            iconColor: const Color(0xFF6366F1),
            title: 'Thực phẩm không thích',
            subtitle: 'Khổ qua, Rau ngò (ngò rí)',
            trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textGray),
          ),
        ],
      ),
    );
  }

  // 4. Khối tiện ích & ứng dụng
  Widget _buildUtilitySettings() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          // Độ nhạy tính năng Lắc
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: AppColors.accentIndigo, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.vibration, size: 16, color: Color(0xFF4F46E5)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Độ nhạy tính năng Lắc (Shake)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
                    Text('Lắc máy để gợi ý món tức thì', style: TextStyle(fontSize: 10, color: AppColors.textLightGray)),
                  ],
                ),
              ),
              const Text('Vừa', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: AppColors.accentIndigo, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                _buildSegment('Nhẹ', 0),
                _buildSegment('Vừa', 1),
                _buildSegment('Mạnh', 2),
              ],
            ),
          ),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),

          // Nhắc uống nước
          _buildActionItem(
            icon: Icons.alarm,
            iconBg: const Color(0xFFE0F2FE),
            iconColor: const Color(0xFF0284C7),
            title: 'Nhắc uống nước & ăn uống',
            subtitle: 'Thông báo thông minh theo nhịp sinh học',
            trailing: Switch(
              value: _waterReminder,
              activeColor: AppColors.primary,
              onChanged: (val) => setState(() => _waterReminder = val),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Đồng bộ Apple Health & Google Fit
          _buildActionItem(
            icon: Icons.health_and_safety_outlined,
            iconBg: const Color(0xFFDCFCE7),
            iconColor: const Color(0xFF16A34A),
            title: 'Apple Health & Google Fit',
            subtitle: 'Tự động đồng bộ bước chân & calo tiêu hao',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Đã kết nối', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                  SizedBox(width: 2),
                  Icon(Icons.check_circle, size: 10, color: Color(0xFF16A34A)),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Món ăn đã lưu
          _buildActionItem(
            icon: Icons.bookmark_outline_rounded,
            iconBg: AppColors.accentIndigo,
            iconColor: const Color(0xFF6366F1),
            title: 'Món ăn đã lưu',
            subtitle: '12 công thức yêu thích',
            trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textGray),
          ),
        ],
      ),
    );
  }

  // --- CÁC WIDGET PHỤ TRỢ ---

  Widget _buildSectionTitle(String title, String action) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
        Text(action, style: const TextStyle(fontSize: 11, color: AppColors.textLightGray)),
      ],
    );
  }

  Widget _buildChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: AppColors.accentIndigo, borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textBlack)),
    );
  }

  Widget _buildSegment(String text, int index) {
    final bool active = _shakeSensitivity == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _shakeSensitivity = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)] : null,
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: active ? AppColors.primaryDark : AppColors.textGray,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
                Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.textLightGray)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
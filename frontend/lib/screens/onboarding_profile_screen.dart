import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/app_state_service.dart';
import '../main.dart';
import 'login_screen.dart';

class OnboardingProfileScreen extends StatefulWidget {
  final String? initialEmail;
  final String? initialName;

  const OnboardingProfileScreen({
    super.key,
    this.initialEmail,
    this.initialName,
  });

  @override
  State<OnboardingProfileScreen> createState() => _OnboardingProfileScreenState();
}

class _OnboardingProfileScreenState extends State<OnboardingProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _targetWeightController = TextEditingController();

  String _gender = 'Nam';
  String _goal = 'LoseWeight';
  String _dietType = 'HighProtein';
  String _activityLevel = 'Moderate';

  @override
  void initState() {
    super.initState();
    final profile = AppStateService.instance.userProfile;
    final candidateName = widget.initialName?.trim() ??
        (profile.fullName.isNotEmpty &&
                profile.fullName != 'Người dùng NutriSnap' &&
                profile.fullName != 'Người dùng mới'
            ? profile.fullName
            : '');
    if (candidateName.isNotEmpty) {
      _nameController.text = candidateName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _targetWeightController.dispose();
    super.dispose();
  }

  // Tính thử BMI trực tiếp khi người dùng nhập
  double? get _calculatedBmi {
    final h = double.tryParse(_heightController.text.trim());
    final w = double.tryParse(_weightController.text.trim());
    if (h == null || w == null || h <= 0 || w <= 0) return null;
    final hM = h / 100.0;
    return double.parse((w / (hM * hM)).toStringAsFixed(1));
  }

  String _getBmiCategory(double bmi) {
    if (bmi < 18.5) return 'Gầy / Thiếu cân';
    if (bmi < 23.0) return 'Chuẩn / Khỏe mạnh';
    if (bmi < 25.0) return 'Tiền béo phì';
    return 'Thừa cân / Cần giảm mỡ';
  }

  void _submitProfile() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final effectiveName = name.isNotEmpty
        ? name
        : (widget.initialName?.trim().isNotEmpty == true
            ? widget.initialName!.trim()
            : 'Người dùng NutriSnap');
    final age = int.parse(_ageController.text.trim());
    final height = double.parse(_heightController.text.trim());
    final weight = double.parse(_weightController.text.trim());
    final targetWeight = double.tryParse(_targetWeightController.text.trim()) ?? weight;

    // Reset nhật ký và nước uống về 0 cho người dùng mới
    AppStateService.instance.mealLogs.clear();
    AppStateService.instance.waterIntakeMl = 0;
    AppStateService.instance.streakDays = 1;

    // Cập nhật số liệu vào AppStateService
    AppStateService.instance.updateProfileMetrics(
      fullName: effectiveName,
      gender: _gender,
      age: age,
      heightCm: height,
      weightKg: weight,
      targetWeightKg: targetWeight,
      goal: _goal,
      dietType: _dietType,
      activityLevel: _activityLevel,
    );

    if (widget.initialEmail != null && widget.initialEmail!.trim().isNotEmpty) {
      AppStateService.instance.userProfile.email = widget.initialEmail!.trim();
      AppStateService.instance.saveToLocalStorage();
    }

    // Đồng bộ chỉ số lên máy chủ backend C# nếu có phiên đăng nhập
    AppStateService.instance.syncProfileToServer();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎉 Thiết lập chỉ số thành công! Chào mừng bạn đến với NutriSnap!'),
        backgroundColor: AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Chuyển sang màn hình chính của ứng dụng
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const MobileWrapper(child: MainShellScreen()),
      ),
    );
  }

  Future<void> _handleExitOrLogout(BuildContext context) async {
    final bool? shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.red, size: 24),
            SizedBox(width: 10),
            Text('Đăng Xuất / Đổi Tài Khoản', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Bạn có chắc chắn muốn thoát về màn hình Đăng nhập không? Thông tin đang nhập sẽ không được lưu.',
          style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Ở lại', style: TextStyle(color: AppColors.textGray, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Đăng Xuất', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (shouldExit == true && context.mounted) {
      await AppStateService.instance.clearLocalStorage();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Bar: Nút Đăng xuất / Quay lại
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () => _handleExitOrLogout(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.textGray),
                            SizedBox(width: 4),
                            Text(
                              'Đăng nhập',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textGray),
                            ),
                          ],
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _handleExitOrLogout(context),
                      icon: const Icon(Icons.logout_rounded, size: 16, color: Colors.red),
                      label: const Text(
                        'Đăng xuất',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Header
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(color: AppColors.accentMint, shape: BoxShape.circle),
                    child: const Icon(Icons.fitness_center_rounded, color: AppColors.primaryDark, size: 32),
                  ),
                ),
                const SizedBox(height: 12),
                const Center(
                  child: Text(
                    'Thiết Lập Chỉ Số Bản Thân',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                  ),
                ),
                const SizedBox(height: 4),
                const Center(
                  child: Text(
                    'Để NutriSnap tính toán calo và gợi ý món ăn chuẩn xác nhất',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.textGray),
                  ),
                ),
                const SizedBox(height: 24),

                // PHẦN 1: THÔNG TIN CƠ BẢN
                _buildSectionHeader('1. Thông tin cá nhân'),
                const SizedBox(height: 10),
                _buildTextField(
                  label: 'Họ và tên của bạn',
                  hintText: 'Nhập họ và tên',
                  controller: _nameController,
                  icon: Icons.person_outline,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Vui lòng nhập họ và tên' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Giới tính', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textGray)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _buildGenderChip('Nam', Icons.male),
                              const SizedBox(width: 8),
                              _buildGenderChip('Nữ', Icons.female),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        label: 'Tuổi',
                        hintText: 'VD: 24',
                        controller: _ageController,
                        icon: Icons.cake_outlined,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Nhập tuổi';
                          final n = int.tryParse(v.trim());
                          if (n == null || n < 10 || n > 120) return 'Từ 10-120';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // PHẦN 2: THỂ TRẠNG HIỆN TẠI
                _buildSectionHeader('2. Chỉ số cơ thể'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        label: 'Chiều cao (cm)',
                        hintText: 'VD: 172',
                        controller: _heightController,
                        icon: Icons.height,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Nhập chiều cao';
                          final n = double.tryParse(v.trim());
                          if (n == null || n < 80 || n > 250) return 'Từ 80-250cm';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTextField(
                        label: 'Cân nặng (kg)',
                        hintText: 'VD: 68',
                        controller: _weightController,
                        icon: Icons.monitor_weight_outlined,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Nhập cân nặng';
                          final n = double.tryParse(v.trim());
                          if (n == null || n < 25 || n > 250) return 'Từ 25-250kg';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTextField(
                        label: 'Mục tiêu (kg)',
                        hintText: 'VD: 65',
                        controller: _targetWeightController,
                        icon: Icons.flag_outlined,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v != null && v.trim().isNotEmpty) {
                            final n = double.tryParse(v.trim());
                            if (n == null || n < 25 || n > 250) return 'Từ 25-250kg';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Hiển thị chỉ số BMI tính thử
                Builder(
                  builder: (_) {
                    final bmi = _calculatedBmi;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: bmi != null ? AppColors.primary.withValues(alpha: 0.3) : Colors.transparent),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            bmi != null ? 'BMI ước tính: $bmi' : 'Nhập chiều cao & cân nặng để tính BMI',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                          ),
                          const Spacer(),
                          if (bmi != null)
                            Text(
                              _getBmiCategory(bmi),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // PHẦN 3: MỤC TIÊU SỨC KHỎE
                _buildSectionHeader('3. Mục tiêu của bạn'),
                const SizedBox(height: 10),
                _buildGoalOption('LoseWeight', 'Giảm cân & Đốt mỡ', 'Thâm hụt calo, ưu tiên giảm mỡ thừa', Icons.trending_down),
                _buildGoalOption('Maintain', 'Duy trì & Giữ dáng', 'Cân bằng calo, săn chắc cơ thể', Icons.balance),
                _buildGoalOption('GainWeight', 'Tăng cơ & Tăng cân', 'Dư thừa calo lành mạnh, tăng cơ bắp', Icons.trending_up),
                const SizedBox(height: 20),

                // PHẦN 4: CHẾ ĐỘ ĂN UỐNG
                _buildSectionHeader('4. Chế độ ăn uống ưu tiên'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildDietChip('HighProtein', '🥩 Giàu đạm (High Protein)'),
                    _buildDietChip('LowCarb', '🥑 Ít tinh bột (Low Carb)'),
                    _buildDietChip('Balanced', '🥗 Cân bằng dinh dưỡng'),
                    _buildDietChip('Vegetarian', '🥦 Ăn chay (Vegetarian)'),
                  ],
                ),
                const SizedBox(height: 20),

                // PHẦN 5: MỨC ĐỘ HOẠT ĐỘNG
                _buildSectionHeader('5. Mức độ vận động hàng ngày'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildActivityChip('Sedentary', 'Ít vận động\n(Văn phòng)'),
                    const SizedBox(width: 8),
                    _buildActivityChip('Moderate', 'Vừa phải\n(1-3 buổi/tuần)'),
                    const SizedBox(width: 8),
                    _buildActivityChip('Active', 'Năng động\n(4-6 buổi/tuần)'),
                  ],
                ),
                const SizedBox(height: 28),

                // NÚT HOÀN TẤT
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      elevation: 2,
                    ),
                    child: const Text(
                      'Hoàn Tất & Bắt Đầu Trải Nghiệm 🚀',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // NÚT ĐĂNG XUẤT / ĐỔI TÀI KHOẢN PHỤ
                Center(
                  child: TextButton.icon(
                    onPressed: () => _handleExitOrLogout(context),
                    icon: const Icon(Icons.logout_rounded, size: 16, color: AppColors.textGray),
                    label: const Text(
                      'Đăng xuất hoặc Đổi tài khoản khác',
                      style: TextStyle(fontSize: 13, color: AppColors.textGray, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textBlack),
    );
  }

  Widget _buildTextField({
    required String label,
    String? hintText,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6)],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textBlack),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 12, color: AppColors.textGray),
          hintText: hintText,
          hintStyle: const TextStyle(fontSize: 12, color: AppColors.textLightGray, fontWeight: FontWeight.normal),
          prefixIcon: Icon(icon, size: 18, color: AppColors.primary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildGenderChip(String val, IconData icon) {
    final isSelected = _gender == val;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _gender = val),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accentMint : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? AppColors.primaryDark : AppColors.textGray),
              const SizedBox(width: 4),
              Text(
                val,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppColors.primaryDark : AppColors.textBlack,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoalOption(String value, String title, String subtitle, IconData icon) {
    final isSelected = _goal == value;
    return InkWell(
      onTap: () => setState(() => _goal = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentIndigo : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: isSelected ? Colors.white : AppColors.textBlack),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textGray)),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDietChip(String value, String label) {
    final isSelected = _dietType == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: isSelected ? Colors.white : AppColors.textBlack,
      ),
      onSelected: (_) => setState(() => _dietType = value),
    );
  }

  Widget _buildActivityChip(String value, String label) {
    final isSelected = _activityLevel == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activityLevel = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accentMint : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isSelected ? AppColors.primaryDark : AppColors.textGray,
            ),
          ),
        ),
      ),
    );
  }
}

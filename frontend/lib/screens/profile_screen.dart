import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_translations.dart';
import '../services/app_state_service.dart';
import '../services/meal_db_service.dart';
import '../services/recipe_translator.dart';
import '../widgets/user_avatar_widget.dart';
import '../widgets/social_auth_helper.dart';
import '../main.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  final Function(int)? onNavigate;

  const ProfileScreen({super.key, this.onNavigate});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final appState = AppStateService.instance;
  bool _waterReminder = true;
  int _shakeSensitivity = 1; // 0: Nhẹ, 1: Vừa, 2: Mạnh

  List<MealItem> _dietMatchedMeals = [];
  bool _isLoadingMeals = false;

  int _refreshCount = 0;

  @override
  void initState() {
    super.initState();
    appState.addListener(_onStateChanged);
    _loadMatchedMeals();
  }

  @override
  void dispose() {
    appState.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) {
      setState(() {});
      _loadMatchedMeals();
    }
  }

  /// Gọi Thuật toán Backend (C# Backend) để lấy món gợi ý khớp với mục tiêu & chế độ ăn
  /// Mỗi ngày hiển thị bộ món khác nhau (trùng 1-2 món với hôm trước)
  /// Mỗi lần ấn nút Đổi món (_refreshCount++) sẽ đổi sang các món mới
  Future<void> _loadMatchedMeals() async {
    final diet = appState.userProfile.dietType;
    final goal = appState.userProfile.goal;
    final remainingCal = appState.remainingCalories;

    setState(() => _isLoadingMeals = true);
    final meals = await TheMealDbService.getDailyMatchedMealsFromBackend(
      dietType: diet,
      goal: goal,
      remainingCalories: remainingCal,
      refreshCount: _refreshCount,
      limit: 4,
    );
    if (mounted) {
      setState(() {
        _dietMatchedMeals = meals;
        _isLoadingMeals = false;
      });
    }
  }

  // DIALOG CHỈNH SỬA CHỈ SỐ BẢN THÂN & MỤC TIÊU
  void _showEditMetricsDialog() {
    final profile = appState.userProfile;

    final nameController = TextEditingController(text: profile.fullName);
    final ageController = TextEditingController(text: profile.age.toString());
    final heightController = TextEditingController(text: profile.heightCm.toString());
    final weightController = TextEditingController(text: profile.weightKg.toString());
    final targetWeightController = TextEditingController(text: profile.targetWeightKg.toString());

    String gender = profile.gender;
    String goal = profile.goal;
    String dietType = profile.dietType;
    String activity = profile.activityLevel;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Cập Nhật Chỉ Số & Mục Tiêu',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                ),
                const Text(
                  'Hệ thống sẽ tự động tính toán lại Calo, Macro và lọc thực đơn phù hợp',
                  style: TextStyle(fontSize: 11, color: AppColors.textGray),
                ),
                const SizedBox(height: 16),

                // Tên
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Họ và tên', prefixIcon: Icon(Icons.person_outline)),
                ),
                const SizedBox(height: 12),

                // Giới tính & Tuổi
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: gender,
                        decoration: const InputDecoration(labelText: 'Giới tính'),
                        items: ['Nam', 'Nữ'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                        onChanged: (val) => setModalState(() => gender = val!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: ageController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Tuổi', prefixIcon: Icon(Icons.cake_outlined)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Chiều cao & Cân nặng
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: heightController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Chiều cao (cm)'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: weightController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Cân nặng (kg)'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: targetWeightController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Mục tiêu (kg)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Mục tiêu sức khỏe
                DropdownButtonFormField<String>(
                  value: goal,
                  decoration: const InputDecoration(labelText: 'Mục tiêu thể trạng'),
                  items: const [
                    DropdownMenuItem(value: 'LoseWeight', child: Text('🎯 Giảm cân & Đốt mỡ')),
                    DropdownMenuItem(value: 'Maintain', child: Text('⚖️ Duy trì & Giữ dáng')),
                    DropdownMenuItem(value: 'GainWeight', child: Text('💪 Tăng cơ & Tăng cân')),
                  ],
                  onChanged: (val) => setModalState(() => goal = val!),
                ),
                const SizedBox(height: 14),

                // Chế độ ăn uống
                DropdownButtonFormField<String>(
                  value: dietType,
                  decoration: const InputDecoration(labelText: 'Chế độ ăn ưa thích'),
                  items: const [
                    DropdownMenuItem(value: 'HighProtein', child: Text('🥩 Giàu đạm (High Protein)')),
                    DropdownMenuItem(value: 'LowCarb', child: Text('🥑 Ít tinh bột (Low Carb)')),
                    DropdownMenuItem(value: 'Balanced', child: Text('🥗 Cân bằng dinh dưỡng')),
                    DropdownMenuItem(value: 'Vegetarian', child: Text('🥦 Ăn chay (Vegetarian)')),
                  ],
                  onChanged: (val) => setModalState(() => dietType = val!),
                ),
                const SizedBox(height: 20),

                // Nút Lưu
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      final name = nameController.text.trim();
                      final age = int.tryParse(ageController.text) ?? 24;
                      final h = double.tryParse(heightController.text) ?? 170;
                      final w = double.tryParse(weightController.text) ?? 65;
                      final tw = double.tryParse(targetWeightController.text) ?? w;

                      appState.updateProfileMetrics(
                        fullName: name.isNotEmpty ? name : profile.fullName,
                        gender: gender,
                        age: age,
                        heightCm: h,
                        weightKg: w,
                        targetWeightKg: tw,
                        goal: goal,
                        dietType: dietType,
                        activityLevel: activity,
                      );

                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Đã cập nhật mục tiêu & tự động tính toán lại dinh dưỡng!'),
                          backgroundColor: AppColors.primaryDark,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Lưu Thay Đổi & Lọc Món Phù Hợp', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Đăng xuất tài khoản'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi ứng dụng NutriSnap?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              appState.logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const MobileWrapper(child: LoginScreen())),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = appState.userProfile;

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                'NutriSnap Profile',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textBlack),
              ),
            ),
            const SizedBox(height: 16),

            // Top Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppTranslations.tr('profile_title'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
                    const SizedBox(height: 2),
                    Text(AppTranslations.tr('profile_subtitle'), style: const TextStyle(fontSize: 12, color: AppColors.textGray)),
                  ],
                ),
                InkWell(
                  onTap: _showEditMetricsDialog,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(color: AppColors.accentMint, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.edit, size: 14, color: AppColors.primaryDark),
                        const SizedBox(width: 4),
                        Text(AppTranslations.tr('edit_profile'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Card thông tin cá nhân
            _buildUserCard(profile),
            const SizedBox(height: 16),

            // Lưới chỉ số thể trạng (BMI, BMR, Calo, Nước)
            _buildMetricsGrid(profile),
            const SizedBox(height: 20),

            // KHỐI ĐẦU RA: CÁC MÓN ĂN PHÙ HỢP VỚI CHẾ ĐỘ & MỤC TIÊU ĐÃ CHỌN
            _buildDietRecommendedMealsSection(profile),
            const SizedBox(height: 20),

            // Liên kết & Quản lý Tài Khoản (Google & Facebook)
            _buildAccountLinkingSection(profile),
            const SizedBox(height: 20),

            // Cài đặt ứng dụng
            _buildSettingsSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(UserProfile profile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          const UserAvatarWidget(
            size: 68,
            showEditBadge: true,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.fullName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
                const SizedBox(height: 2),
                Text(profile.email, style: const TextStyle(fontSize: 12, color: AppColors.textGray)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.accentIndigo, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    '🎯 ${profile.goalDisplayName}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(UserProfile profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppTranslations.tr('body_stats'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildMetricTile(AppTranslations.tr('weight'), '${profile.weightKg} kg', '${AppTranslations.tr('target_weight')}: ${profile.targetWeightKg}kg', Colors.blue)),
            const SizedBox(width: 10),
            Expanded(child: _buildMetricTile(AppTranslations.tr('height'), '${profile.heightCm.toInt()} cm', 'BMI: ${profile.bmi} (${profile.bmiCategory})', Colors.teal)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildMetricTile(AppTranslations.tr('cal_goal'), '${profile.targetCalories} kcal', 'TDEE', Colors.deepOrange)),
            const SizedBox(width: 10),
            Expanded(child: _buildMetricTile(AppTranslations.tr('water_goal'), '${(profile.dailyWaterGoalMl / 1000).toStringAsFixed(1)} L', '35ml/kg', Colors.indigo)),
          ],
        ),
        const SizedBox(height: 10),
        // Macro phân bổ
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(AppTranslations.tr('diet_regime'), style: const TextStyle(fontSize: 12, color: AppColors.textGray)),
                  Text(profile.dietDisplayName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMacroDetail(AppTranslations.tr('protein_label'), '${profile.targetProtein}g', Colors.blue),
                  _buildMacroDetail(AppTranslations.tr('carbs_label'), '${profile.targetCarbs}g', Colors.amber.shade800),
                  _buildMacroDetail(AppTranslations.tr('fat_label'), '${profile.targetFat}g', Colors.red.shade700),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile(String label, String value, String sub, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textGray)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: accentColor)),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(fontSize: 9, color: AppColors.textLightGray), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildMacroDetail(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textGray)),
      ],
    );
  }

  /// ĐẦU RA: CÁC MÓN ĂN PHÙ HỢP VỚI CHẾ ĐỘ & MỤC TIÊU ĐÃ CHỌN
  Widget _buildDietRecommendedMealsSection(UserProfile profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppTranslations.tr('recommended_for_you'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppTranslations.tr('daily_rotation_sub'),
                    style: const TextStyle(fontSize: 11, color: AppColors.textGray),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: _isLoadingMeals
                  ? null
                  : () {
                      setState(() => _refreshCount++);
                      _loadMatchedMeals();
                    },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accentMint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.refresh_rounded, size: 14, color: AppColors.primaryDark),
                    const SizedBox(width: 4),
                    Text(
                      AppTranslations.tr('refresh_dishes'),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_isLoadingMeals)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppColors.primary)))
        else if (_dietMatchedMeals.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: const Center(child: Text('Loading...', style: TextStyle(fontSize: 12, color: AppColors.textGray))),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _dietMatchedMeals.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final meal = _dietMatchedMeals[index];
              final score = meal.matchScore > 0 ? meal.matchScore : 95;

              return InkWell(
                onTap: () async {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  );
                  final detail = await TheMealDbService.getMealDetail(meal.idMeal, lang: appState.currentLanguage);
                  if (!context.mounted) return;
                  Navigator.pop(context);

                  appState.setSelectedMeal(detail ?? meal);
                  if (widget.onNavigate != null) {
                    widget.onNavigate!(6); // Chuyển sang RecipeDetailScreen
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          meal.strMealThumb,
                          width: 58,
                          height: 58,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 58,
                            height: 58,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.restaurant, size: 24, color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appState.currentLanguage == 'vi'
                                  ? RecipeTranslator.translateDishName(meal.strMeal)
                                  : meal.strMeal,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '~${meal.estimatedCalories} kcal • ${meal.estimatedProtein}g ${AppTranslations.tr('pro')}',
                              style: const TextStyle(fontSize: 11, color: AppColors.textGray),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accentMint,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '🎯 $score%',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.primary),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  /// KHỐI LIÊN KẾT & QUẢN LÝ TÀI KHOẢN (GOOGLE & FACEBOOK)
  Widget _buildAccountLinkingSection(UserProfile profile) {
    final isGuest = appState.isGuestMode;
    final guestDays = appState.guestUsageDays;
    final googleLinked = profile.googleEmail != null && profile.googleEmail!.isNotEmpty;
    final fbLinked = profile.facebookName != null && profile.facebookName!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tiêu đề khối
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.link_rounded, size: 18, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Liên Kết & Quản Lý Tài Khoản',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textBlack,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isGuest
                          ? 'Đang dùng Khách (Ngày $guestDays/7)'
                          : 'Tài khoản chính thức đã bảo lưu dữ liệu',
                      style: TextStyle(
                        fontSize: 11,
                        color: isGuest ? const Color(0xFFD97706) : const Color(0xFF166534),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // 1. Google
          _buildSocialLinkRow(
            title: 'Tài khoản Google',
            detail: googleLinked ? profile.googleEmail! : 'Chưa liên kết tài khoản Google',
            isLinked: googleLinked,
            iconWidget: Image.network(
              'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/480px-Google_%22G%22_logo.svg.png',
              width: 22,
              height: 22,
              errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata_rounded, color: Colors.red, size: 26),
            ),
            onConnect: () => SocialAuthHelper.showGoogleAuthDialog(context),
            onDisconnect: () => _confirmUnlink('Google', () => appState.unlinkGoogleAccount()),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // 2. Facebook
          _buildSocialLinkRow(
            title: 'Tài khoản Facebook',
            detail: fbLinked ? profile.facebookName! : 'Chưa liên kết tài khoản Facebook',
            isLinked: fbLinked,
            iconWidget: const Icon(Icons.facebook, color: Color(0xFF1877F2), size: 24),
            onConnect: () => SocialAuthHelper.showFacebookAuthDialog(context),
            onDisconnect: () => _confirmUnlink('Facebook', () => appState.unlinkFacebookAccount()),
          ),

          // 3. Khối kiểm thử ngày Khách (chỉ hiện khi đang ở chế độ khách)
          if (isGuest) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.speed_rounded, size: 16, color: Color(0xFFD97706)),
                      const SizedBox(width: 6),
                      Text(
                        'Mô phỏng thử nghiệm (Ngày $guestDays/7):',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildTestDayChip('Ngày 1 (Bình thường)', 1, guestDays == 1),
                      _buildTestDayChip('Ngày 3 (Nhắc nhở)', 3, guestDays == 3),
                      _buildTestDayChip('Ngày 7 (Bắt buộc khóa)', 7, guestDays == 7),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTestDayChip(String label, int days, bool isSelected) {
    return InkWell(
      onTap: () {
        appState.setTestGuestDays(days);
        setState(() {});
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD97706) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFF59E0B)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF92400E),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialLinkRow({
    required String title,
    required String detail,
    required bool isLinked,
    required Widget iconWidget,
    required VoidCallback onConnect,
    required VoidCallback onDisconnect,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Center(child: iconWidget),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isLinked ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isLinked ? '✓ Đã liên kết' : 'Chưa liên kết',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isLinked ? const Color(0xFF166534) : AppColors.textGray,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: const TextStyle(fontSize: 11, color: AppColors.textGray),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (isLinked) ...[
          OutlinedButton(
            onPressed: onDisconnect,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              visualDensity: VisualDensity.compact,
              side: const BorderSide(color: Color(0xFFFCA5A5)),
              foregroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Hủy', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ] else ...[
          ElevatedButton(
            onPressed: onConnect,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Liên kết', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ],
    );
  }

  void _confirmUnlink(String provider, VoidCallback onUnlink) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Hủy liên kết $provider'),
        content: Text('Bạn có chắc chắn muốn hủy liên kết tài khoản $provider khỏi NutriSnap?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Không', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onUnlink();
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Đã hủy liên kết $provider')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Hủy liên kết'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          // 1. Chỉnh Ngôn ngữ (Language)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: AppColors.accentMint,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.language_rounded, size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppTranslations.tr('language_setting'),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        appState.currentLanguage == 'vi' ? 'Tiếng Việt 🇻🇳' : 'English 🇺🇸',
                        style: const TextStyle(fontSize: 11, color: AppColors.textGray),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    _buildLangButton('vi', '🇻🇳 VI', appState.currentLanguage == 'vi'),
                    _buildLangButton('en', '🇺🇸 EN', appState.currentLanguage == 'en'),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.water_drop_outlined, size: 20, color: Colors.blue),
                  const SizedBox(width: 10),
                  Text(AppTranslations.tr('water_reminder'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
                ],
              ),
              Switch(
                value: _waterReminder,
                activeColor: AppColors.primary,
                onChanged: (val) {
                  setState(() => _waterReminder = val);
                },
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.vibration, size: 20, color: AppColors.textGray),
                  const SizedBox(width: 10),
                  Text(AppTranslations.tr('shake_sensitivity'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
                ],
              ),
              DropdownButton<int>(
                value: _shakeSensitivity,
                underline: const SizedBox(),
                items: [
                  DropdownMenuItem(value: 0, child: Text(appState.currentLanguage == 'vi' ? 'Nhẹ' : 'Low')),
                  DropdownMenuItem(value: 1, child: Text(appState.currentLanguage == 'vi' ? 'Vừa' : 'Medium')),
                  DropdownMenuItem(value: 2, child: Text(appState.currentLanguage == 'vi' ? 'Mạnh' : 'High')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _shakeSensitivity = val);
                },
              ),
            ],
          ),
          const Divider(height: 20),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text(AppTranslations.tr('logout'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
            onTap: _handleLogout,
          ),
        ],
      ),
    );
  }

  Widget _buildLangButton(String langCode, String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        appState.setLanguage(langCode);
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.textGray,
          ),
        ),
      ),
    );
  }
}
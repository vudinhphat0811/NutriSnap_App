import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_translations.dart';
import '../widgets/calorie_ring_painter.dart';
import '../widgets/user_avatar_widget.dart';
import '../widgets/ai_nutrition_report_sheet.dart';
import '../services/app_state_service.dart';
import '../services/fridge_service.dart';
import '../models/ingredient_cut_model.dart';
import '../widgets/notification_center_sheet.dart';
import 'ingredient_macro_calculator_screen.dart';
import 'smart_fridge_screen.dart';

class HomeDashboardScreen extends StatefulWidget {
  final Function(int) onNavigate;

  const HomeDashboardScreen({super.key, required this.onNavigate});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  final appState = AppStateService.instance;
  final fridgeService = FridgeService.instance;

  @override
  void initState() {
    super.initState();
    appState.addListener(_onStateChanged);
    fridgeService.addListener(_onStateChanged);
    fridgeService.init();
    appState.checkAndResetForNewDay();
  }

  @override
  void dispose() {
    appState.removeListener(_onStateChanged);
    fridgeService.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await appState.checkAndResetForNewDay();
          if (appState.authToken != null && !appState.isGuestMode) {
            await appState.fetchDashboardToday();
            await appState.syncMealLogsFromServer();
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
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
              _buildAiNutritionBanner(),
              const SizedBox(height: 16),
              _buildIngredientCutGymSection(),
              const SizedBox(height: 16),
              _buildQuickActions(),
              const SizedBox(height: 16),
              _buildSmartFridgeBanner(),
              const SizedBox(height: 16),
              _buildWaterTracker(),
              const SizedBox(height: 20),
              _buildMealLogSection(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final profile = appState.userProfile;
    final expiringCount = fridgeService.expiringCount;
    final isWaterBehind = appState.waterIntakeMl < (appState.waterGoalMl * 0.6) && DateTime.now().hour >= 14;
    final totalAlerts = expiringCount + (isWaterBehind ? 1 : 0);

    return Row(
      children: [
        const UserAvatarWidget(
          size: 48,
          showEditBadge: true,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${AppTranslations.tr('hello')} ${profile.fullName} 👋',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${AppTranslations.tr('daily_target')}: ${profile.goalDisplayName} • ${profile.dietDisplayName}',
                style: const TextStyle(fontSize: 11, color: AppColors.textGray),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: AppColors.accentIndigo, borderRadius: BorderRadius.circular(20)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_fire_department, size: 14, color: AppColors.primary),
              const SizedBox(width: 4),
              Text('${AppTranslations.tr('streak')} ${appState.streakDays} ${AppTranslations.tr('days')}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Chuông thông báo hạn dùng tủ lạnh & nhắc uống nước
        InkWell(
          onTap: () {
            NotificationCenterSheet.show(context, onNavigate: widget.onNavigate);
          },
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.notifications_outlined, size: 20, color: AppColors.textBlack),
              ),
              if (totalAlerts > 0)
                Positioned(
                  top: -3,
                  right: -3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Center(
                      child: Text(
                        '$totalAlerts',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalorieCard() {
    final profile = appState.userProfile;
    final logged = appState.totalCaloriesLogged;
    final goal = appState.dailyCalorieGoal;
    final remaining = appState.remainingCalories;
    final progress = goal > 0 ? (logged / goal).clamp(0.0, 1.0) : 0.0;

    final targetPro = profile.targetProtein > 0 ? profile.targetProtein : 120.0;
    final targetCarb = profile.targetCarbs > 0 ? profile.targetCarbs : 200.0;
    final targetFat = profile.targetFat > 0 ? profile.targetFat : 50.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppTranslations.tr('energy_today'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.accentMint, borderRadius: BorderRadius.circular(10)),
                child: Text('${AppTranslations.tr('daily_target')} $goal kcal', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              SizedBox(
                width: 110,
                height: 110,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(size: const Size(110, 110), painter: CalorieRingPainter(progress: progress)),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$remaining', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
                        Text(AppTranslations.tr('kcal_left'), style: const TextStyle(fontSize: 9, color: AppColors.textGray)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    _buildNutriRow(AppTranslations.tr('consumed'), '$logged / $goal kcal', progress, AppColors.primary),
                    const SizedBox(height: 8),
                    _buildNutriRow(AppTranslations.tr('protein_label'), '${appState.totalProteinLogged} / ${targetPro.toInt()}g', (appState.totalProteinLogged / targetPro).clamp(0.0, 1.0), Colors.blue),
                    const SizedBox(height: 8),
                    _buildNutriRow(AppTranslations.tr('carbs_label'), '${appState.totalCarbsLogged} / ${targetCarb.toInt()}g', (appState.totalCarbsLogged / targetCarb).clamp(0.0, 1.0), Colors.amber),
                    const SizedBox(height: 8),
                    _buildNutriRow(AppTranslations.tr('fat_label'), '${appState.totalFatLogged} / ${targetFat.toInt()}g', (appState.totalFatLogged / targetFat).clamp(0.0, 1.0), Colors.red.shade400),
                  ],
                ),
              ),
            ],
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
            Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textBlack)),
            const Spacer(),
            Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textGray)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            backgroundColor: const Color(0xFFF1F5F9),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildAiNutritionBanner() {
    final isVi = appState.currentLanguage == 'vi';
    return InkWell(
      onTap: () => AiNutritionReportSheet.show(context, initialPeriod: 'yesterday'),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.accentMint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isVi ? 'Đánh giá AI hôm qua' : 'AI Yesterday Review',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textBlack,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentMint,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isVi ? 'Xem lời khuyên' : 'See tips',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isVi
                        ? 'Chạm để xem điểm số & lời khuyên từ Bác sĩ Dinh dưỡng AI'
                        : 'Tap to view your score & AI dietitian recommendations',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textGray,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textLightGray,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => widget.onNavigate(4), // Quét AI
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
                        child: const Text('AI VISION', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(AppTranslations.tr('scan_ingredient'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(AppTranslations.tr('scan_sub'), style: const TextStyle(fontSize: 11, color: Colors.white70)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(AppTranslations.tr('scan_now'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.white),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: () => widget.onNavigate(5), // Lắc món ăn
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
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.casino_outlined, color: AppColors.primaryDark, size: 18),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFFD6E4FC), borderRadius: BorderRadius.circular(8)),
                        child: const Text('TheMealDB', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(AppTranslations.tr('shake_dish'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
                  const SizedBox(height: 2),
                  Text(AppTranslations.tr('shake_sub_home'), style: const TextStyle(fontSize: 11, color: AppColors.textGray)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(AppTranslations.tr('shake_now'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                      const SizedBox(width: 4),
                      const Icon(Icons.shuffle_rounded, size: 12, color: AppColors.primaryDark),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSmartFridgeBanner() {
    final totalItems = fridgeService.items.length;
    final expiringCount = fridgeService.expiringCount;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SmartFridgeScreen(onNavigate: widget.onNavigate)),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: expiringCount > 0 ? const Color(0xFFFCD34D) : Colors.grey.shade200,
            width: expiringCount > 0 ? 1.4 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: expiringCount > 0 ? const Color(0xFFFEF3C7) : const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Text('🧊', style: TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Tủ Lạnh Thông Minh',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                      ),
                      const SizedBox(width: 6),
                      if (expiringCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '⚠️ $expiringCount cần nấu',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    totalItems > 0
                        ? '$totalItems món lưu trữ • Quản lý hạn dùng & chống lãng phí'
                        : 'Chưa có thực phẩm nào • Chạm để thêm đồ vào tủ',
                    style: const TextStyle(fontSize: 11, color: AppColors.textGray),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textLightGray),
          ],
        ),
      ),
    );
  }

  Widget _buildWaterTracker() {
    final current = appState.waterIntakeMl;
    final goal = appState.waterGoalMl;
    final progress = (current / goal).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(color: Color(0xFFEFF6FF), shape: BoxShape.circle),
            child: const Icon(Icons.water_drop, size: 20, color: Colors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(AppTranslations.tr('water_today'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        '${(current / 1000).toStringAsFixed(1)} / ${(goal / 1000).toStringAsFixed(1)}L',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              appState.addWater(250);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppTranslations.tr('water_added')),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: AppColors.accentMint, borderRadius: BorderRadius.circular(14)),
              child: const Row(
                children: [
                  Icon(Icons.add, size: 14, color: AppColors.primaryDark),
                  Text('250ml', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientCutGymSection() {
    final isVi = appState.currentLanguage == 'vi';

    // Top các nguyên liệu thô tiêu biểu
    final topGymCuts = [
      const IngredientCutModel(
        id: 'raw_chicken_breast',
        category: 'Thịt & Trứng',
        categoryIcon: '🍗',
        name: 'Ức gà',
        englishName: 'Raw Chicken Breast',
        description: 'Chuẩn siết mỡ tăng cơ, đạm tinh khiết, ít mỡ.',
        defaultPortionName: '100g thô',
        defaultPortionWeightG: 100,
        caloriesPer100g: 120,
        proteinPer100g: 22.5,
        carbsPer100g: 0.0,
        fatPer100g: 2.6,
        fiberPer100g: 0.0,
        gymBadges: ['💪 22.5g Đạm', '🔥 120 kcal'],
        imageUrl: 'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?auto=format&fit=crop&w=400&q=80',
      ),
      const IngredientCutModel(
        id: 'raw_chicken_thigh',
        category: 'Thịt & Trứng',
        categoryIcon: '🍗',
        name: 'Đùi gà',
        englishName: 'Raw Chicken Thigh',
        description: 'Đậm vị, nhiều sắt kẽm, thịt mềm ngọt.',
        defaultPortionName: '100g thô',
        defaultPortionWeightG: 100,
        caloriesPer100g: 177,
        proteinPer100g: 19.7,
        carbsPer100g: 0.0,
        fatPer100g: 10.4,
        fiberPer100g: 0.0,
        gymBadges: ['💪 19.7g Đạm', '🩸 Giàu Sắt'],
        imageUrl: 'https://images.unsplash.com/photo-1587593810167-a84920ea0781?auto=format&fit=crop&w=400&q=80',
      ),
      const IngredientCutModel(
        id: 'raw_beef_shank',
        category: 'Thịt & Trứng',
        categoryIcon: '🥩',
        name: 'Bắp bò',
        englishName: 'Raw Beef Shank',
        description: 'Cực nạc, gân giòn giàu collagen bôi trơn khớp.',
        defaultPortionName: '100g thô',
        defaultPortionWeightG: 100,
        caloriesPer100g: 130,
        proteinPer100g: 21.5,
        carbsPer100g: 0.0,
        fatPer100g: 4.2,
        fiberPer100g: 0.0,
        gymBadges: ['💪 21.5g Đạm', '🔥 130 kcal'],
        imageUrl: 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=400&q=80',
      ),
      const IngredientCutModel(
        id: 'raw_beef_tenderloin',
        category: 'Thịt & Trứng',
        categoryIcon: '🥩',
        name: 'Thăn bò',
        englishName: 'Raw Beef Tenderloin',
        description: 'Đỉnh cao đạm bò và Creatine tự nhiên.',
        defaultPortionName: '100g thô',
        defaultPortionWeightG: 100,
        caloriesPer100g: 142,
        proteinPer100g: 22.3,
        carbsPer100g: 0.0,
        fatPer100g: 5.4,
        fiberPer100g: 0.0,
        gymBadges: ['👑 Creatine Cao', '🔥 142 kcal'],
        imageUrl: 'https://images.unsplash.com/photo-1558030006-450675393462?auto=format&fit=crop&w=400&q=80',
      ),
      const IngredientCutModel(
        id: 'raw_egg_white',
        category: 'Thịt & Trứng',
        categoryIcon: '🥚',
        name: 'Lòng trắng trứng',
        englishName: 'Raw Egg White',
        description: '1 quả chỉ ~17 kcal, đạm tinh khiết không mỡ.',
        defaultPortionName: '100g thô',
        defaultPortionWeightG: 100,
        caloriesPer100g: 52,
        proteinPer100g: 10.9,
        carbsPer100g: 0.7,
        fatPer100g: 0.2,
        fiberPer100g: 0.0,
        gymBadges: ['🥚 1 quả = 17 kcal', '🔥 0g Mỡ'],
        imageUrl: 'https://images.unsplash.com/photo-1582722872445-44dc5f7e3c8f?auto=format&fit=crop&w=400&q=80',
      ),
      const IngredientCutModel(
        id: 'raw_sweet_potato',
        category: 'Gạo & Tinh bột',
        categoryIcon: '🍠',
        name: 'Khoai lang',
        englishName: 'Raw Sweet Potato',
        description: 'Carb chậm chất lượng cao, giàu xơ, no lâu.',
        defaultPortionName: '100g thô',
        defaultPortionWeightG: 100,
        caloriesPer100g: 86,
        proteinPer100g: 1.6,
        carbsPer100g: 20.1,
        fatPer100g: 0.1,
        fiberPer100g: 3.0,
        gymBadges: ['🍠 Carb Chậm', '🔥 86 kcal'],
        imageUrl: 'https://images.unsplash.com/photo-1596097635121-14b63b7a0c19?auto=format&fit=crop&w=400&q=80',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header có nút mũi tên mở nhanh vào màn hình tính calo
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const IngredientMacroCalculatorScreen(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.fitness_center_rounded, size: 18, color: Color(0xFFD97706)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              isVi ? 'Đo Calo Nguyên Liệu Thô' : 'Raw Ingredients Calorie',
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accentMint,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'NGUYÊN LIỆU THÔ',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isVi
                            ? 'Ức gà, đùi gà, bắp bò, gạo, rau củ... chuẩn gram thô chưa nấu'
                            : 'Raw chicken, beef, rice, vegetables... precise per gram raw macros',
                        style: const TextStyle(fontSize: 11, color: AppColors.textGray),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textLightGray,
                  size: 20,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Horizontal scroll các bộ phận tiêu biểu
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: topGymCuts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final cut = topGymCuts[index];
                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => IngredientMacroCalculatorScreen(initialCut: cut),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 130,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(cut.categoryIcon, style: const TextStyle(fontSize: 18)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${cut.proteinPer100g.round()}g Pro',
                                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blue),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          cut.name,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${cut.caloriesPer100g.round()} kcal',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                            ),
                            Text(
                              '${cut.fatPer100g}g F',
                              style: const TextStyle(fontSize: 9, color: AppColors.textGray),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'per 100g',
                          style: TextStyle(fontSize: 9, color: AppColors.textLightGray),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Nút bấm mở toàn màn hình bộ đo
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const IngredientMacroCalculatorScreen(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.tune_rounded, size: 16, color: AppColors.primaryDark),
                  SizedBox(width: 6),
                  Text(
                    'Mở Bảng Tính & So Sánh Chi Tiết Từng Bộ Phận',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.primaryDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealLogSection() {
    final logs = appState.todayMealLogs;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(AppTranslations.tr('meal_log'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
            InkWell(
              onTap: () => widget.onNavigate(1), // Màn hình Nhật ký
              child: Text(AppTranslations.tr('see_all'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (logs.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Center(
              child: Text(AppTranslations.tr('no_meals_today'), style: const TextStyle(fontSize: 12, color: AppColors.textGray)),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: logs.length > 3 ? 3 : logs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final log = logs[index];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6)],
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        log.displayImageUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(width: 50, height: 50, color: Colors.grey.shade200),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(log.displayMealType, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
                          const SizedBox(height: 2),
                          Text(
                            log.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                          ),
                          const SizedBox(height: 2),
                          Text('${log.displayTime} • ${log.protein}g ${AppTranslations.tr('pro')} • ${log.carbs}g ${AppTranslations.tr('carb')}', style: const TextStyle(fontSize: 10, color: AppColors.textGray)),
                        ],
                      ),
                    ),
                    Text(
                      '${log.calories} kcal',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

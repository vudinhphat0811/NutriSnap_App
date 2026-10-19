import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_translations.dart';
import '../widgets/calorie_ring_painter.dart';
import '../widgets/user_avatar_widget.dart';
import '../services/app_state_service.dart';

class HomeDashboardScreen extends StatefulWidget {
  final Function(int) onNavigate;

  const HomeDashboardScreen({super.key, required this.onNavigate});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  final appState = AppStateService.instance;

  @override
  void initState() {
    super.initState();
    appState.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    appState.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

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
    final profile = appState.userProfile;
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

  Widget _buildMealLogSection() {
    final logs = appState.mealLogs;

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
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6)],
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        log.imageUrl,
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
                          Text('${log.time} • ${log.protein}g ${AppTranslations.tr('pro')} • ${log.carbs}g ${AppTranslations.tr('carb')}', style: const TextStyle(fontSize: 10, color: AppColors.textGray)),
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
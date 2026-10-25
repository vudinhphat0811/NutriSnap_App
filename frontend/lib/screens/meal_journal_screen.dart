import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_translations.dart';
import '../widgets/ai_nutrition_report_sheet.dart';
import '../services/app_state_service.dart';

class MealJournalScreen extends StatefulWidget {
  final Function(int) onNavigate;
  const MealJournalScreen({super.key, required this.onNavigate});

  @override
  State<MealJournalScreen> createState() => _MealJournalScreenState();
}

class _MealJournalScreenState extends State<MealJournalScreen> {
  final appState = AppStateService.instance;
  String _selectedFilter = 'ALL'; // 'ALL', 'BỮA SÁNG', 'BỮA TRƯA', 'BỮA TỐI', 'ĂN XẾ'
  String _selectedDateScope = 'TODAY'; // 'TODAY' (Hôm nay), 'ALL' (Tất cả lịch sử)

  @override
  void initState() {
    super.initState();
    appState.addListener(_onStateChanged);
    appState.checkAndResetForNewDay();
  }

  @override
  void dispose() {
    appState.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  // Mở BottomSheet thêm nhanh bữa ăn phong cách hiện đại
  void _showAddMealBottomSheet() {
    final titleController = TextEditingController();
    final calController = TextEditingController();
    final proController = TextEditingController();
    final carbController = TextEditingController();
    final fatController = TextEditingController();

    String selectedType = 'BỮA SÁNG';

    final mealTypes = [
      {'key': 'BỮA SÁNG', 'label': AppTranslations.tr('breakfast'), 'icon': '🍳'},
      {'key': 'BỮA TRƯA', 'label': AppTranslations.tr('lunch'), 'icon': '🍲'},
      {'key': 'BỮA TỐI', 'label': AppTranslations.tr('dinner'), 'icon': '🥗'},
      {'key': 'ĂN XẾ', 'label': AppTranslations.tr('snack'), 'icon': '🍎'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thanh kéo handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tiêu đề
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppTranslations.tr('add_new_meal'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, color: AppColors.textGray),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Chọn loại bữa ăn (Segment Chips)
                  Text(
                    AppTranslations.tr('meal_type'),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textBlack),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: mealTypes.map((type) {
                      final isSelected = selectedType == type['key'];
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => selectedType = type['key'] as String),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(type['icon'] as String, style: const TextStyle(fontSize: 16)),
                                const SizedBox(height: 2),
                                Text(
                                  type['label'] as String,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? Colors.white : AppColors.textBlack,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Nhập tên món ăn
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: AppTranslations.tr('dish_name_hint'),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      prefixIcon: const Icon(Icons.restaurant_rounded, size: 20, color: AppColors.primary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Nhập lượng calo
                  TextField(
                    controller: calController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: AppTranslations.tr('calorie_amount'),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      prefixIcon: const Icon(Icons.local_fire_department_rounded, size: 20, color: Colors.orange),
                      suffixText: 'kcal',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Các nút chọn nhanh Calo (+200, +350, +500, +650)
                  Wrap(
                    spacing: 8,
                    children: [200, 350, 500, 650].map((val) {
                      return ActionChip(
                        label: Text('+$val kcal', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        backgroundColor: const Color(0xFFF1F5F9),
                        onPressed: () {
                          calController.text = '$val';
                          proController.text = '${(val * 0.08).round()}';
                          carbController.text = '${(val * 0.11).round()}';
                          fatController.text = '${(val * 0.03).round()}';
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Nút Lưu Bữa Ăn
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final title = titleController.text.trim();
                        final cal = int.tryParse(calController.text.trim()) ?? 350;
                        final pro = int.tryParse(proController.text.trim()) ?? (cal * 0.08).round();
                        final carb = int.tryParse(carbController.text.trim()) ?? (cal * 0.11).round();
                        final fat = int.tryParse(fatController.text.trim()) ?? (cal * 0.03).round();

                        if (title.isNotEmpty) {
                          appState.addCustomEntry(
                            mealType: selectedType,
                            title: title,
                            calories: cal,
                            protein: pro,
                            carbs: carb,
                            fat: fat,
                          );
                          Navigator.pop(ctx);
                        }
                      },
                      icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                      label: Text(
                        AppTranslations.tr('save_meal'),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateScopeSelector() {
    final todayCount = appState.todayMealLogs.length;
    final allCount = appState.mealLogs.length;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedDateScope = 'TODAY'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _selectedDateScope == 'TODAY' ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _selectedDateScope == 'TODAY'
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  'Hôm nay ($todayCount)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: _selectedDateScope == 'TODAY' ? FontWeight.bold : FontWeight.w500,
                    color: _selectedDateScope == 'TODAY' ? AppColors.primary : AppColors.textGray,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedDateScope = 'ALL'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _selectedDateScope == 'ALL' ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _selectedDateScope == 'ALL'
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  'Tất cả lịch sử ($allCount)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: _selectedDateScope == 'ALL' ? FontWeight.bold : FontWeight.w500,
                    color: _selectedDateScope == 'ALL' ? AppColors.primary : AppColors.textGray,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseLogs = _selectedDateScope == 'TODAY' ? appState.todayMealLogs : appState.mealLogs;

    // Lọc theo MealType
    final filteredLogs = _selectedFilter == 'ALL'
        ? baseLogs
        : baseLogs.where((item) {
            final typeUpper = item.mealType.toUpperCase();
            if (_selectedFilter == 'BỮA SÁNG') return typeUpper.contains('SÁNG') || typeUpper.contains('BREAKFAST');
            if (_selectedFilter == 'BỮA TRƯA') return typeUpper.contains('TRƯA') || typeUpper.contains('LUNCH');
            if (_selectedFilter == 'BỮA TỐI') return typeUpper.contains('TỐI') || typeUpper.contains('DINNER');
            if (_selectedFilter == 'ĂN XẾ') return typeUpper.contains('XẾ') || typeUpper.contains('SNACK');
            return true;
          }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            await appState.checkAndResetForNewDay();
            if (appState.authToken != null && !appState.isGuestMode) {
              await appState.syncMealLogsFromServer();
              await appState.fetchDashboardToday();
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top Bar
                _buildTopBar(),
                const SizedBox(height: 14),

                // 2. Chuyển đổi Hôm Nay / Tất Cả Lịch Sử
                _buildDateScopeSelector(),
                const SizedBox(height: 16),

                // 3. Thẻ Hero Dashboard Tổng Hợp Dinh Dưỡng Cao Cấp
                _buildNutritionHeroCard(),
                const SizedBox(height: 20),

                // 4. Thanh Lọc Theo Bữa Ăn (Tabs / Filter Chips)
                _buildMealTypeFilters(baseLogs),
                const SizedBox(height: 16),

                // 5. Danh Sách Món Ăn Trong Ngày
                if (filteredLogs.isEmpty)
                  _buildEmptyState()
                else
                  _buildMealLogsList(filteredLogs),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final now = DateTime.now();
    final dateStr = '${now.day}/${now.month}/${now.year}';

    return Row(
      children: [
        InkWell(
          onTap: () => widget.onNavigate(0),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
            ),
            child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.textBlack),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppTranslations.tr('journal_title'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textBlack),
              ),
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    '${AppTranslations.tr('today')}, $dateStr',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textGray),
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => AiNutritionReportSheet.show(context),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.accentMint,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.all(10),
          ),
          icon: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 20),
          tooltip: appState.currentLanguage == 'vi' ? 'Báo cáo AI' : 'AI Report',
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _showAddMealBottomSheet,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(
            AppTranslations.tr('add_quick'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  /// Thẻ Hero Dashboard: Vòng tròn tiến độ Calo & Thanh Macro chi tiết
  Widget _buildNutritionHeroCard() {
    final bool isToday = _selectedDateScope == 'TODAY';
    final int totalCal = isToday
        ? appState.totalCaloriesLogged
        : appState.mealLogs.fold(0, (sum, i) => sum + i.calories);
    final int goalCal = appState.dailyCalorieGoal > 0 ? appState.dailyCalorieGoal : 2000;
    final double calPercent = (totalCal / goalCal).clamp(0.0, 1.0);

    final int pro = isToday
        ? appState.totalProteinLogged
        : appState.mealLogs.fold(0, (sum, i) => sum + i.protein);
    final int targetPro = appState.userProfile.targetProtein > 0 ? appState.userProfile.targetProtein.round() : 130;

    final int carb = isToday
        ? appState.totalCarbsLogged
        : appState.mealLogs.fold(0, (sum, i) => sum + i.carbs);
    final int targetCarb = appState.userProfile.targetCarbs > 0 ? appState.userProfile.targetCarbs.round() : 180;

    final int fat = isToday
        ? appState.totalFatLogged
        : appState.mealLogs.fold(0, (sum, i) => sum + i.fat);
    final int targetFat = appState.userProfile.targetFat > 0 ? appState.userProfile.targetFat.round() : 50;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Vòng tròn tiến độ Calo
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 95,
                      height: 95,
                      child: CircularProgressIndicator(
                        value: calPercent,
                        strokeWidth: 9,
                        backgroundColor: Colors.white.withValues(alpha: 0.12),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$totalCal',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          '/ $goalCal',
                          style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.7)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${(calPercent * 100).toInt()}%',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),

              // Macro Progress Bars
              Expanded(
                child: Column(
                  children: [
                    _buildMacroProgressBar(
                      label: AppTranslations.tr('protein_label'),
                      current: pro,
                      target: targetPro,
                      color: const Color(0xFF38BDF8), // Cyan
                      unit: 'g',
                    ),
                    const SizedBox(height: 10),
                    _buildMacroProgressBar(
                      label: AppTranslations.tr('carbs_label'),
                      current: carb,
                      target: targetCarb,
                      color: const Color(0xFFFBBF24), // Amber
                      unit: 'g',
                    ),
                    const SizedBox(height: 10),
                    _buildMacroProgressBar(
                      label: AppTranslations.tr('fat_label'),
                      current: fat,
                      target: targetFat,
                      color: const Color(0xFFFB7185), // Rose
                      unit: 'g',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Lời nhắc trạng thái Calo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  appState.remainingCalories >= 0 ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  size: 16,
                  color: appState.remainingCalories >= 0 ? AppColors.primary : Colors.amber,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    appState.remainingCalories >= 0
                        ? '${AppTranslations.tr('remaining')}: ${appState.remainingCalories} kcal'
                        : '${AppTranslations.tr('energy_today')}: Vượt ${-appState.remainingCalories} kcal',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Nút bấm mở báo cáo AI Dinh Dưỡng
          InkWell(
            onTap: () => AiNutritionReportSheet.show(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    appState.currentLanguage == 'vi'
                        ? 'Báo cáo AI: Đánh giá hôm qua, tuần & tháng'
                        : 'AI Review: Yesterday, Week & Month',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Colors.white70),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroProgressBar({
    required String label,
    required int current,
    required int target,
    required Color color,
    required String unit,
  }) {
    final double percent = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70)),
            Text('$current / $target $unit', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 6,
            backgroundColor: Colors.white.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  /// Bộ lọc theo bữa ăn
  Widget _buildMealTypeFilters(List<MealLogEntry> allLogs) {
    final filters = [
      {'key': 'ALL', 'label': '${AppTranslations.tr('see_all').replaceAll(' >', '')} (${allLogs.length})'},
      {'key': 'BỮA SÁNG', 'label': '🍳 ${AppTranslations.tr('breakfast')}'},
      {'key': 'BỮA TRƯA', 'label': '🍲 ${AppTranslations.tr('lunch')}'},
      {'key': 'BỮA TỐI', 'label': '🥗 ${AppTranslations.tr('dinner')}'},
      {'key': 'ĂN XẾ', 'label': '🍎 ${AppTranslations.tr('snack')}'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(f['label']!),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedFilter = f['key']!),
              selectedColor: AppColors.primary,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textBlack,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              side: BorderSide(
                color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Danh sách món ăn đã ghi nhận
  Widget _buildMealLogsList(List<MealLogEntry> logs) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: logs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final log = logs[index];
        final typeColor = _getMealTypeColor(log.mealType);

        return Dismissible(
          key: Key(log.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
                SizedBox(width: 6),
                Text('Xóa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          onDismissed: (_) {
            appState.removeMealLog(log.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${AppTranslations.tr('deleted_meal')}: "${log.title}"'),
                duration: const Duration(seconds: 1),
                backgroundColor: AppColors.primaryDark,
              ),
            );
          },
          child: InkWell(
            onTap: () => _showMealDetailSheet(context, log),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Row(
                children: [
                  // Ảnh món ăn
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      log.displayImageUrl,
                      width: 65,
                      height: 65,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 65,
                        height: 65,
                        color: const Color(0xFFF1F5F9),
                        child: const Icon(Icons.restaurant_rounded, size: 28, color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Thông tin món ăn
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: typeColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                log.displayMealType.toUpperCase(),
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: typeColor),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              log.displayTime,
                              style: const TextStyle(fontSize: 11, color: AppColors.textGray),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (log.isMultiIngredientMeal) ...[
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  log.displayCardTitle,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Chi tiết', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                                    SizedBox(width: 2),
                                    Icon(Icons.arrow_forward_ios_rounded, size: 7, color: Color(0xFF2563EB)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              ...log.parsedIngredients.take(2).map((item) {
                                final icon = MealLogEntry.resolveIngredientIcon(item);
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$icon $item',
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }),
                              if (log.parsedIngredients.length > 2)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '+${log.parsedIngredients.length - 2} món nữa',
                                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                  ),
                                ),
                            ],
                          ),
                        ] else ...[
                          Text(
                            log.title,
                            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _buildMacroPill('${log.protein}g P', const Color(0xFF0284C7)),
                            const SizedBox(width: 6),
                            _buildMacroPill('${log.carbs}g C', const Color(0xFFD97706)),
                            const SizedBox(width: 6),
                            _buildMacroPill('${log.fat}g F', const Color(0xFFE11D48)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Lượng Calo & Nút Xóa
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_fire_department_rounded, size: 16, color: Colors.deepOrange),
                          const SizedBox(width: 2),
                          Text(
                            '${log.calories}',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                          ),
                        ],
                      ),
                      const Text('kcal', style: TextStyle(fontSize: 10, color: AppColors.textGray)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () {
                          appState.removeMealLog(log.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${AppTranslations.tr('deleted_meal')}: "${log.title}"'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        child: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMacroPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Color _getMealTypeColor(String type) {
    final t = type.toUpperCase();
    if (t.contains('SÁNG') || t.contains('BREAKFAST')) return const Color(0xFFD97706);
    if (t.contains('TRƯA') || t.contains('LUNCH')) return const Color(0xFF0284C7);
    if (t.contains('TỐI') || t.contains('DINNER')) return const Color(0xFF4F46E5);
    return const Color(0xFF059669); // Snack
  }

  /// Trạng thái trống (Empty State) sinh động
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Color(0xFFF0FDF4),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lunch_dining_rounded, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 14),
            Text(
              AppTranslations.tr('no_journal_meals'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textBlack),
            ),
            const SizedBox(height: 6),
            const Text(
              'Ghi nhận bữa ăn để theo dõi Calo và Macro mục tiêu mỗi ngày',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textGray),
            ),
            const SizedBox(height: 18),

            // Các nút hành động nhanh
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => widget.onNavigate(4), // Quét AI
                  icon: const Icon(Icons.camera_alt_outlined, size: 16),
                  label: const Text('Quét AI', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _showAddMealBottomSheet,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Nhập nhanh', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// HỘP THOẠI XEM CHI TIẾT BỮA ĂN (HIỂN THỊ TRỌN VẸN CÁC NGUYÊN LIỆU ĐÃ CHỌN)
  void _showMealDetailSheet(BuildContext parentContext, MealLogEntry log) {
    final isMulti = log.isMultiIngredientMeal;
    final ingredients = log.parsedIngredients;

    // Tính % calo từng macro
    final proCal = log.protein * 4.0;
    final carbCal = log.carbs * 4.0;
    final fatCal = log.fat * 9.0;
    final totalMacroCal = (proCal + carbCal + fatCal) <= 0 ? 1.0 : (proCal + carbCal + fatCal);
    final proPct = ((proCal / totalMacroCal) * 100).round();
    final carbPct = ((carbCal / totalMacroCal) * 100).round();
    final fatPct = (100 - proPct - carbPct).clamp(0, 100).toInt();

    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetCtx).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Thanh gạt
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ảnh món ăn
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.network(
                            log.displayImageUrl,
                            width: double.infinity,
                            height: 170,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: double.infinity,
                              height: 170,
                              color: const Color(0xFFF1F5F9),
                              child: const Icon(Icons.restaurant_rounded, size: 50, color: AppColors.primary),
                            ),
                          ),
                        ),
                        // Badge Bữa ăn
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  log.displayMealType.toUpperCase(),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                const Text(' • ', style: TextStyle(color: Colors.white70)),
                                Text(
                                  log.displayTime,
                                  style: const TextStyle(fontSize: 11, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Nút Đóng
                        Positioned(
                          top: 12,
                          right: 12,
                          child: InkWell(
                            onTap: () => Navigator.pop(sheetCtx),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Tiêu đề
                    Text(
                      isMulti ? 'Khẩu phần dinh dưỡng tự chọn' : log.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Đã ghi nhận trong ${log.displayMealType.toLowerCase()} (${log.displayTime})',
                      style: const TextStyle(fontSize: 12, color: AppColors.textGray),
                    ),

                    const SizedBox(height: 16),

                    // Khối tổng Calo & Macros
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.local_fire_department_rounded, color: Colors.deepOrange, size: 22),
                                  SizedBox(width: 6),
                                  Text('TỔNG NĂNG LƯỢNG', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                ],
                              ),
                              Text(
                                '${log.calories} kcal',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF15803D)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildMacroDetailCard('Chất Đạm (P)', '${log.protein}g', '$proPct%', const Color(0xFF0284C7)),
                              const SizedBox(width: 8),
                              _buildMacroDetailCard('Tinh Bột (C)', '${log.carbs}g', '$carbPct%', const Color(0xFFD97706)),
                              const SizedBox(width: 8),
                              _buildMacroDetailCard('Chất Béo (F)', '${log.fat}g', '$fatPct%', const Color(0xFFE11D48)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // DANH SÁCH CHI TIẾT TỪNG NGUYÊN LIỆU (nếu là combo nhiều nguyên liệu)
                    if (isMulti && ingredients.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(Icons.kitchen_rounded, size: 18, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Chi Tiết Các Nguyên Liệu (${ingredients.length} món)',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: ingredients.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                          itemBuilder: (context, idx) {
                            final ing = ingredients[idx];
                            final icon = MealLogEntry.resolveIngredientIcon(ing);
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                              child: Row(
                                children: [
                                  Text(icon, style: const TextStyle(fontSize: 20)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      ing,
                                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                    ),
                                  ),
                                  const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF16A34A)),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // Nút xóa bữa ăn khỏi nhật ký
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          appState.removeMealLog(log.id);
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            SnackBar(
                              content: Text('Đã xóa "${log.title}" khỏi nhật ký'),
                              duration: const Duration(seconds: 2),
                              backgroundColor: AppColors.primaryDark,
                            ),
                          );
                        },
                        icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                        label: const Text('Xóa Bữa Ăn Này Khỏi Nhật Ký', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                          backgroundColor: const Color(0xFFFEF2F2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroDetailCard(String label, String value, String pct, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 2),
            Text(pct, style: TextStyle(fontSize: 9.5, color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_translations.dart';
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

  @override
  Widget build(BuildContext context) {
    final logs = appState.mealLogs;

    // Lọc theo MealType
    final filteredLogs = _selectedFilter == 'ALL'
        ? logs
        : logs.where((item) {
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
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Bar
              _buildTopBar(),
              const SizedBox(height: 16),

              // 2. Thẻ Hero Dashboard Tổng Hợp Dinh Dưỡng Cao Cấp
              _buildNutritionHeroCard(),
              const SizedBox(height: 20),

              // 3. Thanh Lọc Theo Bữa Ăn (Tabs / Filter Chips)
              _buildMealTypeFilters(logs),
              const SizedBox(height: 16),

              // 4. Danh Sách Món Ăn Trong Ngày
              if (filteredLogs.isEmpty)
                _buildEmptyState()
              else
                _buildMealLogsList(filteredLogs),

              const SizedBox(height: 24),
            ],
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
    final int totalCal = appState.totalCaloriesLogged;
    final int goalCal = appState.dailyCalorieGoal > 0 ? appState.dailyCalorieGoal : 2000;
    final double calPercent = (totalCal / goalCal).clamp(0.0, 1.0);

    final int pro = appState.totalProteinLogged;
    final int targetPro = appState.userProfile.targetProtein > 0 ? appState.userProfile.targetProtein.round() : 130;

    final int carb = appState.totalCarbsLogged;
    final int targetCarb = appState.userProfile.targetCarbs > 0 ? appState.userProfile.targetCarbs.round() : 180;

    final int fat = appState.totalFatLogged;
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
                        ? '${AppTranslations.tr('remaining')}: ${appState.remainingCalories} kcal ${AppTranslations.tr('kcal_left')}'
                        : '${AppTranslations.tr('energy_today')}: Vượt ${-appState.remainingCalories} kcal',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
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
                    log.imageUrl,
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
                              log.mealType,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: typeColor),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            log.time,
                            style: const TextStyle(fontSize: 11, color: AppColors.textGray),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        log.title,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
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
}
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/app_state_service.dart';

/// Modal BottomSheet hiển thị báo cáo đánh giá dinh dưỡng từ AI
class AiNutritionReportSheet extends StatefulWidget {
  final String initialPeriod;

  const AiNutritionReportSheet({
    super.key,
    this.initialPeriod = 'yesterday',
  });

  /// Hàm tiện ích để mở Sheet từ bất kỳ màn hình nào
  static Future<void> show(BuildContext context, {String initialPeriod = 'yesterday'}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AiNutritionReportSheet(initialPeriod: initialPeriod),
    );
  }

  @override
  State<AiNutritionReportSheet> createState() => _AiNutritionReportSheetState();
}

class _AiNutritionReportSheetState extends State<AiNutritionReportSheet> {
  late String _selectedPeriod;
  bool _isLoading = false;
  AiNutritionReview? _review;

  @override
  void initState() {
    super.initState();
    _selectedPeriod = widget.initialPeriod;
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
    });

    final report = await AppStateService.instance.fetchAiNutritionReview(_selectedPeriod);

    if (mounted) {
      setState(() {
        _review = report;
        _isLoading = false;
      });
    }
  }

  void _onPeriodChanged(String period) {
    if (_selectedPeriod == period) return;
    setState(() {
      _selectedPeriod = period;
    });
    _loadReport();
  }

  @override
  Widget build(BuildContext context) {
    final isVi = AppStateService.instance.currentLanguage == 'vi';

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // 1. Drag Handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.textLightGray.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 2. Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
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
                      Text(
                        isVi ? 'Đánh Giá Dinh Dưỡng AI' : 'AI Nutrition Assessment',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textBlack,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        isVi ? 'Phân tích & Lời khuyên cá nhân hóa' : 'Personalized Coaching & Insights',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textGray,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: AppColors.textGray),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3. Segmented Period Selector (Hôm qua / 7 ngày qua / Tháng trước)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  _buildPeriodPill('yesterday', isVi ? 'Hôm qua' : 'Yesterday'),
                  _buildPeriodPill('7days', isVi ? '7 ngày qua' : '7 Days'),
                  _buildPeriodPill('month', isVi ? 'Tháng trước' : 'Month'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 4. Content Area
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: AppColors.primary),
                        const SizedBox(height: 16),
                        Text(
                          isVi
                              ? 'Bác sĩ AI đang tổng hợp và đánh giá số liệu...'
                              : 'AI Nutritionist is analyzing your dietary data...',
                          style: const TextStyle(color: AppColors.textGray, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : _review == null
                    ? const SizedBox()
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Card Chấm điểm tổng quan
                            _buildScoreCard(_review!, isVi),
                            const SizedBox(height: 16),

                            if (!_review!.hasData) ...[
                              // Trạng thái tài khoản mới chưa có dữ liệu
                              _buildEmptyAccountCard(isVi),
                              const SizedBox(height: 16),
                            ] else ...[
                              // Thẻ Thống kê Calo & Macro
                              _buildNutrientBreakdownCard(_review!.metrics, isVi),
                              const SizedBox(height: 16),
                            ],

                            // Danh sách Điểm tốt (Strengths)
                            if (_review!.strengths.isNotEmpty) ...[
                              _buildSectionTitle(
                                Icons.check_circle_rounded,
                                const Color(0xFF16A34A),
                                isVi ? 'Điểm tích cực' : 'Key Strengths',
                              ),
                              const SizedBox(height: 8),
                              ..._review!.strengths.map((item) => _buildBulletItem(
                                    item,
                                    Icons.check_rounded,
                                    const Color(0xFF16A34A),
                                    const Color(0xFFDCFCE7),
                                  )),
                              const SizedBox(height: 16),
                            ],

                            // Danh sách Cần cải thiện (Improvements)
                            if (_review!.improvements.isNotEmpty) ...[
                              _buildSectionTitle(
                                Icons.warning_amber_rounded,
                                const Color(0xFFD97706),
                                isVi ? 'Điểm cần lưu ý & Cải thiện' : 'Areas to Improve',
                              ),
                              const SizedBox(height: 8),
                              ..._review!.improvements.map((item) => _buildBulletItem(
                                    item,
                                    Icons.arrow_forward_rounded,
                                    const Color(0xFFD97706),
                                    const Color(0xFFFEF3C7),
                                  )),
                              const SizedBox(height: 16),
                            ],

                            // Danh sách Lời khuyên hành động (Actionable Advice)
                            if (_review!.actionableAdvice.isNotEmpty) ...[
                              _buildSectionTitle(
                                Icons.tips_and_updates_rounded,
                                const Color(0xFF6366F1),
                                isVi ? 'Lời khuyên từ Huấn luyện viên AI' : 'Actionable Advice',
                              ),
                              const SizedBox(height: 8),
                              ..._review!.actionableAdvice.map((item) => _buildBulletItem(
                                    item,
                                    Icons.lightbulb_rounded,
                                    const Color(0xFF6366F1),
                                    const Color(0xFFEEF2FF),
                                  )),
                            ],
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodPill(String periodKey, String label) {
    final isSelected = _selectedPeriod == periodKey;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onPeriodChanged(periodKey),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppColors.textBlack : AppColors.textGray,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreCard(AiNutritionReview review, bool isVi) {
    final hasData = review.hasData;
    final score = review.score;
    Color scoreColor = const Color(0xFF16A34A); // Green
    String scoreLabel = isVi ? 'Xuất sắc' : 'Excellent';

    if (!hasData) {
      scoreColor = const Color(0xFF64748B); // Slate Gray (trung tính, không báo lỗi đỏ)
      scoreLabel = isVi ? 'Chưa ghi món' : 'No logs yet';
    } else if (score < 60) {
      scoreColor = const Color(0xFFDC2626); // Red
      scoreLabel = isVi ? 'Cần cải thiện' : 'Needs Work';
    } else if (score < 80) {
      scoreColor = const Color(0xFFD97706); // Amber
      scoreLabel = isVi ? 'Tương đối tốt' : 'Good';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Vòng tròn điểm số
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scoreColor.withValues(alpha: 0.12),
                  border: Border.all(color: scoreColor.withValues(alpha: 0.4), width: 3),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        review.hasData ? '$score' : '--',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: scoreColor,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        '/100',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: scoreColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Thông tin trạng thái
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: scoreColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        review.hasData ? scoreLabel : (isVi ? 'Chưa có dữ liệu' : 'No Data'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: scoreColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      review.periodLabel,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textBlack,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          Text(
            review.summary,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppColors.textBlack,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyAccountCard(bool isVi) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: AppColors.accentMint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.restaurant_menu_rounded,
              color: AppColors.primary,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isVi ? 'Bắt đầu hành trình dinh dưỡng' : 'Start Your Nutrition Journey',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textBlack,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isVi
                ? 'Tài khoản chưa có dữ liệu bữa ăn trong khoảng thời gian này. Hãy chụp ảnh hoặc ghi chép bữa ăn hôm nay để AI Chuyên Gia bắt đầu phân tích nhé!'
                : 'No meals logged yet for this period. Snap or log your meals today to unlock AI nutritional coaching!',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              color: AppColors.textGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientBreakdownCard(NutritionReviewMetrics metrics, bool isVi) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isVi ? 'Cân bằng Năng lượng & Dưỡng chất' : 'Energy & Macronutrients',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textBlack,
                ),
              ),
              Text(
                '${metrics.mealsCount} ${isVi ? 'bữa ăn' : 'meals'}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textGray,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Calo trung bình vs Mục tiêu
          _buildMetricProgressBar(
            isVi ? 'Năng lượng' : 'Calories',
            '${metrics.avgCaloriesPerDay} / ${metrics.targetCalories} kcal',
            metrics.targetCalories > 0 ? metrics.avgCaloriesPerDay / metrics.targetCalories : 0.0,
            AppColors.primary,
          ),
          const SizedBox(height: 10),

          // Protein
          _buildMetricProgressBar(
            isVi ? 'Đạm (Protein)' : 'Protein',
            '${metrics.avgProteinG} / ${metrics.targetProteinG} g',
            metrics.targetProteinG > 0 ? metrics.avgProteinG / metrics.targetProteinG : 0.0,
            const Color(0xFF3B82F6), // Blue
          ),
          const SizedBox(height: 10),

          // Carbs
          _buildMetricProgressBar(
            isVi ? 'Tinh bột (Carbs)' : 'Carbs',
            '${metrics.avgCarbsG} / ${metrics.targetCarbsG} g',
            metrics.targetCarbsG > 0 ? metrics.avgCarbsG / metrics.targetCarbsG : 0.0,
            const Color(0xFFF59E0B), // Amber
          ),
          const SizedBox(height: 10),

          // Fat
          _buildMetricProgressBar(
            isVi ? 'Chất béo (Fat)' : 'Fat',
            '${metrics.avgFatG} / ${metrics.targetFatG} g',
            metrics.targetFatG > 0 ? metrics.avgFatG / metrics.targetFatG : 0.0,
            const Color(0xFFEF4444), // Red
          ),
        ],
      ),
    );
  }

  Widget _buildMetricProgressBar(String label, String valueText, double ratio, Color color) {
    final clampedRatio = ratio.clamp(0.0, 1.0);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textGray, fontWeight: FontWeight.w500),
            ),
            Text(
              valueText,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textBlack),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: clampedRatio,
            minHeight: 6,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(IconData icon, Color color, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textBlack,
          ),
        ),
      ],
    );
  }

  Widget _buildBulletItem(String text, IconData icon, Color iconColor, Color bgColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textBlack,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

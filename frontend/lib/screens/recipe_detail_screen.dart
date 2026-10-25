import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../constants/app_colors.dart';
import '../constants/app_translations.dart';
import '../services/app_state_service.dart';
import '../services/meal_db_service.dart';
import '../services/recipe_translator.dart';
import '../widgets/recipe_image_widget.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Function(int) onNavigate;

  const RecipeDetailScreen({
    super.key,
    required this.onNavigate,
  });

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  YoutubePlayerController? _youtubeController;
  String? _currentMealId;
  String? _currentVideoId;
  bool _isLoadingDetail = false;
  bool _isAiFiltering = false;

  @override
  void initState() {
    super.initState();
    AppStateService.instance.addListener(_handleAppStateChanged);
    _syncMealAndVideo(force: true);
  }

  void _handleAppStateChanged() {
    // Nếu người dùng chuyển tab sang màn hình khác ngoài RecipeDetail (index != 6), tạm dừng video
    if (AppStateService.instance.currentScreenIndex != 6) {
      _youtubeController?.pauseVideo();
    }
    _syncMealAndVideo();
  }

  void _syncMealAndVideo({bool force = false}) {
    final meal = AppStateService.instance.selectedMeal;
    if (meal == null) return;

    final bool mealChanged = (meal.idMeal != _currentMealId);
    final currentYtUrl = meal.strYoutube?.trim() ?? '';
    final String? newVideoId = currentYtUrl.isNotEmpty ? YoutubePlayerController.convertUrlToId(currentYtUrl) : null;
    final bool videoChanged = (newVideoId != _currentVideoId);

    if (mealChanged || videoChanged || force) {
      _currentMealId = meal.idMeal;
      _currentVideoId = newVideoId;

      _youtubeController?.close();
      _youtubeController = null;

      if (newVideoId != null && newVideoId.isNotEmpty) {
        _youtubeController = YoutubePlayerController.fromVideoId(
          videoId: newVideoId,
          autoPlay: false,
          params: const YoutubePlayerParams(
            showControls: true,
            showFullscreenButton: true,
          ),
        );
      }

      if (mounted) {
        setState(() {});
      }
    }

    if (mealChanged) {
      _ensureDetailLoaded();
    }
  }

  void _ensureDetailLoaded() async {
    final meal = AppStateService.instance.selectedMeal;
    final lang = AppStateService.instance.currentLanguage;
    if (meal == null || meal.idMeal.isEmpty) return;

    final bool isVi = lang == 'vi';
    final bool instructionsNotVi = isVi &&
        (meal.strInstructionsVi == null ||
            meal.strInstructionsVi!.trim().isEmpty ||
            meal.strInstructionsVi == meal.strInstructions ||
            !RecipeTranslator.hasVietnameseDiacritics(meal.strInstructionsVi));

    // Cần tải đầy đủ nếu: chưa có nguyên liệu HOẶC chưa có hướng dẫn HOẶC chưa có bản dịch tiếng Việt hợp lệ
    final bool needsDetail = meal.ingredients.isEmpty ||
        meal.strInstructions == null ||
        meal.strInstructions!.trim().isEmpty ||
        instructionsNotVi ||
        (isVi && meal.ingredientsVi.isEmpty);

    if (needsDetail) {
      if (_isLoadingDetail) return;
      _isLoadingDetail = true;
      if (mounted) setState(() {});
      final fullDetail = await TheMealDbService.getMealDetail(
        meal.idMeal,
        lang: lang,
        forceAi: instructionsNotVi,
      );
      if (mounted && fullDetail != null) {
        AppStateService.instance.setSelectedMeal(fullDetail);
        setState(() {
          _isLoadingDetail = false;
        });
      } else {
        if (mounted) setState(() => _isLoadingDetail = false);
      }
    }
  }

  Future<void> _triggerAiFilter() async {
    final meal = AppStateService.instance.selectedMeal;
    if (meal == null || _isAiFiltering) return;

    setState(() {
      _isAiFiltering = true;
    });

    final updated = await TheMealDbService.getMealDetail(meal.idMeal, lang: 'vi', forceAi: true);
    if (mounted) {
      if (updated != null) {
        AppStateService.instance.setSelectedMeal(updated);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('Bộ lọc AI đã tối ưu và dịch 100% công thức sang Tiếng Việt!')),
              ],
            ),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
      setState(() {
        _isAiFiltering = false;
      });
    }
  }

  @override
  void dispose() {
    AppStateService.instance.removeListener(_handleAppStateChanged);
    _youtubeController?.close();
    super.dispose();
  }

  void _handleBack(BuildContext context) {
    _youtubeController?.pauseVideo();
    // Luôn quay về tab trước đó trong MainShellScreen, tuyệt đối không pop route tránh văng ra Login
    final prevIndex = AppStateService.instance.previousScreenIndex;
    widget.onNavigate(prevIndex == 6 ? 0 : prevIndex);
  }

  @override
  Widget build(BuildContext context) {
    final isVi = AppStateService.instance.currentLanguage == 'vi';

    final selected = AppStateService.instance.selectedMeal;
    if (selected != null && selected.idMeal != _currentMealId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncMealAndVideo();
      });
    }

    final currentMeal = selected ??
        MealItem(
          idMeal: '52772',
          strMeal: 'Teriyaki Chicken Casserole',
          strMealThumb: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=600&q=80',
          strCategory: 'Chicken',
          strArea: 'Japanese',
          strInstructions:
              '1. Luộc chín gà và xé nhỏ.\n2. Trộn xốt teriyaki cùng tỏi băm và gừng nạo.\n3. Xếp rau củ và thịt gà vào khay nướng.\n4. Rưới đều nước xốt và nướng ở nhiệt độ 190°C trong 25 phút.\n5. Thưởng thức nóng kèm cơm lứt hoặc salad.',
          strYoutube: 'https://www.youtube.com/watch?v=4aZr5hZXP_s',
          ingredients: ['Chicken Breast', 'Soy Sauce', 'Brown Sugar', 'Garlic', 'Ginger', 'Broccoli', 'Carrots'],
          measures: ['400g', '3 tbsp', '1 tbsp', '2 cloves', '1 tsp', '1 cây', '1 củ'],
          estimatedCalories: 450,
          estimatedProtein: 38,
          estimatedCarbs: 28,
          estimatedFat: 12,
        );

    final translatedMealName = isVi
        ? (currentMeal.strMealVi ?? RecipeTranslator.translateDishName(currentMeal.strMeal))
        : currentMeal.strMeal;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Column(
            children: [
              // 1. Top App Bar
              _buildTopAppBar(context, currentMeal),

              // 2. Nội dung cuộn chính
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Banner ảnh lớn kèm tên món
                      _buildHeroBanner(currentMeal, translatedMealName, isVi),
                      const SizedBox(height: 16),

                      // Thẻ Năng lượng khẩu phần & Macro
                      _buildNutritionCard(currentMeal),
                      const SizedBox(height: 16),

                      // Khối Video Hướng Dẫn YouTube Trực Tiếp Trên App (Không nhảy trang)
                      _buildVideoSection(context, currentMeal, isVi),
                      const SizedBox(height: 16),

                      // Khối Nguyên liệu cần chuẩn bị (100% dịch theo ngôn ngữ đã chọn)
                      _buildIngredientsSection(currentMeal, isVi),
                      const SizedBox(height: 16),

                      // Khối Hướng dẫn chế biến (100% dịch theo ngôn ngữ đã chọn)
                      _buildCookingStepsSection(currentMeal, isVi),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // 3. Nút cố định ở đáy: "Đã nấu xong & Thêm vào nhật ký"
              _buildBottomCta(context, currentMeal, isVi),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopAppBar(BuildContext context, MealItem meal) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () => _handleBack(context),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back, color: AppColors.textBlack, size: 20),
            ),
          ),
          Text(
            AppTranslations.tr('recipe_detail'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textBlack,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_border, color: AppColors.textBlack),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${AppTranslations.tr('recipe_saved')}: "${meal.strMeal}"'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBanner(MealItem meal, String displayName, bool isVi) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          RecipeImageWidget(
            imageUrl: meal.strMealThumb,
            mealName: meal.strMealVi ?? meal.strMeal,
            category: meal.strCategory,
            height: 230,
            width: double.infinity,
            isHeroBanner: true,
          ),
          Container(
            height: 230,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.8),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (meal.strCategory != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          meal.strCategory!,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    if (meal.strArea != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          meal.strArea!,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionCard(MealItem meal) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppTranslations.tr('energy_today'),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textBlack),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.accentMint, borderRadius: BorderRadius.circular(8)),
                child: Text('1 ${AppTranslations.tr('serving')}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMacroItem(AppTranslations.tr('calories_upper'), '${meal.estimatedCalories}', 'kcal', Colors.deepOrange),
              _buildMacroItem(AppTranslations.tr('pro').toUpperCase(), '${meal.estimatedProtein}', 'g', Colors.blue.shade700),
              _buildMacroItem(AppTranslations.tr('carb').toUpperCase(), '${meal.estimatedCarbs}', 'g', Colors.amber.shade800),
              _buildMacroItem(AppTranslations.tr('fat').toUpperCase(), '${meal.estimatedFat}', 'g', Colors.red.shade700),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroItem(String label, String value, String unit, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textGray, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(width: 2),
            Text(unit, style: const TextStyle(fontSize: 10, color: AppColors.textGray)),
          ],
        ),
      ],
    );
  }

  /// Khối Video Hướng Dẫn Nấu Ăn: Phát TRỰC TIẾP TRONG APP qua YoutubePlayer
  Widget _buildVideoSection(BuildContext context, MealItem meal, bool isVi) {
    final bool hasValidVideo = _youtubeController != null && _currentVideoId != null && _currentVideoId!.isNotEmpty;

    if (hasValidVideo) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE4E6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.play_circle_fill_rounded, color: Color(0xFFE11D48), size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppTranslations.tr('video_guide'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.smart_display_rounded, color: Color(0xFFDC2626), size: 12),
                      const SizedBox(width: 4),
                      Text(
                        AppTranslations.tr('in_app_video'),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Player trực tiếp trong app với ValueKey độc lập theo từng món & video ID
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: YoutubePlayer(
                key: ValueKey('yt_${meal.idMeal}_$_currentVideoId'),
                controller: _youtubeController!,
                aspectRatio: 16 / 9,
              ),
            ),
            const SizedBox(height: 10),

            // Tùy chọn mở xem trên ứng dụng YouTube ngoài
            InkWell(
              onTap: () async {
                final url = meal.strYoutube?.trim();
                if (url != null && url.isNotEmpty) {
                  final uri = Uri.tryParse(url);
                  if (uri != null) {
                    try {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } catch (_) {}
                  }
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Icon(Icons.open_in_new_rounded, size: 14, color: Color(0xFFDC2626)),
                    const SizedBox(width: 4),
                    Text(
                      isVi ? 'Xem trên ứng dụng YouTube' : 'Open in YouTube App',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFDC2626)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Nếu không có video YouTube chính thức thì hiển thị nút tìm kiếm video nấu trên YouTube
    final dishName = (isVi && meal.strMealVi != null && meal.strMealVi!.isNotEmpty) ? meal.strMealVi! : meal.strMeal;
    final searchUrl = 'https://www.youtube.com/results?search_query=${Uri.encodeComponent('$dishName recipe tutorial')}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            final uri = Uri.parse(searchUrl);
            try {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } catch (_) {}
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE4E6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Color(0xFFDC2626), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppTranslations.tr('video_guide'),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppTranslations.tr('video_tap_to_search'),
                        style: const TextStyle(fontSize: 11, color: AppColors.textGray),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.open_in_new_rounded, color: Color(0xFFDC2626), size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Khối Nguyên liệu: Đảm bảo 100% Tiếng Việt khi chọn Tiếng Việt, 100% Tiếng Anh khi chọn Tiếng Anh
  Widget _buildIngredientsSection(MealItem meal, bool isVi) {
    final int count = isVi && meal.ingredientsVi.isNotEmpty
        ? meal.ingredientsVi.length
        : meal.ingredients.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppTranslations.tr('ingredients'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textBlack),
              ),
              if (_isLoadingDetail)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                )
              else
                Text(
                  '$count ${AppTranslations.tr('items_count')}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textGray),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (count == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Center(
                child: Text(
                  _isLoadingDetail ? 'Đang tải nguyên liệu...' : 'Đang cập nhật nguyên liệu cho món này',
                  style: const TextStyle(fontSize: 12, color: AppColors.textGray),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: count,
              separatorBuilder: (_, __) => const Divider(height: 12, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final rawIng = index < meal.ingredients.length ? meal.ingredients[index] : '';
                final rawMeasure = index < meal.measures.length ? meal.measures[index] : '';

                String displayIng;
                String displayMeasure;

                if (isVi) {
                  final candidateIng = (meal.ingredientsVi.isNotEmpty && index < meal.ingredientsVi.length && meal.ingredientsVi[index].trim().isNotEmpty)
                      ? meal.ingredientsVi[index]
                      : rawIng;
                  displayIng = RecipeTranslator.translateIngredient(candidateIng, rawIng);
                  if (displayIng.isEmpty) {
                    displayIng = 'Nguyên liệu ${index + 1}';
                  }

                  final candidateMeasure = (meal.measuresVi.isNotEmpty && index < meal.measuresVi.length && meal.measuresVi[index].trim().isNotEmpty)
                      ? meal.measuresVi[index]
                      : rawMeasure;
                  displayMeasure = RecipeTranslator.translateMeasure(candidateMeasure, displayIng, index);
                } else {
                  displayIng = rawIng.isNotEmpty
                      ? rawIng
                      : (index < meal.ingredientsVi.length ? meal.ingredientsVi[index] : 'Ingredient ${index + 1}');
                  final candidateMeasure = (meal.measures.isNotEmpty && index < meal.measures.length && meal.measures[index].trim().isNotEmpty)
                      ? meal.measures[index]
                      : (index < meal.measuresVi.length ? meal.measuresVi[index] : '');
                  displayMeasure = RecipeTranslator.translateMeasure(candidateMeasure, displayIng, index);
                }

                return Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        displayIng,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textBlack),
                      ),
                    ),
                    if (displayMeasure.isNotEmpty)
                      Text(
                        displayMeasure,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  /// Khối Các bước nấu: Đảm bảo 100% Tiếng Việt khi chọn Tiếng Việt, 100% Tiếng Anh khi chọn Tiếng Anh
  Widget _buildCookingStepsSection(MealItem meal, bool isVi) {
    String instructions;

    if (isVi) {
      if (meal.strInstructionsVi != null &&
          meal.strInstructionsVi!.trim().isNotEmpty &&
          RecipeTranslator.hasVietnameseDiacritics(meal.strInstructionsVi)) {
        instructions = meal.strInstructionsVi!;
      } else {
        instructions = meal.strInstructions ??
            'Làm sạch nguyên liệu và nấu chín theo nhiệt độ thích hợp. Thưởng thức khi còn nóng.';
      }
    } else {
      instructions = meal.strInstructions ??
          'Prepare ingredients and cook thoroughly over appropriate heat. Serve hot.';
    }

    // Bóc tách chuẩn xác các bước nấu bằng RecipeTranslator.parseCookingSteps
    final List<String> rawSteps = RecipeTranslator.parseCookingSteps(instructions);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppTranslations.tr('cooking_steps'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                  ),
                  if (isVi) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, size: 10, color: Color(0xFF16A34A)),
                          SizedBox(width: 3),
                          Text(
                            'AI Filter',
                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              if (_isLoadingDetail || _isAiFiltering)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                )
              else if (isVi)
                InkWell(
                  onTap: _triggerAiFilter,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded, size: 12, color: Color(0xFF64748B)),
                        SizedBox(width: 4),
                        Text(
                          'Dịch lại AI',
                          style: TextStyle(fontSize: 10.5, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (_isAiFiltering) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF16A34A)),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bộ lọc AI đang tối ưu hóa và dịch thuật công thức...',
                      style: TextStyle(fontSize: 11, color: Color(0xFF15803D), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (rawSteps.isNotEmpty)
            ...rawSteps.asMap().entries.map((entry) {
              final stepText = entry.value.trim();
              final displayStep = RecipeTranslator.translateInstructionStep(stepText, entry.key);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.accentIndigo,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${entry.key + 1}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        displayStep,
                        style: const TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF334155)),
                      ),
                    ),
                  ],
                ),
              );
            })
          else
            Text(instructions, style: const TextStyle(fontSize: 12, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildBottomCta(BuildContext context, MealItem meal, bool isVi) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4)),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: () {
            AppStateService.instance.addMealLogFromMeal(meal);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppTranslations.tr('added_success')),
                backgroundColor: AppColors.primary,
                duration: const Duration(seconds: 2),
              ),
            );

            widget.onNavigate(2);
          },
          icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
          label: Text(
            AppTranslations.tr('cooked_add_diary'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
        ),
      ),
    );
  }
}
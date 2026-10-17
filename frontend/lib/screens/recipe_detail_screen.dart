import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../constants/app_colors.dart';
import '../constants/app_translations.dart';
import '../services/app_state_service.dart';
import '../services/meal_db_service.dart';
import '../services/recipe_translator.dart';

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
  bool _isLoadingDetail = false;

  @override
  void initState() {
    super.initState();
    _initYoutubePlayer();
    _ensureDetailLoaded();
  }

  void _initYoutubePlayer() {
    final meal = AppStateService.instance.selectedMeal;
    _currentMealId = meal?.idMeal;
    final url = meal?.strYoutube;

    if (url != null && url.trim().isNotEmpty) {
      final videoId = YoutubePlayerController.convertUrlToId(url);
      if (videoId != null && videoId.isNotEmpty) {
        _youtubeController = YoutubePlayerController.fromVideoId(
          videoId: videoId,
          autoPlay: false,
          params: const YoutubePlayerParams(
            showControls: true,
            showFullscreenButton: true,
          ),
        );
      }
    }
  }

  void _ensureDetailLoaded() async {
    final meal = AppStateService.instance.selectedMeal;
    final lang = AppStateService.instance.currentLanguage;
    if (meal == null || meal.idMeal.isEmpty) return;

    // Cần tải đầy đủ nếu: chưa có nguyên liệu HOẶC chưa có hướng dẫn HOẶC chưa có bản dịch tiếng Việt
    final bool needsDetail = meal.ingredients.isEmpty ||
        meal.strInstructions == null ||
        meal.strInstructions!.trim().isEmpty ||
        (lang == 'vi' && (meal.strInstructionsVi == null || meal.strInstructionsVi!.trim().isEmpty || meal.ingredientsVi.isEmpty));

    if (needsDetail) {
      if (_isLoadingDetail) return;
      _isLoadingDetail = true;
      final fullDetail = await TheMealDbService.getMealDetail(meal.idMeal, lang: lang);
      if (mounted && fullDetail != null) {
        AppStateService.instance.setSelectedMeal(fullDetail);
        if (fullDetail.strYoutube != null && fullDetail.strYoutube!.trim().isNotEmpty) {
          _youtubeController?.close();
          _youtubeController = null;
          _initYoutubePlayer();
        }
        setState(() {
          _isLoadingDetail = false;
        });
      } else {
        if (mounted) setState(() => _isLoadingDetail = false);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final meal = AppStateService.instance.selectedMeal;
    if (meal?.idMeal != _currentMealId) {
      _youtubeController?.close();
      _youtubeController = null;
      _initYoutubePlayer();
      _ensureDetailLoaded();
    }
  }

  @override
  void dispose() {
    _youtubeController?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVi = AppStateService.instance.currentLanguage == 'vi';

    final currentMeal = AppStateService.instance.selectedMeal ??
        MealItem(
          idMeal: '52772',
          strMeal: 'Teriyaki Chicken Casserole',
          strMealThumb: 'https://www.themealdb.com/images/media/meals/wvpsxx1468256321.jpg',
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

    return Scaffold(
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
    );
  }

  Widget _buildTopAppBar(BuildContext context, MealItem meal) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () => widget.onNavigate(0),
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
          Image.network(
            meal.strMealThumb,
            height: 230,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 230,
              color: Colors.grey.shade200,
              child: const Center(child: Icon(Icons.restaurant, size: 50, color: Colors.grey)),
            ),
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
    if (_youtubeController == null && meal.strYoutube != null && meal.strYoutube!.trim().isNotEmpty) {
      final videoId = YoutubePlayerController.convertUrlToId(meal.strYoutube!);
      if (videoId != null && videoId.isNotEmpty) {
        _youtubeController = YoutubePlayerController.fromVideoId(
          videoId: videoId,
          autoPlay: false,
          params: const YoutubePlayerParams(
            showControls: true,
            showFullscreenButton: true,
          ),
        );
      }
    }

    if (_youtubeController != null) {
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

            // Player trực tiếp trong app
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: YoutubePlayer(
                controller: _youtubeController!,
                aspectRatio: 16 / 9,
              ),
            ),
          ],
        ),
      );
    }

    // Nếu không có video YouTube chính thức
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.videocam_off_rounded, color: AppColors.textGray, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppTranslations.tr('no_video_available'),
              style: const TextStyle(fontSize: 11, color: AppColors.textGray),
            ),
          ),
        ],
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
                  if (meal.ingredientsVi.isNotEmpty && index < meal.ingredientsVi.length && meal.ingredientsVi[index].trim().isNotEmpty) {
                    displayIng = meal.ingredientsVi[index];
                  } else if (rawIng.isNotEmpty) {
                    displayIng = RecipeTranslator.translateIngredient(rawIng);
                  } else {
                    displayIng = 'Nguyên liệu ${index + 1}';
                  }

                  if (meal.measuresVi.isNotEmpty && index < meal.measuresVi.length && meal.measuresVi[index].trim().isNotEmpty) {
                    displayMeasure = meal.measuresVi[index];
                  } else if (rawMeasure.isNotEmpty) {
                    displayMeasure = RecipeTranslator.translateMeasure(rawMeasure);
                  } else {
                    displayMeasure = '';
                  }
                } else {
                  displayIng = rawIng.isNotEmpty
                      ? rawIng
                      : (index < meal.ingredientsVi.length ? meal.ingredientsVi[index] : 'Ingredient ${index + 1}');
                  displayMeasure = rawMeasure.isNotEmpty
                      ? rawMeasure
                      : (index < meal.measuresVi.length ? meal.measuresVi[index] : '');
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
    bool alreadyTranslated = false;

    if (isVi) {
      if (meal.strInstructionsVi != null && meal.strInstructionsVi!.trim().isNotEmpty) {
        instructions = meal.strInstructionsVi!;
        alreadyTranslated = true;
      } else {
        instructions = meal.strInstructions ??
            'Làm sạch nguyên liệu và nấu chín theo nhiệt độ thích hợp. Thưởng thức khi còn nóng.';
      }
    } else {
      instructions = meal.strInstructions ??
          'Prepare ingredients and cook thoroughly over appropriate heat. Serve hot.';
    }

    // Tách theo dòng hoặc câu nếu chỉ là một đoạn văn dài
    List<String> rawSteps = instructions.split(RegExp(r'\r\n|\n|\r')).where((s) => s.trim().isNotEmpty).toList();
    if (rawSteps.length <= 1) {
      rawSteps = instructions.split(RegExp(r'\.\s+')).where((s) => s.trim().isNotEmpty).toList();
    }

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
                AppTranslations.tr('cooking_steps'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textBlack),
              ),
              if (_isLoadingDetail)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (rawSteps.isNotEmpty)
            ...rawSteps.asMap().entries.map((entry) {
              final stepText = entry.value.trim();
              final displayStep = (isVi && !alreadyTranslated)
                  ? RecipeTranslator.translateInstructionStep(stepText, entry.key)
                  : stepText;

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
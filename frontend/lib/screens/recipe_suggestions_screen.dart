import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_translations.dart';
import '../services/meal_db_service.dart';
import '../services/app_state_service.dart';
import '../services/recipe_translator.dart';

class RecipeSuggestionsScreen extends StatefulWidget {
  final Function(int) onNavigate;

  const RecipeSuggestionsScreen({
    super.key,
    required this.onNavigate,
  });

  @override
  State<RecipeSuggestionsScreen> createState() => _RecipeSuggestionsScreenState();
}

class _RecipeSuggestionsScreenState extends State<RecipeSuggestionsScreen> {
  final List<String> _categories = ['Chicken', 'Beef', 'Seafood', 'Vegetarian', 'Pasta', 'Dessert'];
  int _selectedCategoryIndex = 0;
  int _selectedQuickFilter = 0; // 0: Tất cả, 1: Phù hợp nhất, 2: Calo thấp, 3: Giàu đạm, 4: Vừa calo còn
  
  List<MealItem> _allMeals = [];
  bool _isLoading = false;
  int _displayLimit = 8;
  int _refreshCount = 0;
  final TextEditingController _searchController = TextEditingController();
  String _activeSearchKeyword = '';

  String _getCategoryDisplayName(String cat) {
    switch (cat) {
      case 'Chicken':
        return AppTranslations.tr('cat_chicken');
      case 'Beef':
        return AppTranslations.tr('cat_beef');
      case 'Seafood':
        return AppTranslations.tr('cat_seafood');
      case 'Vegetarian':
        return AppTranslations.tr('cat_vegetarian');
      case 'Pasta':
        return AppTranslations.tr('cat_pasta');
      case 'Dessert':
        return AppTranslations.tr('cat_dessert');
      default:
        return cat;
    }
  }

  @override
  void initState() {
    super.initState();
    final profile = AppStateService.instance.userProfile;
    if (profile.dietType == 'Vegetarian') {
      final vegIdx = _categories.indexOf('Vegetarian');
      if (vegIdx >= 0) {
        _selectedCategoryIndex = vegIdx;
      }
    }
    _fetchMealsForCategory(_categories[_selectedCategoryIndex]);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Thuật toán tính điểm phù hợp (Match Score: 55% - 98%)
  int _calculateMatchScore(MealItem meal, UserProfile profile, int remainingCal) {
    double score = 72.0;

    // 1. Phù hợp theo Mục tiêu hình thể (goal)
    switch (profile.goal) {
      case 'LoseWeight':
        if (meal.estimatedCalories <= 420) {
          score += 15;
        } else if (meal.estimatedCalories <= 520) {
          score += 8;
        } else if (meal.estimatedCalories > 650) {
          score -= 15;
        }
        if (meal.estimatedProtein >= 28) score += 6;
        if (meal.estimatedFat <= 15) score += 4;
        break;

      case 'GainWeight':
        if (meal.estimatedCalories >= 520) {
          score += 15;
        } else if (meal.estimatedCalories < 380) {
          score -= 10;
        }
        if (meal.estimatedProtein >= 32) score += 10;
        if (meal.estimatedCarbs >= 35) score += 5;
        break;

      case 'Maintain':
      default:
        if (meal.estimatedCalories >= 400 && meal.estimatedCalories <= 580) {
          score += 12;
        } else {
          score += 4;
        }
        if (meal.estimatedProtein >= 22) score += 6;
        break;
    }

    // 2. Phù hợp theo Chế độ ăn (dietType)
    switch (profile.dietType) {
      case 'HighProtein':
        if (meal.estimatedProtein >= 35) {
          score += 15;
        } else if (meal.estimatedProtein >= 25) {
          score += 8;
        } else if (meal.estimatedProtein < 16) {
          score -= 12;
        }
        break;

      case 'LowCarb':
        if (meal.estimatedCarbs <= 20) {
          score += 15;
        } else if (meal.estimatedCarbs <= 32) {
          score += 8;
        } else if (meal.estimatedCarbs > 55) {
          score -= 12;
        }
        break;

      case 'Vegetarian':
        final nameLower = meal.strMeal.toLowerCase();
        final catLower = (meal.strCategory ?? '').toLowerCase();
        final isMeat = nameLower.contains('chicken') ||
            nameLower.contains('beef') ||
            nameLower.contains('pork') ||
            nameLower.contains('meat') ||
            nameLower.contains('fish') ||
            nameLower.contains('shrimp') ||
            nameLower.contains('prawn') ||
            catLower.contains('chicken') ||
            catLower.contains('beef') ||
            catLower.contains('pork') ||
            catLower.contains('seafood') ||
            catLower.contains('lamb');
        if (isMeat) {
          return 0; // Tuyệt đối 0 điểm cho món thịt khi ăn chay
        }
        if (catLower.contains('vegetarian') || catLower.contains('vegan') || nameLower.contains('salad') || nameLower.contains('vegetable') || nameLower.contains('chay')) {
          score += 20;
        }
        break;

      case 'Balanced':
      default:
        if (meal.estimatedProtein >= 20 && meal.estimatedCarbs >= 20) {
          score += 10;
        }
        break;
    }

    // 3. Phù hợp theo Calo còn lại trong ngày (remainingCal)
    if (remainingCal > 0) {
      if (meal.estimatedCalories <= remainingCal) {
        score += 6;
        final ratio = meal.estimatedCalories / remainingCal;
        if (ratio >= 0.35 && ratio <= 0.85) {
          score += 5;
        }
      } else {
        score -= 10;
      }
    }

    return score.round().clamp(55, 98);
  }

  /// Sắp xếp danh sách món theo điểm phù hợp giảm dần
  List<MealItem> _sortByRecommendation(List<MealItem> items) {
    final profile = AppStateService.instance.userProfile;
    final remainingCal = AppStateService.instance.remainingCalories;

    final sorted = List<MealItem>.from(items);
    if (profile.dietType == 'Vegetarian') {
      sorted.removeWhere((m) {
        final nameLower = m.strMeal.toLowerCase();
        final catLower = (m.strCategory ?? '').toLowerCase();
        return nameLower.contains('chicken') ||
            nameLower.contains('beef') ||
            nameLower.contains('pork') ||
            nameLower.contains('meat') ||
            nameLower.contains('fish') ||
            nameLower.contains('shrimp') ||
            nameLower.contains('prawn') ||
            catLower.contains('chicken') ||
            catLower.contains('beef') ||
            catLower.contains('pork') ||
            catLower.contains('seafood') ||
            catLower.contains('lamb');
      });
    }
    sorted.sort((a, b) {
      final scoreA = _calculateMatchScore(a, profile, remainingCal);
      final scoreB = _calculateMatchScore(b, profile, remainingCal);
      return scoreB.compareTo(scoreA); // Điểm cao lên trước
    });
    return sorted;
  }

  Future<void> _fetchMealsForCategory(String category) async {
    setState(() {
      _isLoading = true;
      _activeSearchKeyword = '';
      _displayLimit = 8;
    });

    final profile = AppStateService.instance.userProfile;
    final remainingCal = AppStateService.instance.remainingCalories;

    final results = await TheMealDbService.getBackendRecommendations(
      goal: profile.goal,
      dietType: profile.dietType,
      targetCalories: profile.targetCalories,
      remainingCalories: remainingCal,
      category: category,
      limit: 30,
      refreshCount: _refreshCount,
    );

    if (mounted) {
      setState(() {
        _allMeals = results;
        _isLoading = false;
      });
    }
  }

  Future<void> _searchMeals(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      _fetchMealsForCategory(_categories[_selectedCategoryIndex]);
      return;
    }

    setState(() {
      _isLoading = true;
      _activeSearchKeyword = trimmed;
      _displayLimit = 8;
    });

    final results = await TheMealDbService.searchMeals(trimmed);
    if (mounted) {
      setState(() {
        _allMeals = _sortByRecommendation(results);
        _isLoading = false;
      });
    }
  }

  /// Lọc theo Chip tiêu chí nhanh
  List<MealItem> _getFilteredMeals() {
    final remainingCal = AppStateService.instance.remainingCalories;
    final profile = AppStateService.instance.userProfile;

    return _allMeals.where((meal) {
      switch (_selectedQuickFilter) {
        case 1: // 🎯 Phù hợp nhất (>= 85%)
          final score = _calculateMatchScore(meal, profile, remainingCal);
          return score >= 85;
        case 2: // 🔥 Calo thấp (< 450 kcal)
          return meal.estimatedCalories <= 450;
        case 3: // 💪 Giàu đạm (>= 30g)
          return meal.estimatedProtein >= 30;
        case 4: // ⚡ Vừa calo còn lại
          return remainingCal > 0 ? meal.estimatedCalories <= remainingCal : true;
        case 0:
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredMeals = _getFilteredMeals();
    final displayedMeals = filteredMeals.take(_displayLimit).toList();
    final profile = AppStateService.instance.userProfile;
    final remainingCal = AppStateService.instance.remainingCalories;

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          setState(() => _refreshCount++);
          if (_activeSearchKeyword.isNotEmpty) {
            await _searchMeals(_activeSearchKeyword);
          } else {
            await _fetchMealsForCategory(_categories[_selectedCategoryIndex]);
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
                  'NutriSnap Recipes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                ),
              ),
              const SizedBox(height: 14),

              // Top Bar
              Row(
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
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                      ),
                      child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.textBlack),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppTranslations.tr('recipes_title'),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
                        Text(AppTranslations.tr('recipes_sub'),
                            style: const TextStyle(fontSize: 11, color: AppColors.textGray)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Thanh Tìm Kiếm Thông Minh (Search Bar)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _searchMeals,
                  decoration: InputDecoration(
                    hintText: AppTranslations.tr('search_hint'),
                    hintStyle: const TextStyle(fontSize: 12, color: AppColors.textGray),
                    prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 22),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 20, color: AppColors.textGray),
                            onPressed: () {
                              _searchController.clear();
                              _fetchMealsForCategory(_categories[_selectedCategoryIndex]);
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Danh mục món ăn (Category Chips)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: List.generate(_categories.length, (index) {
                    final cat = _categories[index];
                    final isSelected = _activeSearchKeyword.isEmpty && _selectedCategoryIndex == index;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(_getCategoryDisplayName(cat)),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : AppColors.textBlack,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedCategoryIndex = index;
                              _selectedQuickFilter = 0;
                            });
                            _searchController.clear();
                            _fetchMealsForCategory(cat);
                          }
                        },
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 10),

              // Quick Filter Chips (Bộ lọc tiêu chí thuật toán)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildQuickFilterChip(0, AppTranslations.tr('filter_all')),
                    _buildQuickFilterChip(1, AppTranslations.tr('filter_best_match')),
                    _buildQuickFilterChip(2, AppTranslations.tr('filter_low_cal')),
                    _buildQuickFilterChip(3, AppTranslations.tr('filter_high_protein')),
                    _buildQuickFilterChip(4, AppTranslations.tr('filter_under_remaining')),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Header trạng thái tìm kiếm / kết quả
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _activeSearchKeyword.isNotEmpty
                        ? '${AppTranslations.tr('search_results_for')}: "$_activeSearchKeyword"'
                        : '${AppTranslations.tr('showing_count')} ${displayedMeals.length} ${AppTranslations.tr('of_count')} ${filteredMeals.length} ${AppTranslations.tr('recipes_found')}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textGray),
                  ),
                  if (remainingCal > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accentMint.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '⚡ $remainingCal ${AppTranslations.tr('kcal_left')}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Danh sách món ăn
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (filteredMeals.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                  child: Column(
                    children: [
                      const Icon(Icons.search_off_rounded, size: 48, color: AppColors.textGray),
                      const SizedBox(height: 8),
                      Text(AppTranslations.tr('no_recipes_found'),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textGray)),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _selectedQuickFilter = 0);
                          _fetchMealsForCategory(_categories[_selectedCategoryIndex]);
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(AppTranslations.tr('filter_all')),
                      ),
                    ],
                  ),
                )
              else ...[
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayedMeals.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final meal = displayedMeals[index];
                    final matchScore = _calculateMatchScore(meal, profile, remainingCal);
                    return _buildMealCard(meal, matchScore, remainingCal);
                  },
                ),

                const SizedBox(height: 16),

                // Nút "Xem thêm món" (Lazy loading pagination)
                if (_displayLimit < filteredMeals.length)
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _displayLimit += 8;
                        });
                      },
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                      label: Text(
                        '${AppTranslations.tr('load_more_recipes')} (${displayedMeals.length}/${filteredMeals.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: const BorderSide(color: AppColors.primary, width: 1.2),
                        ),
                      ),
                    ),
                  )
                else if (filteredMeals.length > 8)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        AppTranslations.tr('all_recipes_shown'),
                        style: const TextStyle(fontSize: 12, color: AppColors.textGray),
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickFilterChip(int filterIndex, String label) {
    final isSelected = _selectedQuickFilter == filterIndex;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppColors.primary.withOpacity(0.18),
        backgroundColor: Colors.white,
        showCheckmark: false,
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? AppColors.primaryDark : AppColors.textBlack,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected ? AppColors.primary : Colors.black.withOpacity(0.08),
            width: 1,
          ),
        ),
        onSelected: (selected) {
          setState(() {
            _selectedQuickFilter = isSelected ? 0 : filterIndex;
            _displayLimit = 8;
          });
        },
      ),
    );
  }

  Widget _buildMealCard(MealItem meal, int matchScore, int remainingCal) {
    final isVi = AppStateService.instance.currentLanguage == 'vi';
    final displayName = isVi ? RecipeTranslator.translateDishName(meal.strMeal) : meal.strMeal;

    return InkWell(
      onTap: () async {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        );
        final detail = await TheMealDbService.getMealDetail(meal.idMeal, lang: AppStateService.instance.currentLanguage);
        if (!mounted) return;
        Navigator.pop(context);

        AppStateService.instance.setSelectedMeal(detail ?? meal);
        widget.onNavigate(6);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.035),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ảnh món ăn kèm Match Score badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: Image.network(
                    meal.strMealThumb,
                    height: 165,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 165,
                      color: Colors.grey.shade200,
                      child: const Center(child: Icon(Icons.restaurant, color: Colors.grey, size: 40)),
                    ),
                  ),
                ),
                // Badge điểm phù hợp
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: matchScore >= 88
                          ? AppColors.primary
                          : (matchScore >= 75 ? AppColors.accentMint : Colors.white.withOpacity(0.92)),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 13,
                          color: matchScore >= 88 ? Colors.white : AppColors.primaryDark,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$matchScore% ${AppTranslations.tr('match_score')}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: matchScore >= 88 ? Colors.white : AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tên món ăn
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textBlack,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.accentMint,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          AppTranslations.tr('view_recipe'),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Dinh dưỡng tóm tắt
                  Text(
                    '~${meal.estimatedCalories} kcal • ${meal.estimatedProtein}g ${AppTranslations.tr('pro')} • ${meal.estimatedCarbs}g ${AppTranslations.tr('carb')} • ${meal.estimatedFat}g ${AppTranslations.tr('fat')}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textGray),
                  ),
                  const SizedBox(height: 8),

                  // Các tag tiêu chí nổi bật
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (meal.estimatedProtein >= 30)
                        _buildFeatureTag('💪 ${AppTranslations.tr('badge_high_protein')}', Colors.blue.shade50, Colors.blue.shade800),
                      if (meal.estimatedCalories <= 420)
                        _buildFeatureTag('🔥 ${AppTranslations.tr('badge_low_cal')}', Colors.orange.shade50, Colors.orange.shade800),
                      if (meal.estimatedCarbs <= 20)
                        _buildFeatureTag('🥑 ${AppTranslations.tr('badge_low_carb')}', Colors.purple.shade50, Colors.purple.shade800),
                      if (remainingCal > 0 && meal.estimatedCalories <= remainingCal)
                        _buildFeatureTag('⚡ ${AppTranslations.tr('badge_fits_cal')}', Colors.green.shade50, Colors.green.shade800),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureTag(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor),
      ),
    );
  }
}
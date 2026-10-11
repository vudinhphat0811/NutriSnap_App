enum MatchType { full, partial }

class RecipeModel {
  final String id;
  final String title;
  final String description;
  final String cookTime;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final int matchPercentage;
  final String matchText;
  final MatchType matchType;
  final String? missingIngredient;
  final String imageUrl;
  final List<String> availableIngredients;
  final bool isBookmarked;
  final String chefAdvice;

  const RecipeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.cookTime,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.matchPercentage,
    required this.matchText,
    required this.matchType,
    this.missingIngredient,
    required this.imageUrl,
    required this.availableIngredients,
    this.isBookmarked = false,
    required this.chefAdvice,
  });

  RecipeModel copyWith({
    bool? isBookmarked,
  }) {
    return RecipeModel(
      id: id,
      title: title,
      description: description,
      cookTime: cookTime,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      matchPercentage: matchPercentage,
      matchText: matchText,
      matchType: matchType,
      missingIngredient: missingIngredient,
      imageUrl: imageUrl,
      availableIngredients: availableIngredients,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      chefAdvice: chefAdvice,
    );
  }
}

final List<RecipeModel> mockRecipes = [
  const RecipeModel(
    id: '1',
    title: 'Ức gà áp chảo sốt tiêu đen & Bông cải',
    description: 'Đậm đà, giòn ngọt, giàu dinh dưỡng cho bữa tối phục hồi cơ bắp.',
    cookTime: '15 phút',
    calories: 380,
    protein: 42,
    carbs: 14,
    fat: 8,
    matchPercentage: 100,
    matchText: 'Khớp 100% nguyên liệu',
    matchType: MatchType.full,
    imageUrl: 'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?auto=format&fit=crop&w=600&q=80',
    availableIngredients: ['Ức gà', 'Bông cải xanh', 'Cà chua bi'],
    isBookmarked: true,
    chefAdvice: 'Ức gà nên khứa nhẹ hình quả trám trước khi ướp 5 phút. Khi áp chảo, đậy vung ở 2 phút cuối.',
  ),
  const RecipeModel(
    id: '2',
    title: 'Trứng xào cà chua ăn kèm cơm gạo lứt',
    description: 'Món ăn truyền thống ấm cúng, chuẩn bị siêu tốc, dịu nhẹ đường ruột.',
    cookTime: '10 phút',
    calories: 310,
    protein: 18,
    carbs: 32,
    fat: 12,
    matchPercentage: 100,
    matchText: 'Khớp 100% nguyên liệu',
    matchType: MatchType.full,
    imageUrl: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=600&q=80',
    availableIngredients: ['Trứng gà', 'Cà chua', 'Gạo lứt'],
    isBookmarked: false,
    chefAdvice: 'Đánh trứng nhẹ tay cùng một thìa nước lọc để trứng xốp bông mềm.',
  ),
  const RecipeModel(
    id: '3',
    title: 'Canh ức gà nấu cà chua và nấm',
    description: 'Thanh đạm, cấp ẩm sâu, phù hợp giải nhiệt và giữ nhẹ bụng lúc tối muộn.',
    cookTime: '20 phút',
    calories: 290,
    protein: 35,
    carbs: 18,
    fat: 5,
    matchPercentage: 90,
    matchText: 'Thiếu 1 gia vị (Hành lá)',
    matchType: MatchType.partial,
    missingIngredient: 'Hành lá',
    imageUrl: 'https://images.unsplash.com/photo-1547592166-23ac45744acd?auto=format&fit=crop&w=600&q=80',
    availableIngredients: ['Ức gà', 'Cà chua', 'Nấm mỡ'],
    isBookmarked: false,
    chefAdvice: 'Ức gà thái lát mỏng, cho vào sau cùng khi canh sôi bùng để giữ thịt ngọt mềm.',
  ),
];
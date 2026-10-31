class VoiceAssistantResponse {
  final String? userPrompt;
  final String actionType;
  final String spokenReply;
  final VoiceMealData? mealData;
  final VoiceFridgeRecipeData? recipeData;
  final VoiceWaterData? waterData;
  final VoiceFridgeAddData? fridgeAddData;
  final VoiceNavigateData? navigateData;

  const VoiceAssistantResponse({
    this.userPrompt,
    required this.actionType,
    required this.spokenReply,
    this.mealData,
    this.recipeData,
    this.waterData,
    this.fridgeAddData,
    this.navigateData,
  });

  factory VoiceAssistantResponse.fromJson(Map<String, dynamic> json) {
    return VoiceAssistantResponse(
      userPrompt: json['userPrompt'] ?? json['UserPrompt'],
      actionType: json['actionType'] ?? json['ActionType'] ?? 'general_chat',
      spokenReply: json['spokenReply'] ?? json['SpokenReply'] ?? '',
      mealData: (json['mealData'] != null || json['MealData'] != null)
          ? VoiceMealData.fromJson(Map<String, dynamic>.from(json['mealData'] ?? json['MealData']))
          : null,
      recipeData: (json['recipeData'] != null || json['RecipeData'] != null)
          ? VoiceFridgeRecipeData.fromJson(Map<String, dynamic>.from(json['recipeData'] ?? json['RecipeData']))
          : null,
      waterData: (json['waterData'] != null || json['WaterData'] != null)
          ? VoiceWaterData.fromJson(Map<String, dynamic>.from(json['waterData'] ?? json['WaterData']))
          : null,
      fridgeAddData: (json['fridgeAddData'] != null || json['FridgeAddData'] != null)
          ? VoiceFridgeAddData.fromJson(Map<String, dynamic>.from(json['fridgeAddData'] ?? json['FridgeAddData']))
          : null,
      navigateData: (json['navigateData'] != null || json['NavigateData'] != null)
          ? VoiceNavigateData.fromJson(Map<String, dynamic>.from(json['navigateData'] ?? json['NavigateData']))
          : null,
    );
  }
}

class VoiceMealData {
  final String mealType;
  final String title;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final List<String> items;

  const VoiceMealData({
    required this.mealType,
    required this.title,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.items = const [],
  });

  factory VoiceMealData.fromJson(Map<String, dynamic> json) {
    return VoiceMealData(
      mealType: json['mealType'] ?? json['MealType'] ?? 'Trưa',
      title: json['title'] ?? json['Title'] ?? 'Bữa ăn',
      calories: (json['calories'] ?? json['Calories'] ?? 0).toInt(),
      protein: (json['protein'] ?? json['Protein'] ?? 0.0).toDouble(),
      carbs: (json['carbs'] ?? json['Carbs'] ?? 0.0).toDouble(),
      fat: (json['fat'] ?? json['Fat'] ?? 0.0).toDouble(),
      items: (json['items'] ?? json['Items'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class VoiceFridgeRecipeData {
  final String recipeTitle;
  final String matchExplanation;
  final int prepTimeMinutes;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final List<VoiceRecipeIngredient> ingredientsUsed;
  final List<String> cookingSteps;

  const VoiceFridgeRecipeData({
    required this.recipeTitle,
    required this.matchExplanation,
    this.prepTimeMinutes = 15,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.ingredientsUsed = const [],
    this.cookingSteps = const [],
  });

  factory VoiceFridgeRecipeData.fromJson(Map<String, dynamic> json) {
    return VoiceFridgeRecipeData(
      recipeTitle: json['recipeTitle'] ?? json['RecipeTitle'] ?? 'Món ngon từ tủ lạnh',
      matchExplanation: json['matchExplanation'] ?? json['MatchExplanation'] ?? '',
      prepTimeMinutes: (json['prepTimeMinutes'] ?? json['PrepTimeMinutes'] ?? 15).toInt(),
      calories: (json['calories'] ?? json['Calories'] ?? 0).toInt(),
      protein: (json['protein'] ?? json['Protein'] ?? 0.0).toDouble(),
      carbs: (json['carbs'] ?? json['Carbs'] ?? 0.0).toDouble(),
      fat: (json['fat'] ?? json['Fat'] ?? 0.0).toDouble(),
      ingredientsUsed: (json['ingredientsUsed'] ?? json['IngredientsUsed'] as List?)
              ?.map((e) => VoiceRecipeIngredient.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      cookingSteps: (json['cookingSteps'] ?? json['CookingSteps'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class VoiceRecipeIngredient {
  final String name;
  final String amount;
  final bool inFridge;

  const VoiceRecipeIngredient({
    required this.name,
    required this.amount,
    this.inFridge = true,
  });

  factory VoiceRecipeIngredient.fromJson(Map<String, dynamic> json) {
    return VoiceRecipeIngredient(
      name: json['name'] ?? json['Name'] ?? '',
      amount: json['amount'] ?? json['Amount'] ?? '',
      inFridge: json['inFridge'] ?? json['InFridge'] ?? true,
    );
  }
}

class VoiceWaterData {
  final int amountMl;
  final int newTotalMl;

  const VoiceWaterData({
    required this.amountMl,
    required this.newTotalMl,
  });

  factory VoiceWaterData.fromJson(Map<String, dynamic> json) {
    return VoiceWaterData(
      amountMl: (json['amountMl'] ?? json['AmountMl'] ?? 250).toInt(),
      newTotalMl: (json['newTotalMl'] ?? json['NewTotalMl'] ?? 0).toInt(),
    );
  }
}

class VoiceFridgeAddData {
  final String name;
  final String category;
  final String quantity;
  final int shelfLifeDays;
  final String storageLocation;

  const VoiceFridgeAddData({
    required this.name,
    this.category = 'Thực phẩm',
    this.quantity = '1 phần',
    this.shelfLifeDays = 3,
    this.storageLocation = 'fridge',
  });

  factory VoiceFridgeAddData.fromJson(Map<String, dynamic> json) {
    return VoiceFridgeAddData(
      name: json['name'] ?? json['Name'] ?? 'Thực phẩm mới',
      category: json['category'] ?? json['Category'] ?? 'Thực phẩm tươi',
      quantity: json['quantity'] ?? json['Quantity'] ?? '1 phần',
      shelfLifeDays: (json['shelfLifeDays'] ?? json['ShelfLifeDays'] ?? 3).toInt(),
      storageLocation: json['storageLocation'] ?? json['StorageLocation'] ?? 'fridge',
    );
  }
}

class VoiceNavigateData {
  final String targetScreen;

  const VoiceNavigateData({required this.targetScreen});

  factory VoiceNavigateData.fromJson(Map<String, dynamic> json) {
    return VoiceNavigateData(
      targetScreen: json['targetScreen'] ?? json['TargetScreen'] ?? 'dashboard',
    );
  }
}

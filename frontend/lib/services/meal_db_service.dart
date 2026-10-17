import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
import 'app_state_service.dart';

/// Model chi tiết món ăn (UI Model)
class MealItem {
  final String idMeal;
  final String strMeal;
  final String strMealThumb;
  final String? strCategory;
  final String? strArea;
  final String? strInstructions;
  final String? strYoutube;
  final List<String> ingredients;
  final List<String> measures;
  final int estimatedCalories;
  final int estimatedProtein;
  final int estimatedCarbs;
  final int estimatedFat;
  final int matchScore;
  final List<String> badges;
  final String? strMealVi;
  final String? strInstructionsVi;
  final List<String> ingredientsVi;
  final List<String> measuresVi;

  MealItem({
    required this.idMeal,
    required this.strMeal,
    required this.strMealThumb,
    this.strCategory,
    this.strArea,
    this.strInstructions,
    this.strYoutube,
    this.ingredients = const [],
    this.measures = const [],
    this.strMealVi,
    this.strInstructionsVi,
    this.ingredientsVi = const [],
    this.measuresVi = const [],
    this.estimatedCalories = 350,
    this.estimatedProtein = 28,
    this.estimatedCarbs = 20,
    this.estimatedFat = 10,
    this.matchScore = 0,
    this.badges = const [],
  });

  factory MealItem.fromJson(Map<String, dynamic> json) {
    final List<String> ings = [];
    final List<String> meas = [];

    final rawIngs = json['ingredients'] ?? json['Ingredients'];
    final rawMeas = json['measures'] ?? json['Measures'];
    if (rawIngs is List && rawIngs.isNotEmpty) {
      for (final item in rawIngs) {
        if (item is Map) {
          final name = item['name']?.toString().trim() ?? '';
          final measure = item['measure']?.toString().trim() ?? '';
          if (name.isNotEmpty) {
            ings.add(name);
            meas.add(measure);
          }
        } else if (item != null && item.toString().trim().isNotEmpty) {
          ings.add(item.toString().trim());
        }
      }
      if (meas.isEmpty && rawMeas is List) {
        for (final m in rawMeas) {
          meas.add(m?.toString().trim() ?? '');
        }
      }
    }

    if (ings.isEmpty) {
      for (int i = 1; i <= 20; i++) {
        final ing = json['strIngredient$i']?.toString().trim();
        final mea = json['strMeasure$i']?.toString().trim();
        if (ing != null && ing.isNotEmpty) {
          ings.add(ing);
          meas.add(mea ?? '');
        }
      }
    }

    final int matchScore = (json['matchScore'] ?? json['MatchScore'] ?? 0) is int
        ? (json['matchScore'] ?? json['MatchScore'] ?? 0)
        : int.tryParse(json['matchScore']?.toString() ?? '0') ?? 0;

    final List<String> badgesList = [];
    final rawBadges = json['badges'] ?? json['Badges'];
    if (rawBadges is List) {
      for (final b in rawBadges) {
        badgesList.add(b.toString());
      }
    }

    final List<String> ingsVi = [];
    final rawIngsVi = json['ingredientsVi'] ?? json['IngredientsVi'];
    if (rawIngsVi is List) {
      for (final i in rawIngsVi) {
        ingsVi.add(i.toString());
      }
    }

    final List<String> measVi = [];
    final rawMeasVi = json['measuresVi'] ?? json['MeasuresVi'];
    if (rawMeasVi is List) {
      for (final m in rawMeasVi) {
        measVi.add(m.toString());
      }
    }

    if (ings.isEmpty && ingsVi.isNotEmpty) {
      ings.addAll(ingsVi);
    }
    if (meas.isEmpty && measVi.isNotEmpty) {
      meas.addAll(measVi);
    }

    final mealVi = json['strMealVi'] ?? json['StrMealVi'];
    final instVi = json['strInstructionsVi'] ?? json['StrInstructionsVi'];

    final id = json['idMeal'] ?? json['IdMeal'] ?? json['externalMealId'] ?? '';
    final title = json['strMeal'] ?? json['StrMeal'] ?? json['title'] ?? 'Món ăn';
    final thumb = json['strMealThumb'] ?? json['StrMealThumb'] ?? json['imageUrl'] ??
        'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=600&q=80';
    final categoryField = json['strCategory'] ?? json['StrCategory'] ?? json['category'];
    final areaField = json['strArea'] ?? json['StrArea'] ?? json['area'];
    final instructionsField = json['strInstructions'] ?? json['StrInstructions'] ?? json['instructions'];
    final youtubeField = json['strYoutube'] ?? json['StrYoutube'] ?? json['youtubeUrl'];

    final parsedCal = json['estimatedCalories'] ?? json['EstimatedCalories'] ?? json['totalCalories'];
    final parsedPro = json['estimatedProtein'] ?? json['EstimatedProtein'] ?? json['proteinG'];
    final parsedCarb = json['estimatedCarbs'] ?? json['EstimatedCarbs'] ?? json['carbsG'];
    final parsedFat = json['estimatedFat'] ?? json['EstimatedFat'] ?? json['fatG'];

    return MealItem(
      idMeal: id.toString(),
      strMeal: title.toString(),
      strMealThumb: thumb.toString(),
      strCategory: categoryField?.toString(),
      strArea: areaField?.toString(),
      strInstructions: instructionsField?.toString(),
      strYoutube: youtubeField?.toString(),
      ingredients: ings,
      measures: meas,
      strMealVi: mealVi?.toString(),
      strInstructionsVi: instVi?.toString(),
      ingredientsVi: ingsVi,
      measuresVi: measVi,
      estimatedCalories: parsedCal is num ? parsedCal.round() : 350,
      estimatedProtein: parsedPro is num ? parsedPro.round() : 28,
      estimatedCarbs: parsedCarb is num ? parsedCarb.round() : 20,
      estimatedFat: parsedFat is num ? parsedFat.round() : 10,
      matchScore: matchScore,
      badges: badgesList,
    );
  }

  Map<String, dynamic> toJson() => {
        'idMeal': idMeal,
        'strMeal': strMeal,
        'strMealThumb': strMealThumb,
        'strCategory': strCategory,
        'strArea': strArea,
        'strInstructions': strInstructions,
        'strYoutube': strYoutube,
        'ingredients': ingredients,
        'measures': measures,
        'strMealVi': strMealVi,
        'strInstructionsVi': strInstructionsVi,
        'ingredientsVi': ingredientsVi,
        'measuresVi': measuresVi,
        'estimatedCalories': estimatedCalories,
        'estimatedProtein': estimatedProtein,
        'estimatedCarbs': estimatedCarbs,
        'estimatedFat': estimatedFat,
        'matchScore': matchScore,
        'badges': badges,
      };
}

/// Service gọi dữ liệu món ăn hoàn toàn từ Backend C# .NET Web API
/// (Dart chỉ đóng vai trò Presentation và lưu đệm Offline Cache khi ngắt mạng)
class TheMealDbService {
  static const String _cacheKey = 'nutrisnap_cached_recipes';

  /// Lưu danh sách món ăn vào bộ nhớ đệm (Cache) trên thiết bị
  static Future<void> saveToCache(List<MealItem> newMeals) async {
    try {
      if (newMeals.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      final existingStr = prefs.getString(_cacheKey);
      final List<MealItem> combined = [];
      if (existingStr != null && existingStr.isNotEmpty) {
        final List list = jsonDecode(existingStr);
        for (final item in list) {
          try {
            combined.add(MealItem.fromJson(item as Map<String, dynamic>));
          } catch (_) {}
        }
      }
      for (final m in newMeals) {
        if (!combined.any((x) => x.idMeal == m.idMeal)) {
          combined.add(m);
        }
      }
      final toSave = combined.length > 100 ? combined.sublist(combined.length - 100) : combined;
      await prefs.setString(_cacheKey, jsonEncode(toSave.map((e) => e.toJson()).toList()));
    } catch (e) {
      debugPrint('[Cache Error] $e');
    }
  }

  /// Tải danh sách món ăn từ bộ nhớ đệm Offline
  static Future<List<MealItem>> getCachedMeals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_cacheKey);
      if (str != null && str.isNotEmpty) {
        final List list = jsonDecode(str);
        final res = list.map((e) => MealItem.fromJson(e as Map<String, dynamic>)).toList();
        if (res.isNotEmpty) return res;
      }
    } catch (e) {
      debugPrint('[Get Cache Error] $e');
    }
    return _offlineBackupMeals;
  }

  /// 1. Tìm danh sách món ăn khớp ĐA NGUYÊN LIỆU qua Backend C#
  /// (Được xử lý 100% bằng thuật toán Backend C#, xếp hạng món kết hợp Thịt + Rau Củ chuẩn xác)
  static Future<List<MealItem>> getMealsByMultipleIngredients(List<String> rawIngredients) async {
    if (rawIngredients.isEmpty) return [];

    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/recipes/match-multiple');
      debugPrint('[Backend Recipes] Đang gọi thuật toán khớp đa nguyên liệu C#: $rawIngredients');

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({
              'ingredients': rawIngredients,
              'lang': 'vi',
              'limit': 25,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        AppStateService.instance.setOffline(false);
        final List data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data.isNotEmpty) {
          final res = data.map((m) => MealItem.fromJson(m as Map<String, dynamic>)).toList();
          saveToCache(res);
          return res;
        }
      }
    } catch (e) {
      debugPrint('[Backend Multi-Ingredient Error] Lỗi: $e');
      AppStateService.instance.setOffline(true);
    }

    // Fallback: Tìm trong Offline Cache trên thiết bị nếu ngắt mạng
    final cached = await getCachedMeals();
    final lowerKws = rawIngredients.map((e) => e.toLowerCase()).toList();
    final hasMeat = lowerKws.any((k) =>
        k.contains('bò') || k.contains('heo') || k.contains('lợn') || k.contains('gà') || k.contains('thịt') || k.contains('tôm') || k.contains('cá') ||
        k.contains('beef') || k.contains('pork') || k.contains('chicken') || k.contains('shrimp') || k.contains('fish'));
    final isVegOnly = !hasMeat;

    final scored = cached.map((m) {
      final text = '${m.strMeal} ${m.strMealVi ?? ''} ${m.strCategory ?? ''} ${m.ingredients.join(' ')} ${m.ingredientsVi.join(' ')}'.toLowerCase();
      int matchCount = 0;
      for (final kw in lowerKws) {
        if (text.contains(kw)) matchCount++;
      }
      final catLower = (m.strCategory ?? '').toLowerCase();
      final isMeatDish = catLower.contains('chicken') || catLower.contains('beef') || catLower.contains('pork') || catLower.contains('seafood') || catLower.contains('lamb');
      int score = matchCount * 10;
      if (isVegOnly && !isMeatDish) score += 50; // Ưu tiên món rau khi người dùng chỉ chọn rau
      return MapEntry(m, score);
    }).where((entry) => entry.value > 0).toList();

    scored.sort((a, b) => b.value.compareTo(a.value));
    if (scored.isNotEmpty) {
      return scored.map((e) => e.key).toList();
    }

    return cached.take(8).toList();
  }

  /// Tìm danh sách món ăn theo nguyên liệu đơn
  static Future<List<MealItem>> getMealsByIngredient(String rawIngredient) async {
    return getMealsByMultipleIngredients([rawIngredient]);
  }

  /// 2. Lấy chi tiết món ăn (được dịch tự động 100% tại Backend C#)
  static Future<MealItem?> getMealDetail(String idMeal, {String? lang}) async {
    final effectiveLang = lang ?? 'vi';
    try {
      final backendUrl = Uri.parse('${ApiConstants.baseUrl}/api/recipes/detail/$idMeal?lang=$effectiveLang');
      debugPrint('[Backend Translation] Đang lấy chi tiết món từ backend: $backendUrl');
      final response = await http.get(backendUrl).timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        AppStateService.instance.setOffline(false);
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data is Map<String, dynamic>) {
          final res = MealItem.fromJson(data);
          saveToCache([res]);
          return res;
        }
      }
    } catch (e) {
      debugPrint('[Backend Recipe Detail Error] Lỗi: $e');
      AppStateService.instance.setOffline(true);
    }

    final cached = await getCachedMeals();
    return cached.firstWhere((m) => m.idMeal == idMeal, orElse: () => cached.first);
  }

  /// 3. Lấy món ăn ngẫu nhiên cho chức năng Lắc chọn món (C# Backend xử lý logic và tính điểm)
  static Future<MealItem?> getShakenMeal({String? lang}) async {
    final effectiveLang = lang ?? 'vi';
    try {
      final backendUrl = Uri.parse('${ApiConstants.baseUrl}/api/recipes/shake?lang=$effectiveLang');
      final response = await http.get(backendUrl).timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        AppStateService.instance.setOffline(false);
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data is Map<String, dynamic>) {
          final res = MealItem.fromJson(data);
          saveToCache([res]);
          return res;
        }
      }
    } catch (e) {
      debugPrint('[Backend Shake Error] Lỗi: $e');
      AppStateService.instance.setOffline(true);
    }

    final cached = await getCachedMeals();
    if (cached.isNotEmpty) {
      final list = List<MealItem>.from(cached)..shuffle();
      return list.first;
    }
    return null;
  }

  /// 4. Tìm kiếm món ăn theo từ khóa qua Backend C#
  static Future<List<MealItem>> searchMeals(String query) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/recipes/search?q=${Uri.encodeComponent(query)}&lang=vi');
      debugPrint('[Backend Recipes] Đang tìm món: $uri');
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        AppStateService.instance.setOffline(false);
        final List data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data.isNotEmpty) {
          final res = data.map((m) => MealItem.fromJson(m as Map<String, dynamic>)).toList();
          saveToCache(res);
          return res;
        }
      }
    } catch (e) {
      debugPrint('[Backend Search Error] Lỗi: $e');
      AppStateService.instance.setOffline(true);
    }

    final cached = await getCachedMeals();
    final lower = query.toLowerCase();
    final matches = cached.where((m) =>
        m.strMeal.toLowerCase().contains(lower) ||
        (m.strMealVi ?? '').toLowerCase().contains(lower) ||
        (m.strCategory ?? '').toLowerCase().contains(lower)).toList();
    return matches.isNotEmpty ? matches : cached.take(6).toList();
  }

  /// 5. Lấy danh sách món ăn theo danh mục qua Backend C#
  static Future<List<MealItem>> getMealsByCategory(String category) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/recipes/category/${Uri.encodeComponent(category)}?lang=vi');
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final List data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((m) => MealItem.fromJson(m as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('[Backend Category Error] Lỗi: $e');
    }
    return [];
  }

  /// 6. Lấy gợi ý hàng ngày từ Thuật toán Backend C#
  static Future<List<MealItem>> getDailyMatchedMealsFromBackend({
    required String dietType,
    required String goal,
    required int remainingCalories,
    int refreshCount = 0,
    int limit = 4,
    String? category,
  }) async {
    try {
      final categoryParam = category != null && category.isNotEmpty ? '&category=${Uri.encodeComponent(category)}' : '';
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/api/recipes/daily-matched?dietType=${Uri.encodeComponent(dietType)}&goal=${Uri.encodeComponent(goal)}&remainingCalories=$remainingCalories&refreshCount=$refreshCount&limit=$limit$categoryParam',
      );

      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final List data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data.isNotEmpty) {
          final list = data.map((j) => MealItem.fromJson(j as Map<String, dynamic>)).toList();
          saveToCache(list);
          return list;
        }
      }
    } catch (e) {
      debugPrint('[Backend Recipe Error] Lỗi: $e');
    }

    return (await getCachedMeals()).take(limit).toList();
  }

  /// 7. Gợi ý tổng thể từ Backend Recommendations Endpoint
  static Future<List<MealItem>> getBackendRecommendations({
    required String goal,
    required String dietType,
    required int targetCalories,
    required int remainingCalories,
    String? category,
    int limit = 16,
    int refreshCount = 0,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/recipes/recommendations');
      final res = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'goal': goal,
              'dietType': dietType,
              'targetCalories': targetCalories,
              'remainingCalories': remainingCalories,
              'category': category,
              'limit': limit,
              'refreshCount': refreshCount,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final list = data['data'];
        if (list is List && list.isNotEmpty) {
          final resList = list.map((j) => MealItem.fromJson(j as Map<String, dynamic>)).toList();
          saveToCache(resList);
          return resList;
        }
      }
    } catch (e) {
      debugPrint('[Backend Recommendations Error] Lỗi: $e');
    }

    return getDailyMatchedMealsFromBackend(
      dietType: dietType,
      goal: goal,
      remainingCalories: remainingCalories,
      refreshCount: refreshCount,
      limit: limit,
      category: category,
    );
  }

  /// Danh sách 10 món ăn dự phòng ngoại tuyến chất lượng cao có sẵn trong ứng dụng
  static final List<MealItem> _offlineBackupMeals = [
    MealItem(
      idMeal: 'off_1',
      strMeal: 'Grilled Chicken Breast Salad',
      strMealVi: 'Salad Ức Gà Áp Chảo',
      strMealThumb: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=600&q=80',
      strCategory: 'Chicken',
      strArea: 'Healthy',
      ingredients: ['Chicken Breast', 'Broccoli', 'Tomato', 'Olive Oil', 'Black Pepper', 'Lettuce'],
      ingredientsVi: ['Ức gà', 'Bông cải xanh', 'Cà chua bi', 'Dầu ô liu', 'Tiêu đen', 'Xà lách'],
      measures: ['200g', '100g', '50g', '1 tbsp', '1 tsp', '100g'],
      measuresVi: ['200g', '100g', '50g', '1 thìa canh', '1 thìa cà phê', '100g'],
      strInstructions: '1. Season chicken breast with pepper and olive oil. 2. Grill on medium heat for 6-8 minutes each side. 3. Steam broccoli and wash lettuce. 4. Slice chicken and toss with salad vegetables.',
      strInstructionsVi: '1. Ướp ức gà với chút tiêu đen và dầu ô liu trong 10 phút. 2. Áp chảo ức gà lửa vừa mỗi mặt 6-8 phút cho vàng đều. 3. Luộc chín bông cải xanh và rửa sạch xà lách, cà chua. 4. Cắt lát ức gà và trộn đều cùng rau củ.',
      estimatedCalories: 340,
      estimatedProtein: 38,
      estimatedCarbs: 12,
      estimatedFat: 8,
      matchScore: 98,
      badges: ['Giàu đạm', 'Ít carb', 'Vừa calo ngày'],
    ),
    MealItem(
      idMeal: 'off_2',
      strMeal: 'Beef Pho Noodle Soup',
      strMealVi: 'Phở Bò Tái Hà Nội',
      strMealThumb: 'https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?auto=format&fit=crop&w=600&q=80',
      strCategory: 'Beef',
      strArea: 'Vietnamese',
      ingredients: ['Beef', 'Rice Noodles', 'Ginger', 'Onion', 'Cinnamon', 'Star Anise', 'Spring Onion'],
      ingredientsVi: ['Thịt bò tươi', 'Bánh phở', 'Gừng tươi', 'Hành tây', 'Quế', 'Hoa hồi', 'Hành lá'],
      measures: ['150g', '150g', '20g', '1 piece', '1 piece', '2 pieces', '30g'],
      measuresVi: ['150g', '150g', '20g', '1 củ', '1 thanh', '2 hoa', '30g'],
      strInstructions: '1. Simmer beef bones with roasted ginger, onion, cinnamon and star anise for broth. 2. Blanch rice noodles. 3. Top with thinly sliced fresh beef. 4. Pour boiling broth over beef and garnish with fresh herbs.',
      strInstructionsVi: '1. Hầm xương cùng gừng, hành nướng, quế và hồi để có nước dùng thanh ngọt. 2. Trần bánh phở qua nước sôi. 3. Xếp thịt bò tươi thái mỏng lên trên bánh phở. 4. Chan nước dùng sôi sùng sục để bò tái mềm, rắc hành lá.',
      estimatedCalories: 460,
      estimatedProtein: 32,
      estimatedCarbs: 62,
      estimatedFat: 10,
      matchScore: 95,
      badges: ['Giàu đạm', 'Món Việt truyền thống'],
    ),
    MealItem(
      idMeal: 'off_3',
      strMeal: 'Baked Salmon with Asparagus',
      strMealVi: 'Cá Hồi Nướng Măng Tây',
      strMealThumb: 'https://images.unsplash.com/photo-1467003909585-2f8a72700288?auto=format&fit=crop&w=600&q=80',
      strCategory: 'Seafood',
      strArea: 'Healthy',
      ingredients: ['Salmon', 'Asparagus', 'Lemon', 'Garlic', 'Olive Oil', 'Salt'],
      ingredientsVi: ['Cá hồi phi lê', 'Măng tây', 'Chanh vàng', 'Tỏi băm', 'Dầu ô liu', 'Muối'],
      measures: ['180g', '100g', '1/2 piece', '2 cloves', '1 tbsp', '1 pinch'],
      measuresVi: ['180g', '100g', '1/2 quả', '2 tép', '1 thìa canh', '1 nhúm'],
      strInstructions: '1. Marinate salmon with minced garlic, lemon juice, salt and olive oil. 2. Place on baking sheet with asparagus. 3. Bake at 200C (400F) for 12-15 minutes until salmon flakes easily.',
      strInstructionsVi: '1. Ướp phi lê cá hồi cùng tỏi băm, nước cốt chanh, muối và dầu ô liu. 2. Xếp cá hồi cùng măng tây lên khay nướng. 3. Nướng ở 200°C trong 12-15 phút đến khi cá chín tới mọng nước.',
      estimatedCalories: 410,
      estimatedProtein: 34,
      estimatedCarbs: 8,
      estimatedFat: 24,
      matchScore: 96,
      badges: ['Giàu Omega-3', 'Ít carb', 'Tốt cho tim'],
    ),
  ];
}

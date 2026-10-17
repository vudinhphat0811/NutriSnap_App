import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import 'ai_vision_service.dart';

/// Quản lý dữ liệu Dinh dưỡng nguyên liệu
/// (Dữ liệu chính quy do C# Backend cung cấp qua API /api/recipes/ingredient-lookup)
class OfflineFoodDatabase {
  static final Map<String, DetectedIngredientItem> _cache = {};

  /// Gợi ý nhanh các nguyên liệu phổ biến
  static const List<String> quickSuggestions = [
    '🥩 Thịt heo nạc',
    '🥩 Thịt bò phi lê',
    '🍗 Ức gà',
    '🥚 Trứng gà',
    '🐟 Cá hồi',
    '🦐 Tôm tươi',
    '🥦 Bông cải xanh',
    '🥕 Cà rốt',
    '🍅 Cà chua',
    '🍄 Nấm tươi',
    '🥔 Khoai tây',
    '🧅 Hành tây',
    '🫘 Đậu phụ',
  ];

  /// Tra cứu thông tin dinh dưỡng từ Backend C#
  static Future<DetectedIngredientItem> fetchNutritionAsync(String name) async {
    final clean = name.replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '').trim();
    if (_cache.containsKey(clean.toLowerCase())) {
      return _cache[clean.toLowerCase()]!;
    }

    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/recipes/ingredient-lookup?name=${Uri.encodeComponent(clean)}');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        final item = DetectedIngredientItem.fromJson(data);
        _cache[clean.toLowerCase()] = item;
        return item;
      }
    } catch (e) {
      debugPrint('[Ingredient Lookup Error] $e');
    }

    return lookup(name);
  }

  /// Tra cứu đồng bộ (đọc từ bộ đệm đã nạp hoặc ước tính dự phòng khi ngoại tuyến)
  static DetectedIngredientItem lookup(String inputName) {
    final clean = inputName.replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '').trim();
    final lower = clean.toLowerCase();

    if (_cache.containsKey(lower)) {
      return _cache[lower]!;
    }

    // Kiểm tra tương đối trong cache đã nạp
    for (final entry in _cache.entries) {
      if (lower.contains(entry.key) || entry.key.contains(lower)) {
        return entry.value;
      }
    }

    // Dự phòng offline cơ bản khi chưa có mạng
    final fallbackItem = _getOfflineFallback(clean);
    _cache[lower] = fallbackItem;
    return fallbackItem;
  }

  static DetectedIngredientItem _getOfflineFallback(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('gà')) {
      return DetectedIngredientItem(
        name: name,
        englishName: 'Chicken',
        calories: '165 kcal',
        calorieNumber: 165,
        weight: '~150g',
        protein: '31g Protein',
        carbs: '0g Carbs',
        fat: '3.6g Fat',
        nutritionComment: 'Giàu đạm, ít béo, hỗ trợ phát triển cơ bắp.',
      );
    }
    if (lower.contains('bò')) {
      return DetectedIngredientItem(
        name: name,
        englishName: 'Beef',
        calories: '250 kcal',
        calorieNumber: 250,
        weight: '~150g',
        protein: '28g Protein',
        carbs: '0g Carbs',
        fat: '15g Fat',
        nutritionComment: 'Giàu sắt, kẽm và protein chất lượng cao.',
      );
    }
    if (lower.contains('heo') || lower.contains('lợn')) {
      return DetectedIngredientItem(
        name: name,
        englishName: 'Pork',
        calories: '240 kcal',
        calorieNumber: 240,
        weight: '~150g',
        protein: '26g Protein',
        carbs: '0g Carbs',
        fat: '14g Fat',
        nutritionComment: 'Cung cấp năng lượng cao và vitamin nhóm B.',
      );
    }
    if (lower.contains('trứng')) {
      return DetectedIngredientItem(
        name: name,
        englishName: 'Egg',
        calories: '140 kcal',
        calorieNumber: 140,
        weight: '2 quả (~100g)',
        protein: '13g Protein',
        carbs: '1g Carbs',
        fat: '9.5g Fat',
        nutritionComment: 'Nguồn protein hoàn hảo và choline tốt cho não bộ.',
      );
    }

    return DetectedIngredientItem(
      name: name,
      englishName: 'Food',
      calories: '75 kcal',
      calorieNumber: 75,
      weight: '~100g',
      protein: '3g Protein',
      carbs: '10g Carbs',
      fat: '1g Fat',
      nutritionComment: 'Nguyên liệu thực phẩm tươi ngon, giàu khoáng chất.',
    );
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

/// Chi tiết từng nguyên liệu nhận diện được (UI Model)
class DetectedIngredientItem {
  final String name;
  final String englishName;
  final String calories;
  final int calorieNumber;
  final String weight;
  final String protein;
  final String carbs;
  final String fat;
  final String nutritionComment;

  DetectedIngredientItem({
    required this.name,
    required this.englishName,
    required this.calories,
    required this.calorieNumber,
    required this.weight,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.nutritionComment = '',
  });

  factory DetectedIngredientItem.fromJson(Map<String, dynamic> json) {
    final calStr = json['calories']?.toString() ?? '100 kcal';
    int calNum = 100;
    if (json['calorieNumber'] != null) {
      calNum = int.tryParse(json['calorieNumber'].toString()) ?? 100;
    } else {
      final match = RegExp(r'\d+').firstMatch(calStr);
      if (match != null) {
        calNum = int.tryParse(match.group(0)!) ?? 100;
      }
    }

    return DetectedIngredientItem(
      name: json['name']?.toString() ?? 'Nguyên liệu',
      englishName: json['englishName']?.toString() ?? 'Chicken',
      calories: calStr,
      calorieNumber: calNum,
      weight: json['weight']?.toString() ?? '~100g',
      protein: json['protein']?.toString() ?? '10g Protein',
      carbs: json['carbs']?.toString() ?? '5g Carbs',
      fat: json['fat']?.toString() ?? '2g Fat',
      nutritionComment: json['nutritionComment']?.toString() ?? '',
    );
  }
}

/// Kết quả phân tích nguyên liệu nhận từ Backend C#
class IngredientAnalysisResult {
  final bool isIngredient;
  final String? rejectReason;
  final String name;
  final String englishName;
  final String calories;
  final int calorieNumber;
  final String weight;
  final String nutritionComment;
  final String protein;
  final String carbs;
  final String fat;
  final String context;
  final String? providerName;
  final List<DetectedIngredientItem> ingredients;

  IngredientAnalysisResult({
    required this.isIngredient,
    this.rejectReason,
    this.name = '',
    this.englishName = '',
    this.calories = '',
    this.calorieNumber = 0,
    this.weight = '',
    this.nutritionComment = '',
    this.protein = '',
    this.carbs = '',
    this.fat = '',
    this.context = '',
    this.providerName,
    this.ingredients = const [],
  });

  factory IngredientAnalysisResult.rejected(String reason, {String? provider}) {
    return IngredientAnalysisResult(
      isIngredient: false,
      rejectReason: reason,
      providerName: provider,
      ingredients: const [],
    );
  }

  factory IngredientAnalysisResult.fromJson(Map<String, dynamic> json, {String? provider}) {
    final isIng = json['isIngredient'] == true || (json['isIngredient'] != false && json['name'] != null);

    if (!isIng) {
      return IngredientAnalysisResult.rejected(
        json['rejectReason']?.toString() ??
            'Hình ảnh không phải là nguyên liệu thực phẩm. Vui lòng chụp lại ảnh thịt, cá, trứng, rau, củ hoặc trái cây!',
        provider: provider ?? json['providerName']?.toString(),
      );
    }

    final List<DetectedIngredientItem> parsedIngredients = [];
    if (json['ingredients'] is List) {
      for (final item in json['ingredients']) {
        if (item is Map<String, dynamic>) {
          parsedIngredients.add(DetectedIngredientItem.fromJson(item));
        }
      }
    }

    final calStr = json['calories']?.toString() ?? '150 kcal';
    int calNum = 150;
    if (json['calorieNumber'] != null) {
      calNum = int.tryParse(json['calorieNumber'].toString()) ?? 150;
    } else {
      final match = RegExp(r'\d+').firstMatch(calStr);
      if (match != null) {
        calNum = int.tryParse(match.group(0)!) ?? 150;
      }
    }

    if (parsedIngredients.isEmpty) {
      parsedIngredients.add(DetectedIngredientItem(
        name: json['name']?.toString() ?? 'Nguyên liệu',
        englishName: json['englishName']?.toString() ?? 'chicken',
        calories: calStr,
        calorieNumber: calNum,
        weight: json['weight']?.toString() ?? '~150g',
        protein: json['protein']?.toString() ?? '20g Protein',
        carbs: json['carbs']?.toString() ?? '5g Carbs',
        fat: json['fat']?.toString() ?? '3g Fat',
        nutritionComment: json['nutritionComment']?.toString() ?? '',
      ));
    }

    return IngredientAnalysisResult(
      isIngredient: true,
      name: json['name']?.toString() ?? parsedIngredients.first.name,
      englishName: json['englishName']?.toString() ?? parsedIngredients.first.englishName,
      calories: calStr,
      calorieNumber: calNum,
      weight: json['weight']?.toString() ?? '~150g',
      nutritionComment: json['nutritionComment']?.toString() ??
          json['calorieAdvice']?.toString() ??
          'Nguyên liệu tươi ngon, cung cấp nguồn năng lượng và dưỡng chất thiết yếu cho cơ thể.',
      protein: json['protein']?.toString() ?? '20g Protein',
      carbs: json['carbs']?.toString() ?? '5g Carbs',
      fat: json['fat']?.toString() ?? '3g Fat',
      context: json['context']?.toString() ?? '',
      providerName: provider ?? json['providerName']?.toString(),
      ingredients: parsedIngredients,
    );
  }
}

/// Service gửi ảnh lên Backend C# để xử lý AI Vision
/// (Mọi thuật toán, API key, luân phiên provider và prompt đều do Backend C# đảm nhiệm)
class AIVisionService {
  String? lastUsedProvider;

  /// Gửi ảnh lên Backend C# để phân tích và nhận dữ liệu hiển thị
  Future<IngredientAnalysisResult> analyzeIngredient(Uint8List imageBytes) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/recipes/analyze-image');
      debugPrint('[Frontend AI] Đang gửi ảnh lên Backend C# phân tích: $uri');

      final base64Image = base64Encode(imageBytes);
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'imageBase64': base64Image,
              'contentType': 'image/jpeg',
            }),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final result = IngredientAnalysisResult.fromJson(data);
        lastUsedProvider = result.providerName;
        debugPrint('[Frontend AI] Phân tích thành công từ Backend: ${result.name} (${result.providerName})');
        return result;
      } else {
        debugPrint('[Frontend AI Error] Backend trả mã lỗi: ${response.statusCode} - ${response.body}');
        try {
          final errData = jsonDecode(utf8.decode(response.bodyBytes));
          return IngredientAnalysisResult.rejected(errData['message'] ?? 'Máy chủ không thể phân tích ảnh.');
        } catch (_) {
          return IngredientAnalysisResult.rejected('Máy chủ gặp sự cố xử lý ảnh (Mã lỗi ${response.statusCode}).');
        }
      }
    } catch (e) {
      debugPrint('[Frontend AI Exception] Lỗi kết nối backend: $e');
      return IngredientAnalysisResult.rejected(
        'Không thể kết nối đến máy chủ Backend NutriSnap. Vui lòng kiểm tra kết nối mạng của bạn!',
      );
    }
  }

  /// Nhận diện nguyên liệu trong ảnh (hàm tương thích ngược trả về chuỗi tên)
  Future<String> recognizeIngredient(Uint8List imageBytes) async {
    final result = await analyzeIngredient(imageBytes);
    if (!result.isIngredient) {
      throw Exception(result.rejectReason ?? 'Không nhận diện được nguyên liệu thực phẩm.');
    }
    return result.name;
  }
}

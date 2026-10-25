import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../models/barcode_product_model.dart';

/// Dịch vụ tra cứu mã vạch & mã QR:
/// 100% kết nối Cơ sở Dữ liệu Bên Thứ 3 (Open Food Facts Global Database & C# Backend)
/// Tuyệt đối KHÔNG sử dụng dữ liệu tĩnh tự khai báo.
class BarcodeNutritionService {
  /// Tra cứu mã vạch hoặc mã QR trên CSDL bên thứ 3
  static Future<BarcodeProductModel?> lookupBarcode(String barcode) async {
    final rawCode = barcode.trim();
    if (rawCode.isEmpty) return null;

    final isQrOrUrl = rawCode.startsWith('http://') ||
        rawCode.startsWith('https://') ||
        rawCode.contains('/') ||
        rawCode.contains('?') ||
        rawCode.contains('=') ||
        rawCode.startsWith('www.');

    final cleanCode = isQrOrUrl ? rawCode : rawCode.replaceAll(' ', '').replaceAll('-', '');

    // 1. Thử gọi C# Backend API (kết nối trực tiếp Open Food Facts v2 & hệ thống phân tích bên thứ 3)
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/api/recipes/barcode?code=${Uri.encodeQueryComponent(cleanCode)}');
      final res = await http.get(url).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data['success'] == true && data['product'] != null) {
          return BarcodeProductModel.fromJson(data['product']);
        }
      }
    } catch (e) {
      debugPrint('[BarcodeNutritionService] Backend lookup failed: $e. Thử truy vấn Open Food Facts trực tiếp...');
    }

    // 2. Tra cứu trực tiếp Open Food Facts API v2 từ Client (CSDL Bên thứ 3 mở)
    // Nếu mã là QR chứa link, trích xuất mã số bên trong nếu có
    String lookupCode = cleanCode;
    if (isQrOrUrl) {
      final match = RegExp(r'(?<!\d)(2\d{11,12}|893\d{7,10}|\d{8,14})(?!\d)').firstMatch(rawCode);
      if (match != null) {
        lookupCode = match.group(0)!;
      } else {
        // Link QR không chứa mã số và Backend không phản hồi
        return null;
      }
    }

    final paddedCode = lookupCode.length == 12 ? '0$lookupCode' : lookupCode;

    try {
      final offUrl = Uri.parse('https://world.openfoodfacts.org/api/v2/product/$paddedCode.json');
      final res = await http.get(
        offUrl,
        headers: {'User-Agent': 'NutriSnap-App/2.0 (contact@nutrisnap.app)'},
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data['status'] == 1 && data['product'] != null) {
          final prod = data['product'];
          final name = prod['product_name_vi'] ?? prod['product_name'] ?? prod['product_name_en'];
          if (name == null || name.toString().trim().isEmpty) return null;

          final brand = prod['brands'] ?? 'Chưa rõ thương hiệu';
          final nutriments = prod['nutriments'] ?? {};

          final cal = _parseDouble(nutriments['energy-kcal_100g'] ?? nutriments['energy-kcal'] ?? 0.0);
          final pro = _parseDouble(nutriments['proteins_100g']);
          final carb = _parseDouble(nutriments['carbohydrates_100g']);
          final sugars = _parseDouble(nutriments['sugars_100g']);
          final fat = _parseDouble(nutriments['fat_100g']);
          final satFat = _parseDouble(nutriments['saturated-fat_100g']);
          final fiber = _parseDouble(nutriments['fiber_100g']);
          final sod = _parseDouble(nutriments['sodium_100g']) * 1000.0;

          double netWeight = 100.0;
          if (prod['product_quantity'] != null) {
            netWeight = _parseDouble(prod['product_quantity']);
          } else if (prod['quantity'] != null) {
            netWeight = _parseDouble(prod['quantity']);
          }

          final ingredients = prod['ingredients_text_vi'] ?? prod['ingredients_text'] ?? prod['ingredients_text_en'] ?? '';
          final imageUrl = prod['image_front_url'] ?? prod['image_url'] ?? '';

          return BarcodeProductModel(
            barcode: cleanCode,
            productName: name.toString().trim(),
            brand: brand.toString().trim(),
            category: 'Thực Phẩm Đóng Gói',
            categoryIcon: '📦',
            barcodeType: 'EAN-13 (Open Food Facts)',
            netWeightG: netWeight > 0 ? netWeight : 100.0,
            servingSize: prod['serving_size']?.toString() ?? '${netWeight.round()}g',
            caloriesPer100g: cal,
            proteinPer100g: pro,
            carbsPer100g: carb,
            sugarsPer100g: sugars > 0 ? sugars : null,
            fatPer100g: fat,
            saturatedFatPer100g: satFat > 0 ? satFat : null,
            fiberPer100g: fiber,
            sodiumMg: sod > 0 ? sod : null,
            ingredientsText: ingredients.toString().trim(),
            imageUrl: imageUrl.toString().trim(),
            source: 'Open Food Facts (CSDL Bên Thứ 3)',
            notes: 'Thông số dinh dưỡng trích xuất thực tế từ Cơ sở dữ liệu mở Open Food Facts',
          );
        }
      }
    } catch (e) {
      debugPrint('[BarcodeNutritionService] OpenFoodFacts lookup error: $e');
    }

    // Không tìm thấy trên bất kỳ CSDL bên thứ 3 nào -> Trả về null để UI báo lỗi
    // Tuyệt đối KHÔNG tự bịa ra sản phẩm
    return null;
  }

  /// Gửi ảnh chụp bao bì lên Backend C# để nhận diện mã vạch và thông số qua OCR quang học
  static Future<BarcodeProductModel?> scanBarcodeFromImage(Uint8List imageBytes) async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/api/recipes/scan-barcode-image');
      final base64Image = base64Encode(imageBytes);
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'imageBase64': base64Image,
          'contentType': 'image/jpeg',
        }),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data['success'] == true && data['product'] != null) {
          return BarcodeProductModel.fromJson(data['product']);
        }
      }
    } catch (e) {
      debugPrint('[BarcodeNutritionService] Scan from image failed: $e');
    }
    return null;
  }

  /// Kiểm tra xem chuỗi số có phải cấu trúc tem cân siêu thị (tiền tố 20-29 hoặc 02)
  static bool isScaleBarcode(String barcode) {
    final clean = barcode.trim().replaceAll(' ', '').replaceAll('-', '');
    if (clean.length != 12 && clean.length != 13) return false;
    return clean.startsWith('2') || clean.startsWith('02');
  }

  static double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) {
      final clean = RegExp(r'[\d\.]+').stringMatch(val);
      if (clean != null) return double.tryParse(clean) ?? 0.0;
    }
    return 0.0;
  }
}

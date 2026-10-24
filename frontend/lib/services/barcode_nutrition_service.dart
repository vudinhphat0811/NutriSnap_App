import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../models/barcode_product_model.dart';

class BarcodeNutritionService {
  /// Danh mục sản phẩm siêu thị & Gym mẫu sẵn (Offline Cache)
  static final List<BarcodeProductModel> _sampleProducts = [
    // 1. Khay thịt tươi tem cân
    const BarcodeProductModel(
      barcode: '201024503504',
      productName: 'Khay Ức Gà Phi Lê Tươi MeatDeli (Tem Cân 350g)',
      brand: 'MeatDeli',
      category: 'Thịt Gà & Gia Cầm',
      categoryIcon: '🍗',
      barcodeType: 'Tem Cân Siêu Thị (Variable Weight)',
      netWeightG: 350.0,
      servingSize: '1 Khay 350g',
      caloriesPer100g: 120.0,
      proteinPer100g: 22.5,
      carbsPer100g: 0.0,
      fatPer100g: 2.6,
      fiberPer100g: 0.0,
      sodiumMg: 65.0,
      cutEquivalentId: 'chicken_breast_skinless',
      source: 'Tem Cân Siêu Thị WinMart/MeatDeli',
      notes: 'Tem cân siêu thị: Tự động trích xuất khối lượng tịnh 350g từ mã vạch',
      imageUrl: 'https://images.unsplash.com/photo-1604503468506-a8da13d82791?w=400&q=80',
    ),
    const BarcodeProductModel(
      barcode: '201011002808',
      productName: 'Khay Thịt Bò Thăn Úc Tươi (Tem Cân 280g)',
      brand: 'WinMart / Aeon Fresh',
      category: 'Thịt Bò',
      categoryIcon: '🥩',
      barcodeType: 'Tem Cân Siêu Thị (Variable Weight)',
      netWeightG: 280.0,
      servingSize: '1 Khay 280g',
      caloriesPer100g: 135.0,
      proteinPer100g: 22.0,
      carbsPer100g: 0.0,
      fatPer100g: 4.5,
      fiberPer100g: 0.0,
      sodiumMg: 55.0,
      cutEquivalentId: 'beef_tenderloin',
      source: 'Tem Cân Siêu Thị WinMart',
      notes: 'Tem cân siêu thị: Tự động trích xuất khối lượng tịnh 280g từ mã vạch',
      imageUrl: 'https://images.unsplash.com/photo-1558030006-450675393462?w=400&q=80',
    ),
    const BarcodeProductModel(
      barcode: '201030004502',
      productName: 'Khay Nạc Thăn Heo Tươi CP (Tem Cân 450g)',
      brand: 'CP Foods',
      category: 'Thịt Heo',
      categoryIcon: '🥓',
      barcodeType: 'Tem Cân Siêu Thị (Variable Weight)',
      netWeightG: 450.0,
      servingSize: '1 Khay 450g',
      caloriesPer100g: 143.0,
      proteinPer100g: 21.0,
      carbsPer100g: 0.0,
      fatPer100g: 6.0,
      fiberPer100g: 0.0,
      sodiumMg: 60.0,
      cutEquivalentId: 'pork_tenderloin',
      source: 'Tem Cân Siêu Thị CP Fresh Shop',
      notes: 'Tem cân siêu thị: Tự động trích xuất khối lượng tịnh 450g từ mã vạch',
      imageUrl: 'https://images.unsplash.com/photo-1602498456745-e9503b30470b?w=400&q=80',
    ),
    const BarcodeProductModel(
      barcode: '201040003005',
      productName: 'Khay Cá Hồi Phi Lê Nauy Tươi (Tem Cân 300g)',
      brand: 'Mega Market / Aeon Fresh',
      category: 'Cá & Hải Sản',
      categoryIcon: '🐟',
      barcodeType: 'Tem Cân Siêu Thị (Variable Weight)',
      netWeightG: 300.0,
      servingSize: '1 Khay 300g',
      caloriesPer100g: 208.0,
      proteinPer100g: 20.4,
      carbsPer100g: 0.0,
      fatPer100g: 13.4,
      fiberPer100g: 0.0,
      sodiumMg: 59.0,
      cutEquivalentId: 'salmon_fillet',
      source: 'Tem Cân Siêu Thị Mega Market',
      notes: 'Tem cân siêu thị: Tự động trích xuất khối lượng tịnh 300g từ mã vạch',
      imageUrl: 'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=400&q=80',
    ),

    // 2. Sản phẩm Eat-Clean & Dinh Dưỡng Thể Thao EAN-13
    const BarcodeProductModel(
      barcode: '8936036010017',
      productName: 'Sữa Tươi Tiệt Trùng TH True Milk Ít Đường 180ml',
      brand: 'TH True Milk',
      category: 'Trứng & Sữa / Whey',
      categoryIcon: '🥛',
      barcodeType: 'EAN-13 Tiêu Chuẩn',
      netWeightG: 180.0,
      servingSize: '1 Hộp 180ml',
      caloriesPer100g: 70.0,
      proteinPer100g: 3.0,
      carbsPer100g: 7.8,
      fatPer100g: 3.2,
      fiberPer100g: 0.0,
      sodiumMg: 45.0,
      source: 'Bao Bì Nhà Sản Xuất TH True Milk',
      notes: 'Hộp 180ml chứa ~126 Kcal, 5.4g Protein chất lượng cao',
      imageUrl: 'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=400&q=80',
    ),
    const BarcodeProductModel(
      barcode: '8934673641027',
      productName: 'Sữa Chua Hy Lạp Greek Style Vinamilk Không Đường 100g',
      brand: 'Vinamilk',
      category: 'Trứng & Sữa / Whey',
      categoryIcon: '🥛',
      barcodeType: 'EAN-13 Tiêu Chuẩn',
      netWeightG: 100.0,
      servingSize: '1 Hũ 100g',
      caloriesPer100g: 95.0,
      proteinPer100g: 7.0,
      carbsPer100g: 4.5,
      fatPer100g: 5.2,
      fiberPer100g: 0.0,
      sodiumMg: 38.0,
      source: 'Bao Bì Vinamilk Greek Style',
      notes: 'Sữa chua Hy Lạp đạm cao gấp đôi, giàu lợi khuẩn đường ruột',
      imageUrl: 'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=400&q=80',
    ),
    const BarcodeProductModel(
      barcode: '0030000010402',
      productName: 'Yến Mạch Quaker Oats Quick 1-Minute 500g',
      brand: 'Quaker Oats',
      category: 'Tinh Bột & Ngũ Cốc',
      categoryIcon: '🥣',
      barcodeType: 'EAN-13 Tiêu Chuẩn',
      netWeightG: 500.0,
      servingSize: '1 Khẩu phần 40g',
      caloriesPer100g: 375.0,
      proteinPer100g: 12.5,
      carbsPer100g: 67.5,
      fatPer100g: 7.5,
      fiberPer100g: 10.0,
      sodiumMg: 5.0,
      cutEquivalentId: 'rolled_oats',
      source: 'Bao Bì Chính Hãng Quaker Oats',
      notes: 'Ngũ cốc nguyên cám GI thấp, giàu chất xơ hòa tan Beta-Glucan',
      imageUrl: 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=400&q=80',
    ),
    const BarcodeProductModel(
      barcode: '0748927028669',
      productName: 'Sữa Tăng Cơ Whey Gold Standard 100% ON (Double Rich Choc)',
      brand: 'Optimum Nutrition (ON)',
      category: 'Trứng & Sữa / Whey',
      categoryIcon: '💪',
      barcodeType: 'EAN-13 Tiêu Chuẩn',
      netWeightG: 907.0,
      servingSize: '1 Muỗng (Scoop) 30.4g',
      caloriesPer100g: 394.7,
      proteinPer100g: 78.9,
      carbsPer100g: 9.8,
      fatPer100g: 4.9,
      fiberPer100g: 2.0,
      sodiumMg: 427.0,
      cutEquivalentId: 'whey_isolate',
      source: 'Bao Bì Chính Hãng Optimum Nutrition',
      notes: 'Mỗi muỗng 30.4g cung cấp 24g Protein tinh khiết hấp thu nhanh',
      imageUrl: 'https://images.unsplash.com/photo-1593095948071-474c5cc2989d?w=400&q=80',
    ),
    const BarcodeProductModel(
      barcode: '8934617011015',
      productName: 'Cá Ngừ Ngâm Dầu Canfos Hạ Long 175g',
      brand: 'Hạ Long Canfoco',
      category: 'Cá & Hải Sản',
      categoryIcon: '🐟',
      barcodeType: 'EAN-13 Tiêu Chuẩn',
      netWeightG: 175.0,
      servingSize: '1 Hộp 175g',
      caloriesPer100g: 190.0,
      proteinPer100g: 21.0,
      carbsPer100g: 0.0,
      fatPer100g: 12.0,
      fiberPer100g: 0.0,
      sodiumMg: 380.0,
      cutEquivalentId: 'tuna_steak',
      source: 'Bao Bì Đồ Hộp Hạ Long',
      notes: 'Cá ngừ đại dương đóng hộp tiện lợi, dồi dào Protein và Omega-3',
      imageUrl: 'https://images.unsplash.com/photo-1501595091296-3aa970afb3ff?w=400&q=80',
    ),
    const BarcodeProductModel(
      barcode: '8935049500019',
      productName: 'Hộp 10 Quả Trứng Gà Tươi Tiệt Trùng Ba Huân',
      brand: 'Ba Huân',
      category: 'Trứng & Sữa / Whey',
      categoryIcon: '🥚',
      barcodeType: 'EAN-13 Tiêu Chuẩn',
      netWeightG: 600.0,
      servingSize: '1 Quả (~60g)',
      caloriesPer100g: 143.0,
      proteinPer100g: 12.6,
      carbsPer100g: 0.7,
      fatPer100g: 9.5,
      fiberPer100g: 0.0,
      sodiumMg: 142.0,
      cutEquivalentId: 'whole_egg',
      source: 'Bao Bì Trứng Sạch Ba Huân',
      notes: 'Mỗi quả trung bình 60g có ~86 Kcal và 7.5g Protein sinh học',
      imageUrl: 'https://images.unsplash.com/photo-1506976785307-8732e854ad03?w=400&q=80',
    ),
    const BarcodeProductModel(
      barcode: '8935044400123',
      productName: 'Ức Gà Ăn Liền CP Fi-le Vị Tiêu Đen 100g',
      brand: 'CP Foods',
      category: 'Thịt Gà & Gia Cầm',
      categoryIcon: '🍗',
      barcodeType: 'EAN-13 Tiêu Chuẩn',
      netWeightG: 100.0,
      servingSize: '1 Gói 100g',
      caloriesPer100g: 115.0,
      proteinPer100g: 24.0,
      carbsPer100g: 1.0,
      fatPer100g: 1.5,
      fiberPer100g: 0.0,
      sodiumMg: 320.0,
      cutEquivalentId: 'chicken_breast_skinless',
      source: 'Bao Bì CP Ready-to-eat',
      notes: 'Gói 100g chín sẵn ăn liền, chuẩn Eat-Clean đạm cao không dầu mỡ',
      imageUrl: 'https://images.unsplash.com/photo-1532550907401-a500c9a57435?w=400&q=80',
    ),
  ];

  static List<BarcodeProductModel> getSampleProducts() => List.unmodifiable(_sampleProducts);

  /// Tra cứu mã vạch: Ưu tiên Backend .NET 8, tự động fallback sang Offline Cache & Scale Parser
  static Future<BarcodeProductModel?> lookupBarcode(String barcode) async {
    final cleanCode = barcode.trim().replaceAll(' ', '').replaceAll('-', '');
    if (cleanCode.isEmpty) return null;

    final paddedCode = cleanCode.length == 12 ? '0$cleanCode' : cleanCode;

    // 1. Thử gọi C# Backend API
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/api/recipes/barcode/${Uri.encodeComponent(cleanCode)}');
      final res = await http.get(url).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data['success'] == true && data['product'] != null) {
          return BarcodeProductModel.fromJson(data['product']);
        }
      }
    } catch (e) {
      debugPrint('[BarcodeNutritionService] Online lookup failed, using offline fallback: $e');
    }

    // 2. Tra cứu danh mục mẫu cục bộ
    for (final item in _sampleProducts) {
      if (item.barcode == cleanCode || item.barcode == paddedCode) {
        return item;
      }
    }

    // 3. Nếu là tem cân siêu thị (bắt đầu 20..29)
    if (isScaleBarcode(cleanCode)) {
      final parsed = decodeScaleBarcode(cleanCode);
      if (parsed != null) return parsed;
    }

    // 4. Tra cứu Open Food Facts trực tiếp từ client nếu backend không kết nối được
    try {
      final offUrl = Uri.parse('https://world.openfoodfacts.org/api/v2/product/$paddedCode.json');
      final res = await http.get(offUrl).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data['status'] == 1 && data['product'] != null) {
          final prod = data['product'];
          final name = prod['product_name_vi'] ?? prod['product_name'] ?? 'Sản phẩm mã vạch $cleanCode';
          final brand = prod['brands'] ?? 'Đã xác thực bao bì';
          final nutriments = prod['nutriments'] ?? {};

          final cal = (nutriments['energy-kcal_100g'] ?? nutriments['energy-kcal'] ?? 0.0).toDouble();
          final pro = (nutriments['proteins_100g'] ?? 0.0).toDouble();
          final carb = (nutriments['carbohydrates_100g'] ?? 0.0).toDouble();
          final fat = (nutriments['fat_100g'] ?? 0.0).toDouble();
          final fiber = (nutriments['fiber_100g'] ?? 0.0).toDouble();

          double netWeight = 100.0;
          if (prod['product_quantity'] != null) {
            netWeight = double.tryParse(prod['product_quantity'].toString()) ?? 100.0;
          }

          return BarcodeProductModel(
            barcode: cleanCode,
            productName: name.toString(),
            brand: brand.toString(),
            category: 'Thực Phẩm Đóng Gói',
            categoryIcon: '📦',
            barcodeType: 'EAN-13 Tiêu Chuẩn (Open Food Facts)',
            netWeightG: netWeight > 0 ? netWeight : 100.0,
            servingSize: '${netWeight.round()}g',
            caloriesPer100g: cal,
            proteinPer100g: pro,
            carbsPer100g: carb,
            fatPer100g: fat,
            fiberPer100g: fiber,
            source: 'Open Food Facts Database',
            notes: 'Thông tin dinh dưỡng trích xuất từ cơ sở dữ liệu mở Open Food Facts',
            imageUrl: prod['image_front_url'] ?? '',
          );
        }
      }
    } catch (e) {
      debugPrint('[BarcodeNutritionService] OpenFoodFacts lookup error: $e');
    }

    return null;
  }

  /// Kiểm tra xem mã vạch có thuộc chuẩn tem cân siêu thị GS1 (20..29) không
  static bool isScaleBarcode(String barcode) {
    if (barcode.length != 12 && barcode.length != 13) return false;
    final prefix = barcode.length == 13 ? barcode.substring(0, 2) : barcode.substring(0, 1);
    if (barcode.length == 13) {
      return ['20', '21', '22', '23', '24', '25', '26', '27', '28', '29'].contains(prefix);
    }
    return prefix == '2';
  }

  /// Giải mã tem cân siêu thị bóc tách khối lượng (Grams)
  static BarcodeProductModel? decodeScaleBarcode(String barcode) {
    try {
      double weightG = 250.0;
      String productDigits = '';

      if (barcode.length == 13) {
        productDigits = barcode.substring(2, 7);
        final weightDigits = barcode.substring(7, 11);
        final parsed = double.tryParse(weightDigits);
        if (parsed != null && parsed > 10 && parsed < 5000) {
          weightG = parsed;
        }
      } else if (barcode.length == 12) {
        productDigits = barcode.substring(1, 6);
        final weightDigits = barcode.substring(6, 10);
        final parsed = double.tryParse(weightDigits);
        if (parsed != null && parsed > 10 && parsed < 5000) {
          weightG = parsed;
        }
      }

      String name = 'Khay Thịt Tươi Siêu Thị (${weightG.round()}g)';
      String category = 'Thịt Gà & Gia Cầm';
      String cutId = 'chicken_breast_skinless';
      String icon = '🍗';
      double cal100 = 120.0;
      double pro100 = 22.5;
      double carb100 = 0.0;
      double fat100 = 2.6;

      if (productDigits.startsWith('101') || productDigits.contains('bo') || productDigits.contains('beef')) {
        name = 'Khay Thịt Bò Tươi Siêu Thị (${weightG.round()}g)';
        category = 'Thịt Bò';
        cutId = 'beef_tenderloin';
        icon = '🥩';
        cal100 = 135.0;
        pro100 = 22.0;
        fat100 = 4.5;
      } else if (productDigits.startsWith('103') || productDigits.contains('heo') || productDigits.contains('pork')) {
        name = 'Khay Thịt Heo Nạc Siêu Thị (${weightG.round()}g)';
        category = 'Thịt Heo';
        cutId = 'pork_tenderloin';
        icon = '🥓';
        cal100 = 143.0;
        pro100 = 21.0;
        fat100 = 6.0;
      } else if (productDigits.startsWith('104') || productDigits.contains('ca') || productDigits.contains('fish')) {
        name = 'Khay Cá Phi Lê Siêu Thị (${weightG.round()}g)';
        category = 'Cá & Hải Sản';
        cutId = 'salmon_fillet';
        icon = '🐟';
        cal100 = 208.0;
        pro100 = 20.4;
        fat100 = 13.4;
      }

      return BarcodeProductModel(
        barcode: barcode,
        productName: name,
        brand: 'Siêu Thị (WinMart / Co.op / Aeon)',
        category: category,
        categoryIcon: icon,
        barcodeType: 'Tem Cân Siêu Thị (Variable Weight)',
        netWeightG: weightG,
        servingSize: '1 Khay ${weightG.round()}g',
        caloriesPer100g: cal100,
        proteinPer100g: pro100,
        carbsPer100g: carb100,
        fatPer100g: fat100,
        fiberPer100g: 0.0,
        sodiumMg: 60.0,
        cutEquivalentId: cutId,
        source: 'Tem Cân Tự Động Siêu Thị',
        notes: 'Giải mã tự động: Tiền tố tem cân ${barcode.substring(0, 2)}, trích xuất khối lượng tịnh ${weightG.round()}g',
        imageUrl: 'https://images.unsplash.com/photo-1604503468506-a8da13d82791?w=400&q=80',
      );
    } catch (e) {
      return null;
    }
  }
}

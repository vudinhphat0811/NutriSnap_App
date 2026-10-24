import 'ingredient_cut_model.dart';

class BarcodeProductModel {
  final String barcode;
  final String productName;
  final String brand;
  final String category;
  final String categoryIcon;
  final String barcodeType;
  final double netWeightG;
  final String servingSize;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final double fiberPer100g;
  final double? sodiumMg;
  final String imageUrl;
  final String source;
  final String? cutEquivalentId;
  final String notes;

  const BarcodeProductModel({
    required this.barcode,
    required this.productName,
    required this.brand,
    required this.category,
    this.categoryIcon = '🛒',
    this.barcodeType = 'EAN-13 Tiêu Chuẩn',
    this.netWeightG = 100.0,
    this.servingSize = '100g',
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    required this.fiberPer100g,
    this.sodiumMg,
    this.imageUrl = '',
    this.source = 'NutriSnap Barcode DB',
    this.cutEquivalentId,
    this.notes = '',
  });

  bool get isScaleBarcode => barcodeType.contains('Cân') || barcode.startsWith('2');

  factory BarcodeProductModel.fromJson(Map<String, dynamic> json) {
    return BarcodeProductModel(
      barcode: json['barcode'] ?? json['Barcode'] ?? '',
      productName: json['productName'] ?? json['ProductName'] ?? '',
      brand: json['brand'] ?? json['Brand'] ?? '',
      category: json['category'] ?? json['Category'] ?? 'Thực Phẩm Đóng Gói',
      categoryIcon: json['categoryIcon'] ?? json['CategoryIcon'] ?? '🛒',
      barcodeType: json['barcodeType'] ?? json['BarcodeType'] ?? 'EAN-13 Tiêu Chuẩn',
      netWeightG: (json['netWeightG'] ?? json['NetWeightG'] ?? 100.0).toDouble(),
      servingSize: json['servingSize'] ?? json['ServingSize'] ?? '100g',
      caloriesPer100g: (json['caloriesPer100g'] ?? json['CaloriesPer100g'] ?? 0.0).toDouble(),
      proteinPer100g: (json['proteinPer100g'] ?? json['ProteinPer100g'] ?? 0.0).toDouble(),
      carbsPer100g: (json['carbsPer100g'] ?? json['CarbsPer100g'] ?? 0.0).toDouble(),
      fatPer100g: (json['fatPer100g'] ?? json['FatPer100g'] ?? 0.0).toDouble(),
      fiberPer100g: (json['fiberPer100g'] ?? json['FiberPer100g'] ?? 0.0).toDouble(),
      sodiumMg: json['sodiumMg'] != null ? (json['sodiumMg']).toDouble() : (json['SodiumMg'] != null ? (json['SodiumMg']).toDouble() : null),
      imageUrl: json['imageUrl'] ?? json['ImageUrl'] ?? '',
      source: json['source'] ?? json['Source'] ?? 'NutriSnap DB',
      cutEquivalentId: json['cutEquivalentId'] ?? json['CutEquivalentId'],
      notes: json['notes'] ?? json['Notes'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'barcode': barcode,
    'productName': productName,
    'brand': brand,
    'category': category,
    'categoryIcon': categoryIcon,
    'barcodeType': barcodeType,
    'netWeightG': netWeightG,
    'servingSize': servingSize,
    'caloriesPer100g': caloriesPer100g,
    'proteinPer100g': proteinPer100g,
    'carbsPer100g': carbsPer100g,
    'fatPer100g': fatPer100g,
    'fiberPer100g': fiberPer100g,
    'sodiumMg': sodiumMg,
    'imageUrl': imageUrl,
    'source': source,
    'cutEquivalentId': cutEquivalentId,
    'notes': notes,
  };

  /// Chuyển đổi sang IngredientCutModel để nạp mượt mà vào Bộ Tính Calo
  IngredientCutModel toIngredientCutModel() {
    return IngredientCutModel(
      id: 'barcode_$barcode',
      category: category,
      categoryIcon: categoryIcon,
      name: productName,
      englishName: brand.isNotEmpty ? brand : 'Quét Mã Vạch',
      description: notes.isNotEmpty ? notes : 'Sản phẩm trích xuất từ mã vạch $barcode ($brand)',
      defaultPortionName: servingSize.isNotEmpty ? servingSize : '${netWeightG.round()}g',
      defaultPortionWeightG: netWeightG > 0 ? netWeightG : 100.0,
      caloriesPer100g: caloriesPer100g,
      proteinPer100g: proteinPer100g,
      carbsPer100g: carbsPer100g,
      fatPer100g: fatPer100g,
      fiberPer100g: fiberPer100g,
      suitableGoals: const ['Bao bì siêu thị', 'Đo calo tự động', 'Kiểm soát macros'],
      gymBadges: [
        if (brand.isNotEmpty) brand,
        isScaleBarcode ? 'Tem Cân Siêu Thị' : 'Mã Vạch Chuẩn GS1',
        'Tịnh: ${netWeightG.round()}g',
      ],
      gymTip: notes.isNotEmpty ? notes : 'Khối lượng bao bì/khay cân mặc định là ${netWeightG.round()}g. Bạn có thể kéo thanh trượt để chỉnh lượng gram thực tế đã ăn.',
      imageUrl: imageUrl,
    );
  }

  /// Tính toán Macro theo khối lượng gram
  MacroCalculationResult calculateForWeight(double weightG) {
    return toIngredientCutModel().calculateForWeight(weightG);
  }
}

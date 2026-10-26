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
  final double? sugarsPer100g;
  final double? saturatedFatPer100g;
  final double? sodiumMg;
  final String ingredientsText;
  final String imageUrl;
  final String source;
  final String? cutEquivalentId;
  final String notes;
  final String? manufacturingDate;
  final String? expirationDate;
  final String? storageRecommendation;
  final int? shelfLifeDaysEstimate;

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
    this.sugarsPer100g,
    this.saturatedFatPer100g,
    this.sodiumMg,
    this.ingredientsText = '',
    this.imageUrl = '',
    this.source = 'Open Food Facts (CSDL Bên Thứ 3)',
    this.cutEquivalentId,
    this.notes = '',
    this.manufacturingDate,
    this.expirationDate,
    this.storageRecommendation,
    this.shelfLifeDaysEstimate,
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
      sugarsPer100g: json['sugarsPer100g'] != null ? (json['sugarsPer100g']).toDouble() : (json['SugarsPer100g'] != null ? (json['SugarsPer100g']).toDouble() : null),
      saturatedFatPer100g: json['saturatedFatPer100g'] != null ? (json['saturatedFatPer100g']).toDouble() : (json['SaturatedFatPer100g'] != null ? (json['SaturatedFatPer100g']).toDouble() : null),
      sodiumMg: json['sodiumMg'] != null ? (json['sodiumMg']).toDouble() : (json['SodiumMg'] != null ? (json['SodiumMg']).toDouble() : null),
      ingredientsText: json['ingredientsText'] ?? json['IngredientsText'] ?? '',
      imageUrl: json['imageUrl'] ?? json['ImageUrl'] ?? '',
      source: json['source'] ?? json['Source'] ?? 'Open Food Facts (CSDL Bên Thứ 3)',
      cutEquivalentId: json['cutEquivalentId'] ?? json['CutEquivalentId'],
      notes: json['notes'] ?? json['Notes'] ?? '',
      manufacturingDate: json['manufacturingDate'] ?? json['ManufacturingDate'],
      expirationDate: json['expirationDate'] ?? json['ExpirationDate'],
      storageRecommendation: json['storageRecommendation'] ?? json['StorageRecommendation'],
      shelfLifeDaysEstimate: json['shelfLifeDaysEstimate'] != null ? (json['shelfLifeDaysEstimate'] as num).toInt() : (json['ShelfLifeDaysEstimate'] != null ? (json['ShelfLifeDaysEstimate'] as num).toInt() : null),
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
    'sugarsPer100g': sugarsPer100g,
    'saturatedFatPer100g': saturatedFatPer100g,
    'sodiumMg': sodiumMg,
    'ingredientsText': ingredientsText,
    'imageUrl': imageUrl,
    'source': source,
    'cutEquivalentId': cutEquivalentId,
    'notes': notes,
    'manufacturingDate': manufacturingDate,
    'expirationDate': expirationDate,
    'storageRecommendation': storageRecommendation,
    'shelfLifeDaysEstimate': shelfLifeDaysEstimate,
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

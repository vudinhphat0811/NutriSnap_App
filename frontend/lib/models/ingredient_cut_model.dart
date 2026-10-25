class IngredientCutModel {
  final String id;
  final String category;
  final String categoryIcon;
  final String name;
  final String englishName;
  final String description;
  final String defaultPortionName;
  final double defaultPortionWeightG;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final double fiberPer100g;
  final List<String> suitableGoals;
  final List<String> gymBadges;
  final String gymTip;
  final String imageUrl;

  const IngredientCutModel({
    required this.id,
    required this.category,
    required this.categoryIcon,
    required this.name,
    required this.englishName,
    required this.description,
    required this.defaultPortionName,
    required this.defaultPortionWeightG,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    required this.fiberPer100g,
    this.suitableGoals = const [],
    this.gymBadges = const [],
    this.gymTip = '',
    this.imageUrl = '',
  });

  factory IngredientCutModel.fromJson(Map<String, dynamic> json) {
    return IngredientCutModel(
      id: json['id'] ?? json['Id'] ?? '',
      category: json['category'] ?? json['Category'] ?? '',
      categoryIcon: json['categoryIcon'] ?? json['CategoryIcon'] ?? '🍗',
      name: json['name'] ?? json['Name'] ?? '',
      englishName: json['englishName'] ?? json['EnglishName'] ?? '',
      description: json['description'] ?? json['Description'] ?? '',
      defaultPortionName: json['defaultPortionName'] ?? json['DefaultPortionName'] ?? '100g',
      defaultPortionWeightG: (json['defaultPortionWeightG'] ?? json['DefaultPortionWeightG'] ?? 100.0).toDouble(),
      caloriesPer100g: (json['caloriesPer100g'] ?? json['CaloriesPer100g'] ?? 0.0).toDouble(),
      proteinPer100g: (json['proteinPer100g'] ?? json['ProteinPer100g'] ?? 0.0).toDouble(),
      carbsPer100g: (json['carbsPer100g'] ?? json['CarbsPer100g'] ?? 0.0).toDouble(),
      fatPer100g: (json['fatPer100g'] ?? json['FatPer100g'] ?? 0.0).toDouble(),
      fiberPer100g: (json['fiberPer100g'] ?? json['FiberPer100g'] ?? 0.0).toDouble(),
      suitableGoals: (json['suitableGoals'] ?? json['SuitableGoals'] as List?)?.map((e) => e.toString()).toList() ?? [],
      gymBadges: (json['gymBadges'] ?? json['GymBadges'] as List?)?.map((e) => e.toString()).toList() ?? [],
      gymTip: json['gymTip'] ?? json['GymTip'] ?? '',
      imageUrl: json['imageUrl'] ?? json['ImageUrl'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category,
    'categoryIcon': categoryIcon,
    'name': name,
    'englishName': englishName,
    'description': description,
    'defaultPortionName': defaultPortionName,
    'defaultPortionWeightG': defaultPortionWeightG,
    'caloriesPer100g': caloriesPer100g,
    'proteinPer100g': proteinPer100g,
    'carbsPer100g': carbsPer100g,
    'fatPer100g': fatPer100g,
    'fiberPer100g': fiberPer100g,
    'suitableGoals': suitableGoals,
    'gymBadges': gymBadges,
    'gymTip': gymTip,
    'imageUrl': imageUrl,
  };

  /// Tính toán Macro cho một khối lượng gram bất kỳ
  MacroCalculationResult calculateForWeight(double weightG) {
    final safeWeight = weightG <= 0 ? 1.0 : weightG;
    final factor = safeWeight / 100.0;

    final cal = (caloriesPer100g * factor).roundToDouble();
    final pro = double.parse((proteinPer100g * factor).toStringAsFixed(1));
    final carb = double.parse((carbsPer100g * factor).toStringAsFixed(1));
    final fat = double.parse((fatPer100g * factor).toStringAsFixed(1));
    final fiber = double.parse((fiberPer100g * factor).toStringAsFixed(1));

    final proCal = pro * 4.0;
    final carbCal = carb * 4.0;
    final fatCal = fat * 9.0;
    final totalMacroCal = (proCal + carbCal + fatCal) <= 0 ? 1.0 : (proCal + carbCal + fatCal);

    final proPct = double.parse(((proCal / totalMacroCal) * 100.0).toStringAsFixed(1));
    final carbPct = double.parse(((carbCal / totalMacroCal) * 100.0).toStringAsFixed(1));
    final fatPct = double.parse(((fatCal / totalMacroCal) * 100.0).toStringAsFixed(1));

    return MacroCalculationResult(
      cut: this,
      weightG: safeWeight,
      calories: cal,
      protein: pro,
      carbs: carb,
      fat: fat,
      fiber: fiber,
      proteinPercent: proPct,
      carbsPercent: carbPct,
      fatPercent: fatPct,
    );
  }

  /// Hệ số nở / ngót sau khi nấu chín
  /// Ví dụ: Gạo trắng = 2.6 (nở 260%), Thịt = 0.75 (ngót 25%), Yến mạch = 3.5
  double get cookingYieldRatio {
    final lowerId = id.toLowerCase();
    final lowerCat = category.toLowerCase();
    final lowerName = name.toLowerCase();

    // Gạo
    if (lowerId.contains('rice') || lowerName.contains('gạo')) {
      if (lowerId.contains('brown') || lowerName.contains('lứt')) return 2.5;
      return 2.6;
    }
    // Yến mạch
    if (lowerId.contains('oats') || lowerName.contains('yến mạch')) return 3.5;
    // Đậu khô
    if (lowerId.contains('bean') || lowerName.contains('đậu đen') || lowerName.contains('đậu xanh') || lowerName.contains('đậu đỏ')) return 2.4;

    // Trứng luộc (giữ nguyên khối lượng ~100%, không ngót nước như thịt)
    if (lowerId.contains('egg') || lowerName.contains('trứng') || lowerId.contains('yolk')) {
      return 1.0;
    }

    // Thịt gà, bò, heo (áp chảo/luộc ngót nước ~25%)
    if ((lowerCat.contains('thịt') && !lowerName.contains('trứng')) || lowerId.contains('chicken') || lowerId.contains('beef') || lowerId.contains('pork')) {
      return 0.75; // Ngót ~25% khi nấu
    }
    // Thủy hải sản
    if (lowerCat.contains('thủy') || lowerCat.contains('hải sản') || lowerId.contains('shrimp') || lowerId.contains('fish') || lowerId.contains('squid') || lowerId.contains('salmon') || lowerId.contains('tuna')) {
      return 0.72; // Ngót ~28%
    }
    // Rau củ luộc/xào
    if (lowerCat.contains('rau')) {
      return 0.85; // Mất nhẹ nước khi nấu chín
    }
    // Khoai củ hấp
    if (lowerId.contains('potato') || lowerId.contains('sweet_potato') || lowerId.contains('taro') || lowerName.contains('khoai')) {
      return 0.95;
    }

    // Mặc định
    return 1.0;
  }

  /// Tên gọi khi đã nấu chín
  String get cookedName {
    final lowerId = id.toLowerCase();
    final lowerCat = category.toLowerCase();
    final lowerName = name.toLowerCase();

    if (lowerId.contains('brown_rice') || lowerName.contains('gạo lứt')) return 'cơm gạo lứt chín';
    if (lowerId.contains('rice') || lowerName.contains('gạo')) return 'cơm trắng chín';
    if (lowerId.contains('oats') || lowerName.contains('yến mạch')) return 'cháo yến mạch';
    if (lowerId.contains('bean') || lowerName.contains('đậu')) return 'đậu ninh nhừ';
    if (lowerId.contains('chicken_breast') || lowerName.contains('ức gà')) return 'ức gà chín (áp chảo/luộc)';
    if (lowerId.contains('egg_white') || lowerName.contains('lòng trắng')) return 'lòng trắng trứng luộc';
    if (lowerId.contains('egg_yolk') || lowerName.contains('lòng đỏ')) return 'lòng đỏ trứng luộc';
    if (lowerId.contains('egg') || lowerName.contains('trứng')) return '$name luộc';
    if (lowerCat.contains('thịt')) return '$name chín (áp chảo/luộc)';
    if (lowerCat.contains('hải sản') || lowerCat.contains('thủy')) return '$name chín';
    if (lowerId.contains('sweet_potato') || lowerName.contains('khoai lang')) return 'khoai lang hấp/nướng';
    if (lowerId.contains('potato') || lowerName.contains('khoai tây')) return 'khoai tây luộc';
    if (lowerCat.contains('rau')) return '$name luộc/xào';
    return '$name sau nấu';
  }

  /// Tên gọi chuẩn, viết hoa tự nhiên khi hiển thị trong Danh mục Đã Chín
  String get cookedDisplayName {
    final lowerId = id.toLowerCase();
    final lowerCat = category.toLowerCase();
    final lowerName = name.toLowerCase();

    if (lowerId.contains('brown_rice') || lowerName.contains('gạo lứt')) return 'Cơm gạo lứt';
    if (lowerId.contains('rice') || lowerName.contains('gạo')) return 'Cơm trắng';
    if (lowerId.contains('oats') || lowerName.contains('yến mạch')) return 'Cháo yến mạch';
    if (lowerId.contains('sweet_potato') || lowerName.contains('khoai lang')) return 'Khoai lang hấp / nướng';
    if (lowerId.contains('potato') || lowerName.contains('khoai tây')) return 'Khoai tây luộc';
    if (lowerId.contains('sweet_corn') || lowerName.contains('bắp')) return 'Bắp ngô ngọt luộc';
    if (lowerId.contains('taro') || lowerName.contains('khoai môn')) return 'Khoai môn luộc';
    if (lowerId.contains('bean') || lowerName.contains('đậu')) return '$name ninh chín';

    if (lowerId.contains('chicken_breast') || lowerName.contains('ức gà')) return 'Ức gà chín (áp chảo/luộc)';
    if (lowerId.contains('chicken_thigh') || lowerName.contains('đùi gà')) return 'Đùi gà chín (luộc/nướng)';
    if (lowerId.contains('chicken_drumstick') || lowerName.contains('má đùi')) return 'Má đùi gà chín';
    if (lowerId.contains('egg_white')) return 'Lòng trắng trứng luộc';
    if (lowerId.contains('egg_yolk') || lowerName.contains('lòng đỏ')) return 'Lòng đỏ trứng luộc';
    if (lowerId.contains('egg') || lowerName.contains('trứng')) return '$name luộc';

    if (lowerCat.contains('thịt')) return '$name chín (áp chảo/luộc)';
    if (lowerCat.contains('hải sản') || lowerCat.contains('thủy')) return '$name chín (hấp/luộc)';
    if (lowerCat.contains('rau')) return '$name luộc';
    if (lowerCat.contains('trái cây')) return '$name tươi';

    return '$name chín';
  }

  /// Năng lượng và dinh dưỡng tương đương trên 100g đã chín
  double get caloriesPer100gCooked {
    final ratio = cookingYieldRatio <= 0 ? 1.0 : cookingYieldRatio;
    return (caloriesPer100g / ratio).roundToDouble();
  }

  double get proteinPer100gCooked {
    final ratio = cookingYieldRatio <= 0 ? 1.0 : cookingYieldRatio;
    return double.parse((proteinPer100g / ratio).toStringAsFixed(1));
  }

  double get carbsPer100gCooked {
    final ratio = cookingYieldRatio <= 0 ? 1.0 : cookingYieldRatio;
    return double.parse((carbsPer100g / ratio).toStringAsFixed(1));
  }

  double get fatPer100gCooked {
    final ratio = cookingYieldRatio <= 0 ? 1.0 : cookingYieldRatio;
    return double.parse((fatPer100g / ratio).toStringAsFixed(1));
  }

  /// Mô tả ngắn về độ nở / ngót khi chế biến
  String get cookingYieldSummary {
    final ratio = cookingYieldRatio;
    if (ratio > 1.05) {
      final percent = ((ratio - 1.0) * 100).round();
      return 'Nở thêm +$percent% khi nấu';
    } else if (ratio < 0.95) {
      final shrinkPercent = ((1.0 - ratio) * 100).round();
      return 'Ngót ~$shrinkPercent% khi nấu';
    } else {
      return 'Giữ nguyên khối lượng';
    }
  }

  /// Tính khối lượng chín tương ứng từ gram thô
  double calculateCookedWeight(double rawWeightG) {
    return (rawWeightG * cookingYieldRatio).roundToDouble();
  }

  /// Quy đổi ngược từ gram chín trên đĩa sang gram thô
  double calculateRawWeightFromCooked(double cookedWeightG) {
    final ratio = cookingYieldRatio;
    if (ratio <= 0) return cookedWeightG;
    return (cookedWeightG / ratio).roundToDouble();
  }

  /// Các phần gợi ý dân dã quen thuộc theo thói quen người Việt
  List<HouseholdPortion> get householdPortions {
    final lowerId = id.toLowerCase();
    final lowerCat = category.toLowerCase();
    final lowerName = name.toLowerCase();

    // Gạo
    if (lowerId.contains('rice') || lowerName.contains('gạo')) {
      return const [
        HouseholdPortion(label: '1/2 bát con gạo (~80g thô)', weightG: 80, note: '~208g cơm chín (~1.4 bát con)'),
        HouseholdPortion(label: '1 bát con gạt (~150g thô)', weightG: 150, note: '~390g cơm chín (~2.6 bát con)'),
        HouseholdPortion(label: '1 lon sữa đặc (~250g thô)', weightG: 250, note: '~650g cơm chín (nấu cho 2-3 người)'),
      ];
    }
    // Yến mạch
    if (lowerId.contains('oats') || lowerName.contains('yến mạch')) {
      return const [
        HouseholdPortion(label: '3 thìa canh đầy (~30g)', weightG: 30, note: '~105g cháo yến mạch'),
        HouseholdPortion(label: '1/2 bát con (~50g)', weightG: 50, note: '~175g cháo yến mạch'),
        HouseholdPortion(label: '1 bát con (~90g)', weightG: 90, note: '~315g cháo yến mạch'),
      ];
    }
    // Trứng
    if (lowerId.contains('egg') || lowerName.contains('trứng')) {
      return const [
        HouseholdPortion(label: '1 quả trứng vừa (~55g)', weightG: 55, note: '~78 kcal'),
        HouseholdPortion(label: '2 quả trứng (~110g)', weightG: 110, note: '~156 kcal'),
        HouseholdPortion(label: '3 lòng trắng trứng (~100g)', weightG: 100, note: '~52 kcal, siêu đạm'),
      ];
    }
    // Khoai lang / Khoai tây
    if (lowerId.contains('potato') || lowerName.contains('khoai')) {
      return const [
        HouseholdPortion(label: '1 củ nhỏ (~100g)', weightG: 100, note: '~95g sau hấp'),
        HouseholdPortion(label: '1 củ vừa (~150g)', weightG: 150, note: '~142g sau hấp'),
        HouseholdPortion(label: '1 củ to (~250g)', weightG: 250, note: '~238g sau hấp'),
      ];
    }
    // Thịt gà / Ức gà
    if (lowerId.contains('chicken_breast') || lowerName.contains('ức gà')) {
      return const [
        HouseholdPortion(label: '1/2 miếng ức gà (~100g thô)', weightG: 100, note: '~75g thịt chín (ngót 25%)'),
        HouseholdPortion(label: '1 miếng ức gà vừa (~200g thô)', weightG: 200, note: '~150g thịt chín'),
        HouseholdPortion(label: '1 miếng ức gà lớn (~300g thô)', weightG: 300, note: '~225g thịt chín'),
      ];
    }
    // Thịt nói chung (Bò, Heo)
    if (lowerCat.contains('thịt')) {
      return const [
        HouseholdPortion(label: 'Lòng bàn tay nhỏ (~100g thô)', weightG: 100, note: '~75g thịt chín'),
        HouseholdPortion(label: 'Nắm đấm tay (~120g thô)', weightG: 120, note: '~90g thịt chín'),
        HouseholdPortion(label: 'Lòng bàn tay dày (~150g thô)', weightG: 150, note: '~112g thịt chín'),
      ];
    }
    // Cá & Thủy hải sản
    if (lowerCat.contains('thủy') || lowerCat.contains('hải sản')) {
      return const [
        HouseholdPortion(label: '1 đĩa nhỏ mực/tôm (~100g)', weightG: 100, note: '~72g hải sản chín'),
        HouseholdPortion(label: '1 khúc cá / 1 fillet (~150g)', weightG: 150, note: '~110g cá chín'),
        HouseholdPortion(label: '1 phần ăn lớn (~200g)', weightG: 200, note: '~144g sau nấu'),
      ];
    }
    // Rau củ
    if (lowerCat.contains('rau')) {
      return const [
        HouseholdPortion(label: '1 nắm tay rau (~80g thô)', weightG: 80, note: 'Ăn nhẹ thanh mát'),
        HouseholdPortion(label: '1 đĩa rau nhỏ (~150g thô)', weightG: 150, note: 'Khẩu phần 1 người'),
        HouseholdPortion(label: '1 đĩa rau lớn (~300g thô)', weightG: 300, note: 'Khẩu phần gia đình'),
      ];
    }
    // Trái cây
    if (lowerCat.contains('trái cây')) {
      return const [
        HouseholdPortion(label: '1 quả nhỏ (~100g)', weightG: 100, note: 'Bữa phụ nhẹ nhàng'),
        HouseholdPortion(label: '1 quả vừa (~150g)', weightG: 150, note: 'Khẩu phần tiêu chuẩn'),
        HouseholdPortion(label: '1 đĩa trái cây gọt (~250g)', weightG: 250, note: 'Tráng miệng dồi dào'),
      ];
    }

    // Mặc định
    return const [
      HouseholdPortion(label: 'Khẩu phần nhỏ (50g)', weightG: 50),
      HouseholdPortion(label: 'Khẩu phần chuẩn (100g)', weightG: 100),
      HouseholdPortion(label: 'Khẩu phần vừa (150g)', weightG: 150),
      HouseholdPortion(label: 'Khẩu phần lớn (200g)', weightG: 200),
    ];
  }
}

/// Đơn vị ước lượng dân dã quen thuộc (Household Portion)
class HouseholdPortion {
  final String label;
  final double weightG;
  final String note;
  final String? icon;

  const HouseholdPortion({
    required this.label,
    required this.weightG,
    this.note = '',
    this.icon,
  });
}

class MacroCalculationResult {
  final IngredientCutModel cut;
  final double weightG;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double proteinPercent;
  final double carbsPercent;
  final double fatPercent;

  const MacroCalculationResult({
    required this.cut,
    required this.weightG,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.proteinPercent,
    required this.carbsPercent,
    required this.fatPercent,
  });
}

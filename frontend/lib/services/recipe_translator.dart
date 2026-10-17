/// Adapter hiển thị bản dịch công thức
/// (Lưu ý: Mọi bản dịch chi tiết, nguyên liệu và hướng dẫn nấu đều do C# Backend dịch tự động 100% bằng TranslationService)
class RecipeTranslator {
  /// Hiển thị tên món (Backend đã tự động dịch vào trường strMealVi)
  static String translateDishName(String name) {
    return name;
  }

  /// Hiển thị tên nguyên liệu (Backend đã dịch vào trường ingredientsVi)
  static String translateIngredient(String ingredient) {
    return ingredient;
  }

  /// Hiển thị đơn vị đo (Backend đã dịch vào trường measuresVi)
  static String translateMeasure(String measure) {
    return measure;
  }

  /// Hiển thị bước nấu (Backend đã dịch vào trường strInstructionsVi)
  static String translateInstructionStep(String step, [int stepIndex = 0]) {
    String s = step.trim();
    if (s.isEmpty) return s;
    s = s.replaceAll(RegExp(r'^(Step\s*\d+:?|\d+\.|\d+\))\s*', caseSensitive: false), '').trim();
    if (s.isNotEmpty) {
      s = s[0].toUpperCase() + s.substring(1);
    }
    return s;
  }
}

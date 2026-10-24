/// Adapter hiển thị bản dịch công thức chuẩn xác & tự nhiên
/// Hỗ trợ chuẩn hóa nguyên liệu và đơn vị đo lường ẩm thực 100% Tiếng Việt
class RecipeTranslator {
  static const Map<String, String> _knownIngredients = {
    // Thịt & Thủy hải sản
    'chicken': 'Thịt gà',
    'chicken breast': 'Ức gà',
    'chicken breasts': 'Ức gà',
    'chicken thighs': 'Đùi gà',
    'chicken thigh': 'Đùi gà',
    'chicken wings': 'Cánh gà',
    'chicken legs': 'Đùi gà',
    'chicken drumsticks': 'Đùi gà tỏi',
    'beef': 'Thịt bò',
    'minced beef': 'Thịt bò băm',
    'ground beef': 'Thịt bò xay',
    'beef steak': 'Thịt bò bít tết',
    'beef tenderloin': 'Thăn nội bò',
    'beef sirloin': 'Thăn ngoại bò',
    'pork': 'Thịt heo',
    'minced pork': 'Thịt heo băm',
    'ground pork': 'Thịt heo xay',
    'pork chops': 'Sườn heo',
    'pork belly': 'Thịt ba chỉ',
    'pork shoulder': 'Nạc vai heo',
    'bacon': 'Thịt xông khói',
    'salmon': 'Cá hồi',
    'salmon fillet': 'Phi lê cá hồi',
    'tuna': 'Cá ngừ',
    'cod': 'Cá tuyết',
    'fish': 'Cá tươi',
    'shrimp': 'Tôm',
    'shrimps': 'Tôm',
    'prawns': 'Tôm sú',
    'raw king prawns': 'Tôm tươi',
    'king prawns': 'Tôm sú',
    'tiger prawns': 'Tôm sú',
    'squid': 'Mực',
    'calamari': 'Mực tươi',
    'crab': 'Cua biển',
    'lobster': 'Tôm hùm',
    'egg': 'Trứng',
    'eggs': 'Trứng gà',
    'egg yolk': 'Lòng đỏ trứng',
    'egg white': 'Lòng trắng trứng',
    'tofu': 'Đậu phụ',

    // Rau củ & Thảo mộc
    'garlic': 'Tỏi',
    'garlic clove': 'Tép tỏi',
    'garlic cloves': 'Tép tỏi',
    'onion': 'Hành tây',
    'onions': 'Hành tây',
    'red onion': 'Hành tím',
    'red onions': 'Hành tím',
    'shallot': 'Hành tím',
    'shallots': 'Hành tím',
    'spring onion': 'Hành lá',
    'spring onions': 'Hành lá',
    'green onion': 'Hành lá',
    'green onions': 'Hành lá',
    'scallion': 'Hành lá',
    'scallions': 'Hành lá',
    'chives': 'Hẹ',
    'ginger': 'Gừng',
    'tomato': 'Cà chua',
    'tomatoes': 'Cà chua',
    'plum tomatoes': 'Cà chua quả',
    'cherry tomatoes': 'Cà chua bi',
    'potato': 'Khoai tây',
    'potatoes': 'Khoai tây',
    'sweet potato': 'Khoai lang',
    'sweet potatoes': 'Khoai lang',
    'carrot': 'Cà rốt',
    'carrots': 'Cà rốt',
    'broccoli': 'Bông cải xanh',
    'cauliflower': 'Súp lơ trắng',
    'cabbage': 'Bắp cải',
    'cucumber': 'Dưa leo',
    'mushroom': 'Nấm tươi',
    'mushrooms': 'Nấm tươi',
    'bell pepper': 'Ớt chuông',
    'bell peppers': 'Ớt chuông',
    'red pepper': 'Ớt chuông đỏ',
    'green pepper': 'Ớt chuông xanh',
    'yellow pepper': 'Ớt chuông vàng',
    'sweet pepper': 'Ớt chuông',
    'chilli': 'Ớt cay',
    'chili': 'Ớt cay',
    'chillies': 'Ớt cay',
    'chilies': 'Ớt cay',
    'chilli flakes': 'Ớt vảy',
    'chili flakes': 'Ớt vảy',
    'red pepper flakes': 'Ớt vảy',
    'paprika': 'Ớt bột Paprika',
    'smoked paprika': 'Ớt bột hun khói Paprika',
    'cayenne pepper': 'Ớt bột Cayenne',
    'coriander': 'Rau ngò rí',
    'coriander leaves': 'Rau ngò rí',
    'cilantro': 'Rau ngò rí',
    'parsley': 'Ngò tây',
    'basil': 'Húng quế',
    'mint': 'Bạc hà',
    'mint leaves': 'Lá bạc hà',
    'rosemary': 'Hương thảo',
    'thyme': 'Xạ hương',
    'oregano': 'Kinh giới tây (Oregano)',
    'lemongrass': 'Sả',

    // Gia vị & Sữa
    'salt': 'Muối',
    'sea salt': 'Muối biển',
    'pepper': 'Tiêu',
    'black pepper': 'Tiêu đen',
    'white pepper': 'Tiêu trắng',
    'sugar': 'Đường',
    'brown sugar': 'Đường nâu',
    'honey': 'Mật ong',
    'olive oil': 'Dầu ô liu',
    'vegetable oil': 'Dầu thực vật',
    'coconut oil': 'Dầu dừa',
    'sesame oil': 'Dầu mè',
    'oil': 'Dầu ăn',
    'water': 'Nước',
    'butter': 'Bơ',
    'flour': 'Bột mì',
    'cornstarch': 'Bột bắp',
    'corn flour': 'Bột bắp',
    'rice': 'Gạo / Cơm',
    'jasmine rice': 'Gạo thơm',
    'basmati rice': 'Gạo Basmati',
    'brown rice': 'Gạo lứt',
    'pasta': 'Mì Ý / Pasta',
    'spaghetti': 'Mì Ý',
    'noodles': 'Mì / Sợi phở',
    'soy sauce': 'Nước tương',
    'dark soy sauce': 'Hắc xì dầu',
    'fish sauce': 'Nước mắm',
    'oyster sauce': 'Dầu hào',
    'lemon': 'Chanh vàng',
    'lemon juice': 'Nước cốt chanh vàng',
    'lime': 'Chanh xanh',
    'lime juice': 'Nước cốt chanh',
    'milk': 'Sữa tươi',
    'coconut milk': 'Nước cốt dừa',
    'coconut cream': 'Kem dừa',
    'cheese': 'Phô mai',
    'parmesan': 'Phô mai Parmesan',
    'mozzarella': 'Phô mai Mozzarella',
    'cheddar cheese': 'Phô mai Cheddar',
    'heavy cream': 'Kem béo (Heavy Cream)',
    'sour cream': 'Kem chua (Sour Cream)',
    'yogurt': 'Sữa chua',
    'chicken stock': 'Nước dùng gà',
    'chicken broth': 'Nước hầm gà',
    'beef stock': 'Nước dùng bò',
    'beef broth': 'Nước hầm bò',
    'vegetable stock': 'Nước dùng rau củ',
    'vegetable broth': 'Nước hầm rau củ',
    'tomato puree': 'Sốt cà chua nhuyễn',
    'tomato paste': 'Cà chua cô đặc',
    'tomato sauce': 'Sốt cà chua',
  };

  /// Hiển thị tên món (Backend đã tự động dịch vào trường strMealVi)
  static String translateDishName(String name) {
    return name;
  }

  /// Hiển thị tên nguyên liệu: Tự động khắc phục các lỗi dịch sai ngữ cảnh và Việt hóa 100%
  static String translateIngredient(String ingredient, [String? englishRaw]) {
    final trimIng = ingredient.trim();
    if (trimIng.isEmpty) return trimIng;

    final lower = trimIng.toLowerCase();
    final lowerEn = englishRaw?.trim().toLowerCase() ?? '';

    // 1. Khắc phục lỗi dịch sai ngữ cảnh phổ biến từ nguồn tiếng Anh
    if (lowerEn.isNotEmpty) {
      if ((lowerEn.contains('spring onion') || lowerEn.contains('scallion') || lowerEn.contains('green onion')) &&
          (trimIng == 'Hành tây' || trimIng.toLowerCase().contains('spring onion'))) {
        return 'Hành lá';
      }
      if (lowerEn.contains('shallot') && trimIng == 'Hành tây') {
        return 'Hành tím';
      }
      if (lowerEn.contains('red pepper') && trimIng == 'Tiêu') {
        return 'Ớt chuông đỏ';
      }
      if (lowerEn.contains('green pepper') && trimIng == 'Tiêu') {
        return 'Ớt chuông xanh';
      }
      if (lowerEn.contains('yellow pepper') && trimIng == 'Tiêu') {
        return 'Ớt chuông vàng';
      }
      if ((lowerEn.contains('bell pepper') || lowerEn.contains('sweet pepper')) && trimIng == 'Tiêu') {
        return 'Ớt chuông';
      }
      if (lowerEn.contains('coconut milk') && trimIng == 'Sữa tươi') {
        return 'Nước cốt dừa';
      }
      if (lowerEn.contains('coconut oil') && (trimIng == 'Coconut Oil' || trimIng == 'Dầu ăn')) {
        return 'Dầu dừa';
      }
      if (lowerEn.contains('lime juice') && trimIng == 'Lime juice') {
        return 'Nước cốt chanh';
      }
      if (lowerEn.contains('chilli flakes') || lowerEn.contains('chili flakes')) {
        return 'Ớt vảy';
      }
      if (lowerEn.contains('paprika')) {
        return 'Ớt bột Paprika';
      }
      if (lowerEn.contains('coriander') || lowerEn.contains('cilantro')) {
        return 'Rau ngò rí';
      }
      if (lowerEn == 'raw king prawns' || lowerEn == 'king prawns' || lowerEn == 'tiger prawns') {
        return 'Tôm tươi';
      }
    }

    // 2. Tra cứu trực tiếp từ điển nếu chuỗi còn nguyên tiếng Anh
    if (_knownIngredients.containsKey(lower)) {
      return _knownIngredients[lower]!;
    }
    if (lowerEn.isNotEmpty && _knownIngredients.containsKey(lowerEn)) {
      if (trimIng.toLowerCase() == lowerEn) {
        return _knownIngredients[lowerEn]!;
      }
    }

    return trimIng;
  }

  /// Hiển thị đơn vị đo: Việt hóa cách sơ chế và đơn vị đo, tự động tính khẩu phần ẩm thực thực tế nếu gặp placeholder
  static String translateMeasure(String measure, [String? ingredientName, int index = 0]) {
    String s = measure.trim();
    final lower = s.toLowerCase();

    final isPlaceholder = s.isEmpty ||
        lower.contains('tiêu chuẩn') ||
        lower.contains('tieu chuan') ||
        lower.contains('khẩu phần') ||
        lower.contains('khau phan') ||
        lower.contains('standard portion') ||
        lower.contains('default portion') ||
        lower.contains('masterchef') ||
        lower == 'standard' ||
        lower == 'portion';

    // Khắc phục nhãn giữ chỗ 'Khẩu phần tiêu chuẩn' / 'Khẩu phần MasterChef' thành định lượng ẩm thực thực tế
    if (isPlaceholder) {
      if (ingredientName != null && ingredientName.trim().isNotEmpty) {
        return generateDefaultMeasure(ingredientName, index);
      }
      return 'Vừa đủ dùng';
    }

    if (lower == 'to serve') return 'Dùng kèm';
    if (lower == 'to taste') return 'Vừa ăn';
    if (lower == 'garnish' || lower == 'for garnish') return 'Trang trí';
    if (lower == 'for frying') return 'Dùng để chiên';

    // Thay thế pound sang gam
    s = s.replaceAll(RegExp(r'\b1\s*(?:lb|lbs|pound|pounds)\b', caseSensitive: false), '450g');
    s = s.replaceAll(RegExp(r'\b2\s*(?:lb|lbs|pound|pounds)\b', caseSensitive: false), '900g');
    s = s.replaceAll(RegExp(r'\b1/2\s*(?:lb|lbs|pound|pounds)\b', caseSensitive: false), '225g');
    s = s.replaceAllMapped(RegExp(r'\b(\d+)\s*(?:lb|lbs|pound|pounds)\b', caseSensitive: false), (m) {
      final num = int.tryParse(m.group(1) ?? '1') ?? 1;
      return '${num * 450}g';
    });

    // Chuyển đổi các từ sơ chế (Prep words)
    final prepMap = {
      r'\bfinely chopped\b': 'băm nhuyễn',
      r'\bcoarsely chopped\b': 'thái khúc',
      r'\bchopped\b': 'băm nhỏ',
      r'\bfinely minced\b': 'băm nhuyễn',
      r'\bminced\b': 'băm nhỏ',
      r'\bthinly sliced\b': 'thái lát mỏng',
      r'\bsliced\b': 'thái lát',
      r'\bdiced\b': 'thái hạt lựu',
      r'\bcrushed\b': 'đập dập',
      r'\bgrated\b': 'bào sợi',
      r'\bpeeled\b': 'gọt vỏ',
      r'\bshredded\b': 'xé sợi',
      r'\bmelted\b': 'đun chảy',
      r'\bbeaten\b': 'đánh tan',
      r'\bdrained\b': 'để ráo nước',
      r'\bto serve\b': 'dùng kèm',
      r'\bto taste\b': 'vừa ăn',
    };

    prepMap.forEach((pattern, vi) {
      s = s.replaceAll(RegExp(pattern, caseSensitive: false), vi);
    });

    // Chuyển đổi các đơn vị đo (Unit words)
    final unitMap = {
      r'\btablespoons?\b': 'muỗng canh',
      r'\btbsp\b': 'muỗng canh',
      r'\btbs\b': 'muỗng canh',
      r'\bteaspoons?\b': 'muỗng cà phê',
      r'\btsp\b': 'muỗng cà phê',
      r'\bcloves?\b': 'tép',
      r'\bcups?\b': 'chén',
      r'\bcans?\b': 'lon',
      r'\bpinche?s?\b': 'nhúm',
      r'\bslices?\b': 'lát',
      r'\bpieces?\b': 'miếng',
      r'\bbunche?s?\b': 'bó',
      r'\bsprigs?\b': 'nhánh',
      r'\bstalks?\b': 'nhánh',
      r'\bheads?\b': 'bắp',
      r'\bhandfuls?\b': 'nắm',
      r'\bleaves?\b': 'lá',
    };

    unitMap.forEach((pattern, vi) {
      s = s.replaceAll(RegExp(pattern, caseSensitive: false), vi);
    });

    return s.trim();
  }

  /// Tự động sinh định lượng khẩu phần ẩm thực chuẩn cho người Việt
  static String generateDefaultMeasure(String ingredient, int index) {
    final lower = ingredient.toLowerCase().trim();

    // 1. Nhóm đạm chính (Thịt, cá, tôm, mực, trứng, đậu phụ...)
    if (index == 0 || lower.contains('bò') || lower.contains('gà') || lower.contains('heo') ||
        lower.contains('cá') || lower.contains('tôm') || lower.contains('mực') || lower.contains('beef') ||
        lower.contains('chicken') || lower.contains('salmon') || lower.contains('pork') || lower.contains('shrimp') ||
        lower.contains('seafood') || lower.contains('steak') || lower.contains('tofu') || lower.contains('đậu phụ') ||
        lower.contains('đậu hũ') || lower.contains('tàu hũ')) {
      if (lower.contains('trứng') || lower.contains('egg')) return '2 quả';
      if (lower.contains('tofu') || lower.contains('đậu phụ') || lower.contains('đậu hũ') || lower.contains('tàu hũ')) return '1 - 2 bìa (150g)';
      if (lower.contains('phi lê') || lower.contains('fillet') || lower.contains('cá hồi') || lower.contains('salmon')) return '150g';
      if (lower.contains('ức gà') || lower.contains('bắp bò') || lower.contains('thịt') || lower.contains('sườn')) return '150g - 200g';
      return '150g';
    }

    // 2. Nhóm tinh bột (Cơm, bún, phở, mì, bánh mì, yến mạch)
    if (lower.contains('phở') || lower.contains('bún') || lower.contains('mì') || lower.contains('cơm') ||
        lower.contains('bánh mì') || lower.contains('noodle') || lower.contains('rice') || lower.contains('pasta') ||
        lower.contains('spaghetti') || lower.contains('oats') || lower.contains('yến mạch')) {
      if (lower.contains('bánh mì') || lower.contains('bread')) return '1 ổ';
      if (lower.contains('pasta') || lower.contains('spaghetti')) return '100g';
      return '150g';
    }

    // 3. Nhóm bột & ngũ cốc
    if (lower.contains('bột mì') || lower.contains('bột bắp') || lower.contains('bột năng') || lower.contains('bột gạo') ||
        lower.contains('flour') || lower.contains('cornstarch') || lower.contains('baking powder')) {
      return '2 muỗng canh';
    }

    // 4. Nhóm rau củ & nấm
    if (lower.contains('cải') || lower.contains('muống') || lower.contains('bông cải') || lower.contains('mướp') ||
        lower.contains('rau') || lower.contains('choy') || lower.contains('sum') || lower.contains('xà lách') ||
        lower.contains('greens') || lower.contains('vegetable') || lower.contains('spinach') || lower.contains('broccoli') ||
        lower.contains('cabbage') || lower.contains('bắp cải') || lower.contains('mồng tơi') || lower.contains('ngót')) {
      return '200g';
    }
    if (lower.contains('cà rốt') || lower.contains('khoai') || lower.contains('hành tây') || lower.contains('ớt chuông') ||
        lower.contains('cà chua') || lower.contains('dưa leo') || lower.contains('bí') || lower.contains('carrot') ||
        lower.contains('potato') || lower.contains('tomato') || lower.contains('cucumber') || lower.contains('bell pepper')) {
      return '1 củ / quả';
    }
    if (lower.contains('nấm') || lower.contains('mushroom')) {
      return '100g';
    }
    if (lower.contains('giá đỗ') || lower.contains('sprout') || lower.contains('bắp') || lower.contains('ngô') || lower.contains('corn')) {
      return '100g';
    }

    // 5. Hành tỏi sả gừng & thảo mộc gia vị
    if (lower.contains('tỏi') || lower.contains('garlic')) return '2 - 3 tép băm';
    if (lower.contains('hành tím') || lower.contains('shallot')) return '2 - 3 củ băm';
    if (lower.contains('hành lá') || lower.contains('scallion') || lower.contains('spring onion')) return '2 - 3 nhánh cắt khúc';
    if (lower.contains('sả') || lower.contains('lemongrass')) return '2 cây đập dập';
    if (lower.contains('gừng') || lower.contains('ginger')) return '1 nhánh nhỏ';
    if (lower.contains('ớt') || lower.contains('chili') || lower.contains('chilli')) return '1 - 2 quả cắt lát';
    if (lower.contains('hồi') || lower.contains('quế') || lower.contains('ngò') || lower.contains('mùi') ||
        lower.contains('húng') || lower.contains('basil') || lower.contains('cilantro') || lower.contains('parsley')) return '1 nhúm nhỏ';

    // 6. Nước sốt, dầu mỡ & chất béo
    if (lower.contains('nước mắm') || lower.contains('nước tương') || lower.contains('xì dầu') ||
        lower.contains('dầu hào') || lower.contains('dầu') || lower.contains('sauce') || lower.contains('oil') ||
        lower.contains('tương ớt') || lower.contains('tương cà') || lower.contains('mayonnaise') || lower.contains('ketchup')) {
      return '1 muỗng canh';
    }
    if (lower.contains('bơ') || lower.contains('butter')) return '1 muỗng canh (15g)';
    if (lower.contains('phô mai') || lower.contains('cheese')) return '30g - 50g';

    // 7. Gia vị nêm nếm
    if (lower.contains('tiêu') || lower.contains('pepper')) return '1/2 muỗng cà phê';
    if (lower.contains('đường') || lower.contains('muối') || lower.contains('hạt nêm') || lower.contains('bột canh') ||
        lower.contains('sugar') || lower.contains('salt') || lower.contains('paprika')) {
      return '1 muỗng cà phê';
    }

    // 8. Chất lỏng (nước dùng, sữa, nước dừa)
    if (lower.contains('nước cốt dừa') || lower.contains('coconut milk') || lower.contains('sữa') || lower.contains('milk') || lower.contains('yogurt')) return '100ml';
    if (lower.contains('nước dừa') || lower.contains('nước dùng') || lower.contains('nước hầm') || lower.contains('nước lọc') || lower.contains('broth') || lower.contains('stock') || lower.contains('water')) return '200ml - 300ml';
    if (lower.contains('chanh') || lower.contains('giấm') || lower.contains('lime') || lower.contains('lemon') || lower.contains('vinegar')) return '1 muỗng canh';
    if (lower.contains('mè') || lower.contains('đậu phộng') || lower.contains('lạc') || lower.contains('sesame') || lower.contains('peanut') || lower.contains('nut')) return '1 muỗng canh';

    return 'Vừa đủ dùng';
  }

  /// Hiển thị bước nấu (Backend đã dịch vào trường strInstructionsVi)
  static String translateInstructionStep(String step, [int stepIndex = 0]) {
    return _cleanStepText(step);
  }

  /// Phân tích và bóc tách các bước nấu ăn thông minh, loại bỏ lỗi tách nhầm số thứ tự thành dòng riêng
  static List<String> parseCookingSteps(String instructions) {
    if (instructions.trim().isEmpty) return [];

    String cleaned = instructions.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();

    // 1. Nếu có đánh số trong cùng 1 chuỗi: "1. ... 2. ... 3. ..." hoặc "Bước 1: ... Bước 2: ..."
    final numberedPattern = RegExp(r'(?:^|\s+)(?:bước\s*\d+[:\.]?|step\s*\d+[:\.]?|\d+[\.\)])\s+', caseSensitive: false);
    final matchCount = numberedPattern.allMatches(cleaned).length;
    if (matchCount >= 2) {
      final parts = cleaned.split(numberedPattern)
          .map((s) => _cleanStepText(s))
          .where((s) => s.isNotEmpty && s.length > 3 && !RegExp(r'^\d+$').hasMatch(s))
          .toList();
      if (parts.length >= 2) {
        return parts;
      }
    }

    // 2. Tách theo dòng mới (\n)
    final rawLines = cleaned.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final List<String> mergedSteps = [];

    for (int i = 0; i < rawLines.length; i++) {
      String line = rawLines[i];

      // Nếu dòng này chỉ là số thứ tự hoặc nhãn bước đứng riêng lẻ (VD: "1", "2", "Step 1", "Bước 2:")
      final isStepLabelOnly = RegExp(r'^(?:step\s*\d+[:\.]?|bước\s*\d+[:\.]?|\d+[\.:]?)$', caseSensitive: false).hasMatch(line);

      if (isStepLabelOnly) {
        if (i + 1 < rawLines.length) {
          final nextLine = rawLines[i + 1];
          final cleanedNext = _cleanStepText(nextLine);
          if (cleanedNext.isNotEmpty) {
            mergedSteps.add(cleanedNext);
            i++; // Đã gộp dòng tiếp theo
          }
        }
      } else {
        final cleanedText = _cleanStepText(line);
        if (cleanedText.isNotEmpty && cleanedText.length > 3 && !RegExp(r'^\d+$').hasMatch(cleanedText)) {
          mergedSteps.add(cleanedText);
        }
      }
    }

    if (mergedSteps.length >= 2) {
      return mergedSteps;
    }

    // 3. Nếu vẫn là 1 đoạn văn liên tục, tách theo câu (. ) nhưng loại trừ số đơn lẻ
    final sentences = cleaned
        .split(RegExp(r'\.\s+'))
        .map((s) => _cleanStepText(s))
        .where((s) => s.isNotEmpty && s.length > 5 && !RegExp(r'^\d+$').hasMatch(s))
        .toList();

    if (sentences.isNotEmpty) {
      return sentences;
    }

    return [_cleanStepText(cleaned)];
  }

  static String _cleanStepText(String text) {
    String s = text.trim();
    // Xóa tiền tố "1. ", "Step 1: ", "Bước 1: ", "1) " ở đầu câu để tránh lặp số với badge số của UI
    s = s.replaceAll(RegExp(r'^(?:bước\s*\d+[:\.]?|step\s*\d+[:\.]?|\d+[\.\)])\s*', caseSensitive: false), '').trim();
    if (s.isNotEmpty) {
      s = s[0].toUpperCase() + s.substring(1);
    }
    return s;
  }
}

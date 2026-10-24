import '../models/ingredient_cut_model.dart';

/// Service quản lý danh sách nguyên liệu THÔ (sống, 100g thô chuẩn)
/// Nạp tức thì 100% từ bộ nhớ thiết bị (0ms, không độ trễ, không tốn mạng).
class IngredientCutService {

  /// Lấy toàn bộ danh sách tức thì từ bộ nhớ máy (0ms, không tốn mạng, không độ trễ)
  static List<IngredientCutModel> getAllCuts({String? category}) {
    final safeCat = category ?? 'All';
    if (safeCat == 'All' || safeCat == 'Tất cả' || safeCat.isEmpty) {
      return _allBuiltinCuts;
    }
    return _allBuiltinCuts.where((c) =>
      c.category.toLowerCase().contains(safeCat.toLowerCase()) ||
      safeCat.toLowerCase().contains(c.category.toLowerCase())
    ).toList();
  }

  /// Lấy danh sách nguyên liệu thô (Trả về tức thì từ bộ nhớ, không chờ mạng)
  static Future<List<IngredientCutModel>> getCutsAsync({String? category, String? query}) async {
    // 1. Nếu có từ khóa tìm kiếm
    if (query != null && query.trim().isNotEmpty) {
      return _searchOffline(query.trim());
    }

    // 2. Trả về ngay lập tức dữ liệu nguyên liệu thô
    return getAllCuts(category: category);
  }

  static List<IngredientCutModel> _searchOffline(String q) {
    final lower = q.toLowerCase();
    final all = _getOfflineCuts('All');
    return all.where((c) =>
      c.name.toLowerCase().contains(lower) ||
      c.englishName.toLowerCase().contains(lower) ||
      c.category.toLowerCase().contains(lower) ||
      c.gymBadges.any((b) => b.toLowerCase().contains(lower)) ||
      c.description.toLowerCase().contains(lower)
    ).toList();
  }

  static List<IngredientCutModel> _getOfflineCuts(String category) {
    final all = _allBuiltinCuts;
    if (category == 'All' || category == 'Tất cả' || category.isEmpty) {
      return all;
    }
    return all.where((c) => c.category.contains(category) || category.contains(c.category)).toList();
  }

  static IngredientCutModel _i({
    required String id,
    required String category,
    required String icon,
    required String name,
    required String engName,
    required String desc,
    required String portionName,
    required double portionG,
    required double cal,
    required double pro,
    required double carb,
    required double fat,
    required double fiber,
    String badge = '',
    String tip = '',
  }) {
    return IngredientCutModel(
      id: id,
      category: category,
      categoryIcon: icon,
      name: name,
      englishName: engName,
      description: desc,
      defaultPortionName: portionName,
      defaultPortionWeightG: portionG,
      caloriesPer100g: cal,
      proteinPer100g: pro,
      carbsPer100g: carb,
      fatPer100g: fat,
      fiberPer100g: fiber,
      suitableGoals: const ['Kiểm soát calo', 'Eat Clean', 'Tăng cơ giảm mỡ'],
      gymBadges: badge.isNotEmpty ? [badge] : ['🔥 ${cal.round()} kcal / 100g thô', '💪 ${pro}g Đạm'],
      gymTip: tip,
      imageUrl: '',
    );
  }

  /// Danh mục 70+ nguyên liệu thô (sống, chưa chế biến/nấu nướng) chuẩn xác
  static final List<IngredientCutModel> _allBuiltinCuts = [
    // 1. THỊT & TRỨNG
    _i(id: 'raw_chicken_breast', category: 'Thịt & Trứng', icon: '🍗', name: 'Ức gà', engName: 'Raw Chicken Breast (Skinless)',
       desc: 'Thịt nạc trắng giàu đạm chất lượng cao, cực kỳ ít mỡ.', portionName: '100g thô', portionG: 100, cal: 120, pro: 22.5, carb: 0.0, fat: 2.6, fiber: 0.0,
       badge: '💪 22.5g Đạm / 100g', tip: 'Nguyên liệu vàng cho siết mỡ và tăng cơ nạc.'),

    _i(id: 'raw_chicken_thigh', category: 'Thịt & Trứng', icon: '🍗', name: 'Đùi gà', engName: 'Raw Chicken Thigh',
       desc: 'Thịt sẫm màu, mềm ẩm mọng nước và đậm đà tự nhiên.', portionName: '100g thô', portionG: 100, cal: 177, pro: 19.7, carb: 0.0, fat: 10.4, fiber: 0.0,
       badge: '🍗 177 kcal / 100g', tip: 'Thích hợp cho bữa ăn nạp năng lượng tập luyện.'),

    _i(id: 'raw_chicken_drumstick', category: 'Thịt & Trứng', icon: '🍗', name: 'Má đùi gà', engName: 'Raw Chicken Drumstick/Thigh Cut',
       desc: 'Phần má đùi nhiều cơ nạc xen kẽ, hàm lượng kẽm và sắt cao.', portionName: '100g thô', portionG: 100, cal: 209, pro: 17.5, carb: 0.0, fat: 15.3, fiber: 0.0,
       badge: '🍗 209 kcal / 100g', tip: 'Giàu vi chất sắt và vitamin B12.'),

    _i(id: 'raw_chicken_wing', category: 'Thịt & Trứng', icon: '🍗', name: 'Cánh gà', engName: 'Raw Chicken Wing',
       desc: 'Tỉ lệ da và sụn cao, giàu collagen tự nhiên.', portionName: '100g thô', portionG: 100, cal: 203, pro: 18.3, carb: 0.0, fat: 14.1, fiber: 0.0,
       badge: '🍗 203 kcal / 100g', tip: 'Chứa nhiều collagen tốt cho khớp xương.'),

    _i(id: 'raw_chicken_feet', category: 'Thịt & Trứng', icon: '🍗', name: 'Chân gà', engName: 'Raw Chicken Feet',
       desc: 'Chủ yếu là sụn và da, dồi dào canxi và gelatin.', portionName: '100g thô', portionG: 100, cal: 215, pro: 19.4, carb: 0.2, fat: 14.6, fiber: 0.0,
       badge: '🍗 215 kcal / 100g', tip: 'Hàm lượng canxi và collagen cao.'),

    _i(id: 'raw_beef_tenderloin', category: 'Thịt & Trứng', icon: '🥩', name: 'Thăn bò', engName: 'Raw Beef Tenderloin',
       desc: 'Phần thịt bò mềm nhất, tỉ lệ mỡ thấp, cực giàu đạm và creatine.', portionName: '100g thô', portionG: 100, cal: 142, pro: 22.3, carb: 0.0, fat: 5.4, fiber: 0.0,
       badge: '🥩 22.3g Đạm / 100g', tip: 'Cung cấp sắt heme và creatine tự nhiên tăng sức mạnh cơ bắp.'),

    _i(id: 'raw_beef_shank', category: 'Thịt & Trứng', icon: '🥩', name: 'Bắp bò', engName: 'Raw Beef Shank',
       desc: 'Thịt nạc có nhiều gân hoa giòn rụm, calo vừa phải, giàu kẽm.', portionName: '100g thô', portionG: 100, cal: 130, pro: 21.5, carb: 0.0, fat: 4.2, fiber: 0.0,
       badge: '🥩 130 kcal / 100g', tip: 'Lựa chọn nạc tuyệt vời cho chế độ ăn kiểm soát calo.'),

    _i(id: 'raw_beef_brisket', category: 'Thịt & Trứng', icon: '🥩', name: 'Ba chỉ bò', engName: 'Raw Beef Plate / Brisket',
       desc: 'Thịt xen kẽ các dải mỡ ngậy béo, nhiều calo.', portionName: '100g thô', portionG: 100, cal: 260, pro: 17.0, carb: 0.0, fat: 21.0, fiber: 0.0,
       badge: '🥩 260 kcal / 100g', tip: 'Phù hợp giai đoạn xả cơ (bulking) hoặc chế độ keto.'),

    _i(id: 'raw_beef_flank', category: 'Thịt & Trứng', icon: '🥩', name: 'Gầu bò', engName: 'Raw Beef Flank',
       desc: 'Miếng thịt có mỡ giòn viền ngoài, thơm đậm mùi bò.', portionName: '100g thô', portionG: 100, cal: 251, pro: 17.5, carb: 0.0, fat: 20.0, fiber: 0.0,
       badge: '🥩 251 kcal / 100g', tip: 'Chứa nhiều năng lượng và khoáng chất kẽm.'),

    _i(id: 'raw_beef_chuck', category: 'Thịt & Trứng', icon: '🥩', name: 'Nạc vai bò', engName: 'Raw Beef Chuck',
       desc: 'Thịt nạc vai cân đối, đạm cao mỡ vừa.', portionName: '100g thô', portionG: 100, cal: 165, pro: 20.5, carb: 0.0, fat: 8.5, fiber: 0.0,
       badge: '🥩 165 kcal / 100g', tip: 'Cân bằng hoàn hảo giữa đạm và năng lượng.'),

    _i(id: 'raw_pork_tenderloin', category: 'Thịt & Trứng', icon: '🥩', name: 'Thăn heo', engName: 'Raw Pork Tenderloin',
       desc: 'Phần nạc mềm nhất của heo, calo và chất béo thấp ngang ức gà.', portionName: '100g thô', portionG: 100, cal: 139, pro: 21.1, carb: 0.0, fat: 5.5, fiber: 0.0,
       badge: '🥩 21.1g Đạm / 100g', tip: 'Lựa chọn thịt heo siết mỡ số 1 cho người tập gym.'),

    _i(id: 'raw_pork_belly', category: 'Thịt & Trứng', icon: '🥩', name: 'Ba chỉ heo', engName: 'Raw Pork Belly',
       desc: 'Thịt ba chỉ 3 lớp mỡ nạc đan xen, năng lượng dồi dào.', portionName: '100g thô', portionG: 100, cal: 297, pro: 16.5, carb: 0.0, fat: 25.5, fiber: 0.0,
       badge: '🥩 297 kcal / 100g', tip: 'Cần cân đối khẩu phần khi ăn trong chế độ giảm cân.'),

    _i(id: 'raw_pork_shoulder', category: 'Thịt & Trứng', icon: '🥩', name: 'Nạc vai heo', engName: 'Raw Pork Shoulder',
       desc: 'Thịt vai mềm có chút vân mỡ mỏng không bị khô.', portionName: '100g thô', portionG: 100, cal: 176, pro: 19.0, carb: 0.0, fat: 11.0, fiber: 0.0,
       badge: '🥩 176 kcal / 100g', tip: 'Nguồn đạm phổ biến và giàu vitamin B1.'),

    _i(id: 'raw_pork_ribs', category: 'Thịt & Trứng', icon: '🥩', name: 'Sườn heo', engName: 'Raw Pork Spare Ribs',
       desc: 'Sườn heo gồm thịt nạc dính xương và sụn non.', portionName: '100g thô', portionG: 100, cal: 242, pro: 17.2, carb: 0.0, fat: 18.8, fiber: 0.0,
       badge: '🥩 242 kcal / 100g', tip: 'Giàu canxi và phospho tự nhiên.'),

    _i(id: 'raw_pork_minced', category: 'Thịt & Trứng', icon: '🥩', name: 'Thịt băm heo', engName: 'Raw Ground Pork',
       desc: 'Thịt nạc heo xay nhuyễn tiêu chuẩn.', portionName: '100g thô', portionG: 100, cal: 240, pro: 17.0, carb: 0.0, fat: 19.0, fiber: 0.0,
       badge: '🥩 240 kcal / 100g', tip: 'Dễ dàng định lượng chính xác theo gram.'),

    _i(id: 'raw_pork_leg', category: 'Thịt & Trứng', icon: '🥩', name: 'Nạc mông heo', engName: 'Raw Pork Leg/Ham',
       desc: 'Thịt nạc chắc, ít mỡ, đạm cao.', portionName: '100g thô', portionG: 100, cal: 145, pro: 20.8, carb: 0.0, fat: 6.2, fiber: 0.0,
       badge: '🥩 145 kcal / 100g', tip: 'Lựa chọn kinh tế và nạc cho bữa ăn hàng ngày.'),

    _i(id: 'raw_egg_whole', category: 'Thịt & Trứng', icon: '🥚', name: 'Trứng gà', engName: 'Whole Raw Egg',
       desc: 'Trứng gà nguyên quả chuẩn, tỉ lệ hấp thu protein BV 100.', portionName: '1 quả (~55g)', portionG: 55, cal: 143, pro: 12.6, carb: 0.8, fat: 9.5, fiber: 0.0,
       badge: '🥚 ~78 kcal / quả', tip: 'Siêu thực phẩm tự nhiên với đầy đủ axit amin thiết yếu.'),

    _i(id: 'raw_egg_white', category: 'Thịt & Trứng', icon: '🥚', name: 'Lòng trắng trứng', engName: 'Raw Egg White',
       desc: '100% đạm albumin tinh khiết, hoàn toàn không chứa chất béo.', portionName: '1 lòng trắng (~33g)', portionG: 33, cal: 52, pro: 10.9, carb: 0.7, fat: 0.2, fiber: 0.0,
       badge: '🥚 ~17 kcal / lòng trắng', tip: 'Nguồn đạm tinh khiết bậc nhất để siết calo tối đa.'),

    _i(id: 'raw_egg_yolk', category: 'Thịt & Trứng', icon: '🥚', name: 'Lòng đỏ trứng', engName: 'Raw Egg Yolk',
       desc: 'Chứa choline nuôi não bộ, lutein sáng mắt và vitamin tan trong dầu.', portionName: '1 lòng đỏ (~18g)', portionG: 18, cal: 322, pro: 15.9, carb: 3.6, fat: 26.5, fiber: 0.0,
       badge: '🥚 ~55 kcal / lòng đỏ', tip: 'Giàu choline và vi chất dinh dưỡng quý giá.'),

    _i(id: 'raw_egg_quail', category: 'Thịt & Trứng', icon: '🥚', name: 'Trứng cút', engName: 'Raw Quail Egg',
       desc: 'Hàm lượng vitamin A, B và sắt cao hơn tỷ lệ ở trứng gà.', portionName: '1 quả (~10g)', portionG: 10, cal: 158, pro: 13.0, carb: 0.4, fat: 11.1, fiber: 0.0,
       badge: '🥚 ~16 kcal / quả', tip: 'Nạp vi chất dinh dưỡng đậm đặc.'),

    _i(id: 'raw_egg_duck', category: 'Thịt & Trứng', icon: '🥚', name: 'Trứng vịt', engName: 'Raw Duck Egg',
       desc: 'Trứng vịt to hơn trứng gà, vị béo ngậy và nhiều đạm.', portionName: '1 quả (~70g)', portionG: 70, cal: 185, pro: 13.0, carb: 1.5, fat: 14.2, fiber: 0.0,
       badge: '🥚 ~130 kcal / quả', tip: 'Cung cấp lượng axit béo và năng lượng dồi dào.'),

    // 2. THỦY HẢI SẢN
    _i(id: 'raw_salmon', category: 'Thủy hải sản', icon: '🐟', name: 'Cá hồi', engName: 'Raw Salmon',
       desc: 'Cá hồi thịt cam đậm, kho tàng Axit béo Omega-3 EPA & DHA.', portionName: '100g thô', portionG: 100, cal: 208, pro: 20.4, carb: 0.0, fat: 13.4, fiber: 0.0,
       badge: '🐟 Giàu Omega-3', tip: 'Axit béo lành mạnh bảo vệ tim mạch và phục hồi khớp.'),

    _i(id: 'raw_basa', category: 'Thủy hải sản', icon: '🐟', name: 'Cá basa', engName: 'Raw Basa Fish',
       desc: 'Thịt cá trắng mềm ngọt, đạm sạch dễ hấp thu, calo vừa phải.', portionName: '100g thô', portionG: 100, cal: 124, pro: 17.5, carb: 0.0, fat: 5.8, fiber: 0.0,
       badge: '🐟 124 kcal / 100g', tip: 'Thực phẩm đạm kinh tế và dễ tìm.'),

    _i(id: 'raw_tuna', category: 'Thủy hải sản', icon: '🐟', name: 'Cá ngừ', engName: 'Raw Tuna',
       desc: 'Thịt đỏ săn chắc, đạm siêu cao lên tới 28g/100g, cực ít mỡ.', portionName: '100g thô', portionG: 100, cal: 130, pro: 28.0, carb: 0.0, fat: 1.0, fiber: 0.0,
       badge: '💪 28g Đạm / 100g', tip: 'Hàm lượng đạm nạc top đầu thế giới thủy hải sản.'),

    _i(id: 'raw_tilapia', category: 'Thủy hải sản', icon: '🐟', name: 'Cá rô phi', engName: 'Raw Tilapia',
       desc: 'Cá thịt trắng nạc, ít tanh, không béo.', portionName: '100g thô', portionG: 100, cal: 96, pro: 20.1, carb: 0.0, fat: 1.7, fiber: 0.0,
       badge: '🐟 Chỉ 96 kcal / 100g', tip: 'Nguồn đạm nạc tinh khiết tuyệt vời.'),

    _i(id: 'raw_mackerel', category: 'Thủy hải sản', icon: '🐟', name: 'Cá thu', engName: 'Raw Mackerel',
       desc: 'Cá biển thịt thơm béo, dồi dào vitamin D và Omega-3.', portionName: '100g thô', portionG: 100, cal: 205, pro: 18.6, carb: 0.0, fat: 13.9, fiber: 0.0,
       badge: '🐟 Giàu Vitamin D', tip: 'Tăng cường hấp thu canxi và hỗ trợ miễn dịch.'),

    _i(id: 'raw_snakehead', category: 'Thủy hải sản', icon: '🐟', name: 'Cá lóc (cá quả)', engName: 'Raw Snakehead Fish',
       desc: 'Cá nước ngọt lành tính, vị ngọt tự nhiên, nhiều đạm ít mỡ.', portionName: '100g thô', portionG: 100, cal: 97, pro: 18.2, carb: 0.0, fat: 2.7, fiber: 0.0,
       badge: '🐟 97 kcal / 100g', tip: 'Hỗ trợ hồi phục sức khỏe và làm lành vết thương.'),

    _i(id: 'raw_shrimp', category: 'Thủy hải sản', icon: '🦐', name: 'Tôm', engName: 'Raw Shrimp',
       desc: 'Tôm thịt chắc giòn, đạm cao, cực ít calo và chất béo.', portionName: '100g thô', portionG: 100, cal: 85, pro: 18.4, carb: 0.9, fat: 0.9, fiber: 0.0,
       badge: '🦐 Chỉ 85 kcal / 100g', tip: 'Cung cấp astaxanthin chống oxy hóa mạnh mẽ.'),

    _i(id: 'raw_squid', category: 'Thủy hải sản', icon: '🦑', name: 'Mực', engName: 'Raw Squid',
       desc: 'Mực thịt dày giòn ngọt, giàu đồng, kẽm và protein nạc.', portionName: '100g thô', portionG: 100, cal: 92, pro: 15.6, carb: 3.1, fat: 1.4, fiber: 0.0,
       badge: '🦑 92 kcal / 100g', tip: 'Tốt cho việc siết cân mà không gây ngán.'),

    _i(id: 'raw_octopus', category: 'Thủy hải sản', icon: '🐙', name: 'Bạch tuộc', engName: 'Raw Octopus',
       desc: 'Bạch tuộc thịt săn chắc, chứa nhiều vitamin B12 và sắt.', portionName: '100g thô', portionG: 100, cal: 82, pro: 14.9, carb: 2.2, fat: 1.0, fiber: 0.0,
       badge: '🐙 82 kcal / 100g', tip: 'Thực phẩm giàu vi chất và rất ít calo.'),

    _i(id: 'raw_crab', category: 'Thủy hải sản', icon: '🦀', name: 'Cua biển', engName: 'Raw Sea Crab',
       desc: 'Thịt cua thơm ngọt, giàu đạm và canxi tự nhiên.', portionName: '100g thô', portionG: 100, cal: 87, pro: 18.1, carb: 0.4, fat: 1.1, fiber: 0.0,
       badge: '🦀 18.1g Đạm / 100g', tip: 'Bổ sung canxi và khoáng chất biển.'),

    _i(id: 'raw_clam', category: 'Thủy hải sản', icon: '🦪', name: 'Ngao (nghêu)', engName: 'Raw Clam',
       desc: 'Giàu sắt gấp nhiều lần thịt bò, cực kỳ bổ máu và ít calo.', portionName: '100g thô', portionG: 100, cal: 74, pro: 12.8, carb: 2.6, fat: 1.0, fiber: 0.0,
       badge: '🦪 Siêu Giàu Sắt', tip: 'Hỗ trợ tăng sinh hồng cầu và thể lực.'),

    // 3. RAU CỦ
    _i(id: 'raw_broccoli', category: 'Rau củ', icon: '🥦', name: 'Bông cải xanh', engName: 'Raw Broccoli',
       desc: 'Giàu sulforaphane chống viêm, chất xơ và vitamin C.', portionName: '100g thô', portionG: 100, cal: 34, pro: 2.8, carb: 6.6, fat: 0.4, fiber: 2.6,
       badge: '🥦 Top 1 Rau Thể Thao', tip: 'Giúp no lâu và thải độc gan.'),

    _i(id: 'raw_cauliflower', category: 'Rau củ', icon: '🥦', name: 'Súp lơ trắng', engName: 'Raw Cauliflower',
       desc: 'Vị ngọt thanh, calo cực thấp, thay thế tinh bột rất tốt.', portionName: '100g thô', portionG: 100, cal: 25, pro: 1.9, carb: 5.0, fat: 0.3, fiber: 2.0,
       badge: '🥦 25 kcal / 100g', tip: 'Lựa chọn hàng đầu để làm giả cơm.'),

    _i(id: 'raw_spinach', category: 'Rau củ', icon: '🥬', name: 'Cải bó xôi', engName: 'Raw Spinach',
       desc: 'Rau bina giàu sắt, magie, canxi và chất chống oxy hóa lutein.', portionName: '100g thô', portionG: 100, cal: 23, pro: 2.9, carb: 3.6, fat: 0.4, fiber: 2.2,
       badge: '🌿 23 kcal / 100g', tip: 'Tăng cường cơ bắp và bảo vệ mắt.'),

    _i(id: 'raw_bok_choy', category: 'Rau củ', icon: '🥬', name: 'Cải thìa', engName: 'Raw Bok Choy',
       desc: 'Cải thìa mọng nước, thanh mát, hầu như không có calo.', portionName: '100g thô', portionG: 100, cal: 13, pro: 1.5, carb: 2.2, fat: 0.2, fiber: 1.0,
       badge: '🥬 13 kcal / 100g', tip: 'Giúp no bụng mà không làm tăng calo.'),

    _i(id: 'raw_choy_sum', category: 'Rau củ', icon: '🥬', name: 'Cải ngọt', engName: 'Raw Choy Sum',
       desc: 'Rau cải ngọt quen thuộc, giàu vitamin A và vitamin C.', portionName: '100g thô', portionG: 100, cal: 16, pro: 1.7, carb: 2.1, fat: 0.2, fiber: 1.2,
       badge: '🥬 16 kcal / 100g', tip: 'Bổ sung chất xơ hòa tan hỗ trợ tiêu hóa.'),

    _i(id: 'raw_water_spinach', category: 'Rau củ', icon: '🥬', name: 'Rau muống', engName: 'Raw Water Spinach',
       desc: 'Rau muống xanh thanh mát, giàu chất xơ và sắt.', portionName: '100g thô', portionG: 100, cal: 19, pro: 3.2, carb: 2.1, fat: 0.4, fiber: 2.1,
       badge: '🌿 19 kcal / 100g', tip: 'Thực phẩm quen thuộc thanh nhiệt cơ thể.'),

    _i(id: 'raw_cabbage', category: 'Rau củ', icon: '🥬', name: 'Bắp cải', engName: 'Raw Green Cabbage',
       desc: 'Bắp cải xanh giòn ngọt, giàu glutamine bảo vệ niêm mạc dạ dày.', portionName: '100g thô', portionG: 100, cal: 25, pro: 1.3, carb: 5.8, fat: 0.1, fiber: 2.5,
       badge: '🥬 25 kcal / 100g', tip: 'Chất xơ dồi dào tạo cảm giác no dai dẳng.'),

    _i(id: 'raw_red_cabbage', category: 'Rau củ', icon: '🥬', name: 'Bắp cải tím', engName: 'Raw Red Cabbage',
       desc: 'Màu tím đặc trưng từ anthocyanin chống lão hóa cực mạnh.', portionName: '100g thô', portionG: 100, cal: 31, pro: 1.4, carb: 7.4, fat: 0.2, fiber: 2.1,
       badge: '💜 Giàu Anthocyanin', tip: 'Tăng đề kháng và làm đẹp da.'),

    _i(id: 'raw_carrot', category: 'Rau củ', icon: '🥕', name: 'Cà rốt', engName: 'Raw Carrot',
       desc: 'Nguồn cung cấp beta-carotene tiền vitamin A dồi dào.', portionName: '100g thô', portionG: 100, cal: 41, pro: 0.9, carb: 9.6, fat: 0.2, fiber: 2.8,
       badge: '🥕 41 kcal / 100g', tip: 'Hỗ trợ thị lực và miễn dịch.'),

    _i(id: 'raw_tomato', category: 'Rau củ', icon: '🍅', name: 'Cà chua', engName: 'Raw Tomato',
       desc: 'Giàu chất chống oxy hóa lycopene, vitamin C và kali.', portionName: '100g thô', portionG: 100, cal: 18, pro: 0.9, carb: 3.9, fat: 0.2, fiber: 1.2,
       badge: '🍅 18 kcal / 100g', tip: 'Lycopene bảo vệ tim mạch và làn da.'),

    _i(id: 'raw_cucumber', category: 'Rau củ', icon: '🥒', name: 'Dưa chuột', engName: 'Raw Cucumber',
       desc: 'Chứa tới 95% là nước, thanh nhiệt và bù khoáng cấp tốc.', portionName: '100g thô', portionG: 100, cal: 15, pro: 0.7, carb: 3.6, fat: 0.1, fiber: 0.5,
       badge: '🥒 15 kcal / 100g', tip: 'Thực phẩm ăn vặt không lo tăng cân.'),

    _i(id: 'raw_bell_pepper', category: 'Rau củ', icon: '🫑', name: 'Ớt chuông', engName: 'Raw Bell Pepper',
       desc: 'Lượng vitamin C cao gấp 3 lần quả cam, hỗ trợ đốt mỡ.', portionName: '100g thô', portionG: 100, cal: 26, pro: 1.0, carb: 6.0, fat: 0.3, fiber: 2.1,
       badge: '🫑 Gấp 3 Lần Vitamin C', tip: 'Thúc đẩy quá trình trao đổi chất.'),

    _i(id: 'raw_king_oyster_mushroom', category: 'Rau củ', icon: '🍄', name: 'Nấm đùi gà', engName: 'Raw King Oyster Mushroom',
       desc: 'Thịt nấm dày ngọt như thịt gà, giàu beta-glucan tăng đề kháng.', portionName: '100g thô', portionG: 100, cal: 35, pro: 3.3, carb: 5.0, fat: 0.5, fiber: 2.3,
       badge: '🍄 3.3g Đạm / 100g', tip: 'Nguồn đạm nấm thực vật thơm ngon.'),

    _i(id: 'raw_enoki_mushroom', category: 'Rau củ', icon: '🍄', name: 'Nấm kim châm', engName: 'Raw Enoki Mushroom',
       desc: 'Sợi nấm giòn ngọt, chứa nhiều axit amin thiết yếu.', portionName: '100g thô', portionG: 100, cal: 37, pro: 2.7, carb: 7.8, fat: 0.3, fiber: 2.7,
       badge: '🍄 37 kcal / 100g', tip: 'Bổ sung chất xơ và tăng miễn dịch.'),

    _i(id: 'raw_shiitake_mushroom', category: 'Rau củ', icon: '🍄', name: 'Nấm hương', engName: 'Raw Shiitake Mushroom',
       desc: 'Hương thơm đặc trưng, giàu lentinan bảo vệ tế bào.', portionName: '100g thô', portionG: 100, cal: 34, pro: 2.2, carb: 6.8, fat: 0.5, fiber: 2.5,
       badge: '🍄 34 kcal / 100g', tip: 'Giúp tăng cường hệ miễn dịch tự nhiên.'),

    _i(id: 'raw_onion', category: 'Rau củ', icon: '🧅', name: 'Hành tây', engName: 'Raw Onion',
       desc: 'Chứa quercetin chống viêm và hỗ trợ hạ đường huyết.', portionName: '100g thô', portionG: 100, cal: 40, pro: 1.1, carb: 9.3, fat: 0.1, fiber: 1.7,
       badge: '🧅 40 kcal / 100g', tip: 'Tạo vị ngọt tự nhiên cho mọi món ăn.'),

    _i(id: 'raw_zucchini', category: 'Rau củ', icon: '🥒', name: 'Bí ngòi', engName: 'Raw Zucchini',
       desc: 'Calo cực thấp, nhiều nước và chất xơ hòa tan.', portionName: '100g thô', portionG: 100, cal: 17, pro: 1.2, carb: 3.1, fat: 0.3, fiber: 1.0,
       badge: '🥒 17 kcal / 100g', tip: 'Tuyệt vời cho chế độ ăn keto và thâm hụt calo.'),

    _i(id: 'raw_pumpkin', category: 'Rau củ', icon: '🎃', name: 'Bí đỏ', engName: 'Raw Pumpkin',
       desc: 'Bí đỏ giàu tinh bột chậm, kali và vitamin A.', portionName: '100g thô', portionG: 100, cal: 26, pro: 1.0, carb: 6.5, fat: 0.1, fiber: 0.5,
       badge: '🎃 26 kcal / 100g', tip: 'Nguồn carb sạch ít calo thay thế cơm.'),

    _i(id: 'raw_asparagus', category: 'Rau củ', icon: '🌱', name: 'Măng tây', engName: 'Raw Asparagus',
       desc: 'Giàu folate và asparagine hỗ trợ đào thải muối thừa, giảm tích nước.', portionName: '100g thô', portionG: 100, cal: 20, pro: 2.2, carb: 3.9, fat: 0.1, fiber: 2.1,
       badge: '🌱 Thải Muối & Nước', tip: 'Thực phẩm quen thuộc của các VĐV siết cơ.'),

    _i(id: 'raw_lettuce', category: 'Rau củ', icon: '🥗', name: 'Xà lách', engName: 'Raw Lettuce',
       desc: 'Lá xà lách tươi giòn, cung cấp nước và khoáng chất.', portionName: '100g thô', portionG: 100, cal: 15, pro: 1.4, carb: 2.9, fat: 0.2, fiber: 1.3,
       badge: '🥗 15 kcal / 100g', tip: 'Thực phẩm nền tảng cho các món salad.'),

    _i(id: 'raw_celery', category: 'Rau củ', icon: '🥬', name: 'Cần tây', engName: 'Raw Celery',
       desc: 'Chứa apigenin giúp thư giãn mạch máu và thanh lọc độc tố.', portionName: '100g thô', portionG: 100, cal: 16, pro: 0.7, carb: 3.0, fat: 0.2, fiber: 1.6,
       badge: '🌿 16 kcal / 100g', tip: 'Hỗ trợ kiểm soát huyết áp và giảm viêm.'),

    _i(id: 'raw_bean_sprout', category: 'Rau củ', icon: '🌱', name: 'Giá đỗ', engName: 'Raw Bean Sprouts',
       desc: 'Mầm đậu xanh giàu vitamin E, canxi và enzyme sống.', portionName: '100g thô', portionG: 100, cal: 30, pro: 3.0, carb: 5.0, fat: 0.2, fiber: 1.8,
       badge: '🌱 30 kcal / 100g', tip: 'Bổ sung enzyme hỗ trợ quá trình tiêu hóa.'),

    // 4. TRÁI CÂY
    _i(id: 'raw_banana', category: 'Trái cây', icon: '🍌', name: 'Chuối', engName: 'Raw Banana',
       desc: 'Giàu carbohydrate hấp thu nhanh và kali chống chuột rút cơ bắp.', portionName: '1 quả (~100g)', portionG: 100, cal: 89, pro: 1.1, carb: 22.8, fat: 0.3, fiber: 2.6,
       badge: '🍌 89 kcal / quả', tip: 'Nạp năng lượng tối ưu trước buổi tập 30 phút.'),

    _i(id: 'raw_apple', category: 'Trái cây', icon: '🍎', name: 'Táo', engName: 'Raw Apple',
       desc: 'Giàu chất xơ pectin hòa tan giúp no lâu và ổn định đường huyết.', portionName: '1 quả (~150g)', portionG: 150, cal: 52, pro: 0.3, carb: 13.8, fat: 0.2, fiber: 2.4,
       badge: '🍎 78 kcal / quả', tip: 'Bữa phụ kinh điển cho chế độ giảm mỡ.'),

    _i(id: 'raw_avocado', category: 'Trái cây', icon: '🥑', name: 'Bơ', engName: 'Raw Avocado',
       desc: 'Trái cây dồi dào chất béo không bão hòa đơn tốt cho tim và khớp.', portionName: '100g thô', portionG: 100, cal: 160, pro: 2.0, carb: 8.5, fat: 14.7, fiber: 6.7,
       badge: '🥑 Giàu Chất Béo Tốt', tip: 'Giàu chất béo lành mạnh và chất xơ hòa tan.'),

    _i(id: 'raw_watermelon', category: 'Trái cây', icon: '🍉', name: 'Dưa hấu', engName: 'Raw Watermelon',
       desc: 'Chứa 92% nước, giàu citrulline giúp giãn nở mạch máu và giảm đau cơ.', portionName: '1 miếng (~150g)', portionG: 150, cal: 30, pro: 0.6, carb: 7.6, fat: 0.2, fiber: 0.4,
       badge: '🍉 45 kcal / miếng', tip: 'Giải khát tức thì và bù nước sau tập luyện.'),

    _i(id: 'raw_guava', category: 'Trái cây', icon: '🍐', name: 'Ổi', engName: 'Raw Guava',
       desc: 'Lượng vitamin C gấp 4 lần quả cam, chất xơ cao, đường thấp.', portionName: '1 quả (~150g)', portionG: 150, cal: 68, pro: 2.6, carb: 14.3, fat: 1.0, fiber: 5.4,
       badge: '🍐 Vua Vitamin C & Xơ', tip: 'Hỗ trợ siết mỡ bụng và kiểm soát đường huyết.'),

    _i(id: 'raw_orange', category: 'Trái cây', icon: '🍊', name: 'Cam', engName: 'Raw Orange',
       desc: 'Giàu vitamin C tự nhiên, flavonoid và kali.', portionName: '1 quả (~150g)', portionG: 150, cal: 47, pro: 0.9, carb: 11.8, fat: 0.1, fiber: 2.4,
       badge: '🍊 70 kcal / quả', tip: 'Tăng cường sức đề kháng và phục hồi.'),

    _i(id: 'raw_strawberry', category: 'Trái cây', icon: '🍓', name: 'Dâu tây', engName: 'Raw Strawberry',
       desc: 'Cực kỳ ít đường, giàu chất chống oxy hóa anthocyanin.', portionName: '100g thô', portionG: 100, cal: 32, pro: 0.7, carb: 7.7, fat: 0.3, fiber: 2.0,
       badge: '🍓 32 kcal / 100g', tip: 'Món tráng miệng ít calo hoàn hảo.'),

    _i(id: 'raw_dragonfruit', category: 'Trái cây', icon: '🐉', name: 'Thanh long', engName: 'Raw Dragon Fruit',
       desc: 'Mát lành, hạt thanh long chứa nhiều chất béo omega-3 tự nhiên.', portionName: '100g thô', portionG: 100, cal: 60, pro: 1.2, carb: 13.0, fat: 0.6, fiber: 2.9,
       badge: '🐉 60 kcal / 100g', tip: 'Chất xơ tự nhiên hỗ trợ nhuận tràng.'),

    _i(id: 'raw_mango', category: 'Trái cây', icon: '🥭', name: 'Xoài', engName: 'Raw Mango',
       desc: 'Vị ngọt thơm đậm đà, giàu vitamin A và polyphenol.', portionName: '100g thô', portionG: 100, cal: 60, pro: 0.8, carb: 15.0, fat: 0.4, fiber: 1.6,
       badge: '🥭 60 kcal / 100g', tip: 'Cung cấp năng lượng tự nhiên nhanh chóng.'),

    _i(id: 'raw_grape', category: 'Trái cây', icon: '🍇', name: 'Nho', engName: 'Raw Grape',
       desc: 'Chứa resveratrol chống oxy hóa và bảo vệ tim mạch.', portionName: '100g thô', portionG: 100, cal: 67, pro: 0.6, carb: 17.2, fat: 0.4, fiber: 0.9,
       badge: '🍇 67 kcal / 100g', tip: 'Bổ sung đường đơn lành mạnh từ tự nhiên.'),

    _i(id: 'raw_kiwi', category: 'Trái cây', icon: '🥝', name: 'Kiwi', engName: 'Raw Kiwi',
       desc: 'Chứa enzyme actinidin phân giải protein giúp tiêu hóa nhanh.', portionName: '1 quả (~75g)', portionG: 75, cal: 61, pro: 1.1, carb: 14.7, fat: 0.5, fiber: 3.0,
       badge: '🥝 45 kcal / quả', tip: 'Hỗ trợ tiêu hóa tối đa bữa ăn nhiều đạm.'),

    _i(id: 'raw_pineapple', category: 'Trái cây', icon: '🍍', name: 'Dứa (thơm)', engName: 'Raw Pineapple',
       desc: 'Giàu enzyme bromelain chống viêm và phân cắt protein.', portionName: '100g thô', portionG: 100, cal: 50, pro: 0.5, carb: 13.1, fat: 0.1, fiber: 1.4,
       badge: '🍍 50 kcal / 100g', tip: 'Hỗ trợ hấp thụ thịt và giảm đau nhức cơ bắp.'),

    _i(id: 'raw_pomelo', category: 'Trái cây', icon: '🍈', name: 'Bưởi', engName: 'Raw Pomelo',
       desc: 'Chứa naringenin hỗ trợ kích hoạt thụ thể đốt mỡ trong gan.', portionName: '100g thô', portionG: 100, cal: 42, pro: 0.8, carb: 10.7, fat: 0.1, fiber: 1.0,
       badge: '🍈 42 kcal / 100g', tip: 'Trái cây vàng cho người muốn giảm béo bụng.'),

    _i(id: 'raw_pear', category: 'Trái cây', icon: '🍐', name: 'Lê', engName: 'Raw Pear',
       desc: 'Vị thanh mát mọng nước, giàu chất xơ hòa tan.', portionName: '1 quả (~150g)', portionG: 150, cal: 57, pro: 0.4, carb: 15.2, fat: 0.1, fiber: 3.1,
       badge: '🍐 85 kcal / quả', tip: 'Làm dịu cổ họng và hỗ trợ đường ruột.'),

    // 5. GẠO & TINH BỘT THÔ
    _i(id: 'raw_white_rice', category: 'Gạo & Tinh bột', icon: '🍚', name: 'Gạo trắng', engName: 'Raw White Rice (Dry Grain)',
       desc: 'Hạt gạo thô nguyên chất, nguồn carb chính cung cấp năng lượng sạch.', portionName: '100g thô', portionG: 100, cal: 365, pro: 7.1, carb: 80.0, fat: 0.7, fiber: 1.3,
       badge: '🍚 365 kcal / 100g thô', tip: 'Nguồn năng lượng cơ bản cho cơ bắp hoạt động.'),

    _i(id: 'raw_brown_rice', category: 'Gạo & Tinh bột', icon: '🌾', name: 'Gạo lứt', engName: 'Raw Brown Rice (Dry Grain)',
       desc: 'Gạo còn nguyên lớp cám, giàu vitamin B, magie và chất xơ.', portionName: '100g thô', portionG: 100, cal: 370, pro: 7.9, carb: 77.2, fat: 2.9, fiber: 3.5,
       badge: '🌾 Carb Chậm & Giàu Xơ', tip: 'Chỉ số GI thấp, giải phóng năng lượng từ từ.'),

    _i(id: 'raw_rolled_oats', category: 'Gạo & Tinh bột', icon: '🥣', name: 'Yến mạch', engName: 'Raw Rolled Oats',
       desc: 'Chứa beta-glucan làm giảm cholesterol máu, đạm thực vật cao.', portionName: '100g thô', portionG: 100, cal: 389, pro: 16.9, carb: 66.3, fat: 6.9, fiber: 10.6,
       badge: '🥣 16.9g Đạm / 100g', tip: 'Carb chậm số 1 cho bữa sáng gymer.'),

    _i(id: 'raw_sweet_potato', category: 'Gạo & Tinh bột', icon: '🍠', name: 'Khoai lang', engName: 'Raw Sweet Potato',
       desc: 'Củ thô giàu tinh bột kháng, chất xơ và tiền vitamin A.', portionName: '1 củ (~150g)', portionG: 150, cal: 86, pro: 1.6, carb: 20.1, fat: 0.1, fiber: 3.0,
       badge: '🍠 86 kcal / 100g thô', tip: 'Carb phức chất lượng cao hỗ trợ siết cơ giảm mỡ.'),

    _i(id: 'raw_potato', category: 'Gạo & Tinh bột', icon: '🥔', name: 'Khoai tây', engName: 'Raw Potato',
       desc: 'Củ thô giàu kali hơn cả chuối, tinh bột dễ tiêu hóa.', portionName: '1 củ (~150g)', portionG: 150, cal: 77, pro: 2.0, carb: 17.5, fat: 0.1, fiber: 2.2,
       badge: '🥔 Chỉ số no rất cao', tip: 'Giúp no lâu và bổ sung kali cho cơ bắp.'),

    _i(id: 'raw_sweet_corn', category: 'Gạo & Tinh bột', icon: '🌽', name: 'Bắp ngọt (ngô)', engName: 'Raw Sweet Corn',
       desc: 'Hạt ngô thô mọng sữa, giàu lutein, zeaxanthin và chất xơ.', portionName: '100g thô', portionG: 100, cal: 86, pro: 3.2, carb: 19.0, fat: 1.2, fiber: 2.0,
       badge: '🌽 86 kcal / 100g thô', tip: 'Nguồn carb ngọt thanh tự nhiên.'),

    _i(id: 'raw_taro', category: 'Gạo & Tinh bột', icon: '🥔', name: 'Khoai môn', engName: 'Raw Taro',
       desc: 'Củ thô giàu chất xơ và kháng tinh bột, calo thấp.', portionName: '100g thô', portionG: 100, cal: 112, pro: 1.5, carb: 26.5, fat: 0.2, fiber: 4.1,
       badge: '🥔 112 kcal / 100g thô', tip: 'Carb no lâu và thơm bùi.'),

    _i(id: 'raw_black_bean', category: 'Gạo & Tinh bột', icon: '🫘', name: 'Đậu đen', engName: 'Raw Black Beans (Dry)',
       desc: 'Hạt đậu đen khô, giàu anthocyanin, đạm thực vật và molypden.', portionName: '100g thô', portionG: 100, cal: 341, pro: 21.6, carb: 62.4, fat: 1.4, fiber: 15.2,
       badge: '🫘 21.6g Đạm / 100g thô', tip: 'Nguồn đạm và chất xơ thực vật khổng lồ.'),

    _i(id: 'raw_green_bean', category: 'Gạo & Tinh bột', icon: '🫘', name: 'Đậu xanh', engName: 'Raw Mung Beans (Dry)',
       desc: 'Hạt đậu xanh khô thanh nhiệt, giải độc và giàu khoáng chất.', portionName: '100g thô', portionG: 100, cal: 347, pro: 23.9, carb: 62.6, fat: 1.2, fiber: 16.3,
       badge: '🫘 23.9g Đạm / 100g thô', tip: 'Cực giàu đạm và vitamin nhóm B.'),

    _i(id: 'raw_red_bean', category: 'Gạo & Tinh bột', icon: '🫘', name: 'Đậu đỏ', engName: 'Raw Red Kidney Beans (Dry)',
       desc: 'Hạt đậu đỏ khô giàu chất sắt, magie và protein thực vật nạc.', portionName: '100g thô', portionG: 100, cal: 329, pro: 19.9, carb: 61.3, fat: 0.8, fiber: 15.2,
       badge: '🫘 19.9g Đạm / 100g thô', tip: 'Hỗ trợ bổ máu và phát triển cơ bắp.'),

    // 6. ĐẬU & HẠT
    _i(id: 'raw_tofu', category: 'Đậu & Hạt', icon: '🧈', name: 'Đậu phụ', engName: 'Raw Fresh Tofu',
       desc: 'Đậu hũ thô trắng mềm, nguồn đạm đậu nành lành tính không cholesterol.', portionName: '1 miếng (~150g)', portionG: 150, cal: 76, pro: 8.1, carb: 1.9, fat: 4.8, fiber: 0.3,
       badge: '🧈 8.1g Đạm / 100g', tip: 'Thực phẩm đạm nền tảng cho người ăn chay.'),

    _i(id: 'raw_almond', category: 'Đậu & Hạt', icon: '🥜', name: 'Hạnh nhân', engName: 'Raw Almonds',
       desc: 'Hạt hạnh nhân thô giàu vitamin E, magie và chất béo không bão hòa đơn.', portionName: '1 nắm (~30g)', portionG: 30, cal: 579, pro: 21.2, carb: 21.6, fat: 49.9, fiber: 12.5,
       badge: '🥜 Giàu Vitamin E & Magie', tip: 'Bảo vệ màng tế bào và phục hồi cơ thể.'),

    _i(id: 'raw_walnut', category: 'Đậu & Hạt', icon: '🥜', name: 'Hạt óc chó', engName: 'Raw Walnuts',
       desc: 'Vua của các loại hạt về hàm lượng Omega-3 thực vật (ALA).', portionName: '1 nắm (~30g)', portionG: 30, cal: 654, pro: 15.2, carb: 13.7, fat: 65.2, fiber: 6.7,
       badge: '🧠 Siêu Thực Phẩm Não Bộ', tip: 'Cải thiện trí nhớ và điều hòa huyết áp.'),

    _i(id: 'raw_cashew', category: 'Đậu & Hạt', icon: '🥜', name: 'Hạt điều', engName: 'Raw Cashews',
       desc: 'Vị ngọt bùi tự nhiên, dồi dào kẽm, magie và sắt.', portionName: '1 nắm (~30g)', portionG: 30, cal: 553, pro: 18.2, carb: 30.2, fat: 43.8, fiber: 3.3,
       badge: '🥜 18.2g Đạm / 100g', tip: 'Giúp xương khớp chắc khỏe.'),

    _i(id: 'raw_peanut', category: 'Đậu & Hạt', icon: '🥜', name: 'Hạt lạc (đậu phộng)', engName: 'Raw Peanuts',
       desc: 'Hạt lạc thô giàu đạm bậc nhất trong các loại đậu hạt, kèm niacin B3.', portionName: '1 nắm (~30g)', portionG: 30, cal: 567, pro: 25.8, carb: 16.1, fat: 49.2, fiber: 8.5,
       badge: '🥜 25.8g Đạm / 100g', tip: 'Nguồn năng lượng bền bỉ giá trị cao.'),

    _i(id: 'raw_chia_seed', category: 'Đậu & Hạt', icon: '🌱', name: 'Hạt chia', engName: 'Raw Chia Seeds',
       desc: 'Hạt chia thô nở gấp 10 lần trong nước, kho tàng Omega-3 và chất xơ hòa tan.', portionName: '1 muỗng (~15g)', portionG: 15, cal: 486, pro: 16.5, carb: 42.1, fat: 30.7, fiber: 34.4,
       badge: '🌱 34.4g Xơ / 100g', tip: 'Tạo cảm giác no lâu và thanh lọc đường ruột.'),

    // 7. SỮA & SỮA CHUA
    _i(id: 'raw_yogurt_plain', category: 'Sữa & Sữa chua', icon: '🥛', name: 'Sữa chua không đường', engName: 'Plain Unsweetened Yogurt',
       desc: 'Sữa chua lên men tự nhiên, giàu lợi khuẩn Probiotics, không đường.', portionName: '1 hộp (100g)', portionG: 100, cal: 61, pro: 3.5, carb: 4.8, fat: 3.1, fiber: 0.0,
       badge: '🥛 61 kcal / hộp', tip: 'Lựa chọn tốt nhất cho siết calo và đường ruột.'),

    _i(id: 'raw_yogurt_sweet', category: 'Sữa & Sữa chua', icon: '🥛', name: 'Sữa chua có đường', engName: 'Sweetened Yogurt',
       desc: 'Sữa chua vị ngọt dịu thơm mát, bổ sung năng lượng nhanh.', portionName: '1 hộp (100g)', portionG: 100, cal: 105, pro: 3.0, carb: 15.5, fat: 3.0, fiber: 0.0,
       badge: '🥛 105 kcal / hộp', tip: 'Nạp carb nhanh trước giờ tập luyện.'),

    _i(id: 'raw_yogurt_greek', category: 'Sữa & Sữa chua', icon: '🥣', name: 'Sữa chua Hy Lạp', engName: 'Greek Yogurt Plain',
       desc: 'Lọc bỏ váng sữa, lượng đạm gấp 3 lần sữa chua thường, đặc quánh tự nhiên.', portionName: '100g', portionG: 100, cal: 97, pro: 10.0, carb: 3.6, fat: 5.0, fiber: 0.0,
       badge: '💪 10g Đạm / 100g', tip: 'Thực phẩm vàng xây dựng cơ bắp nạc.'),

    _i(id: 'raw_milk_unsweetened', category: 'Sữa & Sữa chua', icon: '🥛', name: 'Sữa tươi không đường', engName: 'Fresh Milk Unsweetened',
       desc: 'Sữa bò tươi nguyên chất 100%, giàu canxi và đạm tự nhiên cân bằng.', portionName: '1 ly (200ml)', portionG: 200, cal: 62, pro: 3.2, carb: 4.7, fat: 3.5, fiber: 0.0,
       badge: '🥛 62 kcal / 100ml', tip: 'Dễ dàng kết hợp yến mạch hoặc trái cây.'),

    _i(id: 'raw_soy_milk', category: 'Sữa & Sữa chua', icon: '🥛', name: 'Sữa đậu nành', engName: 'Pure Soy Milk',
       desc: 'Sữa từ hạt đậu nành nguyên chất, không đường, giàu isoflavone.', portionName: '1 ly (200ml)', portionG: 200, cal: 54, pro: 3.1, carb: 5.5, fat: 1.8, fiber: 0.5,
       badge: '🌱 Đạm Thực Vật', tip: 'Phù hợp cho người ăn chay hoặc không dung nạp lactose.'),
  ];
}

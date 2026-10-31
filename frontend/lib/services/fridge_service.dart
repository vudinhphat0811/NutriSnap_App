import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/fridge_item_model.dart';
import 'app_state_service.dart';

/// Dịch vụ quản lý Tủ Lạnh Thông Minh (Smart Fridge & Pantry)
class FridgeService extends ChangeNotifier {
  static final FridgeService instance = FridgeService._internal();

  FridgeService._internal();

  /// Key lưu trữ SharedPreferences được cá nhân hoá theo từng tài khoản
  String get _storageKey {
    final email = AppStateService.instance.userProfile.email.trim().toLowerCase();
    if (email.isNotEmpty) {
      final safeKey = email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      return 'nutrisnap_fridge_items_$safeKey';
    }
    return 'nutrisnap_fridge_items_guest';
  }

  static const String _legacyStorageKey = 'nutrisnap_fridge_items_v1';
  final List<FridgeItemModel> _items = [];
  bool _initialized = false;

  List<FridgeItemModel> get items => List.unmodifiable(_items);

  /// Khi chuyển đổi tài khoản hoặc đăng xuất, tải lại tủ lạnh của tài khoản mới
  Future<void> reloadForCurrentUser() async {
    _initialized = false;
    _items.clear();
    await init();
  }

  /// Số lượng thực phẩm cần chú ý (quá hạn hoặc sắp hết hạn trong <= 2 ngày)
  int get expiringCount {
    return _items.where((item) => item.isExpired || item.isExpiringToday || item.isExpiringSoon).length;
  }

  /// Danh sách thực phẩm sắp hết hạn và đã quá hạn (được xếp ưu tiên lên đầu)
  List<FridgeItemModel> get expiringItems {
    final list = _items.where((item) => item.isExpired || item.isExpiringToday || item.isExpiringSoon).toList();
    list.sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));
    return list;
  }

  /// Khởi tạo dữ liệu từ SharedPreferences theo tài khoản hiện tại
  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      String? rawJson = prefs.getString(_storageKey);

      // Nếu tài khoản mới chưa có key riêng, thử migrate từ legacy key nếu có
      if (rawJson == null && prefs.containsKey(_legacyStorageKey)) {
        rawJson = prefs.getString(_legacyStorageKey);
      }

      if (rawJson != null && rawJson.isNotEmpty) {
        final List decoded = jsonDecode(rawJson);
        _items.clear();
        for (var itemMap in decoded) {
          try {
            _items.add(FridgeItemModel.fromJson(Map<String, dynamic>.from(itemMap)));
          } catch (e) {
            debugPrint('[FridgeService] Error parsing item: $e');
          }
        }
      } else {
        // Nạp sẵn một số đồ mẫu siêu thị thực tế để người dùng trải nghiệm ngay
        _seedSampleItems();
        await _save();
      }
      _initialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[FridgeService] Init error: $e');
    }
  }

  /// Thêm 1 thực phẩm vào tủ lạnh
  Future<void> addItem(FridgeItemModel item) async {
    _items.removeWhere((i) => i.id == item.id);
    _items.insert(0, item);
    await _save();
    notifyListeners();
  }

  /// Thêm danh sách nhiều thực phẩm (vd khi quét AI nhiều nguyên liệu)
  Future<void> addItems(List<FridgeItemModel> newItems) async {
    for (var item in newItems) {
      _items.removeWhere((i) => i.id == item.id);
      _items.insert(0, item);
    }
    await _save();
    notifyListeners();
  }

  /// Cập nhật thông tin thực phẩm
  Future<void> updateItem(FridgeItemModel item) async {
    final index = _items.indexWhere((i) => i.id == item.id);
    if (index != -1) {
      _items[index] = item;
      await _save();
      notifyListeners();
    }
  }

  /// Xóa thực phẩm khỏi tủ lạnh
  Future<void> deleteItem(String id) async {
    _items.removeWhere((i) => i.id == id);
    await _save();
    notifyListeners();
  }

  /// Đã dùng món: Xóa khỏi tủ lạnh và tùy chọn ghi nhận calo vào Nhật Ký Ăn Uống
  Future<void> consumeItem(
    String id, {
    bool logToMealJournal = true,
    String mealType = 'lunch',
    double? consumedGrams,
  }) async {
    final item = _items.firstWhere((i) => i.id == id, orElse: () => throw Exception('Không tìm thấy thực phẩm'));
    final grams = consumedGrams ?? item.netWeightG;

    if (logToMealJournal && grams > 0) {
      final factor = grams / 100.0;
      final calo = (item.caloriesPer100g * factor).round();
      final pro = (item.proteinPer100g * factor);
      final carb = (item.carbsPer100g * factor);
      final fat = (item.fatPer100g * factor);

      // Ghi nhận vào AppStateService
      AppStateService.instance.addCustomEntry(
        mealType: mealType.toUpperCase(),
        title: '${item.categoryIcon} ${item.name} (${grams.toInt()}g)',
        calories: calo > 0 ? calo : 150,
        protein: pro.toInt(),
        carbs: carb.toInt(),
        fat: fat.toInt(),
      );
    }

    _items.removeWhere((i) => i.id == id);
    await _save();
    notifyListeners();
  }

  /// Lọc danh sách thực phẩm theo vị trí hoặc trạng thái
  List<FridgeItemModel> getFilteredItems({
    String? storageLocation, // 'all', 'fridge', 'freezer', 'pantry'
    bool expiringOnly = false,
    String searchQuery = '',
  }) {
    var result = List<FridgeItemModel>.from(_items);

    if (storageLocation != null && storageLocation != 'all') {
      result = result.where((i) => i.storageLocation == storageLocation).toList();
    }

    if (expiringOnly) {
      result = result.where((i) => i.isExpired || i.isExpiringToday || i.isExpiringSoon).toList();
    }

    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      result = result.where((i) =>
        i.name.toLowerCase().contains(q) ||
        i.category.toLowerCase().contains(q)
      ).toList();
    }

    // Sắp xếp: Đồ sắp hết hạn hoặc đã quá hạn xếp lên trước
    result.sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));
    return result;
  }

  /// Gợi ý Hạn sử dụng tiêu chuẩn theo loại thực phẩm (Smart Shelf-Life Preset)
  int getSuggestedShelfLifeDays(String name, {String category = '', String storageLocation = 'fridge'}) {
    if (storageLocation == 'freezer') return 60; // Ngăn đông: 2 tháng
    if (storageLocation == 'pantry') return 180; // Tủ khô: 6 tháng

    final lower = '$name $category'.toLowerCase();

    // Rau ăn lá
    if (lower.contains('rau') || lower.contains('cải') || lower.contains('muống') ||
        lower.contains('xà lách') || lower.contains('mồng tơi') || lower.contains('ngót') ||
        lower.contains('hành lá') || lower.contains('ngò') || lower.contains('spinach')) {
      return 3;
    }

    // Củ quả cứng
    if (lower.contains('cà rốt') || lower.contains('khoai') || lower.contains('bí') ||
        lower.contains('củ cải') || lower.contains('hành tây') || lower.contains('tỏi')) {
      return 12;
    }

    // Quả vỏ mềm
    if (lower.contains('cà chua') || lower.contains('bơ') || lower.contains('chuối') ||
        lower.contains('dâu') || lower.contains('nho') || lower.contains('dưa leo')) {
      return 4;
    }

    // Trái cây vỏ dày / tươi lâu
    if (lower.contains('táo') || lower.contains('cam') || lower.contains('quýt') ||
        lower.contains('lê') || lower.contains('bưởi') || lower.contains('dưa hấu')) {
      return 8;
    }

    // Thịt tươi
    if (lower.contains('thịt') || lower.contains('heo') || lower.contains('bò') ||
        lower.contains('gà') || lower.contains('vịt') || lower.contains('pork') || lower.contains('beef')) {
      return 2;
    }

    // Cá & Hải sản tươi
    if (lower.contains('cá') || lower.contains('tôm') || lower.contains('mực') ||
        lower.contains('salmon') || lower.contains('fish') || lower.contains('seafood')) {
      return 2;
    }

    // Sữa tươi & Sữa chua
    if (lower.contains('sữa') || lower.contains('yogurt') || lower.contains('milk')) {
      return 5;
    }

    // Trứng
    if (lower.contains('trứng') || lower.contains('egg')) {
      return 21;
    }

    return 4; // Mặc định 4 ngày trong ngăn mát
  }

  /// Trích xuất ngày sản xuất và hạn sử dụng từ chuỗi văn bản (Tầng 1 Regex OCR)
  Map<String, DateTime?> parseDatesFromText(String rawText) {
    DateTime? nsx;
    DateTime? hsd;

    // Pattern bắt ngày: dd/mm/yyyy, dd-mm-yyyy, dd.mm.yy, yyyy-mm-dd
    final datePattern = r'(\d{1,2}[-/. ]\d{1,2}[-/. ]\d{2,4}|\d{4}[-/. ]\d{1,2}[-/. ]\d{1,2})';

    // Regex NSX
    final nsxRegex = RegExp(r'(?:NSX|MFG|NĐG|PROD|Ngày\s*SX|Ngày\s*ĐG)[\s.:]*' + datePattern, caseSensitive: false);
    final nsxMatch = nsxRegex.firstMatch(rawText);
    if (nsxMatch != null && nsxMatch.groupCount >= 1) {
      nsx = _tryParseDateString(nsxMatch.group(1));
    }

    // Regex HSD
    final hsdRegex = RegExp(r'(?:HSD|EXP|BBE|BB|USE\s*BY|Hạn\s*Dùng|Sử\s*Dụng\s*Trước)[\s.:]*' + datePattern, caseSensitive: false);
    final hsdMatch = hsdRegex.firstMatch(rawText);
    if (hsdMatch != null && hsdMatch.groupCount >= 1) {
      hsd = _tryParseDateString(hsdMatch.group(1));
    }

    // Nếu không có tiền tố NSX/HSD nhưng có 2 dòng ngày đứng cạnh nhau (thường ở đáy lon)
    if (hsd == null && nsx == null) {
      final allDateMatches = RegExp(datePattern).allMatches(rawText).toList();
      if (allDateMatches.length >= 2) {
        nsx = _tryParseDateString(allDateMatches[0].group(0));
        hsd = _tryParseDateString(allDateMatches[1].group(0));
      } else if (allDateMatches.length == 1) {
        hsd = _tryParseDateString(allDateMatches[0].group(0));
      }
    }

    return {'nsx': nsx, 'hsd': hsd};
  }

  DateTime? _tryParseDateString(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final clean = text.trim().replaceAll(RegExp(r'[^0-9\-/.]'), '');
    final parts = clean.split(RegExp(r'[-/.]'));
    if (parts.length != 3) return null;

    try {
      int day = 0, month = 0, year = 0;
      if (parts[0].length == 4) {
        // YYYY-MM-DD
        year = int.parse(parts[0]);
        month = int.parse(parts[1]);
        day = int.parse(parts[2]);
      } else {
        // DD-MM-YYYY hoặc DD-MM-YY
        day = int.parse(parts[0]);
        month = int.parse(parts[1]);
        year = int.parse(parts[2]);
        if (year < 100) year += 2000;
      }
      if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return DateTime(year, month, day);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listMap = _items.map((i) => i.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(listMap));
    } catch (e) {
      debugPrint('[FridgeService] Save error: $e');
    }
  }

  void _seedSampleItems() {
    final now = DateTime.now();
    _items.addAll([
      FridgeItemModel(
        id: 'seed_1',
        name: 'Thịt ba chỉ heo',
        category: 'Thịt & Trứng',
        categoryIcon: '🥩',
        quantity: '400g',
        netWeightG: 400,
        storageLocation: 'fridge',
        manufacturingDate: now.subtract(const Duration(days: 1)),
        expirationDate: now.add(const Duration(days: 1)), // Hết hạn ngày mai -> Cảnh báo vàng
        addedAt: now.subtract(const Duration(days: 1)),
        caloriesPer100g: 260,
        proteinPer100g: 16.5,
        carbsPer100g: 0.0,
        fatPer100g: 21.5,
        notes: 'Khay tem cân siêu thị WinMart',
      ),
      FridgeItemModel(
        id: 'seed_2',
        name: 'Cá hồi tươi phi lê',
        category: 'Hải sản',
        categoryIcon: '🐟',
        quantity: '300g',
        netWeightG: 300,
        storageLocation: 'fridge',
        manufacturingDate: now,
        expirationDate: now.add(const Duration(days: 2)), // Còn 2 ngày
        addedAt: now,
        caloriesPer100g: 208,
        proteinPer100g: 20.4,
        carbsPer100g: 0.0,
        fatPer100g: 13.4,
        notes: 'Co.opmart phi lê tươi',
      ),
      FridgeItemModel(
        id: 'seed_3',
        name: 'Cà chua bi tươi',
        category: 'Rau củ',
        categoryIcon: '🍅',
        quantity: '500g',
        netWeightG: 500,
        storageLocation: 'fridge',
        manufacturingDate: now.subtract(const Duration(days: 2)),
        expirationDate: now.add(const Duration(days: 3)), // Còn 3 ngày
        addedAt: now.subtract(const Duration(days: 2)),
        caloriesPer100g: 18,
        proteinPer100g: 0.9,
        carbsPer100g: 3.9,
        fatPer100g: 0.2,
        notes: 'Rau VietGAP',
      ),
      FridgeItemModel(
        id: 'seed_4',
        name: 'Sữa chua không đường Vinamilk',
        category: 'Sữa & Bơ',
        categoryIcon: '🥛',
        quantity: '4 hộp',
        netWeightG: 400,
        storageLocation: 'fridge',
        manufacturingDate: now.subtract(const Duration(days: 10)),
        expirationDate: now.add(const Duration(days: 14)), // Tươi lâu
        addedAt: now.subtract(const Duration(days: 2)),
        caloriesPer100g: 61,
        proteinPer100g: 3.7,
        carbsPer100g: 4.8,
        fatPer100g: 3.1,
        notes: 'Lốc 4 hộp',
      ),
    ]);
  }
}

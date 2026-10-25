import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../models/barcode_product_model.dart';
import '../models/ingredient_cut_model.dart';
import '../services/app_state_service.dart';
import '../services/ingredient_cut_service.dart';
import '../widgets/barcode_scanner_sheet.dart';

/// Màn hình Tính & Đo Calo Nguyên Liệu Thô (Sống, chưa nấu nướng)
/// Bố cục chuẩn chia làm 2 phần:
/// - PHẦN TRÊN: Tìm kiếm & Chọn nguyên liệu thô theo danh mục
/// - PHẦN DƯỚI: Danh sách các nguyên liệu đã chọn (có nút tăng giảm gram) + Tổng Calo & Macros cố định
class IngredientMacroCalculatorScreen extends StatefulWidget {
  final IngredientCutModel? initialCut;

  const IngredientMacroCalculatorScreen({super.key, this.initialCut});

  @override
  State<IngredientMacroCalculatorScreen> createState() => _IngredientMacroCalculatorScreenState();
}

class _IngredientMacroCalculatorScreenState extends State<IngredientMacroCalculatorScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<IngredientCutModel> _allCuts = [];
  List<IngredientCutModel> _filteredCuts = [];
  String _selectedCategory = 'Tất cả';
  bool _isInfoBannerExpanded = false;

  // Chế độ chọn: false = Nguyên liệu thô (sống), true = Nguyên liệu đã chín (sau nấu)
  bool _isCookedMode = false;

  // Map lưu trữ trọng lượng gram đã chọn: Map<cutId, weightInGrams>
  final Map<String, double> _selectedWeights = {};

  // Lưu xem món đó người dùng thêm theo dạng Đã Chín (true) hay Thô (false)
  final Map<String, bool> _itemAddedAsCooked = {};

  // Tra cứu nhanh đối tượng theo ID
  final Map<String, IngredientCutModel> _cutsMap = {};

  // Sản phẩm vừa quét từ mã vạch
  BarcodeProductModel? _lastScannedProduct;

  final List<String> _categories = [
    'Tất cả',
    'Thịt & Trứng',
    'Thủy hải sản',
    'Rau củ',
    'Trái cây',
    'Gạo & Tinh bột',
    'Đậu & Hạt',
    'Sữa & Sữa chua',
  ];

  @override
  void initState() {
    super.initState();
    _loadCutsInstant();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadCutsInstant() {
    final list = IngredientCutService.getAllCuts();
    _allCuts = list;
    _cutsMap.clear();
    for (final c in list) {
      _cutsMap[c.id] = c;
    }

    if (widget.initialCut != null) {
      final init = widget.initialCut!;
      _selectedWeights[init.id] = init.defaultPortionWeightG > 0 ? init.defaultPortionWeightG : 100.0;
    }

    _applyFilters();
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    List<IngredientCutModel> result = _allCuts;

    // Lọc theo danh mục
    if (_selectedCategory != 'Tất cả') {
      result = result.where((c) =>
        c.category.toLowerCase().contains(_selectedCategory.toLowerCase()) ||
        _selectedCategory.toLowerCase().contains(c.category.toLowerCase())
      ).toList();
    }

    // Lọc theo từ khóa tìm kiếm (hỗ trợ cả tên thô lẫn tên món chín)
    if (query.isNotEmpty) {
      result = result.where((c) =>
        c.name.toLowerCase().contains(query) ||
        c.cookedDisplayName.toLowerCase().contains(query) ||
        c.cookedName.toLowerCase().contains(query) ||
        c.englishName.toLowerCase().contains(query) ||
        c.category.toLowerCase().contains(query)
      ).toList();
    }

    setState(() {
      _filteredCuts = result;
    });
  }

  void _onCategorySelected(String cat) {
    if (_selectedCategory == cat) return;
    setState(() {
      _selectedCategory = cat;
    });
    _applyFilters();
  }

  void _addItem(IngredientCutModel cut, {double step = 50.0}) {
    HapticFeedback.lightImpact();
    setState(() {
      final current = _selectedWeights[cut.id] ?? 0.0;
      if (current == 0) {
        _itemAddedAsCooked[cut.id] = _isCookedMode;
        _selectedWeights[cut.id] = cut.defaultPortionWeightG > 0 ? cut.defaultPortionWeightG : 100.0;
      } else {
        _selectedWeights[cut.id] = current + step;
      }
    });
  }

  void _decreaseItem(IngredientCutModel cut, {double step = 50.0}) {
    HapticFeedback.lightImpact();
    setState(() {
      final current = _selectedWeights[cut.id] ?? 0.0;
      if (current <= step) {
        _selectedWeights.remove(cut.id);
        _itemAddedAsCooked.remove(cut.id);
      } else {
        _selectedWeights[cut.id] = current - step;
      }
    });
  }

  void _removeItem(String cutId) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectedWeights.remove(cutId);
      _itemAddedAsCooked.remove(cutId);
    });
  }

  void _clearSelection() {
    if (_selectedWeights.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa giỏ nguyên liệu?'),
        content: const Text('Bạn có chắc muốn xóa tất cả nguyên liệu đã chọn không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedWeights.clear();
                _itemAddedAsCooked.clear();
              });
              Navigator.pop(ctx);
            },
            child: const Text('Xóa hết', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// Mở hộp thoại nhập trọng lượng với hỗ trợ chuyển đổi Thô <-> Chín và Ước lượng dân dã
  void _openWeightEditDialog(IngredientCutModel cut) {
    final isAlreadyCooked = _itemAddedAsCooked[cut.id] ?? _isCookedMode;
    final currentWeight = (_selectedWeights[cut.id] ?? cut.defaultPortionWeightG).round();

    // activeMode: 0 = Cân lúc Thô (Sống), 1 = Cân lúc Đã Chín
    int activeMode = isAlreadyCooked ? 1 : 0;
    final controller = TextEditingController(text: currentWeight.toString());

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final currentInputVal = double.tryParse(controller.text.trim()) ?? 0.0;

          // Tính toán quy đổi theo chế độ hiện tại
          double rawG = activeMode == 0 ? currentInputVal : cut.calculateRawWeightFromCooked(currentInputVal);
          double cookedG = activeMode == 0 ? cut.calculateCookedWeight(currentInputVal) : currentInputVal;
          if (rawG < 0) rawG = 0;
          if (cookedG < 0) cookedG = 0;

          // Macros theo rawG
          final ratio = rawG / 100.0;
          final cal = (cut.caloriesPer100g * ratio).round();
          final pro = (cut.proteinPer100g * ratio).toStringAsFixed(1);
          final carb = (cut.carbsPer100g * ratio).toStringAsFixed(1);
          final fat = (cut.fatPer100g * ratio).toStringAsFixed(1);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            titlePadding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            title: Row(
              children: [
                Text(cut.categoryIcon, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cut.name,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        cut.englishName,
                        style: const TextStyle(fontSize: 10.5, color: AppColors.textGray),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Chuyển đổi chế độ: Cân Thô vs Cân Chín
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              if (activeMode != 0) {
                                setDialogState(() {
                                  activeMode = 0;
                                  controller.text = rawG.round().toString();
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: activeMode == 0 ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: activeMode == 0
                                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  'Cân lúc Thô (Sống)',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: activeMode == 0 ? FontWeight.bold : FontWeight.w500,
                                    color: activeMode == 0 ? AppColors.primary : AppColors.textGray,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              if (activeMode != 1) {
                                setDialogState(() {
                                  activeMode = 1;
                                  controller.text = cookedG.round().toString();
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: activeMode == 1 ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: activeMode == 1
                                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  'Cân lúc Đã Chín',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: activeMode == 1 ? FontWeight.bold : FontWeight.w500,
                                    color: activeMode == 1 ? AppColors.primary : AppColors.textGray,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 2. Ô nhập số gram
                  Text(
                    activeMode == 0
                        ? 'Khối lượng nguyên liệu thô (sống):'
                        : 'Khối lượng thức ăn chín trên đĩa:',
                    style: const TextStyle(fontSize: 12, color: AppColors.textGray, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: false,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      suffixText: 'g',
                      prefixIcon: Icon(
                        activeMode == 0 ? Icons.scale_rounded : Icons.restaurant_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 3. Khung Preview Quy Đổi Thông Minh & Calo tức thì
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              activeMode == 0 ? Icons.trending_up_rounded : Icons.cached_rounded,
                              size: 14,
                              color: const Color(0xFF16A34A),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                activeMode == 0
                                    ? (cut.cookingYieldRatio > 1.05
                                        ? 'Nở thành: ~${cookedG.round()}g ${cut.cookedName} (x${cut.cookingYieldRatio})'
                                        : (cut.cookingYieldRatio < 0.95
                                            ? 'Sau nấu ngót còn: ~${cookedG.round()}g ${cut.cookedName} (teo ${((1 - cut.cookingYieldRatio) * 100).round()}%)'
                                            : 'Thành phẩm sau nấu: ~${cookedG.round()}g'))
                                    : 'Tương đương: ~${rawG.round()}g nguyên liệu thô (sống)',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF15803D),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '🔥 $cal kcal  •  P: ${pro}g  •  C: ${carb}g  •  F: ${fat}g',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 4. Ước lượng dân dã quen thuộc (Household Portions)
                  const Text('Ước lượng dân dã quen thuộc:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: cut.householdPortions.map((hp) {
                      return InkWell(
                        onTap: () {
                          setDialogState(() {
                            if (activeMode == 0) {
                              controller.text = hp.weightG.round().toString();
                            } else {
                              controller.text = cut.calculateCookedWeight(hp.weightG).round().toString();
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Text(
                            hp.label,
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 10),

                  // 5. Khối lượng gram chọn nhanh
                  const Text('Chọn nhanh gram:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [50, 100, 150, 200, 300].map((g) {
                      return InkWell(
                        onTap: () {
                          setDialogState(() {
                            controller.text = g.toString();
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Text(
                            '$g g',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedWeights.remove(cut.id);
                    _itemAddedAsCooked.remove(cut.id);
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('Bỏ chọn', style: TextStyle(color: Colors.red)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  final inputVal = double.tryParse(controller.text.trim()) ?? 0.0;
                  if (inputVal > 0) {
                    setState(() {
                      _selectedWeights[cut.id] = inputVal;
                      _itemAddedAsCooked[cut.id] = (activeMode == 1);
                    });
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('Xác nhận'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Quét mã vạch siêu thị
  Future<void> _openBarcodeScanner() async {
    final product = await BarcodeScannerSheet.show(context);
    if (product == null || !mounted) return;

    setState(() {
      _lastScannedProduct = product;
      final scannedCut = product.toIngredientCutModel();
      _allCuts.removeWhere((c) => c.id == scannedCut.id);
      _allCuts.insert(0, scannedCut);
      _cutsMap[scannedCut.id] = scannedCut;
      _selectedWeights[scannedCut.id] = product.netWeightG > 0 ? product.netWeightG : 100.0;
      _applyFilters();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã nhận diện "${product.productName}" và thêm vào giỏ!'),
          backgroundColor: const Color(0xFF16A34A),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Tính toán tổng Calo và Macros các nguyên liệu đã chọn
  ({
    int calories,
    double protein,
    double carbs,
    double fat,
    double totalWeight,
    double totalCookedWeight,
    int itemCount,
  }) _computeTotals() {
    double totalCal = 0;
    double totalPro = 0;
    double totalCarb = 0;
    double totalFat = 0;
    double totalWeight = 0;
    double totalCookedWeight = 0;
    int count = 0;

    for (final entry in _selectedWeights.entries) {
      final cut = _cutsMap[entry.key];
      final weight = entry.value;
      if (cut != null && weight > 0) {
        final isCooked = _itemAddedAsCooked[entry.key] == true;
        double rawG;
        double cookedG;
        if (isCooked) {
          cookedG = weight;
          rawG = cut.calculateRawWeightFromCooked(weight);
        } else {
          rawG = weight;
          cookedG = cut.calculateCookedWeight(weight);
        }

        final ratio = rawG / 100.0;
        totalCal += cut.caloriesPer100g * ratio;
        totalPro += cut.proteinPer100g * ratio;
        totalCarb += cut.carbsPer100g * ratio;
        totalFat += cut.fatPer100g * ratio;
        totalWeight += rawG;
        totalCookedWeight += cookedG;
        count++;
      }
    }

    return (
      calories: totalCal.round(),
      protein: totalPro,
      carbs: totalCarb,
      fat: totalFat,
      totalWeight: totalWeight,
      totalCookedWeight: totalCookedWeight,
      itemCount: count,
    );
  }

  /// Chi tiết toàn diện dinh dưỡng & Mẹo bảo toàn dưỡng chất khi nấu
  void _showCutDetailSheet(IngredientCutModel cut) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isSelected = (_selectedWeights[cut.id] ?? 0) > 0;
        final cooked100g = cut.calculateCookedWeight(100).round();

        final proCal = cut.proteinPer100g * 4.0;
        final carbCal = cut.carbsPer100g * 4.0;
        final fatCal = cut.fatPer100g * 9.0;
        final totalMacroCal = (proCal + carbCal + fatCal) <= 0 ? 1.0 : (proCal + carbCal + fatCal);

        final proPct = ((proCal / totalMacroCal) * 100).round();
        final carbPct = ((carbCal / totalMacroCal) * 100).round();
        final fatPct = (100 - proPct - carbPct).clamp(0, 100);

        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thanh kéo
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Header
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _getCategoryColor(cut.category).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(cut.categoryIcon, style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cut.name,
                            style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                          ),
                          Text(
                            cut.englishName,
                            style: const TextStyle(fontSize: 11, color: AppColors.textGray),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textGray),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // 1. Thẻ Quy đổi Thô <-> Chín Trực quan
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.sync_alt_rounded, size: 16, color: AppColors.primary),
                              SizedBox(width: 6),
                              Text(
                                'QUY ĐỔI THÔ ⇄ CHÍN',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: cut.cookingYieldRatio > 1.05
                                  ? const Color(0xFFFEF3C7)
                                  : (cut.cookingYieldRatio < 0.95 ? const Color(0xFFFEE2E2) : const Color(0xFFE0F2FE)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              cut.cookingYieldSummary,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: cut.cookingYieldRatio > 1.05
                                    ? const Color(0xFFB45309)
                                    : (cut.cookingYieldRatio < 0.95 ? const Color(0xFFB91C1C) : const Color(0xFF0369A1)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                children: [
                                  const Text('100g Thô (Sống)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  Text('${cut.caloriesPer100g.round()} kcal', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF15803D))),
                                ],
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.textGray),
                          ),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                children: [
                                  Text('~${cooked100g}g ${cut.cookedName}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 2),
                                  const Text('Calo cốt lõi giữ nguyên', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        cut.cookingYieldRatio > 1.05
                            ? '💡 Khi nấu chín, ${cut.name.toLowerCase()} hút nước nở gấp ${cut.cookingYieldRatio} lần. Lượng calo không tăng lên mà phân bổ vào thể tích nước.'
                            : (cut.cookingYieldRatio < 0.95
                                ? '💡 Khi nấu chín, ${cut.name.toLowerCase()} bốc hơi nước và mỡ thừa khiến thịt ngót đi ~${((1 - cut.cookingYieldRatio) * 100).round()}%. Đạm và dinh dưỡng nạc hầu như giữ trọn vẹn.'
                                : '💡 Khối lượng trước và sau chế biến hầu như tương đương nhau.'),
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF475569), height: 1.35),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 2. Dinh Dưỡng 100g Chuẩn
                const Text('HÀM LƯỢNG DINH DƯỠNG (100G THÔ CHUẨN):', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildNutrientTile('Năng lượng', '${cut.caloriesPer100g.round()}', 'kcal', const Color(0xFF15803D)),
                    const SizedBox(width: 6),
                    _buildNutrientTile('Đạm (Protein)', '${cut.proteinPer100g}', 'g', const Color(0xFFEF4444)),
                    const SizedBox(width: 6),
                    _buildNutrientTile('Carb', '${cut.carbsPer100g}', 'g', const Color(0xFFD97706)),
                    const SizedBox(width: 6),
                    _buildNutrientTile('Béo (Fat)', '${cut.fatPer100g}', 'g', const Color(0xFF0284C7)),
                  ],
                ),

                const SizedBox(height: 10),

                // Phân bổ năng lượng
                Row(
                  children: [
                    const Text('Tỷ lệ Calo: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    Text('Đạm $proPct%  •  Carb $carbPct%  •  Béo $fatPct%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 6,
                    child: Row(
                      children: [
                        if (proPct > 0) Expanded(flex: proPct, child: Container(color: const Color(0xFFEF4444))),
                        if (carbPct > 0) Expanded(flex: carbPct, child: Container(color: const Color(0xFFD97706))),
                        if (fatPct > 0) Expanded(flex: fatPct, child: Container(color: const Color(0xFF0284C7))),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // 3. Mẹo Dinh Dưỡng & Chế Biến Giữ Dưỡng Chất
                if (cut.gymTip.isNotEmpty || cut.description.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lightbulb_rounded, size: 16, color: Color(0xFFD97706)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            cut.gymTip.isNotEmpty ? cut.gymTip : cut.description,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF92400E), height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // 4. Nút Chọn / Chỉnh Cân Nặng
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openWeightEditDialog(cut);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          side: const BorderSide(color: AppColors.primary),
                        ),
                        child: const Text('Tùy chỉnh gram', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          _addItem(cut);
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(isSelected ? 'Thêm +50g' : 'Chọn vào giỏ', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNutrientTile(String title, String val, String unit, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(title, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(val, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
                const SizedBox(width: 1),
                Text(unit, style: TextStyle(fontSize: 9.5, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Lưu vào nhật ký hôm nay
  void _saveToMealJournal() {
    final totals = _computeTotals();
    if (totals.calories <= 0) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Lưu Vào Nhật Ký Ăn Uống',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textGray),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calculate_rounded, color: AppColors.primary, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tổng: ${totals.calories} kcal (${totals.totalWeight.round()}g thô • ~${totals.totalCookedWeight.round()}g chín)',
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                          ),
                          Text(
                            'Đạm: ${totals.protein.round()}g • Carb: ${totals.carbs.round()}g • Béo: ${totals.fat.round()}g',
                            style: const TextStyle(fontSize: 11, color: AppColors.textGray),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Chọn bữa ăn muốn lưu:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildMealOption(ctx, 'Bữa Sáng', '☀️', totals),
                  const SizedBox(width: 8),
                  _buildMealOption(ctx, 'Bữa Trưa', '🥪', totals),
                  const SizedBox(width: 8),
                  _buildMealOption(ctx, 'Bữa Tối', '🍲', totals),
                  const SizedBox(width: 8),
                  _buildMealOption(ctx, 'Bữa Phụ', '🍎', totals),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMealOption(BuildContext ctx, String mealName, String emoji, dynamic totals) {
    return Expanded(
      child: InkWell(
        onTap: () {
          Navigator.pop(ctx);
          _confirmLogToAppState(mealName, totals);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 4),
              Text(mealName, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmLogToAppState(String mealName, dynamic totals) {
    // Tìm nguyên liệu đầu tiên để phân giải ảnh đại diện chuẩn xác nhất
    String? firstCutName;
    for (final e in _selectedWeights.entries) {
      if (e.value > 0 && _cutsMap.containsKey(e.key)) {
        firstCutName = _cutsMap[e.key]?.name;
        break;
      }
    }

    final selectedItemsDesc = _selectedWeights.entries.map((e) {
      final cut = _cutsMap[e.key];
      if (cut == null) return '';
      final isCooked = _itemAddedAsCooked[e.key] == true;
      final name = isCooked ? cut.cookedDisplayName : cut.name;
      final unit = isCooked ? 'g chín' : 'g thô';
      return '$name (${e.value.round()}$unit)';
    }).where((s) => s.isNotEmpty).join(', ');

    final title = selectedItemsDesc.isNotEmpty
        ? 'Dinh dưỡng: $selectedItemsDesc'
        : 'Khẩu phần ăn ($mealName)';

    final customImage = MealLogEntry.resolveImageForTitle(firstCutName ?? title);

    AppStateService.instance.addCustomEntry(
      mealType: mealName,
      title: title,
      calories: totals.calories as int,
      protein: (totals.protein as double).round(),
      carbs: (totals.carbs as double).round(),
      fat: (totals.fat as double).round(),
      imageUrl: customImage,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text('Đã lưu ${totals.calories} kcal vào $mealName hôm nay!')),
          ],
        ),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Color _getCategoryColor(String cat) {
    if (cat.contains('Thịt') || cat.contains('Trứng')) return const Color(0xFFEF4444);
    if (cat.contains('Thủy') || cat.contains('hải sản') || cat.contains('Hải sản')) return const Color(0xFF0284C7);
    if (cat.contains('Rau')) return const Color(0xFF10B981);
    if (cat.contains('Trái cây')) return const Color(0xFFF59E0B);
    if (cat.contains('Gạo') || cat.contains('Tinh bột')) return const Color(0xFF8B5CF6);
    if (cat.contains('Đậu') || cat.contains('Hạt')) return const Color(0xFFD97706);
    if (cat.contains('Sữa')) return const Color(0xFF06B6D4);
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final totals = _computeTotals();
    final selectedCount = totals.itemCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isCookedMode ? 'Đo Calo Thức Ăn Đã Chín' : 'Đo Calo Nguyên Liệu Thô',
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.bold,
                color: AppColors.textBlack,
              ),
            ),
            Text(
              _isCookedMode
                  ? 'Chuẩn 100g sau nấu (cơm, áp chảo, luộc, hấp)'
                  : 'Chuẩn 100g thô (sống, chưa nấu nướng)',
              style: const TextStyle(fontSize: 11, color: AppColors.textGray),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary),
            tooltip: 'Quét mã vạch siêu thị',
            onPressed: _openBarcodeScanner,
          ),
          if (selectedCount > 0)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Color(0xFFDC2626)),
              tooltip: 'Xóa giỏ nguyên liệu',
              onPressed: _clearSelection,
            ),
        ],
      ),
      body: Column(
        children: [
          // ========================================================
          // PHẦN 1 (TRÊN): TÌM KIẾM & CHỌN NGUYÊN LIỆU (Flex 6 khi giỏ trống, 5 khi đã chọn)
          // ========================================================
          Expanded(
            flex: selectedCount == 0 ? 6 : 5,
            child: Container(
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1.0. Nút Chuyển Đổi: Nguyên Liệu Thô vs Thức Ăn Đã Chín
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                if (_isCookedMode) {
                                  setState(() {
                                    _isCookedMode = false;
                                    _applyFilters();
                                  });
                                }
                              },
                              borderRadius: BorderRadius.circular(9),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(vertical: 7),
                                decoration: BoxDecoration(
                                  color: !_isCookedMode ? AppColors.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: !_isCookedMode
                                      ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 4, offset: const Offset(0, 1))]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '🌾 Nguyên Liệu Thô',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: !_isCookedMode ? FontWeight.bold : FontWeight.w600,
                                        color: !_isCookedMode ? Colors.white : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                if (!_isCookedMode) {
                                  setState(() {
                                    _isCookedMode = true;
                                    _applyFilters();
                                  });
                                }
                              },
                              borderRadius: BorderRadius.circular(9),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(vertical: 7),
                                decoration: BoxDecoration(
                                  color: _isCookedMode ? const Color(0xFFEA580C) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: _isCookedMode
                                      ? [BoxShadow(color: const Color(0xFFEA580C).withValues(alpha: 0.25), blurRadius: 4, offset: const Offset(0, 1))]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '🍳 Thức Ăn Đã Chín',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: _isCookedMode ? FontWeight.bold : FontWeight.w600,
                                        color: _isCookedMode ? Colors.white : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 1.1. Thanh tìm kiếm
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => _applyFilters(),
                      decoration: InputDecoration(
                        hintText: _isCookedMode
                            ? 'Tìm món đã chín... (vd: cơm trắng, ức gà áp chảo, khoai hấp)'
                            : 'Tìm nguyên liệu thô... (vd: đùi gà, gạo, cà chua)',
                        hintStyle: const TextStyle(fontSize: 12.5, color: AppColors.textGray),
                        prefixIcon: Icon(
                          _isCookedMode ? Icons.restaurant_menu_rounded : Icons.search_rounded,
                          size: 20,
                          color: _isCookedMode ? const Color(0xFFEA580C) : AppColors.primary,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  _applyFilters();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),

                  // 1.2. Danh mục nguyên liệu thô (Scroll ngang)
                  SizedBox(
                    height: 32,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      physics: const BouncingScrollPhysics(),
                      itemCount: _categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        final isSelected = (_selectedCategory == cat);

                        return InkWell(
                          onTap: () => _onCategorySelected(cat),
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Text(
                                cat,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? Colors.white : AppColors.textBlack,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 6),

                  // 1.25. Banner Mẹo cân đo chuẩn xác (Collapsible)
                  InkWell(
                    onTap: () => setState(() => _isInfoBannerExpanded = !_isInfoBannerExpanded),
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.lightbulb_outline_rounded, size: 15, color: Color(0xFF2563EB)),
                              const SizedBox(width: 6),
                              const Expanded(
                                child: Text(
                                  'Mẹo: Nên cân lúc thô (sống) hay lúc đã chín?',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(
                                _isInfoBannerExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                size: 16,
                                color: const Color(0xFF2563EB),
                              ),
                            ],
                          ),
                          if (_isInfoBannerExpanded) ...[
                            const SizedBox(height: 6),
                            const Text(
                              '• 🍚 Gạo thô khi nấu cơm hút nước nở gấp ~2.6 lần (100g gạo thô = 260g cơm chín, 100g cơm chín chỉ ~130 kcal do phần lớn là nước).\n• 🥩 Thịt sống khi nấu chín mất nước teo ngót ~25% (100g thịt sống = 75g thịt chín, calo cốt lõi giữ nguyên).\n• ⚖️ Cân lúc THÔ là chuẩn xác số 1 thế giới. Bạn cũng có thể bấm vào số gram bất kỳ để đổi sang "Cân lúc đã chín"!',
                              style: TextStyle(fontSize: 10.5, color: Color(0xFF1E40AF), height: 1.4),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Banner sản phẩm vừa quét mã vạch (nếu có)
                  if (_lastScannedProduct != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      color: const Color(0xFFECFDF5),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Đã nhận diện: "${_lastScannedProduct!.productName}" (${_lastScannedProduct!.netWeightG.round()}g)',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF065F46)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          InkWell(
                            onTap: () => setState(() => _lastScannedProduct = null),
                            child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF059669)),
                          ),
                        ],
                      ),
                    ),

                  // 1.3. Danh sách nguyên liệu thô để chọn
                  Expanded(
                    child: _filteredCuts.isEmpty
                            ? const Center(
                                child: Text('Không tìm thấy nguyên liệu thô phù hợp.',
                                    style: TextStyle(fontSize: 12, color: AppColors.textGray)),
                              )
                            : ListView.separated(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                                itemCount: _filteredCuts.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 6),
                                itemBuilder: (context, index) {
                                  final cut = _filteredCuts[index];
                                  final currentWeight = _selectedWeights[cut.id] ?? 0.0;
                                  final isSelected = currentWeight > 0;

                                  return _buildRawCatalogItem(cut, isSelected, currentWeight);
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),

          // THANH PHÂN CÁCH RÕ RÀNG GIỮA 2 PHẦN
          Container(
            height: 6,
            color: const Color(0xFFE2E8F0),
          ),

          // ========================================================
          // PHẦN 2 (DƯỚI): NGUYÊN LIỆU ĐÃ CHỌN & TỔNG CALO (Flex 4 khi giỏ trống, 5 khi đã chọn)
          // ========================================================
          Expanded(
            flex: selectedCount == 0 ? 4 : 5,
            child: Container(
              color: const Color(0xFFF8FAFC),
              child: Column(
                children: [
                  // 2.1. Tiêu đề phần dưới: "Nguyên liệu đã chọn" + Xóa hết
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.checklist_rounded, size: 18, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              'NGUYÊN LIỆU ĐÃ CHỌN ($selectedCount)',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF334155),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        if (selectedCount > 0)
                          InkWell(
                            onTap: _clearSelection,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Text(
                                'Xóa tất cả',
                                style: TextStyle(fontSize: 11.5, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // 2.2. Danh sách các nguyên liệu đã chọn (với Stepper chỉnh gram)
                  Expanded(
                    child: selectedCount == 0
                        ? Center(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_shopping_cart_rounded, size: 28, color: Colors.grey.shade400),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Chưa chọn nguyên liệu nào',
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                  ),
                                  const SizedBox(height: 3),
                                  const Text(
                                    'Nhấn nút [+] ở danh sách trên để thêm nguyên liệu thô.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 11, color: AppColors.textGray),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            itemCount: _selectedWeights.keys.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final cutId = _selectedWeights.keys.elementAt(index);
                              final cut = _cutsMap[cutId];
                              if (cut == null) return const SizedBox.shrink();
                              final weight = _selectedWeights[cutId] ?? 0.0;
                              final calo = ((cut.caloriesPer100g * weight) / 100.0).round();

                              return _buildSelectedItemRow(cut, weight, calo);
                            },
                          ),
                  ),

                  // 2.3. Khung Tổng Calo & Nút Lưu Nhật Ký cố định ở đáy phần dưới
                  _buildBottomTotalSummaryCard(totals),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Từng hàng trong Danh mục nguyên liệu (Phần trên - hiển thị theo Chế độ Thô hoặc Đã Chín)
  Widget _buildRawCatalogItem(IngredientCutModel cut, bool isSelected, double currentWeight) {
    final displayName = _isCookedMode ? cut.cookedDisplayName : cut.name;
    final displayCalo = _isCookedMode ? cut.caloriesPer100gCooked.round() : cut.caloriesPer100g.round();
    final displayPro = _isCookedMode ? cut.proteinPer100gCooked : cut.proteinPer100g;
    final displayCarb = _isCookedMode ? cut.carbsPer100gCooked : cut.carbsPer100g;
    final displayFat = _isCookedMode ? cut.fatPer100gCooked : cut.fatPer100g;
    final isItemCookedInCart = _itemAddedAsCooked[cut.id] == true;

    return InkWell(
      onTap: () => _showCutDetailSheet(cut),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          children: [
            // Icon phân loại nguyên liệu
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _getCategoryColor(cut.category).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(cut.categoryIcon, style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 10),

            // Tên nguyên liệu + macros + badge
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: AppColors.textBlack,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_isCookedMode)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEDD5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '🍳 Đã chín',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFC2410C)),
                          ),
                        )
                      else if (cut.cookingYieldRatio > 1.05)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Nở ${(cut.cookingYieldRatio * 100).round()}%',
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                          ),
                        )
                      else if (cut.cookingYieldRatio < 0.95)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Ngót -${((1 - cut.cookingYieldRatio) * 100).round()}%',
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFB91C1C)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_isCookedMode ? '100g chín' : '100g thô'} | P: ${displayPro}g • C: ${displayCarb}g • F: ${displayFat}g',
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Cột bên phải: Calo / 100g + Nút Thêm
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$displayCalo kcal',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: _isCookedMode ? const Color(0xFFEA580C) : const Color(0xFF15803D),
                  ),
                ),
                const SizedBox(height: 3),
                if (!isSelected)
                  InkWell(
                    onTap: () => _addItem(cut),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: _isCookedMode ? const Color(0xFFEA580C) : AppColors.primary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                          const SizedBox(width: 2),
                          Text(
                            _isCookedMode ? 'Chọn (chín)' : 'Chọn (thô)',
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  InkWell(
                    onTap: () => _addItem(cut, step: 50.0),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF16A34A)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${currentWeight.round()}g ${isItemCookedInCart ? 'chín' : 'thô'}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.add_rounded, size: 13, color: Color(0xFF15803D)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Từng hàng trong Danh sách nguyên liệu đã chọn (Phần dưới)
  Widget _buildSelectedItemRow(IngredientCutModel cut, double weight, int calo) {
    final isCooked = _itemAddedAsCooked[cut.id] == true;
    final displayName = isCooked ? cut.cookedDisplayName : cut.name;

    double rawG;
    double cookedG;
    if (isCooked) {
      cookedG = weight;
      rawG = cut.calculateRawWeightFromCooked(weight);
    } else {
      rawG = weight;
      cookedG = cut.calculateCookedWeight(weight);
    }

    final ratio = rawG / 100.0;
    final pro = (cut.proteinPer100g * ratio).toStringAsFixed(1);
    final carb = (cut.carbsPer100g * ratio).toStringAsFixed(1);
    final fat = (cut.fatPer100g * ratio).toStringAsFixed(1);

    String yieldText = '';
    if (isCooked) {
      yieldText = '🍳 Đã chín: ${cookedG.round()}g (quy đổi ~${rawG.round()}g thô)';
    } else {
      if (cut.cookingYieldRatio > 1.05) {
        yieldText = '🌾 Thô: ${rawG.round()}g (nở thành ~${cookedG.round()}g ${cut.cookedName})';
      } else if (cut.cookingYieldRatio < 0.95) {
        yieldText = '🌾 Thô: ${rawG.round()}g (sau chín còn ~${cookedG.round()}g)';
      } else {
        yieldText = '🌾 Thô: ${rawG.round()}g (sau nấu ~${cookedG.round()}g)';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Emoji tròn nhỏ (bấm xem chi tiết)
              InkWell(
                onTap: () => _showCutDetailSheet(cut),
                child: Text(cut.categoryIcon, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 8),

              // Tên + Calo theo gram đã chọn + Macros (bấm xem chi tiết)
              Expanded(
                child: InkWell(
                  onTap: () => _showCutDetailSheet(cut),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '$calo kcal',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Đạm: ${pro}g • Carb: ${carb}g • Béo: ${fat}g',
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Stepper [-] [150g chín/thô] [+]
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => _decreaseItem(cut, step: 50.0),
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                        child: Icon(Icons.remove_rounded, size: 14, color: Color(0xFF334155)),
                      ),
                    ),
                    InkWell(
                      onTap: () => _openWeightEditDialog(cut),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                        color: Colors.white,
                        child: Text(
                          '${weight.round()}g',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => _addItem(cut, step: 50.0),
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                        child: Icon(Icons.add_rounded, size: 14, color: Color(0xFF334155)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 6),

              // Nút xóa nhanh
              InkWell(
                onTap: () => _removeItem(cut.id),
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),

          // Badge độ nở / ngót thành phẩm sau chín
          Container(
            margin: const EdgeInsets.only(top: 4, left: 26),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isCooked ? const Color(0xFFFFF7ED) : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: isCooked ? const Color(0xFFFED7AA) : const Color(0xFFBBF7D0)),
            ),
            child: Text(
              yieldText,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: isCooked ? const Color(0xFFC2410C) : const Color(0xFF15803D),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Khung hiển thị Tổng Calo và Nút Lưu cố định ở đáy Phần dưới
  Widget _buildBottomTotalSummaryCard(dynamic totals) {
    final hasItems = totals.itemCount > 0;

    // Tính % Calo từng macro
    final proCal = totals.protein * 4.0;
    final carbCal = totals.carbs * 4.0;
    final fatCal = totals.fat * 9.0;
    final totalMacroCal = (proCal + carbCal + fatCal) <= 0 ? 1.0 : (proCal + carbCal + fatCal);

    final proPct = ((proCal / totalMacroCal) * 100).round();
    final carbPct = ((carbCal / totalMacroCal) * 100).round();
    final fatPct = (100 - proPct - carbPct).clamp(0, 100).toInt();

    // Gợi ý mục tiêu dinh dưỡng
    String goalHint = '🥗 Bữa ăn Cân Bằng';
    if (proPct >= 35) {
      goalHint = '💪 Bữa Siêu Đạm (Tăng cơ/Siết)';
    } else if (carbPct >= 55) {
      goalHint = '⚡ Nạp Năng Lượng (Trước tập)';
    } else if (fatPct >= 45) {
      goalHint = '🥑 Bữa Low-Carb / Keto';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dòng 1: TỔNG CALO VÀ KHỐI LƯỢNG THÔ & THÀNH PHẨM CHÍN
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Text(
                      'TỔNG CALO: ',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                    ),
                    Flexible(
                      child: Text(
                        '${totals.calories} kcal',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF15803D),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${totals.totalWeight.round()}g thô (${totals.itemCount} món)',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (totals.totalCookedWeight > 0)
                      Text(
                        'Thành phẩm: ~${totals.totalCookedWeight.round()}g chín',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF0D9488)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Dòng 2: Badges 3 Macro (Đạm, Carb, Béo)
          Row(
            children: [
              _buildMacroPill('Đạm', totals.protein, const Color(0xFFEF4444)),
              const SizedBox(width: 6),
              _buildMacroPill('Carb', totals.carbs, const Color(0xFFD97706)),
              const SizedBox(width: 6),
              _buildMacroPill('Béo', totals.fat, const Color(0xFF0284C7)),
            ],
          ),

          if (hasItems) ...[
            const SizedBox(height: 6),

            // Dòng 2.5: Thanh Phân Bổ Tỷ Lệ % Calo
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 5,
                child: Row(
                  children: [
                    if (proPct > 0) Expanded(flex: proPct, child: Container(color: const Color(0xFFEF4444))),
                    if (carbPct > 0) Expanded(flex: carbPct, child: Container(color: const Color(0xFFD97706))),
                    if (fatPct > 0) Expanded(flex: fatPct, child: Container(color: const Color(0xFF0284C7))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tỷ lệ: Đạm $proPct% • Carb $carbPct% • Béo $fatPct%',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
                Text(
                  goalHint,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                ),
              ],
            ),
          ],

          const SizedBox(height: 8),

          // Dòng 3: Nút Lưu Nhật Ký
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton.icon(
              onPressed: hasItems ? _saveToMealJournal : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFCBD5E1),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.bookmark_add_outlined, size: 16),
              label: const Text(
                'Lưu vào nhật ký ăn uống',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroPill(String label, double val, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            '$label: ${val.toStringAsFixed(1)}g',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ),
      ),
    );
  }
}

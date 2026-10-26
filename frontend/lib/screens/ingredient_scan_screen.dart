import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/app_colors.dart';
import '../constants/app_translations.dart';
import '../services/ai_vision_service.dart';
import '../services/meal_db_service.dart';
import '../services/app_state_service.dart';
import '../services/recipe_translator.dart';
import '../services/offline_food_db.dart';
import '../widgets/marquee_text.dart';
import '../widgets/recipe_image_widget.dart';
import '../models/barcode_product_model.dart';
import '../widgets/barcode_scanner_sheet.dart';

class IngredientScanScreen extends StatefulWidget {
  final Function(int) onNavigate;

  const IngredientScanScreen({
    super.key,
    required this.onNavigate,
  });

  @override
  State<IngredientScanScreen> createState() => _IngredientScanScreenState();
}

class _IngredientScanScreenState extends State<IngredientScanScreen> with SingleTickerProviderStateMixin {
  final AIVisionService _aiService = AIVisionService();
  final picker = ImagePicker();

  Uint8List? _imageBytes;
  bool _isLoading = false;
  bool _isLoadingMeals = false;
  String _aiStatusMessage = 'Chưa quét hình ảnh';

  // Animation tia quét Laser & hiệu ứng camera scanner
  late AnimationController _scannerAnimController;
  late Animation<double> _laserAnimation;

  @override
  void initState() {
    super.initState();
    _scannerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _laserAnimation = CurvedAnimation(
      parent: _scannerAnimController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _scannerAnimController.dispose();
    super.dispose();
  }

  // Dữ liệu phân tích nguyên liệu từ AI
  IngredientAnalysisResult? _analysisResult;

  // Index nguyên liệu đang được chọn để xem gợi ý món
  final Set<int> _selectedIngredientIndices = {0};

  // Danh sách các món ăn khớp
  List<MealItem> _matchingMeals = [];

  Future<void> _pickAndAnalyzeImage(ImageSource source) async {
    final XFile? photo = await picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 800,
    );

    if (photo == null) return;

    final bytes = await photo.readAsBytes();

    setState(() {
      _imageBytes = bytes;
      _isLoading = true;
      _analysisResult = null;
      _matchingMeals = [];
      _selectedIngredientIndices.clear();
      _selectedIngredientIndices.add(0);
      _aiStatusMessage = 'AI Local (LM Studio) đang kiểm tra & nhận diện nguyên liệu...';
    });

    try {
      final result = await _aiService.analyzeIngredient(bytes);

      setState(() {
        _analysisResult = result;
        _isLoading = false;
        _selectedIngredientIndices.clear();
        if (result.ingredients.isNotEmpty) {
          _selectedIngredientIndices.add(0);
        }
        if (!result.isIngredient) {
          _aiStatusMessage = 'Từ chối: Không phải nguyên liệu thực phẩm';
        } else {
          final count = result.ingredients.length;
          _aiStatusMessage = 'Phát hiện $count nguyên liệu (${result.providerName ?? _aiService.lastUsedProvider ?? 'Local AI'})';
        }
      });

      // Nếu đúng là nguyên liệu thực phẩm, tự động lấy các món ăn khớp theo các nguyên liệu đã chọn
      if (result.isIngredient) {
        _fetchMealsForSelectedIngredients();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _analysisResult = IngredientAnalysisResult.rejected(
          'Lỗi khi kết nối dịch vụ AI: $e',
          provider: _aiService.lastUsedProvider,
        );
        _aiStatusMessage = 'Lỗi kết nối AI';
      });
    }
  }

  /// Lấy danh sách món ăn khớp với TẤT CẢ hoặc các nguyên liệu được chọn (xếp hạng theo độ khớp)
  Future<void> _fetchMealsForSelectedIngredients() async {
    final ingredients = _analysisResult?.ingredients ?? [];
    if (_selectedIngredientIndices.isEmpty || ingredients.isEmpty) {
      if (mounted) {
        setState(() {
          _matchingMeals = [];
          _isLoadingMeals = false;
        });
      }
      return;
    }

    if (mounted) setState(() => _isLoadingMeals = true);

    try {
      final selectedItems = _selectedIngredientIndices
          .where((i) => i >= 0 && i < ingredients.length)
          .map((i) => ingredients[i])
          .toList();

      if (selectedItems.isEmpty) {
        if (mounted) {
          setState(() {
            _matchingMeals = [];
            _isLoadingMeals = false;
          });
        }
        return;
      }

      if (selectedItems.isEmpty) {
        if (mounted) {
          setState(() {
            _matchingMeals = [];
            _isLoadingMeals = false;
          });
        }
        return;
      }

      // Toàn bộ logic xếp hạng món và đối soát nguyên liệu (Thịt + Rau Củ) do Backend C# xử lý 100%
      final ingredientNames = selectedItems.map((e) => e.name).toList();
      final meals = await TheMealDbService.getMealsByMultipleIngredients(ingredientNames);

      if (mounted) {
        setState(() {
          _matchingMeals = meals;
          _isLoadingMeals = false;
        });
      }
    } catch (e) {
      debugPrint('[Multi-ingredient fetch error]: $e');
      if (mounted) {
        setState(() => _isLoadingMeals = false);
      }
    }
  }

  Widget _buildSourceActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconBg,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textBlack),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: AppColors.textGray),
            ),
          ],
        ),
      ),
    );
  }

  /// HỘP THOẠI ĐỔI ẢNH (DÀNH RIÊNG CHO NÚT 'ĐỔI ẢNH KHÁC')
  void _showChangePhotoPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Đổi Ảnh Nguyên Liệu',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textBlack),
              ),
              const SizedBox(height: 4),
              const Text(
                'Chụp ảnh mới hoặc chọn từ thư viện để AI phân tích lại',
                style: TextStyle(fontSize: 11, color: AppColors.textGray),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildSourceActionCard(
                      icon: Icons.camera_alt_rounded,
                      title: AppTranslations.tr('camera_option'),
                      subtitle: 'Chụp ảnh mới',
                      iconBg: AppColors.accentMint,
                      iconColor: AppColors.primaryDark,
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickAndAnalyzeImage(ImageSource.camera);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildSourceActionCard(
                      icon: Icons.photo_library_rounded,
                      title: 'Thư viện ảnh',
                      subtitle: 'Chọn từ album',
                      iconBg: const Color(0xFFE0F2FE),
                      iconColor: const Color(0xFF0284C7),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickAndAnalyzeImage(ImageSource.gallery);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// HỘP THOẠI QUÉT NGUYÊN LIỆU ĐẦY ĐỦ (2X2 GRID GỌN GÀNG, KHÔNG BAO GIỜ BỊ TRÀN)
  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  AppTranslations.tr('scan_sheet_title'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                ),
                const SizedBox(height: 4),
                Text(
                  AppTranslations.tr('scan_sheet_sub'),
                  style: const TextStyle(fontSize: 11, color: AppColors.textGray),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildSourceActionCard(
                        icon: Icons.camera_alt_rounded,
                        title: AppTranslations.tr('camera_option'),
                        subtitle: 'Chụp trực tiếp',
                        iconBg: AppColors.accentMint,
                        iconColor: AppColors.primaryDark,
                        onTap: () {
                          Navigator.pop(ctx);
                          _pickAndAnalyzeImage(ImageSource.camera);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildSourceActionCard(
                        icon: Icons.photo_library_rounded,
                        title: 'Thư viện ảnh',
                        subtitle: 'Tải từ album',
                        iconBg: const Color(0xFFE0F2FE),
                        iconColor: const Color(0xFF0284C7),
                        onTap: () {
                          Navigator.pop(ctx);
                          _pickAndAnalyzeImage(ImageSource.gallery);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildSourceActionCard(
                        icon: Icons.qr_code_scanner_rounded,
                        title: 'Quét mã vạch',
                        subtitle: 'Bao bì siêu thị GS1',
                        iconBg: const Color(0xFFFEE2E2),
                        iconColor: const Color(0xFFDC2626),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final product = await BarcodeScannerSheet.show(context);
                          if (product != null && mounted) {
                            _addBarcodeProductToScan(product);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildSourceActionCard(
                        icon: Icons.edit_note_rounded,
                        title: 'Nhập tay',
                        subtitle: 'Tự chọn nguyên liệu',
                        iconBg: const Color(0xFFDCFCE7),
                        iconColor: AppColors.primaryDark,
                        onTap: () {
                          Navigator.pop(ctx);
                          _showManualIngredientSheet();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Nạp trực tiếp sản phẩm mã vạch vào danh sách phân tích và gợi ý món ăn
  void _addBarcodeProductToScan(BarcodeProductModel product) {
    final newIng = DetectedIngredientItem(
      name: product.productName,
      englishName: product.cutEquivalentId ?? 'Ingredient',
      calories: '${product.caloriesPer100g.round()} kcal',
      calorieNumber: product.caloriesPer100g.round(),
      weight: product.servingSize,
      protein: '${product.proteinPer100g.toStringAsFixed(1)}g Protein',
      carbs: '${product.carbsPer100g.toStringAsFixed(1)}g Carbs',
      fat: '${product.fatPer100g.toStringAsFixed(1)}g Fat',
      nutritionComment: product.notes.isNotEmpty ? product.notes : 'Sản phẩm ${product.brand}',
    );

    setState(() {
      _isLoading = false;
      final currentList = _analysisResult?.ingredients.toList() ?? [];
      currentList.insert(0, newIng);

      _analysisResult = IngredientAnalysisResult(
        isIngredient: true,
        name: product.productName,
        englishName: product.cutEquivalentId ?? 'Ingredient',
        calories: '${product.caloriesPer100g.round()} kcal',
        calorieNumber: product.caloriesPer100g.round(),
        weight: product.servingSize,
        protein: '${product.proteinPer100g.toStringAsFixed(1)}g Protein',
        carbs: '${product.carbsPer100g.toStringAsFixed(1)}g Carbs',
        fat: '${product.fatPer100g.toStringAsFixed(1)}g Fat',
        nutritionComment: product.notes,
        context: 'Đã nhận diện sản phẩm qua mã vạch GS1: ${product.productName} (${product.brand}).',
        ingredients: currentList,
      );
      _selectedIngredientIndices.clear();
      _selectedIngredientIndices.add(0);
      _aiStatusMessage = 'Đã quét mã vạch: ${product.productName}';
    });

    _fetchMealsForSelectedIngredients();
  }

  /// HỘP THOẠI NHẬP TAY NGUYÊN LIỆU (100% OFFLINE)
  void _showManualIngredientSheet() {
    final textController = TextEditingController();
    final List<String> selectedIngredients = (_analysisResult?.ingredients ?? [])
        .map((e) => e.name)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            void toggleIngredient(String name) {
              final trimmed = name.trim();
              if (trimmed.isEmpty) return;
              final cleanName = trimmed.replaceAll(RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true), '').trim();
              final existingIndex = selectedIngredients.indexWhere((e) => e.toLowerCase() == cleanName.toLowerCase());
              setSheetState(() {
                if (existingIndex != -1) {
                  selectedIngredients.removeAt(existingIndex);
                } else {
                  selectedIngredients.add(cleanName);
                }
              });
              textController.clear();
            }

            void addIngredient(String name) => toggleIngredient(name);

            void removeIngredient(int index) {
              setSheetState(() {
                selectedIngredients.removeAt(index);
              });
            }

            final tempItems = selectedIngredients.map((n) => OfflineFoodDatabase.lookup(n)).toList();
            final totalTempCal = tempItems.fold(0, (sum, i) => sum + i.calorieNumber);

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.accentMint,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.kitchen_rounded, color: AppColors.primaryDark, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Nhập nguyên liệu có sẵn',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textBlack,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Tra cứu calo & Gợi ý món ngon (Hỗ trợ 100% Offline)',
                                style: TextStyle(fontSize: 11, color: AppColors.textGray),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetCtx),
                          icon: const Icon(Icons.close, color: AppColors.textGray),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 24),

                  // Phần thân cuộn được
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Ô nhập text + Nút Thêm
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: textController,
                                  decoration: InputDecoration(
                                    hintText: 'Nhập tên nguyên liệu (vd: thịt bò, trứng, cà chua...)',
                                    hintStyle: const TextStyle(fontSize: 13, color: AppColors.textLightGray),
                                    prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 20),
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                                    ),
                                  ),
                                  onSubmitted: (val) => addIngredient(val),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: () => addIngredient(textController.text),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text('Thêm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ],
                          ),

                          const SizedBox(height: 18),

                          // Gợi ý chọn nhanh 1 chạm
                          const Row(
                            children: [
                              Icon(Icons.bolt_rounded, size: 16, color: Color(0xFFF59E0B)),
                              SizedBox(width: 6),
                              Text(
                                'Gợi ý chọn nhanh 1 chạm:',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textBlack,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: OfflineFoodDatabase.quickSuggestions.map((suggestion) {
                              final cleanName = suggestion.replaceAll(RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true), '').trim();
                              final isSelected = selectedIngredients.any((e) => e.toLowerCase() == cleanName.toLowerCase());

                              return InkWell(
                                onTap: () => addIngredient(suggestion),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        suggestion,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                          color: isSelected ? const Color(0xFF166534) : AppColors.textBlack,
                                        ),
                                      ),
                                      if (isSelected) ...[
                                        const SizedBox(width: 4),
                                        const Icon(Icons.check, size: 14, color: Color(0xFF166534)),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 22),

                          // Danh sách nguyên liệu đã chọn
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Nguyên liệu đã chọn (${selectedIngredients.length}):',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textBlack,
                                ),
                              ),
                              if (selectedIngredients.isNotEmpty)
                                TextButton(
                                  onPressed: () {
                                    setSheetState(() => selectedIngredients.clear());
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: const Text('Xóa tất cả', style: TextStyle(fontSize: 12)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          if (selectedIngredients.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: const Column(
                                children: [
                                  Icon(Icons.egg_alt_outlined, size: 36, color: Color(0xFF94A3B8)),
                                  SizedBox(height: 8),
                                  Text(
                                    'Chưa có nguyên liệu nào được chọn',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Gõ tên nguyên liệu hoặc chạm vào các gợi ý ở trên',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            )
                          else
                            Column(
                              children: [
                                ...List.generate(selectedIngredients.length, (idx) {
                                  final name = selectedIngredients[idx];
                                  final info = OfflineFoodDatabase.lookup(name);
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.02),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: AppColors.accentMint,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.check_circle_outline, size: 16, color: AppColors.primaryDark),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                info.name,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.textBlack,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${info.calories} • ${info.weight} • ${info.protein}',
                                                style: const TextStyle(fontSize: 11, color: AppColors.textGray),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                                          onPressed: () => removeIngredient(idx),
                                        ),
                                      ],
                                    ),
                                  );
                                }),

                                // Thẻ tổng kết calo tạm tính
                                Container(
                                  margin: const EdgeInsets.only(top: 8, bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFFFDE68A)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.local_fire_department, size: 18, color: Color(0xFFD97706)),
                                          SizedBox(width: 6),
                                          Text(
                                            'Tổng năng lượng ước tính:',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF92400E),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '~$totalTempCal kcal',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFFB45309),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),

                  // Thanh nút bấm ở dưới cùng
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -3),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: selectedIngredients.isEmpty
                              ? null
                              : () {
                                  Navigator.pop(sheetCtx);
                                  _processManualIngredients(selectedIngredients);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey.shade300,
                            disabledForegroundColor: Colors.grey.shade500,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.search, size: 20),
                          label: Text(
                            selectedIngredients.isEmpty
                                ? 'Hãy chọn ít nhất 1 nguyên liệu'
                                : 'Phân Tích & Tìm Món (${selectedIngredients.length} nguyên liệu)',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Xử lý danh sách nguyên liệu nhập tay từ người dùng
  void _processManualIngredients(List<String> rawNames) {
    if (rawNames.isEmpty) return;

    final List<DetectedIngredientItem> items = rawNames.map((name) => OfflineFoodDatabase.lookup(name)).toList();
    final totalCal = items.fold(0, (sum, i) => sum + i.calorieNumber);

    int totalPro = 0;
    int totalCarb = 0;
    int totalFat = 0;
    for (final it in items) {
      final pMatch = RegExp(r'(\d+)').firstMatch(it.protein);
      if (pMatch != null) totalPro += int.parse(pMatch.group(1)!);
      final cMatch = RegExp(r'(\d+)').firstMatch(it.carbs);
      if (cMatch != null) totalCarb += int.parse(cMatch.group(1)!);
      final fMatch = RegExp(r'(\d+)').firstMatch(it.fat);
      if (fMatch != null) totalFat += int.parse(fMatch.group(1)!);
    }

    final combinedResult = IngredientAnalysisResult(
      isIngredient: true,
      name: items.map((e) => e.name).join(', '),
      englishName: items.first.englishName,
      calories: '$totalCal kcal',
      calorieNumber: totalCal,
      weight: '~${items.length * 120}g',
      protein: '${totalPro}g Protein',
      carbs: '${totalCarb}g Carbs',
      fat: '${totalFat}g Fat',
      nutritionComment: 'Dữ liệu dinh dưỡng được tính toán từ ${items.length} nguyên liệu trong bếp của bạn: ${items.map((e) => e.name).join(", ")}. Bữa ăn cung cấp cân bằng đạm, calo và năng lượng thiết yếu.',
      providerName: 'Chế độ Nhập tay (Offline Dinh dưỡng)',
      ingredients: items,
    );

    setState(() {
      _imageBytes = null;
      _isLoading = false;
      _analysisResult = combinedResult;
      _selectedIngredientIndices.clear();
      _selectedIngredientIndices.addAll(List.generate(items.length, (i) => i));
      _matchingMeals = [];
      _aiStatusMessage = 'Đã phân tích ${items.length} nguyên liệu (Nhập tay Ngoại tuyến)';
    });

    // Lọc và xếp hạng món ăn phù hợp với TẤT CẢ các nguyên liệu đã nhập
    _fetchMealsForSelectedIngredients();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Tiêu đề thương hiệu
            const Center(
              child: Text(
                'NutriSnap AI Vision',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textBlack,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 2. Thanh trạng thái & Nút chụp lại
            _buildTopActionBar(),
            const SizedBox(height: 14),

            // 3. Banner hiển thị ảnh chụp hoặc Giao diện Camera Scanner sinh động
            if (_imageBytes != null) ...[
              _buildImagePreviewBanner(),
              const SizedBox(height: 16),
            ] else ...[
              _buildAnimatedScannerDefaultView(),
              const SizedBox(height: 16),
            ],

            // 4. Nếu đang tải
            if (_isLoading) _buildLoadingCard(),

            // 5. TRƯỜNG HỢP 1: TỪ CHỐI NHẬN DIỆN (Nếu không phải nguyên liệu thực phẩm)
            if (!_isLoading && _analysisResult != null && !_analysisResult!.isIngredient)
              _buildRejectionCard(),

            // 6. TRƯỜNG HỢP 2: LÀ NGUYÊN LIỆU THỰC PHẨM
            if (!_isLoading && _analysisResult != null && _analysisResult!.isIngredient) ...[
              // A. Tên nguyên liệu + Lượng Calo + Macro
              _buildIngredientHeaderCard(),
              const SizedBox(height: 16),

              // B. DANH SÁCH CÁC NGUYÊN LIỆU NHẬN DIỆN ĐƯỢC
              _buildDetectedIngredientsList(),
              const SizedBox(height: 16),

              // C. Nhận xét chuyên sâu về nguyên liệu
              _buildNutritionCommentCard(),
              const SizedBox(height: 20),

              // D. Danh sách các món ăn khớp
              _buildMatchingMealsSection(),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS CON ---

  Widget _buildTopActionBar() {
    return Row(
      children: [
        InkWell(
          onTap: () => widget.onNavigate(0),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
              ],
            ),
            child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.textBlack),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppTranslations.tr('scan_title'),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textBlack),
              ),
              const SizedBox(height: 2),
              Text(
                _aiStatusMessage == 'Chưa quét hình ảnh' ? AppTranslations.tr('scan_status_default') : _aiStatusMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.textGray),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: _showManualIngredientSheet,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFF2563EB)),
                SizedBox(width: 4),
                Text(
                  'Nhập tay',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        InkWell(
          onTap: _showImageSourcePicker,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.accentMint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.camera_alt_outlined, size: 14, color: AppColors.primaryDark),
                const SizedBox(width: 4),
                Text(
                  AppTranslations.tr('scan_button'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreviewBanner() {
    if (_imageBytes == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: _showChangePhotoPicker,
      child: Stack(
        children: [
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(
                    _imageBytes!,
                    fit: BoxFit.cover,
                  ),
                  // Khi AI đang quét ảnh thật, hiển thị tia laser chạy trên ảnh
                  if (_isLoading)
                    AnimatedBuilder(
                      animation: _laserAnimation,
                      builder: (context, child) {
                        return Positioned(
                          top: _laserAnimation.value * 190,
                          left: 0,
                          right: 0,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Color(0xFF10B981),
                                      Color(0xFF34D399),
                                      Color(0xFF10B981),
                                      Colors.transparent,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF10B981).withOpacity(0.9),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                height: 26,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      const Color(0xFF10B981).withOpacity(0.25),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: InkWell(
              onTap: _showChangePhotoPicker,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.refresh_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      AppTranslations.tr('change_photo'),
                      style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// GIAO DIỆN QUÉT MẶC ĐỊNH SINH ĐỘNG (AI Camera Scanner Viewfinder)
  Widget _buildAnimatedScannerDefaultView() {
    return Column(
      children: [
        // 1. KHUNG NGẮM CAMERA AI SCANNER CHUYỂN ĐỘNG
        Container(
          height: 270,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0F172A),
                Color(0xFF1E293B),
              ],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: const Color(0xFF10B981).withOpacity(0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withOpacity(0.12),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Stack(
              children: [
                // 4 Góc ngắm camera viewfinder
                Positioned(top: 14, left: 14, child: _buildCornerBracket(top: true, left: true)),
                Positioned(top: 14, right: 14, child: _buildCornerBracket(top: true, left: false)),
                Positioned(bottom: 14, left: 14, child: _buildCornerBracket(top: false, left: true)),
                Positioned(bottom: 14, right: 14, child: _buildCornerBracket(top: false, left: false)),

                // Tia quét Laser chuyển động lên xuống
                AnimatedBuilder(
                  animation: _laserAnimation,
                  builder: (context, child) {
                    return Positioned(
                      top: 25 + (_laserAnimation.value * 210),
                      left: 20,
                      right: 20,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Color(0xFF10B981),
                                  Color(0xFF34D399),
                                  Color(0xFF10B981),
                                  Colors.transparent,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withOpacity(0.9),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: 28,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  const Color(0xFF10B981).withOpacity(0.2),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Tâm ngắm hồng ngoại AI ở giữa
                Center(
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF10B981).withOpacity(0.25),
                        width: 1.5,
                      ),
                      color: const Color(0xFF10B981).withOpacity(0.04),
                    ),
                    child: Center(
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF10B981).withOpacity(0.4),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.filter_center_focus_rounded,
                          color: Color(0xFF34D399),
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),

                // Các nhãn thực phẩm nổi nhấp nhô xung quanh tâm ngắm
                AnimatedBuilder(
                  animation: _laserAnimation,
                  builder: (context, child) {
                    final progress = _laserAnimation.value;
                    return Stack(
                      children: [
                        Positioned(
                          top: 42 + (sin(progress * pi) * 6),
                          left: 28,
                          child: _buildFloatingFoodBadge('🥩', 'Thịt tươi'),
                        ),
                        Positioned(
                          top: 42 - (sin(progress * pi) * 6),
                          right: 28,
                          child: _buildFloatingFoodBadge('🥦', 'Rau xanh'),
                        ),
                        Positioned(
                          bottom: 50 + (cos(progress * pi) * 5),
                          left: 32,
                          child: _buildFloatingFoodBadge('🥕', 'Củ quả'),
                        ),
                        Positioned(
                          bottom: 50 - (cos(progress * pi) * 5),
                          right: 32,
                          child: _buildFloatingFoodBadge('🐟', 'Hải sản'),
                        ),
                      ],
                    );
                  },
                ),

                // Thanh trạng thái AI Vision Scanner ở phía trên
                Positioned(
                  top: 14,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withOpacity(0.8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF34D399),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'AI VISION SCANNER • SẴN SÀNG',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: Color(0xFF34D399),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Lời nhắc ở đáy viewfinder
                Positioned(
                  bottom: 14,
                  left: 20,
                  right: 20,
                  child: Center(
                    child: Text(
                      'Đặt nguyên liệu vào khung ngắm để phân tích dinh dưỡng',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.75),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 2. HAI NÚT BẤM TO CHỤP ẢNH & THƯ VIỆN TRỰC TIẾP
        Row(
          children: [
            Expanded(
              flex: 6,
              child: ElevatedButton.icon(
                onPressed: () => _pickAndAnalyzeImage(ImageSource.camera),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.camera_alt_rounded, size: 20),
                label: Text(
                  AppTranslations.tr('camera_option'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 5,
              child: OutlinedButton.icon(
                onPressed: () => _pickAndAnalyzeImage(ImageSource.gallery),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryDark,
                  side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.photo_library_outlined, size: 18, color: Color(0xFF6366F1)),
                label: Text(
                  AppTranslations.tr('gallery_option'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // 2b. NÚT NHẬP TAY NGUYÊN LIỆU TRỰC TIẾP (100% OFFLINE)
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showManualIngredientSheet,
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFFF0FDF4),
              foregroundColor: const Color(0xFF166534),
              side: const BorderSide(color: Color(0xFF86EFAC), width: 1.2),
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.edit_note_rounded, size: 22, color: AppColors.primary),
            label: const Text(
              '✍️ Nhập tay nguyên liệu trong bếp (Hỗ trợ Ngoại tuyến)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 3. THẺ TÍNH NĂNG AI THÔNG MINH & BỘ LỌC AN TOÀN
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF166534)),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'NutriSnap AI Vision Hoạt Động Thế Nào?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textBlack,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildFeatureRow(
                Icons.verified_user_outlined,
                const Color(0xFF10B981),
                'Kiểm duyệt an toàn thực phẩm',
                'Tự động từ chối nếu ảnh không phải nguyên liệu (vật dụng, người, phong cảnh...).',
              ),
              const SizedBox(height: 10),
              _buildFeatureRow(
                Icons.local_fire_department_outlined,
                const Color(0xFFF97316),
                'Ước tính Calo & Macro tức thì',
                'Phân tích chi tiết lượng Đạm (Protein), Tinh bột (Carb), Chất béo (Fat).',
              ),
              const SizedBox(height: 10),
              _buildFeatureRow(
                Icons.restaurant_menu_rounded,
                const Color(0xFF6366F1),
                'Khớp công thức TheMealDB',
                'Gợi ý các món ăn ngon nhất có thể nấu ngay với nguyên liệu vừa quét.',
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 4. GỢI Ý NGUYÊN LIỆU PHỔ BIẾN
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '💡 Hỗ trợ nhận diện tốt nhất:',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textGray),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildIngredientTag('🥩 Thịt heo / bò'),
                  _buildIngredientTag('🍗 Thịt gà'),
                  _buildIngredientTag('🥦 Bông cải'),
                  _buildIngredientTag('🥚 Trứng gà'),
                  _buildIngredientTag('🥕 Cà rốt'),
                  _buildIngredientTag('🍅 Cà chua'),
                  _buildIngredientTag('🐟 Cá tươi'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCornerBracket({required bool top, required bool left}) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        border: Border(
          top: top ? const BorderSide(color: Color(0xFF34D399), width: 3.5) : BorderSide.none,
          bottom: !top ? const BorderSide(color: Color(0xFF34D399), width: 3.5) : BorderSide.none,
          left: left ? const BorderSide(color: Color(0xFF34D399), width: 3.5) : BorderSide.none,
          right: !left ? const BorderSide(color: Color(0xFF34D399), width: 3.5) : BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildFloatingFoodBadge(String emoji, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, Color color, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textBlack),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: AppColors.textGray, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, color: Color(0xFF334155), fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            AppTranslations.tr('analyzing'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textBlack),
          ),
          const SizedBox(height: 4),
          const Text(
            'Hệ thống AI đa đám mây đang kiểm tra nguyên liệu và calo',
            style: TextStyle(fontSize: 12, color: AppColors.textGray),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// TỪ CHỐI NHẬN DIỆN KHI KHÔNG PHẢI NGUYÊN LIỆU THỰC PHẨM
  Widget _buildRejectionCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.no_food_outlined, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Từ chối nhận diện: Không phải nguyên liệu!',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF991B1B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _analysisResult?.rejectReason ??
                'Ảnh đã chụp không chứa nguyên liệu thực phẩm hoặc thức ăn. Vui lòng thử lại với ảnh thịt, cá, rau củ hoặc nguyên liệu tươi sống.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF7F1D1D), height: 1.4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showChangePhotoPicker,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFEF4444)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.camera_alt_outlined, color: Color(0xFFEF4444), size: 18),
              label: const Text(
                'Chụp lại ảnh nguyên liệu thực tế',
                style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showManualIngredientSheet,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              icon: const Icon(Icons.edit_note_rounded, size: 20),
              label: const Text(
                '✍️ Hoặc nhập tay nguyên liệu bạn có',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ĐẦU RA: TÊN NGUYÊN LIỆU + CALO
  Widget _buildIngredientHeaderCard() {
    final res = _analysisResult!;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accentMint,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.restaurant_menu_rounded, size: 28, color: AppColors.primaryDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: MarqueeText(
                            text: res.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textBlack,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            res.ingredients.length > 1
                                ? '${res.ingredients.length} nguyên liệu ✓'
                                : 'Hợp lệ ✓',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      res.ingredients.length > 1
                          ? 'Tổng khối lượng: ${res.weight} (${res.ingredients.length} loại)'
                          : (res.weight.toLowerCase().contains('100g')
                              ? 'Định mức khẩu phần: ${res.weight}'
                              : 'Ước tính khối lượng: ${res.weight}'),
                      style: const TextStyle(fontSize: 12, color: AppColors.textGray),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // LƯỢNG CALO NỔI BẬT
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.accentIndigo,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_fire_department, color: Colors.deepOrange, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        res.weight.toLowerCase().contains('100g') ? 'NĂNG LƯỢNG (TRÊN 100G)' : 'NĂNG LƯỢNG (CALO)',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textGray),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        res.calories,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    AppStateService.instance.currentLanguage == 'vi' ? res.name.toUpperCase() : res.englishName.toUpperCase(),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Macro Stats: Protein, Carbs, Fat
          Row(
            children: [
              Expanded(child: _buildMacroBadge('Đạm (Protein)', res.protein, Colors.blue.shade700, const Color(0xFFEFF6FF))),
              const SizedBox(width: 8),
              Expanded(child: _buildMacroBadge('Tinh bột (Carb)', res.carbs, Colors.amber.shade800, const Color(0xFFFFFBEB))),
              const SizedBox(width: 8),
              Expanded(child: _buildMacroBadge('Chất béo (Fat)', res.fat, Colors.red.shade700, const Color(0xFFFEF2F2))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroBadge(String title, String val, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(fontSize: 9, color: AppColors.textGray, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(
            val,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
          ),
        ],
      ),
    );
  }

  /// ĐẦU RA: NHẬN XÉT VỀ NGUYÊN LIỆU
  Widget _buildNutritionCommentCard() {
    final res = _analysisResult!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 8),
              const Text(
                'Nhận Xét Dinh Dưỡng Từ Chuyên Gia AI',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textBlack),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            res.nutritionComment,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF334155),
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
          ),
          if (res.context.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Bối cảnh nhận diện: ${res.context}',
              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textLightGray),
            ),
          ],
        ],
      ),
    );
  }

  /// BẢNG DANH SÁCH NHIỀU NGUYÊN LIỆU PHÁT HIỆN ĐƯỢC
  Widget _buildDetectedIngredientsList() {
    final ingredients = _analysisResult?.ingredients ?? [];
    if (ingredients.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.accentMint,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.format_list_bulleted_rounded, size: 16, color: AppColors.primaryDark),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Nguyên Liệu Nhận Diện (${ingredients.length})',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _showManualIngredientSheet,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_note_rounded, size: 14, color: Color(0xFF2563EB)),
                      SizedBox(width: 3),
                      Text(
                        '✍️ Thêm/Sửa',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Chạm để chọn hoặc hủy chọn nhiều nguyên liệu để lọc món ăn gợi ý:',
            style: TextStyle(fontSize: 11, color: AppColors.textGray),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: ingredients.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = ingredients[index];
              final isSelected = _selectedIngredientIndices.contains(index);

              return InkWell(
                onTap: () {
                  setState(() {
                    if (_selectedIngredientIndices.contains(index)) {
                      _selectedIngredientIndices.remove(index);
                    } else {
                      _selectedIngredientIndices.add(index);
                    }
                  });
                  _fetchMealsForSelectedIngredients();
                },
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Emoji đại diện
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFDCFCE7) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            _getIngredientEmoji(item.name),
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Tên & Thông số
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: MarqueeText(
                                    text: item.name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? const Color(0xFF065F46) : AppColors.textBlack,
                                    ),
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Đang chọn',
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  item.weight,
                                  style: const TextStyle(fontSize: 11, color: AppColors.textGray),
                                ),
                                const SizedBox(width: 6),
                                const Text('•', style: TextStyle(color: AppColors.textLightGray, fontSize: 10)),
                                const SizedBox(width: 6),
                                Text(
                                  item.calories,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFEA580C)),
                                ),
                                const SizedBox(width: 6),
                                const Text('•', style: TextStyle(color: AppColors.textLightGray, fontSize: 10)),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    item.protein,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        size: 20,
                        color: isSelected ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _getIngredientEmoji(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('bò') || lower.contains('beef')) return '🥩';
    if (lower.contains('gà') || lower.contains('chicken')) return '🍗';
    if (lower.contains('heo') || lower.contains('lợn') || lower.contains('pork')) return '🥓';
    if (lower.contains('cá') || lower.contains('fish') || lower.contains('salmon')) return '🐟';
    if (lower.contains('tôm') || lower.contains('shrimp')) return '🦐';
    if (lower.contains('trứng') || lower.contains('egg')) return '🥚';
    if (lower.contains('cải') || lower.contains('rau') || lower.contains('broccoli')) return '🥦';
    if (lower.contains('cà rốt') || lower.contains('carrot')) return '🥕';
    if (lower.contains('cà chua') || lower.contains('tomato')) return '🍅';
    if (lower.contains('hành') || lower.contains('onion')) return '🧅';
    if (lower.contains('khoai') || lower.contains('potato')) return '🥔';
    if (lower.contains('nấm') || lower.contains('mushroom')) return '🍄';
    if (lower.contains('ớt') || lower.contains('chili') || lower.contains('pepper')) return '🌶️';
    if (lower.contains('đậu') || lower.contains('bean') || lower.contains('tofu')) return '🫘';
    return '🥗';
  }

  /// ĐẦU RA: CÁC MÓN ĂN KHỚP VỚI NGUYÊN LIỆU (Đã gỡ TheMealDB, hỗ trợ chữ chạy LED)
  Widget _buildMatchingMealsSection() {
    final ingredients = _analysisResult?.ingredients ?? [];
    final selectedItems = _selectedIngredientIndices
        .where((i) => i >= 0 && i < ingredients.length)
        .map((i) => ingredients[i])
        .toList();

    final activeIngredientName = selectedItems.isNotEmpty
        ? selectedItems.map((e) => e.name).join(' + ')
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Tiêu đề danh mục (Loại bỏ hoàn toàn TheMealDB theo yêu cầu)
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.accentMint,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.restaurant, size: 16, color: AppColors.primaryDark),
            ),
            const SizedBox(width: 8),
            Text(
              AppTranslations.tr('matching_recipes'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textBlack),
            ),
          ],
        ),

        // 2. Chip hiển thị nguyên liệu đang được chọn gợi ý với hiệu ứng chữ LED chạy nếu quá dài
        if (activeIngredientName.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                AppStateService.instance.currentLanguage == 'vi'
                    ? 'Gợi ý món từ (${selectedItems.length}):'
                    : 'Recipes for (${selectedItems.length}):',
                style: const TextStyle(fontSize: 12, color: AppColors.textGray),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: MarqueeText(
                    text: activeIngredientName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF166534),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.track_changes_rounded, size: 14, color: AppColors.primary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Lọc theo mục tiêu: ${AppStateService.instance.userProfile.goalDisplayName} • Calo còn lại: ${AppStateService.instance.remainingCalories} kcal',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F766E)),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),

        if (_selectedIngredientIndices.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Text(
                'Vui lòng chọn ít nhất 1 nguyên liệu phía trên để hiển thị gợi ý món ăn.',
                style: TextStyle(fontSize: 12, color: AppColors.textGray),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else if (_isLoadingMeals)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  SizedBox(height: 10),
                  Text('Đang tìm món phù hợp...', style: TextStyle(fontSize: 12, color: AppColors.textGray)),
                ],
              ),
            ),
          )
        else if (_matchingMeals.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Center(
              child: Text(
                AppTranslations.tr('no_matching_recipes'),
                style: const TextStyle(fontSize: 12, color: AppColors.textGray),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _matchingMeals.length > 12 ? 12 : _matchingMeals.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final meal = _matchingMeals[index];
              return _buildMealTile(meal);
            },
          ),
      ],
    );
  }

  Widget _buildMealTile(MealItem meal) {
    return InkWell(
      onTap: () async {
        // Tải chi tiết món ăn với ngôn ngữ hiện tại và bộ lọc AI
        final navigator = Navigator.of(context);
        final lang = AppStateService.instance.currentLanguage;
        final bool isViLang = lang == 'vi';
        final bool needsAi = isViLang &&
            (meal.strInstructionsVi == null ||
                meal.strInstructionsVi!.trim().isEmpty ||
                meal.strInstructionsVi == meal.strInstructions ||
                !RecipeTranslator.hasVietnameseDiacritics(meal.strInstructionsVi));

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              margin: const EdgeInsets.symmetric(horizontal: 40),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 16)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
                  ),
                  const SizedBox(width: 14),
                  Flexible(
                    child: Text(
                      needsAi ? 'Bộ lọc AI đang tải & dịch công thức...' : 'Đang mở công thức...',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textBlack),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        final detail = await TheMealDbService.getMealDetail(
          meal.idMeal,
          lang: lang,
          forceAi: needsAi,
        );
        navigator.pop(); // Đóng loading

        if (detail != null) {
          AppStateService.instance.setSelectedMeal(detail);
        } else {
          AppStateService.instance.setSelectedMeal(meal);
        }

        // Chuyển sang màn hình RecipeDetailScreen (Index 6)
        widget.onNavigate(6);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            RecipeImageWidget(
              imageUrl: meal.strMealThumb,
              mealName: meal.strMealVi ?? meal.strMeal,
              category: meal.strCategory,
              width: 64,
              height: 64,
              borderRadius: BorderRadius.circular(12),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hiệu ứng chữ chạy LED (Marquee) khi tên món dài
                  MarqueeText(
                    text: AppStateService.instance.currentLanguage == 'vi'
                        ? ((meal.strMealVi != null && meal.strMealVi!.trim().isNotEmpty)
                            ? meal.strMealVi!
                            : RecipeTranslator.translateDishName(meal.strMeal))
                        : meal.strMeal,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department_outlined, size: 14, color: AppColors.primary),
                      const SizedBox(width: 2),
                      Text(
                        '~${meal.estimatedCalories} kcal',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${meal.estimatedProtein}g Đạm',
                        style: const TextStyle(fontSize: 11, color: AppColors.textGray),
                      ),
                      if (meal.badges.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 2,
                            children: meal.badges.take(2).map((b) {
                              final isTheMealDb = b.contains('TheMealDB');
                              final isGoal = b.contains('Giảm Cân') || b.contains('Tăng Cơ') || b.contains('Giữ Dáng') || b.contains('Calo') || b.contains('Ít Calo');
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isTheMealDb
                                      ? const Color(0xFFEFF6FF)
                                      : (isGoal ? const Color(0xFFFEF3C7) : const Color(0xFFF0FDF4)),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isTheMealDb
                                        ? const Color(0xFFBFDBFE)
                                        : (isGoal ? const Color(0xFFFDE68A) : const Color(0xFFBBF7D0)),
                                  ),
                                ),
                                child: Text(
                                  b,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 9.0,
                                    fontWeight: FontWeight.bold,
                                    color: isTheMealDb
                                        ? const Color(0xFF1D4ED8)
                                        : (isGoal ? const Color(0xFFB45309) : const Color(0xFF166534)),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textLightGray),
          ],
        ),
      ),
    );
  }
}
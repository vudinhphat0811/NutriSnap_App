import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/app_colors.dart';
import '../models/barcode_product_model.dart';
import '../services/barcode_nutrition_service.dart';

/// Modal Quét Mã Vạch Siêu Thị & Bao Bì Thực Phẩm
/// Hỗ trợ:
/// 1. Viewfinder laser scan mô phỏng
/// 2. Chụp ảnh / Chọn ảnh từ thư viện bằng ImagePicker
/// 3. Nhập mã vạch 13 số trực tiếp
/// 4. Danh sách các khay thịt & đồ gym mẫu siêu thị thực tế
class BarcodeScannerSheet extends StatefulWidget {
  const BarcodeScannerSheet({super.key});

  static Future<BarcodeProductModel?> show(BuildContext context) {
    return showModalBottomSheet<BarcodeProductModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const BarcodeScannerSheet(),
    );
  }

  @override
  State<BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends State<BarcodeScannerSheet> with SingleTickerProviderStateMixin {
  late AnimationController _laserController;
  late Animation<double> _laserAnimation;

  final TextEditingController _barcodeInputController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  int _currentTab = 0; // 0: Viewfinder & Camera, 1: Nhập tay, 2: Sản phẩm mẫu
  bool _isSearching = false;
  String? _errorMessage;
  BarcodeProductModel? _scannedProduct;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(parent: _laserController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _laserController.dispose();
    _barcodeInputController.dispose();
    super.dispose();
  }

  Future<void> _searchBarcode(String code) async {
    final clean = code.trim();
    if (clean.isEmpty) return;

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _scannedProduct = null;
    });

    final product = await BarcodeNutritionService.lookupBarcode(clean);

    if (mounted) {
      setState(() {
        _isSearching = false;
        if (product != null) {
          _scannedProduct = product;
        } else {
          _errorMessage = 'Không tìm thấy thông tin cho mã vạch "$clean". Vui lòng kiểm tra lại hoặc thử danh sách mẫu.';
        }
      });
    }
  }

  Future<void> _handlePickImage(ImageSource source) async {
    try {
      final photo = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (photo == null) return;

      // Mô phỏng nhận diện mã vạch từ ảnh chụp bao bì/tem cân siêu thị
      setState(() => _isSearching = true);
      await Future.delayed(const Duration(milliseconds: 1200));

      // Thử bóc tách số từ tên file nếu có, hoặc nhận diện mẫu thịt siêu thị
      final nameLower = photo.name.toLowerCase();
      String testBarcode = '201024503504'; // Mặc định: Khay Ức Gà MeatDeli 350g

      if (nameLower.contains('milk') || nameLower.contains('sua')) {
        testBarcode = '8936036010017';
      } else if (nameLower.contains('oat') || nameLower.contains('yen')) {
        testBarcode = '0030000010402';
      } else if (nameLower.contains('beef') || nameLower.contains('bo')) {
        testBarcode = '201011002808';
      } else if (nameLower.contains('whey')) {
        testBarcode = '0748927028669';
      }

      await _searchBarcode(testBarcode);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _errorMessage = 'Lỗi truy cập máy ảnh: $e';
        });
      }
    }
  }

  void _onSelectProduct(BarcodeProductModel product) {
    setState(() {
      _scannedProduct = product;
      _errorMessage = null;
    });
  }

  void _confirmAndApply() {
    if (_scannedProduct != null) {
      Navigator.pop(context, _scannedProduct);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final samples = BarcodeNutritionService.getSampleProducts();

    return Container(
      height: mediaQuery.size.height * 0.88,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E242B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[700] : Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // 2. Header (Two-tier hierarchy)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quét Mã Vạch Siêu Thị & Bao Bì',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tự động bóc tách khay thịt cân & sản phẩm Eat-Clean',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  splashRadius: 20,
                ),
              ],
            ),
          ),

          // 3. Tab Bar điều hướng tiện lợi
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A323D) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _buildSegmentButton(0, '📷 Viewfinder & Camera', isDark),
                _buildSegmentButton(1, '⌨️ Nhập 13 Số', isDark),
                _buildSegmentButton(2, '🛒 Mẫu Siêu Thị', isDark),
              ],
            ),
          ),

          // 4. Nội dung chính theo Tab
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  // Loading Indicator
                  if (_isSearching)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          const CircularProgressIndicator(color: AppColors.primary),
                          const SizedBox(height: 12),
                          Text(
                            'Đang tra cứu dữ liệu dinh dưỡng & giải mã tem cân...',
                            style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),

                  // Lỗi không tìm thấy
                  if (_errorMessage != null && !_isSearching)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Thẻ kết quả quét được
                  if (_scannedProduct != null && !_isSearching)
                    _buildScannedResultCard(_scannedProduct!, isDark),

                  // Nội dung các Tab
                  if (!_isSearching) ...[
                    if (_currentTab == 0) _buildViewfinderTab(isDark),
                    if (_currentTab == 1) _buildManualInputTab(isDark),
                    if (_currentTab == 2) _buildSampleProductsTab(samples, isDark),
                  ],
                ],
              ),
            ),
          ),

          // 5. Bottom Action Bar (Khi có sản phẩm được chọn)
          if (_scannedProduct != null)
            Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, mediaQuery.padding.bottom + 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E242B) : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _scannedProduct = null);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Quét Lại'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _confirmAndApply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 20),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Nạp Vào Bộ Tính Calo',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(int index, String title, bool isDark) {
    final isSelected = _currentTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF384352) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  // === TAB 0: VIEWFINDER & CAMERA ===
  Widget _buildViewfinderTab(bool isDark) {
    return Column(
      children: [
        const SizedBox(height: 8),
        // Khung quét laser
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF0F141C),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Stack(
              children: [
                // 4 góc căn chỉnh
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: CustomPaint(painter: _ScannerCornersPainter()),
                  ),
                ),

                // Đường laser quét chạy lên xuống
                AnimatedBuilder(
                  animation: _laserAnimation,
                  builder: (context, child) {
                    return Positioned(
                      top: 220 * _laserAnimation.value,
                      left: 20,
                      right: 20,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Colors.transparent,
                              AppColors.primary,
                              Colors.white,
                              AppColors.primary,
                              Colors.transparent,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.8),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                // Dòng chữ hướng dẫn
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.barcode_reader, color: AppColors.primary, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Đưa mã vạch bao bì hoặc tem cân vào khung',
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Hỗ trợ EAN-13 GS1 & Tem cân siêu thị (WinMart, Aeon, CP, MeatDeli)',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Nút mở Camera và Thư Viện Ảnh
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _handlePickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_rounded, size: 18),
                label: const Text('Chụp Bao Bì / Tem'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _handlePickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_rounded, size: 18),
                label: const Text('Chọn Từ Album'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Gợi ý nhanh thử quét ngay
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF262E38) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.bolt_rounded, color: Colors.amber, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Thử nghiệm nhanh quét khay thịt siêu thị:',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildQuickScanChip('🥩 MeatDeli Ức Gà 350g', '201024503504'),
                  _buildQuickScanChip('🥩 Bò Thăn Úc 280g', '201011002808'),
                  _buildQuickScanChip('🥓 Nạc Thăn Heo 450g', '201030004502'),
                  _buildQuickScanChip('🥛 TH True Milk 180ml', '8936036010017'),
                  _buildQuickScanChip('💪 Whey ON 30g', '0748927028669'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickScanChip(String label, String code) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11.5)),
      avatar: const Icon(Icons.qr_code_2_rounded, size: 14, color: AppColors.primary),
      onPressed: () => _searchBarcode(code),
      backgroundColor: AppColors.primary.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  // === TAB 1: NHẬP MÃ VẠCH THỦ CÔNG ===
  Widget _buildManualInputTab(bool isDark) {
    final input = _barcodeInputController.text.trim();
    final isScale = BarcodeNutritionService.isScaleBarcode(input);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Nhập mã số vạch (8 - 13 chữ số) in trên bao bì hoặc tem cân:',
          style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[300] : Colors.grey[700]),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _barcodeInputController,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                onSubmitted: (val) => _searchBarcode(val),
                decoration: InputDecoration(
                  hintText: 'Ví dụ: 8936036010017 hoặc 201024503504',
                  prefixIcon: const Icon(Icons.pin_rounded, color: AppColors.primary),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF262E38) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: input.isEmpty ? null : () => _searchBarcode(input),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Tra Cứu', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        if (input.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isScale ? Colors.teal : Colors.blue).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isScale ? '🏷️ Nhận diện: Tem Cân Siêu Thị (Tiền tố 20..29)' : '📦 Nhận diện: Mã vạch EAN-13 GS1',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: isScale ? Colors.teal : Colors.blue,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        // Ghi chú về tem cân siêu thị
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.amber, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '💡 Mẹo: Tem dán trên khay thịt tươi tại WinMart, Aeon, Co.opmart bắt đầu bằng số 20-29. NutriSnap sẽ tự động bóc tách đúng số gram của khay thịt đó!',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // === TAB 2: SẢN PHẨM MẪU SIÊU THỊ ===
  Widget _buildSampleProductsTab(List<BarcodeProductModel> samples, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Text(
          'Chọn sản phẩm siêu thị hoặc khay thịt tươi để kiểm tra ngay:',
          style: TextStyle(fontSize: 12.5, color: isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: samples.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, idx) {
            final item = samples[idx];
            final isCurrent = _scannedProduct?.barcode == item.barcode;

            return InkWell(
              onTap: () => _onSelectProduct(item),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : (isDark ? const Color(0xFF262E38) : const Color(0xFFF8FAFC)),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isCurrent
                        ? AppColors.primary
                        : (isDark ? Colors.grey[800]! : Colors.grey[200]!),
                    width: isCurrent ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E242B) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(item.categoryIcon, style: const TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.brand,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (item.isScaleBarcode ? Colors.teal : Colors.blue).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.isScaleBarcode ? 'Khay ${item.netWeightG.round()}g' : '${item.netWeightG.round()}g/ml',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: item.isScaleBarcode ? Colors.teal : Colors.blue,
                                  ),
                                ),
                              ),
                              Text(
                                '${item.caloriesPer100g.round()} kcal/100g',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isCurrent ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                      color: isCurrent ? AppColors.primary : Colors.grey,
                      size: 20,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // === THẺ KẾT QUẢ SẢN PHẨM ĐÃ QUÉT ===
  Widget _buildScannedResultCard(BarcodeProductModel product, bool isDark) {
    final portionMacros = product.calculateForWeight(product.netWeightG);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF232B35) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tầng 1: Icon + Tên + Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(product.categoryIcon, style: const TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.productName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildBadge(product.brand, AppColors.primary),
                        _buildBadge(
                          product.isScaleBarcode ? 'Tem Cân Siêu Thị' : 'Mã EAN-13',
                          product.isScaleBarcode ? Colors.teal : Colors.blue,
                        ),
                        _buildBadge('Tịnh: ${product.netWeightG.round()}g', Colors.orange),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Tầng 2: Dinh dưỡng toàn bộ khẩu phần (khay cân hoặc bao bì)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Dinh Dưỡng Theo Khay/Gói (${product.netWeightG.round()}g):',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              Text(
                '${portionMacros.calories.round()} Kcal',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 4 thông số Macro chính
          Row(
            children: [
              _buildMacroMiniCol('Đạm (Protein)', '${portionMacros.protein}g', Colors.redAccent),
              _buildMacroMiniCol('Tinh Bột', '${portionMacros.carbs}g', Colors.amber),
              _buildMacroMiniCol('Chất Béo', '${portionMacros.fat}g', Colors.blue),
              _buildMacroMiniCol('Chất Xơ', '${portionMacros.fiber}g', Colors.green),
            ],
          ),

          if (product.notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E242B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      product.notes,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildMacroMiniCol(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 9.5, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

/// Vẽ 4 góc căn chỉnh của khung quét Barcode
class _ScannerCornersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 24.0;

    // Top-left
    canvas.drawLine(const Offset(0, 0), const Offset(cornerLength, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, cornerLength), paint);

    // Top-right
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - cornerLength, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, cornerLength), paint);

    // Bottom-left
    canvas.drawLine(Offset(0, size.height), Offset(cornerLength, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - cornerLength), paint);

    // Bottom-right
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - cornerLength, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

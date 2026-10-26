import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../constants/app_colors.dart';
import '../models/barcode_product_model.dart';
import '../models/fridge_item_model.dart';
import '../services/barcode_nutrition_service.dart';
import '../services/fridge_service.dart';

/// Modal Quét Mã Vạch Siêu Thị & Bao Bì Thực Phẩm
/// Hỗ trợ:
/// 1. Quét Camera thời gian thực siêu tốc (<0.05s) bằng Google ML Kit
/// 2. Chụp ảnh / Chọn ảnh từ thư viện để AI Vision đọc bao bì
/// 3. Nhập mã vạch 13 số trực tiếp
/// 4. Danh sách các khay thịt & đồ gym mẫu siêu thị thực tế
class BarcodeScannerSheet extends StatefulWidget {
  final int initialMode; // 0: Ăn ngay & Tính Calo, 1: Cất vào Tủ Lạnh

  const BarcodeScannerSheet({super.key, this.initialMode = 0});

  static Future<BarcodeProductModel?> show(BuildContext context, {int initialMode = 0}) {
    return showModalBottomSheet<BarcodeProductModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BarcodeScannerSheet(initialMode: initialMode),
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
  MobileScannerController? _scannerController;

  int _operatingMode = 0; // 0: Nhật ký ăn uống, 1: Cất vào Tủ lạnh
  DateTime _nsxDate = DateTime.now();
  DateTime _hsdDate = DateTime.now().add(const Duration(days: 4));
  String _storageLocation = 'fridge'; // 'fridge', 'freezer', 'pantry'

  int _currentTab = 0; // 0: Viewfinder & Camera, 1: Nhập tay, 2: Sản phẩm mẫu
  bool _isSearching = false;
  bool _isFlashOn = false;
  String? _lastScannedCode;
  DateTime? _lastScannedTime;
  String? _scannedRawCode;
  BarcodeFormat? _scannedFormat;
  String? _errorMessage;
  BarcodeProductModel? _scannedProduct;
  bool _cameraInitialized = false;
  bool _cameraError = false;
  String? _cameraErrorMessage;

  @override
  void initState() {
    super.initState();
    _operatingMode = widget.initialMode;
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(parent: _laserController, curve: Curves.easeInOut),
    );

    _initMobileScanner();
  }

  void _initMobileScanner() {
    try {
      _scannerController = MobileScannerController(
        autoStart: !kIsWeb, // Trên web không tự động start ngay trong constructor để tránh uncaught browser exception
        detectionSpeed: DetectionSpeed.noDuplicates,
        detectionTimeoutMs: 800,
        facing: CameraFacing.back,
        torchEnabled: false,
        formats: const [
          BarcodeFormat.ean13,
          BarcodeFormat.ean8,
          BarcodeFormat.upcA,
          BarcodeFormat.upcE,
          BarcodeFormat.code128,
          BarcodeFormat.code39,
          BarcodeFormat.qrCode,
        ],
      );

      if (kIsWeb) {
        // Trên web, khởi động sau khi render frame đầu tiên với try-catch an toàn
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _startWebScannerSafely();
        });
      } else {
        _cameraInitialized = true;
      }
    } catch (e) {
      debugPrint('[BarcodeScanner] Error creating MobileScannerController: $e');
      _cameraError = true;
      _cameraErrorMessage = e.toString();
      _scannerController = null;
    }
  }

  Future<void> _startWebScannerSafely() async {
    if (!mounted || _scannerController == null) return;
    try {
      await _scannerController!.start();
      if (mounted) {
        setState(() {
          _cameraInitialized = true;
          _cameraError = false;
        });
      }
    } catch (e) {
      debugPrint('[BarcodeScanner] Web camera start caught gracefully: $e');
      if (mounted) {
        setState(() {
          _cameraError = true;
          _cameraErrorMessage = 'Trình duyệt chưa cho phép mở camera hoặc không tìm thấy webcam.';
        });
      }
    }
  }

  @override
  void dispose() {
    _laserController.dispose();
    _barcodeInputController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_isSearching || _scannedProduct != null) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcodeItem = barcodes.first;
    final code = barcodeItem.rawValue;
    if (code == null || code.trim().isEmpty) return;
    final clean = code.trim();

    // Tránh quét liên tục cùng 1 mã trong 3 giây
    final now = DateTime.now();
    if (_lastScannedCode == clean && _lastScannedTime != null && now.difference(_lastScannedTime!).inSeconds < 3) {
      return;
    }

    _lastScannedCode = clean;
    _lastScannedTime = now;
    _scannedRawCode = clean;
    _scannedFormat = barcodeItem.format;

    if (!kIsWeb) {
      try {
        HapticFeedback.mediumImpact();
      } catch (_) {}
    }
    _searchBarcode(clean);
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
          _setupDatesForProduct(product);
        } else {
          _errorMessage = 'Không tìm thấy thông tin cho mã vạch "$clean" trên CSDL Open Food Facts hay iCheck Việt Nam. Vui lòng kiểm tra lại hoặc chụp ảnh bao bì.';
        }
      });
    }
  }

  void _setupDatesForProduct(BarcodeProductModel product) {
    DateTime? parsedNsx = product.manufacturingDate != null ? DateTime.tryParse(product.manufacturingDate!) : null;
    DateTime? parsedHsd = product.expirationDate != null ? DateTime.tryParse(product.expirationDate!) : null;

    _nsxDate = parsedNsx ?? DateTime.now();
    if (parsedHsd != null) {
      _hsdDate = parsedHsd;
    } else {
      final days = FridgeService.instance.getSuggestedShelfLifeDays(product.productName, category: product.category);
      _hsdDate = DateTime.now().add(Duration(days: days));
    }
    if (product.storageRecommendation != null && product.storageRecommendation!.contains('đông')) {
      _storageLocation = 'freezer';
    } else if (product.storageRecommendation != null && product.storageRecommendation!.contains('khô')) {
      _storageLocation = 'pantry';
    } else {
      _storageLocation = 'fridge';
    }
  }

  Future<void> _handlePickImage(ImageSource source) async {
    try {
      final actualSource = kIsWeb ? ImageSource.gallery : source;
      final photo = await _picker.pickImage(
        source: actualSource,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (photo == null) return;

      setState(() {
        _isSearching = true;
        _errorMessage = null;
        _scannedProduct = null;
      });

      final bytes = await photo.readAsBytes();
      final product = await BarcodeNutritionService.scanBarcodeFromImage(bytes);

      if (mounted) {
        setState(() {
          _isSearching = false;
          if (product != null) {
            _scannedProduct = product;
            _scannedRawCode = product.barcode;
            _scannedFormat = product.barcodeType.toLowerCase().contains('qr') ? BarcodeFormat.qrCode : BarcodeFormat.ean13;
            _setupDatesForProduct(product);
          } else {
            _errorMessage = 'Không nhận diện được mã vạch hoặc tem siêu thị từ ảnh này. Vui lòng chụp rõ góc tem cân hoặc nhập 13 số.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _errorMessage = 'Lỗi truy cập máy ảnh: $e';
        });
      }
    }
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

          // 2.1. Chuyển đổi 2 Chế Độ Hoạt Động
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF262D37) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _operatingMode = 0),
                    borderRadius: BorderRadius.circular(13),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _operatingMode == 0
                            ? (isDark ? const Color(0xFF1E242B) : Colors.white)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: _operatingMode == 0
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🍽️', style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 6),
                          Text(
                            'Ăn Ngay & Ghi Calo',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: _operatingMode == 0 ? FontWeight.bold : FontWeight.w500,
                              color: _operatingMode == 0 ? AppColors.primaryDark : AppColors.textGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _operatingMode = 1),
                    borderRadius: BorderRadius.circular(13),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _operatingMode == 1
                            ? (isDark ? const Color(0xFF1E242B) : Colors.white)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: _operatingMode == 1
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🧊', style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 6),
                          Text(
                            'Cất Tủ Lạnh (Theo dõi HSD)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: _operatingMode == 1 ? FontWeight.bold : FontWeight.w500,
                              color: _operatingMode == 1 ? AppColors.primaryDark : AppColors.textGray,
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
                _buildSegmentButton(0, '📷 Quét Trực Tiếp', isDark),
                _buildSegmentButton(1, '⌨️ Nhập Mã Số / Link', isDark),
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

                  // Nội dung các Tab (chỉ hiển thị camera/nhập liệu khi chưa có sản phẩm được quét)
                  if (!_isSearching && _scannedProduct == null) ...[
                    if (_currentTab == 0) _buildViewfinderTab(isDark),
                    if (_currentTab == 1) _buildManualInputTab(isDark),
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
                        setState(() {
                          _scannedProduct = null;
                          _scannedRawCode = null;
                          _scannedFormat = null;
                          _errorMessage = null;
                        });
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
                      onPressed: () {
                        if (_operatingMode == 0) {
                          _confirmAndApply();
                        } else {
                          final prod = _scannedProduct!;
                          FridgeService.instance.addItem(
                            FridgeItemModel(
                              id: 'barcode_${prod.barcode}_${DateTime.now().millisecondsSinceEpoch}',
                              name: prod.productName,
                              category: prod.category,
                              categoryIcon: prod.categoryIcon,
                              quantity: '${prod.netWeightG.toInt()}g',
                              netWeightG: prod.netWeightG,
                              storageLocation: _storageLocation,
                              manufacturingDate: _nsxDate,
                              expirationDate: _hsdDate,
                              addedAt: DateTime.now(),
                              barcode: prod.barcode,
                              caloriesPer100g: prod.caloriesPer100g,
                              proteinPer100g: prod.proteinPer100g,
                              carbsPer100g: prod.carbsPer100g,
                              fatPer100g: prod.fatPer100g,
                              notes: prod.notes,
                            ),
                          );
                          Navigator.pop(context, prod);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✅ Đã cất "${prod.productName}" vào Tủ Lạnh (HSD: ${_hsdDate.day}/${_hsdDate.month})!'),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_operatingMode == 1 ? Icons.inventory_2_rounded : Icons.check_circle_rounded, size: 20),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _operatingMode == 1 ? 'Cất Vào Tủ Lạnh' : 'Nạp Vào Bộ Tính Calo',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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

  // === TAB 0: VIEWFINDER & CAMERA (GOOGLE ML KIT REAL-TIME SCANNER) ===
  Widget _buildViewfinderTab(bool isDark) {
    final showLiveCamera = _currentTab == 0 &&
        _scannedProduct == null &&
        _scannerController != null &&
        _cameraInitialized &&
        !_cameraError;

    return Column(
      children: [
        const SizedBox(height: 8),
        // Khung quét camera thời gian thực với Google ML Kit / Web ZXing
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 250,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF0F141C),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 1.5),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Live Camera Barcode Scanner hoặc Fallback Card an toàn
                if (showLiveCamera)
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: _onBarcodeDetected,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error) {
                      return _buildCameraFallbackView(
                        isDark,
                        message: 'Không thể mở luồng camera (${error.errorCode.name}). Bạn có thể tải ảnh bao bì từ máy tính!',
                      );
                    },
                  )
                else
                  _buildCameraFallbackView(
                    isDark,
                    message: kIsWeb
                        ? 'Trình duyệt Web chưa cấp quyền camera hoặc máy tính không có webcam. Bạn có thể tải ảnh bao bì từ máy tính hoặc dùng danh sách mẫu!'
                        : (_cameraErrorMessage ?? 'Không thể kết nối máy ảnh. Vui lòng kiểm tra quyền truy cập.'),
                  ),

                // 2. 4 góc căn chỉnh
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: CustomPaint(painter: _ScannerCornersPainter()),
                  ),
                ),

                // 3. Đường laser quét chạy lên xuống (khi camera hoặc chế độ quét sẵn sàng)
                if (showLiveCamera)
                  AnimatedBuilder(
                    animation: _laserAnimation,
                    builder: (context, child) {
                      return Positioned(
                        top: 250 * _laserAnimation.value,
                        left: 24,
                        right: 24,
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

                // 4. Các nút điều khiển nhanh (Bật/Tắt Flash & Đổi Camera)
                if (showLiveCamera && !kIsWeb)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            iconSize: 20,
                            icon: Icon(
                              _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                              color: _isFlashOn ? Colors.amber : Colors.white,
                            ),
                            tooltip: 'Bật/Tắt đèn pin',
                            onPressed: () async {
                              try {
                                await _scannerController?.toggleTorch();
                                if (mounted) setState(() => _isFlashOn = !_isFlashOn);
                              } catch (_) {}
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            iconSize: 20,
                            icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white),
                            tooltip: 'Đổi camera trước/sau',
                            onPressed: () async {
                              try {
                                await _scannerController?.switchCamera();
                              } catch (_) {}
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                // 5. Badge nhãn hướng dẫn phía dưới
                Positioned(
                  bottom: 12,
                  left: 16,
                  right: 16,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt_rounded, color: AppColors.primary, size: 16),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              kIsWeb
                                  ? 'Web Mode: Quét Webcam hoặc Tải Ảnh Bao Bì Máy Tính'
                                  : 'Google ML Kit: Tự động bắt mã vạch tức thì (<0.05s)',
                              style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
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

        const SizedBox(height: 16),

        // Nút mở Camera và Thư Viện Ảnh (Tối ưu cho cả Web và Mobile)
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _handlePickImage(kIsWeb ? ImageSource.gallery : ImageSource.camera),
                icon: const Icon(kIsWeb ? Icons.upload_file_rounded : Icons.camera_alt_rounded, size: 18),
                label: const Text(kIsWeb ? 'Tải Ảnh Bao Bì' : 'Chụp Bao Bì / Tem'),
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

        // Hướng dẫn tra cứu CSDL bên thứ 3
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
              Row(
                children: [
                  const Icon(Icons.public_rounded, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Tra Cứu Trực Tiếp CSDL Bên Thứ 3',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Mỗi khi quét hoặc nhập mã vạch/QR, ứng dụng sẽ gửi yêu cầu trực tiếp đến Cơ sở Dữ liệu Thực phẩm Mở Quốc tế (Open Food Facts API) và bóc tách thông số dinh dưỡng thực tế từ nhãn bao bì.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.4,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCameraFallbackView(bool isDark, {required String message}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              kIsWeb ? Icons.photo_camera_back_rounded : Icons.videocam_off_rounded,
              color: AppColors.primary,
              size: 34,
            ),
            const SizedBox(height: 8),
            const Text(
              kIsWeb ? 'Chế độ Quét Trên Web (Chrome)' : 'Không Thể Mở Camera',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: TextStyle(color: Colors.grey[300], fontSize: 11, height: 1.3),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _handlePickImage(ImageSource.gallery),
                  icon: const Icon(Icons.upload_file_rounded, size: 15),
                  label: const Text('Chọn file ảnh bao bì', style: TextStyle(fontSize: 11.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  ),
                ),
                if (kIsWeb)
                  OutlinedButton.icon(
                    onPressed: _startWebScannerSafely,
                    icon: const Icon(Icons.refresh_rounded, size: 15, color: Colors.white),
                    label: const Text('Thử mở Webcam', style: TextStyle(fontSize: 11.5, color: Colors.white)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white38),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
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
                  hintText: 'Ví dụ: 3017620422003, 5449000000996 hoặc đường link QR...',
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
                  isScale ? 'Nhận diện: Tem Cân Siêu Thị (Tiền tố 20..29)' : 'Nhận diện: Mã vạch chuẩn EAN-13 / UPC / QR',
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
            color: Colors.blue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.blue, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tem dán trên khay thực phẩm tươi sống có tiền tố 20-29 sẽ tự động được trích xuất khối lượng tịnh (gam) trực tiếp từ cấu trúc mã số vạch.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // === THẺ THÔNG SỐ SẢN PHẨM & DINH DƯỠNG TRÍCH XUẤT TỪ MÃ VẠCH (CSDL BÊN THỨ 3) ===
  Widget _buildScannedResultCard(BarcodeProductModel product, bool isDark) {
    final isQr = product.barcodeType.contains('QR') || _scannedFormat == BarcodeFormat.qrCode;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF232B35) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isQr ? Colors.purple : AppColors.primary,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isQr ? Colors.purple : AppColors.primary).withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Dãy mã vạch thực tế & Nguồn CSDL Bên Thứ 3
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A222C) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isQr ? Colors.purple.withValues(alpha: 0.3) : AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isQr ? Icons.qr_code_2_rounded : Icons.barcode_reader,
                  size: 20,
                  color: isQr ? Colors.purple : AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isQr ? 'MÃ QR THỰC TẾ:' : 'MÃ VẠCH THỰC TẾ:',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.4,
                              color: isQr ? Colors.purple : AppColors.primary,
                            ),
                          ),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                product.source.isNotEmpty ? product.source : 'CSDL Bên Thứ 3',
                                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.primary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _scannedRawCode ?? product.barcode,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 2. Thông tin chính thức từ CSDL: Tên + Hãng + Khối lượng (Có ảnh thật từ OpenFoodFacts nếu có)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (product.imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    product.imageUrl,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: (isQr ? Colors.purple : AppColors.primary).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.qr_code_scanner_rounded, color: isQr ? Colors.purple : AppColors.primary, size: 28),
                    ),
                  ),
                )
              else
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: (isQr ? Colors.purple : AppColors.primary).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.inventory_2_outlined, color: isQr ? Colors.purple : AppColors.primary, size: 28),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.productName,
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (product.brand.isNotEmpty)
                          _buildBadge(product.brand, AppColors.primary),
                        _buildBadge(product.barcodeType, isQr ? Colors.purple : Colors.blue),
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
          const SizedBox(height: 10),

          // 3. Bảng Dinh Dưỡng Thực Tế (Nutrition Facts trên 100g)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Bảng Thông Số Dinh Dưỡng (100g):',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
              Text(
                '${product.caloriesPer100g.round()} Kcal',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 4 thông số chính: Đạm, Tinh bột, Béo, Xơ
          Row(
            children: [
              _buildMacroMiniCol('Đạm (Protein)', '${product.proteinPer100g}g', Colors.redAccent),
              _buildMacroMiniCol('Tinh Bột (Carbs)', '${product.carbsPer100g}g', Colors.amber),
              _buildMacroMiniCol('Chất Béo (Fat)', '${product.fatPer100g}g', Colors.blue),
              _buildMacroMiniCol('Chất Xơ (Fiber)', '${product.fiberPer100g}g', Colors.green),
            ],
          ),

          // Thông số chi tiết phụ: Đường, Chất béo bão hòa, Natri
          if (product.sugarsPer100g != null || product.saturatedFatPer100g != null || product.sodiumMg != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E242B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  if (product.sugarsPer100g != null)
                    Text('Đường: ${product.sugarsPer100g}g', style: const TextStyle(fontSize: 11)),
                  if (product.saturatedFatPer100g != null)
                    Text('Béo bão hòa: ${product.saturatedFatPer100g}g', style: const TextStyle(fontSize: 11)),
                  if (product.sodiumMg != null)
                    Text('Natri: ${product.sodiumMg!.round()}mg', style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ],

          // 4. Thành phần nguyên liệu thực tế từ nhãn bao bì
          if (product.ingredientsText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E242B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Thành Phần Nguyên Liệu (Trên Bao Bì):',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    product.ingredientsText,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],

          // 5. Cấu hình Lưu Trữ & Hạn Sử Dụng (Chế độ Tủ Lạnh)
          if (_operatingMode == 1) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E242B) : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('🧊', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Thiết Lập Lưu Trữ & Hạn Dùng',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          product.expirationDate != null ? '⚡ OCR nhận diện' : '💡 HSD gợi ý',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  const Text('Vị trí cất:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('❄️ Ngăn mát', style: TextStyle(fontSize: 11)),
                        selected: _storageLocation == 'fridge',
                        onSelected: (_) => setState(() => _storageLocation = 'fridge'),
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: const Text('🧊 Ngăn đông', style: TextStyle(fontSize: 11)),
                        selected: _storageLocation == 'freezer',
                        onSelected: (_) => setState(() => _storageLocation = 'freezer'),
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: const Text('📦 Tủ khô', style: TextStyle(fontSize: 11)),
                        selected: _storageLocation == 'pantry',
                        onSelected: (_) => setState(() => _storageLocation = 'pantry'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Ngày SX (NSX)', style: TextStyle(fontSize: 10, color: AppColors.textGray)),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${_nsxDate.day}/${_nsxDate.month}/${_nsxDate.year}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: _nsxDate,
                                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                        lastDate: DateTime.now(),
                                      );
                                      if (picked != null) setState(() => _nsxDate = picked);
                                    },
                                    child: const Icon(Icons.edit_calendar_rounded, size: 16, color: AppColors.primary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Hạn Dùng (HSD)', style: TextStyle(fontSize: 10, color: Colors.red)),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${_hsdDate.day}/${_hsdDate.month}/${_hsdDate.year}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
                                  ),
                                  InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: _hsdDate,
                                        firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                        lastDate: DateTime.now().add(const Duration(days: 730)),
                                      );
                                      if (picked != null) setState(() => _hsdDate = picked);
                                    },
                                    child: const Icon(Icons.edit_calendar_rounded, size: 16, color: Colors.red),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _scannedProduct = null;
                _scannedRawCode = null;
                _scannedFormat = null;
                _errorMessage = null;
              });
            },
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Quét mã khác (Mở lại camera)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(38),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
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

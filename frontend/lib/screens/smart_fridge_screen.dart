import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/app_colors.dart';
import '../models/fridge_item_model.dart';
import '../services/fridge_service.dart';
import '../services/ai_vision_service.dart';
import '../widgets/barcode_scanner_sheet.dart';

/// Màn hình Quản Lý Tủ Lạnh & Hạn Dùng Thực Phẩm (Smart Fridge & Pantry)
class SmartFridgeScreen extends StatefulWidget {
  final Function(int) onNavigate;

  const SmartFridgeScreen({super.key, required this.onNavigate});

  @override
  State<SmartFridgeScreen> createState() => _SmartFridgeScreenState();
}

class _SmartFridgeScreenState extends State<SmartFridgeScreen> {
  final fridgeService = FridgeService.instance;
  final TextEditingController _searchController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String _selectedTab = 'all'; // 'all', 'fridge', 'freezer', 'pantry', 'expiring'
  bool _isAiScanning = false;

  @override
  void initState() {
    super.initState();
    fridgeService.addListener(_onStateChange);
    fridgeService.init();
  }

  @override
  void dispose() {
    fridgeService.removeListener(_onStateChange);
    _searchController.dispose();
    super.dispose();
  }

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final allItems = fridgeService.items;
    final expiringCount = fridgeService.expiringCount;

    final filteredItems = fridgeService.getFilteredItems(
      storageLocation: _selectedTab == 'expiring' ? null : _selectedTab,
      expiringOnly: _selectedTab == 'expiring',
      searchQuery: _searchController.text,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textBlack, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          children: [
            Text('🧊', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text(
              'Tủ Lạnh Thông Minh',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textBlack),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.accentMint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${allItems.length} món',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isAiScanning)
            const LinearProgressIndicator(color: AppColors.primary, minHeight: 3),

          // 1. THANH TỔNG HỢP TRẠNG THÁI HẠN DÙNG
          _buildSummaryStatusHeader(allItems),

          // 2. Ô TÌM KIẾM
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Tìm thực phẩm trong tủ lạnh...',
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.textGray),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textGray, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: AppColors.textGray),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
              ),
            ),
          ),

          // 3. TABS PHÂN LOẠI VỊ TRÍ & HẠN DÙNG
          _buildFilterTabs(allItems.length, expiringCount),

          // 4. DANH SÁCH THỰC PHẨM
          Expanded(
            child: filteredItems.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 88),
                    itemCount: filteredItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      return _buildFridgeItemCard(item);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddFoodBottomSheet,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Thêm Thực Phẩm',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildSummaryStatusHeader(List<FridgeItemModel> allItems) {
    int freshCount = 0;
    int expiringSoonCount = 0;
    int expiredCount = 0;

    for (var i in allItems) {
      if (i.isExpired || i.isExpiringToday) {
        expiredCount++;
      } else if (i.isExpiringSoon) {
        expiringSoonCount++;
      } else {
        freshCount++;
      }
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatPill('🟢 Tươi ngon', '$freshCount', const Color(0xFF10B981)),
          Container(width: 1, height: 28, color: Colors.grey.shade200),
          _buildStatPill('🟡 Cần nấu gấp', '$expiringSoonCount', const Color(0xFFF59E0B)),
          Container(width: 1, height: 28, color: Colors.grey.shade200),
          _buildStatPill('🔴 Đã quá hạn', '$expiredCount', const Color(0xFFEF4444)),
        ],
      ),
    );
  }

  Widget _buildStatPill(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textGray)),
      ],
    );
  }

  Widget _buildFilterTabs(int totalCount, int expiringCount) {
    final tabs = [
      {'id': 'all', 'label': 'Tất cả ($totalCount)'},
      {'id': 'expiring', 'label': '⚠️ Cần nấu ($expiringCount)'},
      {'id': 'fridge', 'label': '❄️ Ngăn mát'},
      {'id': 'freezer', 'label': '🧊 Ngăn đông'},
      {'id': 'pantry', 'label': '📦 Đồ khô'},
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final isSelected = _selectedTab == tab['id'];
          return ChoiceChip(
            label: Text(
              tab['label']!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : AppColors.textBlack,
              ),
            ),
            selected: isSelected,
            selectedColor: AppColors.primary,
            backgroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isSelected ? AppColors.primary : Colors.grey.shade200,
              ),
            ),
            onSelected: (_) {
              setState(() {
                _selectedTab = tab['id']!;
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildFridgeItemCard(FridgeItemModel item) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (item.isExpired || item.isExpiringToday)
              ? const Color(0xFFFCA5A5)
              : (item.isExpiringSoon ? const Color(0xFFFCD34D) : Colors.grey.shade200),
          width: (item.isExpired || item.isExpiringSoon || item.isExpiringToday) ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dòng 1: Icon, Tên, Trạng thái HSD
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: item.statusBackgroundColor.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(item.categoryIcon, style: const TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          '${item.storageLocationIcon} ${item.storageLocationName}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textGray),
                        ),
                        const SizedBox(width: 6),
                        const Text('•', style: TextStyle(fontSize: 11, color: AppColors.textGray)),
                        const SizedBox(width: 6),
                        Text(
                          item.quantity,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: item.statusBackgroundColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  item.statusLabel,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: item.statusColor),
                ),
              ),
            ],
          ),

          // Dòng 2: Chi tiết NSX / HSD
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'NSX: ${item.manufacturingDate != null ? "${item.manufacturingDate!.day}/${item.manufacturingDate!.month}/${item.manufacturingDate!.year}" : "Mới mua"}',
                  style: const TextStyle(fontSize: 10, color: AppColors.textGray),
                ),
                Text(
                  'HSD: ${item.expirationDate.day}/${item.expirationDate.month}/${item.expirationDate.year}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: item.isExpired ? Colors.red : const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Dòng 3: Nút Thao Tác (Gợi ý nấu ăn / Đã dùng / Xóa)
          Row(
            children: [
              // Nút 1: Nấu món ăn với nguyên liệu này
              Expanded(
                flex: 3,
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    widget.onNavigate(4); // Mở IngredientScanScreen
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('🍴 Đã chọn "${item.name}" để tìm công thức nấu ăn!'),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.restaurant_menu_rounded, size: 14, color: AppColors.primaryDark),
                        SizedBox(width: 4),
                        Text(
                          'Nấu món này',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Nút 2: Đã dùng món
              Expanded(
                flex: 3,
                child: InkWell(
                  onTap: () => _confirmConsumeItem(item),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF475569)),
                        SizedBox(width: 4),
                        Text(
                          'Đã dùng',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Nút 3: Xóa
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.grey),
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  fridgeService.deleteItem(item.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Đã bỏ "${item.name}" khỏi tủ lạnh.'),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🥗', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text(
            'Không có thực phẩm nào phù hợp',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textBlack),
          ),
          const SizedBox(height: 4),
          const Text(
            'Bấm nút "+ Thêm Thực Phẩm" bên dưới để cất đồ vào tủ.',
            style: TextStyle(fontSize: 12, color: AppColors.textGray),
          ),
        ],
      ),
    );
  }

  void _confirmConsumeItem(FridgeItemModel item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Text(item.categoryIcon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            const Text('Xác nhận dùng món', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Bạn đã dùng hết "${item.name}"? Hệ thống sẽ trừ khỏi tủ lạnh và ghi nhận dinh dưỡng (${item.caloriesPer100g.toInt()} kcal / 100g) vào Nhật Ký Ăn Uống hôm nay.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: AppColors.textGray)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await fridgeService.consumeItem(item.id, logToMealJournal: true, mealType: 'lunch');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ Đã dùng "${item.name}" và cập nhật vào Nhật Ký!'),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Dùng & Ghi Calo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Modal chọn 3 phương thức thêm thực phẩm vào tủ lạnh
  void _showAddFoodBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Thêm Thực Phẩm Vào Tủ Lạnh',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textBlack),
              ),
              const SizedBox(height: 4),
              const Text(
                'Chọn phương thức tiện lợi nhất cho bạn:',
                style: TextStyle(fontSize: 12, color: AppColors.textGray),
              ),
              const SizedBox(height: 18),

              // Cách 1: Quét Mã Vạch & Tem Siêu Thị
              _buildAddMethodTile(
                icon: Icons.qr_code_scanner_rounded,
                iconColor: Colors.blue,
                bgColor: const Color(0xFFEFF6FF),
                title: 'Quét Mã Vạch / Tem Siêu Thị',
                subtitle: 'Tự động đọc mã vạch, NSX & HSD từ tem cân',
                onTap: () async {
                  Navigator.pop(ctx);
                  await BarcodeScannerSheet.show(context);
                },
              ),
              const SizedBox(height: 12),

              // Cách 2: Chụp Ảnh Rau Củ / Trái Cây (AI Vision + HSD Thông Minh)
              _buildAddMethodTile(
                icon: Icons.camera_alt_rounded,
                iconColor: AppColors.primary,
                bgColor: AppColors.accentMint,
                title: 'Chụp Ảnh Rau Củ & Trái Cây',
                subtitle: 'AI nhận diện món & tự động đề xuất HSD an toàn',
                onTap: () async {
                  Navigator.pop(ctx);
                  _handleScanProduceWithAi();
                },
              ),
              const SizedBox(height: 12),

              // Cách 3: Nhập Thủ Công
              _buildAddMethodTile(
                icon: Icons.edit_note_rounded,
                iconColor: Colors.deepPurple,
                bgColor: const Color(0xFFF3E8FF),
                title: 'Nhập Thủ Công Bằng Tay',
                subtitle: 'Điền tên món, chọn ngày NSX & HSD tùy ý',
                onTap: () {
                  Navigator.pop(ctx);
                  _showManualAddDialog();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddMethodTile({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textGray)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textLightGray),
          ],
        ),
      ),
    );
  }

  /// Xử lý chụp ảnh rau củ / trái cây bằng AI Vision
  Future<void> _handleScanProduceWithAi() async {
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (photo == null) return;

      setState(() => _isAiScanning = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🧠 AI Vision đang phân tích rau củ & tính toán HSD...'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );

      final bytes = await photo.readAsBytes();
      final aiService = AIVisionService();
      final result = await aiService.analyzeIngredient(bytes);
      final recognized = result.ingredients;

      setState(() => _isAiScanning = false);

      if (recognized.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không nhận diện rõ loại rau củ nào. Vui lòng chụp lại hoặc nhập tay.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Mở modal xác nhận các món rau củ vừa nhận diện
      if (mounted) {
        _showRecognizedProduceSheet(recognized);
      }
    } catch (e) {
      setState(() => _isAiScanning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi quét AI: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  void _showRecognizedProduceSheet(List<DetectedIngredientItem> items) {
    final now = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Đã Nhận Diện Rau Củ / Trái Cây',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textBlack),
              ),
              const SizedBox(height: 4),
              const Text(
                'AI đã tự động gán Hạn Sử Dụng an toàn theo chuẩn bảo quản thực phẩm:',
                style: TextStyle(fontSize: 12, color: AppColors.textGray),
              ),
              const SizedBox(height: 14),

              ...items.map((item) {
                final name = item.name.isNotEmpty ? item.name : item.englishName;
                final shelfDays = fridgeService.getSuggestedShelfLifeDays(name);
                final expDate = now.add(Duration(days: shelfDays));

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      const Text('🥗', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            Text('HSD đề xuất: $shelfDays ngày (tới ${expDate.day}/${expDate.month})',
                                style: const TextStyle(fontSize: 11, color: AppColors.primaryDark)),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          fridgeService.addItem(
                            FridgeItemModel(
                              id: 'ai_${DateTime.now().millisecondsSinceEpoch}_$name',
                              name: name,
                              category: 'Rau củ & Trái cây',
                              categoryIcon: '🥗',
                              quantity: item.weight.isNotEmpty ? item.weight : '1 phần',
                              storageLocation: 'fridge',
                              manufacturingDate: now,
                              expirationDate: expDate,
                              addedAt: now,
                              caloriesPer100g: item.calorieNumber.toDouble(),
                              notes: 'Nhận diện tự động bằng AI Vision',
                            ),
                          );
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✅ Đã cất "$name" vào tủ lạnh (HSD: $shelfDays ngày)!'),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Cất vào tủ', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  /// Dialog nhập thủ công
  void _showManualAddDialog() {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '500g');
    String selectedLocation = 'fridge';
    DateTime nsxDate = DateTime.now();
    DateTime hsdDate = DateTime.now().add(const Duration(days: 4));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Thêm Thực Phẩm Thủ Công', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tên thực phẩm *',
                    hintText: 'Ví dụ: Thịt bò xay, Chuối tiêu, Cải ngọt...',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Số lượng / Khối lượng',
                    hintText: 'Ví dụ: 500g, 2 quả, 1 túi...',
                  ),
                ),
                const SizedBox(height: 14),

                const Text('Vị trí lưu trữ:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('❄️ Ngăn mát', style: TextStyle(fontSize: 11)),
                      selected: selectedLocation == 'fridge',
                      onSelected: (_) => setDialogState(() => selectedLocation = 'fridge'),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('🧊 Ngăn đông', style: TextStyle(fontSize: 11)),
                      selected: selectedLocation == 'freezer',
                      onSelected: (_) => setDialogState(() => selectedLocation = 'freezer'),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('📦 Tủ khô', style: TextStyle(fontSize: 11)),
                      selected: selectedLocation == 'pantry',
                      onSelected: (_) => setDialogState(() => selectedLocation = 'pantry'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Chọn NSX
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('NSX: ${nsxDate.day}/${nsxDate.month}/${nsxDate.year}', style: const TextStyle(fontSize: 12)),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: nsxDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setDialogState(() => nsxDate = picked);
                      },
                      child: const Text('Chọn NSX', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),

                // Chọn HSD
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('HSD: ${hsdDate.day}/${hsdDate.month}/${hsdDate.year}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: hsdDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime.now().add(const Duration(days: 730)),
                        );
                        if (picked != null) setDialogState(() => hsdDate = picked);
                      },
                      child: const Text('Chọn HSD', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy', style: TextStyle(color: AppColors.textGray)),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;

                fridgeService.addItem(
                  FridgeItemModel(
                    id: 'manual_${DateTime.now().millisecondsSinceEpoch}',
                    name: name,
                    category: 'Thực phẩm gia đình',
                    categoryIcon: selectedLocation == 'freezer' ? '🧊' : '🛒',
                    quantity: qtyCtrl.text.trim().isNotEmpty ? qtyCtrl.text.trim() : '1 phần',
                    storageLocation: selectedLocation,
                    manufacturingDate: nsxDate,
                    expirationDate: hsdDate,
                    addedAt: DateTime.now(),
                  ),
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ Đã thêm "$name" vào tủ lạnh!'),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Lưu vào Tủ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

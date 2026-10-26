import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/fridge_item_model.dart';
import '../services/app_state_service.dart';
import '../services/fridge_service.dart';
import '../screens/smart_fridge_screen.dart';

/// Modal Trung Tâm Thông Báo: Cảnh báo Hạn sử dụng Tủ Lạnh & Nhắc nhở Uống Nước
class NotificationCenterSheet extends StatefulWidget {
  final Function(int) onNavigate;

  const NotificationCenterSheet({super.key, required this.onNavigate});

  static Future<void> show(BuildContext context, {required Function(int) onNavigate}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NotificationCenterSheet(onNavigate: onNavigate),
    );
  }

  @override
  State<NotificationCenterSheet> createState() => _NotificationCenterSheetState();
}

class _NotificationCenterSheetState extends State<NotificationCenterSheet> {
  final fridgeService = FridgeService.instance;
  final appState = AppStateService.instance;

  @override
  void initState() {
    super.initState();
    fridgeService.addListener(_onStateChange);
    appState.addListener(_onStateChange);
  }

  @override
  void dispose() {
    fridgeService.removeListener(_onStateChange);
    appState.removeListener(_onStateChange);
    super.dispose();
  }

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  String _getWaterAdvice() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 11) {
      return 'Chào buổi sáng! Một cốc nước ấm sẽ đánh thức hệ tiêu hóa và thúc đẩy trao đổi chất cả ngày.';
    } else if (hour >= 11 && hour < 14) {
      return 'Bữa trưa đến rồi! Uống nước trước khi ăn giúp dạ dày làm việc nhẹ nhàng và tránh ăn quá mức.';
    } else if (hour >= 14 && hour < 18) {
      return 'Buổi chiều cơ thể dễ mất nước dẫn đến buồn ngủ. Bổ sung ngay 1 ly nước mát để lấy lại năng lượng!';
    } else {
      return 'Uống một lượng nước vừa đủ vào buổi tối để hỗ trợ cơ thể thanh lọc và phục hồi suốt đêm.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final expiringItems = fridgeService.expiringItems;
    final waterCurrent = appState.waterIntakeMl;
    final waterGoal = appState.waterGoalMl;
    final waterProgress = (waterCurrent / waterGoal).clamp(0.0, 1.0);
    final isWaterBehind = waterProgress < 0.6 && DateTime.now().hour >= 14;

    final totalAlerts = expiringItems.length + (isWaterBehind ? 1 : 0);

    return Container(
      height: mediaQuery.size.height * 0.82,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E242B) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Handle bar
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
                    color: AppColors.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_active_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trung Tâm Nhắc Nhở',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                      ),
                      Text(
                        'Cảnh báo hạn dùng tủ lạnh & lịch uống nước',
                        style: TextStyle(fontSize: 11, color: AppColors.textGray),
                      ),
                    ],
                  ),
                ),
                if (totalAlerts > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '$totalAlerts thông báo',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: AppColors.textGray),
                ),
              ],
            ),
          ),
          const Divider(height: 18, thickness: 1),

          // Content list
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                // 1. KHU VỰC NHẮC NHỞ UỐNG NƯỚC
                _buildWaterReminderCard(waterCurrent, waterGoal, waterProgress),
                const SizedBox(height: 18),

                // 2. KHU VỰC CẢNH BÁO HẠN DÙNG TỦ LẠNH
                _buildFridgeAlertsSection(expiringItems),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaterReminderCard(int current, int goal, double progress) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDBEAFE), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.water_drop_rounded, color: Colors.blue, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nhắc Nhở Uống Nước Hôm Nay',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                    ),
                    Text(
                      'Mục tiêu: ${(goal / 1000).toStringAsFixed(1)} Lít • Đã uống: ${(current / 1000).toStringAsFixed(1)}L',
                      style: const TextStyle(fontSize: 11, color: AppColors.textGray),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: progress >= 1.0 ? const Color(0xFFD1FAE5) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  progress >= 1.0 ? '🎉 Đạt chỉ tiêu' : '${(progress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: progress >= 1.0 ? const Color(0xFF047857) : Colors.blue.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Lời khuyên theo giờ
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.tips_and_updates_outlined, size: 16, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getWaterAdvice(),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF334155), height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Thanh tiến trình
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ),
          const SizedBox(height: 12),

          // Nút bấm uống nước nhanh
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    appState.addWater(250);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('💧 Tuyệt vời! Đã ghi nhận thêm 250ml nước.'),
                        duration: Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                  label: const Text(
                    'Đã uống 1 ly (+250ml)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  appState.addWater(100);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('💧 Đã ghi nhận +100ml nước.'),
                      duration: Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF93C5FD)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('+100ml', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: () {
                  appState.addWater(500);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('💧 Đã ghi nhận +500ml nước.'),
                      duration: Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF93C5FD)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('+500ml', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFridgeAlertsSection(List<FridgeItemModel> expiringItems) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text('🧊', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                const Text(
                  'Cảnh Báo Hạn Dùng Tủ Lạnh',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                ),
              ],
            ),
            InkWell(
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SmartFridgeScreen(onNavigate: widget.onNavigate)),
                );
              },
              child: const Row(
                children: [
                  Text(
                    'Xem tủ lạnh',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.primary),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (expiringItems.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Row(
              children: [
                Text('🎉', style: TextStyle(fontSize: 26)),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tủ lạnh đang rất an toàn!',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Không có thực phẩm nào sắp hết hạn trong 3 ngày tới.',
                        style: TextStyle(fontSize: 11, color: AppColors.textGray),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: expiringItems.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = expiringItems[index];
              return _buildExpiringItemTile(item);
            },
          ),
      ],
    );
  }

  Widget _buildExpiringItemTile(FridgeItemModel item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: item.statusColor.withOpacity(0.35), width: 1.2),
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
          // Dòng thông tin chính
          Row(
            children: [
              Text(item.categoryIcon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.quantity} • ${item.storageLocationIcon} ${item.storageLocationName}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textGray),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: item.statusBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.statusLabel,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: item.statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Hai nút hành động nhanh
          Row(
            children: [
              // Nút 1: Gợi ý món nấu ngay
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    // Chuyển sang màn hình nhận diện / gợi ý món ăn với nguyên liệu này
                    widget.onNavigate(4); // Index 4: IngredientScanScreen
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('🍴 Đã mở công cụ nấu ăn với "${item.name}"!'),
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
                          'Gợi ý nấu ngay',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Nút 2: Đã dùng món (trừ tủ lạnh & log calo)
              Expanded(
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
                          'Đã dùng món',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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
          'Bạn đã dùng hết "${item.name}"? Hệ thống sẽ trừ khỏi tủ lạnh và có thể ghi nhận calo vào Nhật ký ăn uống hôm nay.',
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
}

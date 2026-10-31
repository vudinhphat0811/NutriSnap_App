import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/step_tracker_service.dart';
import '../services/google_fit_service.dart';

class StepTrackerDetailSheet extends StatefulWidget {
  const StepTrackerDetailSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const StepTrackerDetailSheet(),
    );
  }

  @override
  State<StepTrackerDetailSheet> createState() => _StepTrackerDetailSheetState();
}

class _StepTrackerDetailSheetState extends State<StepTrackerDetailSheet> {
  final _stepService = StepTrackerService.instance;
  final _fitService = GoogleFitService.instance;

  @override
  void initState() {
    super.initState();
    _stepService.addListener(_onStateChange);
    _fitService.addListener(_onStateChange);
    _fitService.init();
  }

  @override
  void dispose() {
    _stepService.removeListener(_onStateChange);
    _fitService.removeListener(_onStateChange);
    super.dispose();
  }

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  void _showEditGoalDialog() {
    final controller = TextEditingController(text: '${_stepService.stepGoal}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('🎯', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text('Mục Tiêu Bước Chân', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chọn mục tiêu số bước mỗi ngày để duy trì lối sống lành mạnh và đốt cháy calo:',
              style: TextStyle(fontSize: 13, color: AppColors.textGray),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Số bước mục tiêu',
                suffixText: 'bước',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [6000, 8000, 10000, 12000].map((preset) {
                return ActionChip(
                  label: Text('$preset bước', style: const TextStyle(fontSize: 12)),
                  backgroundColor: _stepService.stepGoal == preset ? AppColors.primary.withValues(alpha: 0.15) : Colors.grey.shade100,
                  onPressed: () {
                    controller.text = '$preset';
                  },
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: AppColors.textGray)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final newGoal = int.tryParse(controller.text) ?? 6000;
              _stepService.updateGoal(newGoal);
              Navigator.pop(ctx);
            },
            child: const Text('Lưu Mục Tiêu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAddManualStepsDialog() {
    final controller = TextEditingController(text: '1000');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('🏃‍♂️', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text('Thêm Bước Vận Động', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nhập số bước khi bạn tập trên máy chạy bộ (Treadmill) hoặc vận động mà không mang điện thoại:',
              style: TextStyle(fontSize: 13, color: AppColors.textGray),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Số bước cộng thêm',
                suffixText: 'bước',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [500, 1000, 2000, 3000].map((preset) {
                return ActionChip(
                  label: Text('+$preset', style: const TextStyle(fontSize: 12)),
                  backgroundColor: Colors.blue.shade50,
                  onPressed: () {
                    controller.text = '$preset';
                  },
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: AppColors.textGray)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final steps = int.tryParse(controller.text) ?? 0;
              if (steps > 0) {
                _stepService.addManualSteps(steps);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Cộng Bước', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final steps = _stepService.todaySteps;
    final goal = _stepService.stepGoal;
    final progress = _stepService.stepProgress;
    final cal = _stepService.burnedCalories;
    final dist = _stepService.distanceKm;
    final mins = _stepService.activeMinutes;
    final hasPerm = _stepService.hasPermission;

    String statusText = 'Sẵn sàng đo';
    Color statusColor = AppColors.primary;
    IconData statusIcon = Icons.directions_walk_rounded;

    if (_stepService.pedestrianStatus == 'walking') {
      statusText = 'Đang di chuyển';
      statusColor = Colors.green;
      statusIcon = Icons.directions_run_rounded;
    } else if (_stepService.pedestrianStatus == 'stopped') {
      statusText = 'Đang dừng lại';
      statusColor = Colors.blueGrey;
      statusIcon = Icons.accessibility_new_rounded;
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('👟', style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Theo Dõi Bước Chân',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                      ),
                      Text(
                        'Cảm biến phần cứng tiết kiệm pin',
                        style: TextStyle(fontSize: 12, color: AppColors.textGray),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textGray),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Permission Warning Banner if not granted
            if (!hasPerm)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.amber.shade800, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chưa cấp quyền cảm biến',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Cho phép quyền vận động để máy tự đếm bước chân ngầm khi bỏ túi.',
                            style: TextStyle(fontSize: 11, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade800,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        await _stepService.requestPermission();
                      },
                      child: const Text('Cấp Quyền', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

            // Main Circle Progress & Step Counter
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade50.withValues(alpha: 0.6), Colors.amber.shade50.withValues(alpha: 0.3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.orange.shade100),
              ),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 170,
                        height: 170,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 12,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, color: statusColor, size: 28),
                          const SizedBox(height: 4),
                          Text(
                            '$steps',
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.textBlack),
                          ),
                          Text(
                            'Mục tiêu: $goal bước',
                            style: const TextStyle(fontSize: 12, color: AppColors.textGray, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3 Metric Cards Row
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    icon: '🔥',
                    title: 'Calo Đốt',
                    value: cal.toStringAsFixed(0),
                    unit: 'kcal',
                    color: Colors.red.shade50,
                    textColor: Colors.red.shade700,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    icon: '📍',
                    title: 'Quãng Đường',
                    value: dist.toStringAsFixed(2),
                    unit: 'km',
                    color: Colors.blue.shade50,
                    textColor: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    icon: '⏱️',
                    title: 'Thời Gian',
                    value: '$mins',
                    unit: 'phút',
                    color: Colors.teal.shade50,
                    textColor: Colors.teal.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Google Fit Integration Banner
            _buildGoogleFitSection(),
            const SizedBox(height: 4),

            // Action Buttons (Edit Goal & Add Manual Steps)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(color: Colors.orange.shade300),
                    ),
                    icon: const Icon(Icons.tune_rounded, color: Colors.orange, size: 18),
                    label: const Text(
                      'Đổi Mục Tiêu',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                    onPressed: _showEditGoalDialog,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                    label: const Text(
                      'Cộng Bước Thủ Công',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    onPressed: _showAddManualStepsDialog,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Info note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Row(
                children: [
                  Text('💡', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Cảm biến phần cứng tự động đếm khi bạn bỏ điện thoại trong túi hoặc cầm trên tay mà không tiêu tốn pin.',
                      style: TextStyle(fontSize: 11, color: AppColors.textGray, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleFitSection() {
    final isLinked = _fitService.isLinked;
    final isSyncing = _fitService.isSyncing;
    final email = _fitService.linkedEmail;
    final lastSync = _fitService.lastSyncTime;

    String lastSyncText = 'Chưa đồng bộ';
    if (lastSync != null) {
      lastSyncText = 'Đồng bộ lúc ${lastSync.hour.toString().padLeft(2, '0')}:${lastSync.minute.toString().padLeft(2, '0')}';
    }

    if (isLinked) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF86EFAC)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Text('⚡', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Đã liên kết Google Fit',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.check_circle, size: 14, color: Color(0xFF16A34A)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email ?? 'Tài khoản Google',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF15803D), fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        lastSyncText,
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                if (isSyncing)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF16A34A)),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.sync_rounded, color: Color(0xFF16A34A), size: 22),
                    tooltip: 'Đồng bộ dữ liệu mới nhất',
                    onPressed: () async {
                      final success = await _fitService.syncTodayData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success ? 'Đã đồng bộ dữ liệu mới nhất từ Google Fit!' : 'Không có dữ liệu mới hoặc lỗi kết nối.'),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
              ],
            ),
            const Divider(height: 18, thickness: 0.5, color: Color(0xFFBBF7D0)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Dữ liệu tự động lọc rung lắc xe máy',
                  style: TextStyle(fontSize: 10.5, color: Color(0xFF166534)),
                ),
                GestureDetector(
                  onTap: () async {
                    await _fitService.unlinkGoogleFit();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã hủy liên kết Google Fit, chuyển về cảm biến máy.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: Text(
                    'Hủy liên kết',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.red.shade600),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: const Text('⚡', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Flexible(
                      child: Text(
                        'Đồng Bộ Google Fit',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Chuẩn xác',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.blue.shade900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Lọc bỏ rung lắc xe máy & đồng bộ dữ liệu từ đồng hồ.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: isSyncing
                ? null
                : () async {
                    final success = await _fitService.linkGoogleFit(context);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success ? 'Kết nối Google Fit thành công!' : (_fitService.lastError ?? 'Đã hủy kết nối.')),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
            child: isSyncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Kết Nối',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String icon,
    required String title,
    required String value,
    required String unit,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.8), fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textColor),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

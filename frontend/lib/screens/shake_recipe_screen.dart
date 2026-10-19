import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../constants/app_colors.dart';
import '../constants/app_translations.dart';
import '../services/meal_db_service.dart';
import '../services/app_state_service.dart';
import '../services/recipe_translator.dart';

class ShakeRecipeScreen extends StatefulWidget {
  final Function(int) onNavigate;

  const ShakeRecipeScreen({
    super.key,
    required this.onNavigate,
  });

  @override
  State<ShakeRecipeScreen> createState() => _ShakeRecipeScreenState();
}

class _ShakeRecipeScreenState extends State<ShakeRecipeScreen> with TickerProviderStateMixin {
  bool _isShaking = false;
  bool _showDropSuccess = false;
  MealItem? _shakenMeal;
  List<MealItem> _quickSuggestions = [];

  // Animation lắc (wobble / shake)
  late AnimationController _wobbleController;

  // Animation rớt món (drop bounce)
  late AnimationController _dropController;
  late Animation<Offset> _dropSlideAnimation;
  late Animation<double> _dropScaleAnimation;

  // Animation các đĩa món ăn nhảy lên xuống (bouncing food plates)
  late AnimationController _bouncingPlatesController;

  // Cảm biến gia tốc lắc điện thoại
  StreamSubscription<UserAccelerometerEvent>? _userSensorSub;
  StreamSubscription<AccelerometerEvent>? _sensorSubscription;
  DateTime _lastShakeTime = DateTime.now();
  double _lastX = 0.0;
  double _lastY = 0.0;
  double _lastZ = 0.0;

  @override
  void initState() {
    super.initState();

    // 1. Controller lắc nồi/hộp khi đang chọn món
    _wobbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    // 2. Controller hiệu ứng rớt món nảy vật lý
    _dropController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _dropSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _dropController,
      curve: Curves.bounceOut,
    ));

    _dropScaleAnimation = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _dropController,
      curve: Curves.easeOutBack,
    ));

    // 3. Controller các đĩa món ăn nhảy nhót sinh động lúc mới vào
    _bouncingPlatesController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _initAccelerometer();
    _loadInitialData();
  }

  /// Lắng nghe chuyển động lắc trên cả máy thật và máy ảo Android Virtual Sensors
  void _initAccelerometer() {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      debugPrint('[Shake Sensors] Chế độ Desktop/Web: Sử dụng nút bấm, không kích hoạt cảm biến phần cứng.');
      return;
    }

    // 1. Kênh UserAccelerometer (Đã lọc bỏ trọng lực g = 9.8) - Cực nhạy cho máy ảo và máy thật
    try {
      _userSensorSub = userAccelerometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen(
        (UserAccelerometerEvent event) {
          final double force = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
          // Trên máy ảo khi kéo Virtual Sensors hoặc lắc máy thật: force vượt ngưỡng 4.2 m/s²
          if (force > 4.2) {
            _triggerShake();
          }
        },
        onError: (err) {
          debugPrint('[UserAccelerometer Error] $err');
        },
      );
    } catch (e) {
      debugPrint('[UserAccelerometer Exception] $e');
    }

    // 2. Kênh Accelerometer tiêu chuẩn kết hợp đo biến thiên gia tốc (Delta Jerk)
    try {
      _sensorSubscription = accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen(
        (AccelerometerEvent event) {
          final double gX = event.x;
          final double gY = event.y;
          final double gZ = event.z;
          final double gForce = sqrt(gX * gX + gY * gY + gZ * gZ);

          final double delta = (gX - _lastX).abs() + (gY - _lastY).abs() + (gZ - _lastZ).abs();
          _lastX = gX;
          _lastY = gY;
          _lastZ = gZ;

          // Nhận diện khi:
          // - Lực lắc mạnh gForce > 14.0 m/s² (hạ từ 19.5 để máy ảo / lắc nhẹ tay nhận ngay)
          // - Hoặc biến thiên gia tốc delta > 7.0 m/s² (khi di chuyển thanh trượt trong Emulator Virtual Sensors)
          if (gForce > 14.0 || delta > 7.0) {
            _triggerShake();
          }
        },
        onError: (err) {
          debugPrint('[Accelerometer Error] $err');
        },
      );
    } catch (e) {
      debugPrint('[Accelerometer Exception] $e');
    }
  }

  void _triggerShake() {
    final now = DateTime.now();
    if (now.difference(_lastShakeTime).inMilliseconds > 1800) {
      _lastShakeTime = now;
      _performShake();
    }
  }

  @override
  void dispose() {
    _userSensorSub?.cancel();
    _userSensorSub = null;
    _sensorSubscription?.cancel();
    _sensorSubscription = null;
    _wobbleController.dispose();
    _dropController.dispose();
    _bouncingPlatesController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final suggestions = await TheMealDbService.getMealsByCategory('Chicken');
    if (mounted) {
      setState(() {
        _shakenMeal = null; // Bắt đầu ở trạng thái chờ lắc với các đĩa món nhảy lên xuống!
        _quickSuggestions = suggestions.take(4).toList();
      });
    }
  }

  /// Thực hiện hành động Lắc & Rớt Món
  Future<void> _performShake() async {
    if (_isShaking) return;

    setState(() {
      _isShaking = true;
      _showDropSuccess = false;
    });

    HapticFeedback.mediumImpact();
    _wobbleController.repeat(reverse: true);

    try {
      final lang = AppStateService.instance.currentLanguage;
      // Gọi Backend C# để lấy món lắc ngẫu nhiên đã dịch tự động 100% & tính MatchScore
      final newMeal = await TheMealDbService.getShakenMeal(lang: lang);

      // Tạo độ trễ hồi hộp ~900ms để hiệu ứng lắc nồi diễn ra sinh động
      await Future.delayed(const Duration(milliseconds: 900));

      if (mounted) {
        _wobbleController.stop();
        _wobbleController.reset();

        if (newMeal != null) {
          setState(() {
            _shakenMeal = newMeal;
            _isShaking = false;
            _showDropSuccess = true;
          });
          HapticFeedback.heavyImpact();
          _dropController.forward(from: 0.0);
        } else {
          setState(() => _isShaking = false);
        }
      }
    } catch (e) {
      if (mounted) {
        _wobbleController.stop();
        _wobbleController.reset();
        setState(() => _isShaking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar
              _buildTopBar(),
              const SizedBox(height: 12),

              // Dải thông báo mẹo lắc điện thoại
              _buildShakeHintBanner(),
              const SizedBox(height: 16),

              // Thẻ món ăn chính với hiệu ứng LẮC & RỚT MÓN
              _buildShakeHeroCard(),
              const SizedBox(height: 20),

              // Nút bấm lắc món ăn (dành cho cả máy ảo & nút bấm nhanh)
              _buildShakeButton(),
              const SizedBox(height: 24),

              // Danh sách món gợi ý nhanh
              _buildSuggestionsList(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
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
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
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
                AppTranslations.tr('shake_title'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textBlack),
              ),
              Text(
                AppTranslations.tr('shake_sub_desc'),
                style: const TextStyle(fontSize: 11, color: AppColors.textGray),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(color: AppColors.accentMint, shape: BoxShape.circle),
          child: const Icon(Icons.casino_rounded, size: 20, color: AppColors.primaryDark),
        ),
      ],
    );
  }

  Widget _buildShakeHintBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.vibration_rounded, color: Color(0xFF2563EB), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppTranslations.tr('shake_hint'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)),
            ),
          ),
        ],
      ),
    );
  }

  /// Thẻ món ăn chính: Có hiệu ứng rung lắc (wobble) và hiệu ứng rớt món (bounce drop)
  Widget _buildShakeHeroCard() {
    final meal = _shakenMeal;

    // 1. Trạng thái đang lắc: Hiệu ứng Nồi Lắc Thần Kỳ đung đưa
    if (_isShaking) {
      return _buildWobbleShakingCard();
    }

    // 2. Trạng thái ban đầu lúc mới vào: Hộp đĩa món ăn nhảy lên xuống sinh động!
    if (meal == null) {
      return _buildInitialBouncingPlatesCard();
    }

    final isVi = AppStateService.instance.currentLanguage == 'vi';
    final displayName = isVi
        ? (meal.strMealVi ?? RecipeTranslator.translateDishName(meal.strMeal))
        : meal.strMeal;

    // 3. Trạng thái đã lắc xong: Món ăn RỚT XUỐNG với hiệu ứng Slide & Bounce vật lý

    // 2. Trạng thái đã lắc xong: Món ăn RỚT XUỐNG với hiệu ứng Slide & Bounce vật lý
    return SlideTransition(
      position: _dropSlideAnimation,
      child: ScaleTransition(
        scale: _dropScaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 14, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thông báo "Ting! Rớt trúng món ngon"
              if (_showDropSuccess)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.stars_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        AppTranslations.tr('shake_drop_success'),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),

              // Ảnh món ăn với các huy hiệu
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(_showDropSuccess ? 0 : 24),
                    ),
                    child: Image.network(
                      meal.strMealThumb,
                      height: 195,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 195,
                        color: Colors.grey.shade200,
                        child: const Center(child: Icon(Icons.restaurant, size: 40, color: Colors.grey)),
                      ),
                    ),
                  ),

                  // Huy hiệu Calo
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_fire_department, size: 14, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text(
                            '~${meal.estimatedCalories} kcal',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Huy hiệu Thể loại / MatchScore
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (meal.badges.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              meal.badges.first,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          )
                        else if (meal.strCategory != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              meal.strCategory!,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        if (meal.matchScore > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade700,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '🎯 ${meal.matchScore}% Match',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              // Thông tin chi tiết món rớt trúng
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${isVi ? "Khu vực" : "Origin"}: ${meal.strArea ?? (isVi ? "Quốc tế" : "International")} • ${meal.estimatedProtein}g ${AppTranslations.tr('pro')} • ${meal.estimatedCarbs}g ${AppTranslations.tr('carb')} • ${meal.estimatedFat}g ${AppTranslations.tr('fat')}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textGray),
                    ),
                    const SizedBox(height: 14),

                    // Nút bấm chuyển sang xem chi tiết & cách nấu
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          AppStateService.instance.setSelectedMeal(meal);
                          widget.onNavigate(6); // Chuyển sang màn hình chi tiết món ăn
                        },
                        icon: const Icon(Icons.menu_book_rounded, size: 16),
                        label: Text(
                          AppTranslations.tr('view_recipe_now'),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Hộp đĩa món ăn nhảy lên xuống sinh động lúc mới vào màn hình Lắc
  Widget _buildInitialBouncingPlatesCard() {
    return InkWell(
      onTap: _performShake,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: 330,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFFDE68A), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Huy hiệu mời gọi nổi bật
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.amber.shade700,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.amber.withValues(alpha: 0.3), blurRadius: 6),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                  SizedBox(width: 6),
                  Text(
                    'CHƯA BIẾT HÔM NAY ĂN GÌ?',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                  ),
                ],
              ),
            ),

            // Dàn đĩa món ăn nhảy lên xuống nhịp nhàng (Bouncing Food Plates)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildBouncingPlateItem(emoji: '🍲', label: 'Món súp', phaseOffset: 0.0),
                  _buildBouncingPlateItem(emoji: '🥗', label: 'Salad', phaseOffset: 0.25),
                  _buildBouncingPlateItem(emoji: '🥩', label: 'Bít tết', phaseOffset: 0.5),
                  _buildBouncingPlateItem(emoji: '🍝', label: 'Mỳ Ý', phaseOffset: 0.75),
                ],
              ),
            ),

            // Tiêu đề & nút hành động chạm
            Column(
              children: [
                const Text(
                  'Lắc điện thoại để rớt món! 🎲',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Cầm máy lắc mạnh hoặc chạm vào đây để chọn món',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppColors.textGray),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app_rounded, size: 16, color: AppColors.primaryDark),
                      SizedBox(width: 6),
                      Text(
                        'Chạm hoặc Lắc ngay',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Đĩa món ăn nhảy nhót sinh động với bóng nảy thực tế
  Widget _buildBouncingPlateItem({
    required String emoji,
    required String label,
    required double phaseOffset,
  }) {
    return AnimatedBuilder(
      animation: _bouncingPlatesController,
      builder: (context, child) {
        final double progress = (_bouncingPlatesController.value + phaseOffset) % 1.0;
        final double bounceY = sin(progress * 2 * pi) * 14.0;
        final double shadowScale = 1.0 - (bounceY.abs() / 26.0);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.translate(
              offset: Offset(0, -bounceY),
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: const Color(0xFFF1F5F9), width: 2),
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 30)),
              ),
            ),
            const SizedBox(height: 8),
            Transform.scale(
              scaleX: shadowScale.clamp(0.5, 1.0),
              scaleY: 0.5,
              child: Container(
                width: 34,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: (0.12 * shadowScale).clamp(0.04, 0.12)),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Hiệu ứng Nồi Thần Kỳ lắc rung bần bật khi đang chọn món
  Widget _buildWobbleShakingCard() {
    return AnimatedBuilder(
      animation: _wobbleController,
      builder: (context, child) {
        final double angle = sin(_wobbleController.value * 2 * pi) * 0.10;
        final double scale = 1.0 + (sin(_wobbleController.value * 2 * pi) * 0.04);
        return Transform.rotate(
          angle: angle,
          child: Transform.scale(
            scale: scale,
            child: child,
          ),
        );
      },
      child: Container(
        height: 310,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFFDE68A), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10),
                ],
              ),
              child: const Icon(Icons.soup_kitchen_rounded, size: 54, color: AppColors.primary),
            ),
            const SizedBox(height: 18),
            Text(
              AppTranslations.tr('shaking'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textBlack),
            ),
            const SizedBox(height: 10),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('🍲', style: TextStyle(fontSize: 22)),
                SizedBox(width: 8),
                Text('🥗', style: TextStyle(fontSize: 22)),
                SizedBox(width: 8),
                Text('🥩', style: TextStyle(fontSize: 22)),
                SizedBox(width: 8),
                Text('🍜', style: TextStyle(fontSize: 22)),
                SizedBox(width: 8),
                Text('🍱', style: TextStyle(fontSize: 22)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              AppTranslations.tr('shake_instruction'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.textGray),
            ),
          ],
        ),
      ),
    );
  }

  /// Nút Lắc chọn món (Hỗ trợ máy ảo và thao tác 1 chạm)
  Widget _buildShakeButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isShaking ? null : _performShake,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 2,
        ),
        icon: const Icon(Icons.casino_rounded, size: 22),
        label: Text(
          _isShaking ? AppTranslations.tr('shaking') : '${AppTranslations.tr('shake_btn')} 🎲',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildSuggestionsList() {
    final isVi = AppStateService.instance.currentLanguage == 'vi';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppTranslations.tr('other_suggestions'),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textBlack),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _quickSuggestions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final meal = _quickSuggestions[index];
            final name = isVi
                ? (meal.strMealVi ?? RecipeTranslator.translateDishName(meal.strMeal))
                : meal.strMeal;

            return InkWell(
              onTap: () {
                AppStateService.instance.setSelectedMeal(meal);
                widget.onNavigate(6);
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6),
                  ],
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        meal.strMealThumb,
                        width: 55,
                        height: 55,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 55,
                          height: 55,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.restaurant, size: 24, color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '~${meal.estimatedCalories} kcal • ${meal.estimatedProtein}g ${AppTranslations.tr('pro')}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textGray),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.textLightGray),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
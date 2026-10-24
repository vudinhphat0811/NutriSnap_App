import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'constants/app_colors.dart';
import 'widgets/app_bottom_bar.dart';
import 'screens/home_dashboard_screen.dart';
import 'screens/meal_journal_screen.dart';
import 'screens/recipe_suggestions_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/ingredient_scan_screen.dart';
import 'screens/shake_recipe_screen.dart';
import 'screens/recipe_detail_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_profile_screen.dart';
import 'services/app_state_service.dart';
import 'constants/api_constants.dart';
import 'widgets/guest_trial_barrier.dart';
import 'widgets/social_auth_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConstants.loadSocialConfigs();
  await AppStateService.instance.loadFromLocalStorage();
  runApp(const NutriSnapApp());
}

class NutriSnapApp extends StatelessWidget {
  const NutriSnapApp({super.key});

  Widget _getInitialScreen() {
    final appState = AppStateService.instance;
    final profile = appState.userProfile;
    final bool hasValidMetrics = profile.hasProfile &&
        profile.heightCm > 0 &&
        profile.weightKg > 0 &&
        profile.age > 0;

    // 1. Nếu đã có tài khoản hoặc ở chế độ Khách nhưng CHƯA có thông tin sức khỏe -> Luôn hiện bảng nhập thông tin
    if ((appState.authToken != null || appState.isGuestMode) && !hasValidMetrics) {
      return OnboardingProfileScreen(
        initialEmail: profile.email.isNotEmpty ? profile.email : null,
        initialName: profile.fullName.isNotEmpty ? profile.fullName : null,
      );
    }

    // 2. Nếu đã đăng nhập / khách và ĐÃ CÓ đầy đủ thông tin -> Vào thẳng màn hình chính
    if ((appState.authToken != null || appState.isGuestMode) && hasValidMetrics) {
      return const MobileWrapper(child: MainShellScreen());
    }

    // 3. Chưa đăng nhập -> Vào màn hình Đăng nhập
    return const LoginScreen();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NutriSnap',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,
        fontFamily: 'Roboto',
      ),
      // Bọc khung mô phỏng khi chạy Web/Desktop, trên Android/iOS chạy tràn màn hình điện thoại tự nhiên
      builder: (context, child) {
        if (!kIsWeb) {
          return child ?? const SizedBox();
        }
        return Scaffold(
          backgroundColor: const Color(0xFFCBD5E1),
          body: Center(
            child: Container(
              width: 410,
              height: 860,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 24,
                    spreadRadius: 4,
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: child ?? const SizedBox(),
              ),
            ),
          ),
        );
      },
      home: _getInitialScreen(),
    );
  }
}

// Bọc khung mô phỏng kích thước điện thoại di động (pass-through an toàn)
class MobileWrapper extends StatelessWidget {
  final Widget child;
  const MobileWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // Biến quản lý index màn hình đang hiển thị
  int _activeScreenIndex = 0;

  // Chế độ nút ở giữa: 'camera' hoặc 'shake' (Lắc)
  String _centerMode = 'camera';
  bool _isMenuOpen = false;

  late AnimationController _menuController;
  late Animation<double> _expandAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _fabRotationAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppStateService.instance.addListener(_onStateChanged);
    AppStateService.instance.checkAndResetForNewDay();

    _menuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 240),
    );

    _expandAnimation = CurvedAnimation(
      parent: _menuController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInOutCubic,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _menuController,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
      reverseCurve: const Interval(0.0, 0.65, curve: Curves.easeIn),
    );

    _fabRotationAnimation = Tween<double>(begin: 0.0, end: 0.125).animate(
      CurvedAnimation(
        parent: _menuController,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInOutCubic,
      ),
    );

    // Kiểm tra an toàn: Nếu người dùng vào MainShellScreen nhưng chưa thiết lập chỉ số, chuyển ngay sang OnboardingProfileScreen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = AppStateService.instance.userProfile;
      final bool hasValidMetrics = profile.hasProfile &&
          profile.heightCm > 0 &&
          profile.weightKg > 0 &&
          profile.age > 0;

      if (!hasValidMetrics && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OnboardingProfileScreen(
              initialEmail: profile.email.isNotEmpty ? profile.email : null,
              initialName: profile.fullName.isNotEmpty ? profile.fullName : null,
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppStateService.instance.removeListener(_onStateChanged);
    _menuController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AppStateService.instance.checkAndResetForNewDay();
    }
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  // Hàm chuyển đổi tab / màn hình
  void _navigateTo(int index) {
    if (_isMenuOpen) {
      _closeFabMenu();
    }
    if (_activeScreenIndex != 6 && index == 6) {
      AppStateService.instance.previousScreenIndex = _activeScreenIndex;
    }
    AppStateService.instance.setCurrentScreenIndex(index);
    setState(() {
      _activeScreenIndex = index;
      if (index == 4) {
        _centerMode = 'camera';
      } else if (index == 5) {
        _centerMode = 'shake';
      }
    });
  }

  void _toggleFabMenu() {
    HapticFeedback.lightImpact();
    if (_isMenuOpen) {
      _closeFabMenu();
    } else {
      _openFabMenu();
    }
  }

  void _openFabMenu() {
    setState(() {
      _isMenuOpen = true;
    });
    _menuController.forward(from: 0.0);
  }

  void _closeFabMenu() {
    _menuController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _isMenuOpen = false;
        });
      }
    });
  }

  void _selectCenterMode(String mode) {
    HapticFeedback.mediumImpact();
    final targetIndex = mode == 'camera' ? 4 : 5;
    setState(() {
      _centerMode = mode;
    });
    _menuController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _isMenuOpen = false;
        });
        _navigateTo(targetIndex);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateService.instance;
    final isOffline = appState.isOffline;
    final isGuestMode = appState.isGuestMode;
    final guestDays = appState.guestUsageDays;
    final isGuestTrialExpired = appState.isGuestTrialExpired;

    // Danh sách 7 màn hình của ứng dụng
    final List<Widget> appScreens = [
      HomeDashboardScreen(onNavigate: _navigateTo),       // Index 0: Trang chủ
      MealJournalScreen(onNavigate: _navigateTo),         // Index 1: Nhật ký
      RecipeSuggestionsScreen(onNavigate: _navigateTo),   // Index 2: Thực đơn gợi ý
      ProfileScreen(onNavigate: _navigateTo),             // Index 3: Hồ sơ
      IngredientScanScreen(onNavigate: _navigateTo),      // Index 4: Nhận diện AI
      ShakeRecipeScreen(onNavigate: _navigateTo),         // Index 5: Lắc chọn món
      RecipeDetailScreen(onNavigate: _navigateTo),        // Index 6: Chi tiết công thức
    ];

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.background,

          // Hiển thị Banner ngoại tuyến, cảnh báo dùng thử khách và tab màn hình
          body: Column(
            children: [
              // 1. Banner Ngoại Tuyến Thân Thiện
              if (isOffline)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEF3C7), // Amber 100
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFFCD34D), width: 1),
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_off_rounded, color: Color(0xFFD97706), size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Chế độ Ngoại tuyến (Offline). Bạn vẫn có thể xem món đã lưu & tra cứu dinh dưỡng.',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            AppStateService.instance.setOffline(false);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDE68A),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Đã hiểu',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 2. Banner Nhắc Nhở Trải Nghiệm Khách (Từ ngày 1 đến ngày 6)
              if (!isOffline && isGuestMode && !isGuestTrialExpired)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF0FDF4),
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFBBF7D0), width: 1),
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        const Icon(Icons.schedule_rounded, color: Color(0xFF166534), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Chế độ Khách (Ngày $guestDays/7). Hãy liên kết tài khoản để lưu trữ vĩnh viễn.',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF166534),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => SocialAuthHelper.showGoogleAuthDialog(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Liên kết',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              Expanded(
                child: IndexedStack(
                  index: _activeScreenIndex,
                  children: appScreens,
                ),
              ),
            ],
          ),

          // Nút tròn ở giữa: Camera / Lắc có viền đen sắc sảo và hiệu ứng chuyển đổi mềm mại
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          floatingActionButton: GestureDetector(
            onTap: _toggleFabMenu,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
                border: Border.all(
                  color: Colors.black, // Viền đen theo yêu cầu
                  width: 2.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: AnimatedBuilder(
                  animation: _fabRotationAnimation,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _fabRotationAnimation.value * 2 * 3.14159,
                      child: Icon(
                        _isMenuOpen
                            ? Icons.close_rounded
                            : (_centerMode == 'shake' ? Icons.casino_rounded : Icons.camera_alt_rounded),
                        color: Colors.white,
                        size: 26,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // Footer điều hướng giữa 4 tab chính (0, 1, 2, 3)
          bottomNavigationBar: AppBottomBar(
            currentIndex: _activeScreenIndex <= 3 ? _activeScreenIndex : -1,
            onTapTab: (index) => _navigateTo(index),
            onCameraTap: _toggleFabMenu,
          ),
        ),

        // 3. Menu sổ lên 2 icon Camera / Lắc với hiệu ứng mượt mà mềm mại
        if (_isMenuOpen)
          Positioned.fill(
            child: Stack(
              children: [
                // Backdrop mờ nhẹ, ấn vào bất kỳ đâu để đóng lại êm dịu
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _closeFabMenu,
                    behavior: HitTestBehavior.opaque,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.32),
                      ),
                    ),
                  ),
                ),

                // 2 nút chức năng nổi lên trên nút trung tâm
                Positioned(
                  bottom: 74 + MediaQuery.of(context).padding.bottom,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _expandAnimation,
                      builder: (context, child) {
                        final progress = _expandAnimation.value;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Nút 2: Lắc chọn món (Shake)
                            Transform.translate(
                              offset: Offset(0, (1 - progress) * 45),
                              child: Transform.scale(
                                scale: 0.35 + (progress * 0.65),
                                child: Opacity(
                                  opacity: progress.clamp(0.0, 1.0),
                                  child: _buildMenuOptionPill(
                                    mode: 'shake',
                                    title: 'Lắc chọn món',
                                    subtitle: 'Gợi ý món ăn ngẫu nhiên',
                                    icon: Icons.casino_rounded,
                                    badgeColor: const Color(0xFFF59E0B),
                                    isSelected: _centerMode == 'shake',
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Nút 1: Quét nhận diện AI (Camera)
                            Transform.translate(
                              offset: Offset(0, (1 - progress) * 18),
                              child: Transform.scale(
                                scale: 0.35 + (progress * 0.65),
                                child: Opacity(
                                  opacity: progress.clamp(0.0, 1.0),
                                  child: _buildMenuOptionPill(
                                    mode: 'camera',
                                    title: 'Quét nhận diện AI',
                                    subtitle: 'Chụp ảnh & Quét nguyên liệu',
                                    icon: Icons.camera_alt_rounded,
                                    badgeColor: AppColors.primary,
                                    isSelected: _centerMode == 'camera',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

        // 4. Khóa Bắt Buộc Liên Kết Tài Khoản Nếu Dùng Khách Từ Ngày Thứ 7
        if (isGuestTrialExpired)
          const Positioned.fill(
            child: GuestTrialBarrierModal(),
          ),
      ],
    );
  }

  // Widget hiển thị từng tùy chọn với viền đen và animation mượt mà
  Widget _buildMenuOptionPill({
    required String mode,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color badgeColor,
    required bool isSelected,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectCenterMode(mode),
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.black, // Viền đen theo yêu cầu
              width: isSelected ? 2.5 : 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 1.8),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primary, width: 1),
                          ),
                          child: const Text(
                            'Đang chọn',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
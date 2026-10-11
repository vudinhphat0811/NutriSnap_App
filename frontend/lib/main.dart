import 'package:flutter/material.dart';
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

void main() {
  runApp(const NutriSnapApp());
}

class NutriSnapApp extends StatelessWidget {
  const NutriSnapApp({super.key});

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
      // Bắt đầu ứng dụng tại màn hình Đăng nhập (nằm trong khung MobileWrapper)
      home: const MobileWrapper(child: LoginScreen()),
    );
  }
}

// Bọc khung mô phỏng kích thước điện thoại di động
class MobileWrapper extends StatelessWidget {
  final Widget child;
  const MobileWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
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
                color: Colors.black.withOpacity(0.12),
                blurRadius: 24,
                spreadRadius: 4,
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: child,
          ),
        ),
      ),
    );
  }
}

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  // Biến quản lý index màn hình đang hiển thị
  int _activeScreenIndex = 0;

  // Hàm chuyển đổi tab / màn hình
  void _navigateTo(int index) {
    setState(() {
      _activeScreenIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Danh sách 7 màn hình của ứng dụng
    final List<Widget> appScreens = [
      HomeDashboardScreen(onNavigate: _navigateTo),       // Index 0: Trang chủ
      MealJournalScreen(onNavigate: _navigateTo),         // Index 1: Nhật ký
      RecipeSuggestionsScreen(onNavigate: _navigateTo),   // Index 2: Thực đơn gợi ý
      const ProfileScreen(),                              // Index 3: Hồ sơ
      IngredientScanScreen(onNavigate: _navigateTo),      // Index 4: Nhận diện AI
      ShakeRecipeScreen(onNavigate: _navigateTo),         // Index 5: Lắc chọn món
      RecipeDetailScreen(onNavigate: _navigateTo),        // Index 6: Chi tiết công thức
    ];

    return Scaffold(
      backgroundColor: AppColors.background,

      // Hiển thị và chuyển tab ngay lập tức
      body: IndexedStack(
        index: _activeScreenIndex,
        children: appScreens,
      ),

      // Nút tròn Camera chuyển sang trang Quét nhận diện AI (Index 4)
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        shape: const CircleBorder(),
        backgroundColor: AppColors.primary,
        elevation: 4,
        onPressed: () => _navigateTo(4),
        child: const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 28),
      ),

      // Footer điều hướng giữa 4 tab chính (0, 1, 2, 3)
      bottomNavigationBar: AppBottomBar(
        currentIndex: _activeScreenIndex <= 3 ? _activeScreenIndex : -1,
        onTapTab: (index) => _navigateTo(index),
        onCameraTap: () => _navigateTo(4),
      ),
    );
  }
}
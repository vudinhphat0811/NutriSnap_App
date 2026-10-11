import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppBottomBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTapTab;
  final VoidCallback onCameraTap;

  const AppBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTapTab,
    required this.onCameraTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      color: Colors.white,
      elevation: 12,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildItem(Icons.home_rounded, 'Trang chủ', 0),
            _buildItem(Icons.menu_book_rounded, 'Nhật ký', 1),
            const SizedBox(width: 44),
            _buildItem(Icons.restaurant_menu_rounded, 'Thực đơn', 2),
            _buildItem(Icons.person_outline_rounded, 'Hồ sơ', 3),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(IconData icon, String label, int index) {
    final bool isSelected = currentIndex == index;
    final color = isSelected ? AppColors.primaryDark : AppColors.textLightGray;
    return InkWell(
      onTap: () => onTapTab(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
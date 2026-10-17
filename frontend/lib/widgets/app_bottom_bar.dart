import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_translations.dart';

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
      notchMargin: 5.0,
      color: Colors.white,
      elevation: 8,
      padding: EdgeInsets.zero,
      height: 52,
      child: SizedBox(
        height: 52,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildItem(Icons.home_rounded, AppTranslations.tr('nav_home'), 0),
            _buildItem(Icons.menu_book_rounded, AppTranslations.tr('nav_diary'), 1),
            const SizedBox(width: 48),
            _buildItem(Icons.restaurant_menu_rounded, AppTranslations.tr('nav_recipes'), 2),
            _buildItem(Icons.person_outline_rounded, AppTranslations.tr('nav_profile'), 3),
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
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 21),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
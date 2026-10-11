import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class MealJournalScreen extends StatelessWidget {
  final Function(int) onNavigate;
  const MealJournalScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nhật ký bữa ăn', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Lịch sử nạp dinh dưỡng các ngày trước.', style: TextStyle(color: AppColors.textGray)),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () => onNavigate(6), child: const Text('Xem lại công thức bữa trưa >')),
          ],
        ),
      ),
    );
  }
}
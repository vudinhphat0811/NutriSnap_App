import 'package:flutter/material.dart';

/// Model đại diện cho một món thực phẩm được lưu trữ trong Tủ Lạnh Thông Minh
class FridgeItemModel {
  final String id;
  final String name;
  final String category;
  final String categoryIcon;
  final String quantity; // ví dụ: "500g", "2 hộp", "1 nải"
  final double netWeightG;
  final String storageLocation; // 'fridge' (ngăn mát), 'freezer' (ngăn đông), 'pantry' (tủ khô)
  final DateTime? manufacturingDate; // Ngày sản xuất (NSX)
  final DateTime expirationDate; // Hạn sử dụng (HSD / NHH)
  final DateTime addedAt;
  final String? barcode;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final String notes;

  const FridgeItemModel({
    required this.id,
    required this.name,
    required this.category,
    this.categoryIcon = '🛒',
    required this.quantity,
    this.netWeightG = 100.0,
    this.storageLocation = 'fridge',
    this.manufacturingDate,
    required this.expirationDate,
    required this.addedAt,
    this.barcode,
    this.caloriesPer100g = 0.0,
    this.proteinPer100g = 0.0,
    this.carbsPer100g = 0.0,
    this.fatPer100g = 0.0,
    this.notes = '',
  });

  /// Số ngày còn lại tính đến hạn sử dụng
  int get daysRemaining {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exp = DateTime(expirationDate.year, expirationDate.month, expirationDate.day);
    return exp.difference(today).inDays;
  }

  /// Đã quá hạn
  bool get isExpired => daysRemaining < 0;

  /// Hết hạn đúng hôm nay
  bool get isExpiringToday => daysRemaining == 0;

  /// Sắp hết hạn trong vòng 1-2 ngày
  bool get isExpiringSoon => daysRemaining > 0 && daysRemaining <= 2;

  /// Còn tươi mới
  bool get isFresh => daysRemaining > 2;

  /// Nhãn hiển thị trạng thái hạn dùng
  String get statusLabel {
    if (daysRemaining < -1) return 'Quá hạn ${-daysRemaining} ngày';
    if (daysRemaining == -1) return 'Quá hạn hôm qua';
    if (daysRemaining == 0) return 'Hết hạn hôm nay!';
    if (daysRemaining == 1) return 'Hết hạn ngày mai!';
    if (daysRemaining == 2) return 'Còn 2 ngày nữa';
    return 'Còn $daysRemaining ngày';
  }

  /// Màu sắc trạng thái
  Color get statusColor {
    if (isExpired || isExpiringToday) return const Color(0xFFEF4444); // Đỏ
    if (isExpiringSoon) return const Color(0xFFF59E0B); // Vàng cam
    return const Color(0xFF10B981); // Xanh lá
  }

  /// Màu nền badge trạng thái
  Color get statusBackgroundColor {
    if (isExpired || isExpiringToday) return const Color(0xFFFEE2E2);
    if (isExpiringSoon) return const Color(0xFFFEF3C7);
    return const Color(0xFFD1FAE5);
  }

  /// Tên vị trí bảo quản
  String get storageLocationName {
    switch (storageLocation) {
      case 'freezer':
        return 'Ngăn đông';
      case 'pantry':
        return 'Tủ đồ khô';
      case 'fridge':
      default:
        return 'Ngăn mát';
    }
  }

  /// Icon vị trí bảo quản
  String get storageLocationIcon {
    switch (storageLocation) {
      case 'freezer':
        return '🧊';
      case 'pantry':
        return '📦';
      case 'fridge':
      default:
        return '❄️';
    }
  }

  FridgeItemModel copyWith({
    String? id,
    String? name,
    String? category,
    String? categoryIcon,
    String? quantity,
    double? netWeightG,
    String? storageLocation,
    DateTime? manufacturingDate,
    DateTime? expirationDate,
    DateTime? addedAt,
    String? barcode,
    double? caloriesPer100g,
    double? proteinPer100g,
    double? carbsPer100g,
    double? fatPer100g,
    String? notes,
  }) {
    return FridgeItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      categoryIcon: categoryIcon ?? this.categoryIcon,
      quantity: quantity ?? this.quantity,
      netWeightG: netWeightG ?? this.netWeightG,
      storageLocation: storageLocation ?? this.storageLocation,
      manufacturingDate: manufacturingDate ?? this.manufacturingDate,
      expirationDate: expirationDate ?? this.expirationDate,
      addedAt: addedAt ?? this.addedAt,
      barcode: barcode ?? this.barcode,
      caloriesPer100g: caloriesPer100g ?? this.caloriesPer100g,
      proteinPer100g: proteinPer100g ?? this.proteinPer100g,
      carbsPer100g: carbsPer100g ?? this.carbsPer100g,
      fatPer100g: fatPer100g ?? this.fatPer100g,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'categoryIcon': categoryIcon,
    'quantity': quantity,
    'netWeightG': netWeightG,
    'storageLocation': storageLocation,
    'manufacturingDate': manufacturingDate?.toIso8601String(),
    'expirationDate': expirationDate.toIso8601String(),
    'addedAt': addedAt.toIso8601String(),
    'barcode': barcode,
    'caloriesPer100g': caloriesPer100g,
    'proteinPer100g': proteinPer100g,
    'carbsPer100g': carbsPer100g,
    'fatPer100g': fatPer100g,
    'notes': notes,
  };

  factory FridgeItemModel.fromJson(Map<String, dynamic> json) {
    return FridgeItemModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? 'Thực phẩm',
      categoryIcon: json['categoryIcon'] ?? '🛒',
      quantity: json['quantity'] ?? '100g',
      netWeightG: (json['netWeightG'] as num?)?.toDouble() ?? 100.0,
      storageLocation: json['storageLocation'] ?? 'fridge',
      manufacturingDate: json['manufacturingDate'] != null
          ? DateTime.tryParse(json['manufacturingDate'])
          : null,
      expirationDate: json['expirationDate'] != null
          ? DateTime.parse(json['expirationDate'])
          : DateTime.now().add(const Duration(days: 3)),
      addedAt: json['addedAt'] != null
          ? DateTime.parse(json['addedAt'])
          : DateTime.now(),
      barcode: json['barcode'],
      caloriesPer100g: (json['caloriesPer100g'] as num?)?.toDouble() ?? 0.0,
      proteinPer100g: (json['proteinPer100g'] as num?)?.toDouble() ?? 0.0,
      carbsPer100g: (json['carbsPer100g'] as num?)?.toDouble() ?? 0.0,
      fatPer100g: (json['fatPer100g'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] ?? '',
    );
  }
}

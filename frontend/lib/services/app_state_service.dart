import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
import 'meal_db_service.dart';

class UserProfile {
  String fullName;
  String email;
  int age;
  String gender; // "Nam", "Nữ"
  double heightCm;
  double weightKg;
  double targetWeightKg;
  String goal; // "LoseWeight", "Maintain", "GainWeight"
  String dietType; // "HighProtein", "LowCarb", "Balanced", "Vegetarian"
  String activityLevel; // "Sedentary", "Moderate", "Active"
  int targetCalories;
  double targetProtein;
  double targetCarbs;
  double targetFat;
  int dailyWaterGoalMl;
  bool hasProfile;
  String? avatarPath;
  String? googleEmail;
  String? facebookName;

  UserProfile({
    this.fullName = '',
    this.email = '',
    this.age = 0,
    this.gender = '',
    this.heightCm = 0.0,
    this.weightKg = 0.0,
    this.targetWeightKg = 0.0,
    this.goal = 'LoseWeight',
    this.dietType = 'HighProtein',
    this.activityLevel = 'Moderate',
    this.targetCalories = 0,
    this.targetProtein = 0.0,
    this.targetCarbs = 0.0,
    this.targetFat = 0.0,
    this.dailyWaterGoalMl = 0,
    this.hasProfile = false,
    this.avatarPath,
    this.googleEmail,
    this.facebookName,
  });

  bool get isProfileCompleted => hasProfile && heightCm > 0 && weightKg > 0 && age > 0;

  double get bmi {
    if (heightCm <= 0 || weightKg <= 0) return 0.0;
    final hM = heightCm / 100.0;
    return double.parse((weightKg / (hM * hM)).toStringAsFixed(1));
  }

  String get bmiCategory {
    final b = bmi;
    final isVi = AppStateService.instance.currentLanguage == 'vi';
    if (b <= 0) return isVi ? 'Chưa thiết lập' : 'Not configured';
    if (b < 18.5) return isVi ? 'Gầy / Thiếu cân' : 'Underweight';
    if (b < 23.0) return isVi ? 'Chuẩn / Khỏe mạnh' : 'Normal / Healthy';
    if (b < 25.0) return isVi ? 'Tiền béo phì' : 'Overweight';
    return isVi ? 'Béo phì / Cần giảm mỡ' : 'Obese / Need fat loss';
  }

  String get goalDisplayName {
    final isVi = AppStateService.instance.currentLanguage == 'vi';
    switch (goal) {
      case 'LoseWeight':
        return isVi ? 'Giảm cân & Đốt mỡ' : 'Lose Weight & Burn Fat';
      case 'GainWeight':
        return isVi ? 'Tăng cơ & Tăng cân' : 'Build Muscle & Gain Weight';
      default:
        return isVi ? 'Duy trì & Giữ dáng' : 'Maintain & Stay Fit';
    }
  }

  String get dietDisplayName {
    final isVi = AppStateService.instance.currentLanguage == 'vi';
    switch (dietType) {
      case 'HighProtein':
        return isVi ? 'Giàu đạm (High Protein)' : 'High Protein';
      case 'LowCarb':
        return isVi ? 'Ít tinh bột (Low Carb)' : 'Low Carb';
      case 'Vegetarian':
        return isVi ? 'Ăn chay lành mạnh' : 'Vegetarian';
      default:
        return isVi ? 'Cân bằng dinh dưỡng' : 'Balanced Nutrition';
    }
  }

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'email': email,
        'age': age,
        'gender': gender,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'targetWeightKg': targetWeightKg,
        'goal': goal,
        'dietType': dietType,
        'activityLevel': activityLevel,
        'targetCalories': targetCalories,
        'targetProtein': targetProtein,
        'targetCarbs': targetCarbs,
        'targetFat': targetFat,
        'dailyWaterGoalMl': dailyWaterGoalMl,
        'hasProfile': hasProfile,
        'avatarPath': avatarPath,
        'googleEmail': googleEmail,
        'facebookName': facebookName,
      };

  factory UserProfile.fromJson(Map<String, dynamic> map) => UserProfile(
        fullName: map['fullName'] ?? '',
        email: map['email'] ?? '',
        age: map['age'] ?? 0,
        gender: map['gender'] ?? '',
        heightCm: (map['heightCm'] as num?)?.toDouble() ?? 0.0,
        weightKg: (map['weightKg'] as num?)?.toDouble() ?? 0.0,
        targetWeightKg: (map['targetWeightKg'] as num?)?.toDouble() ?? 0.0,
        goal: map['goal'] ?? 'LoseWeight',
        dietType: map['dietType'] ?? 'HighProtein',
        activityLevel: map['activityLevel'] ?? 'Moderate',
        targetCalories: map['targetCalories'] ?? 0,
        targetProtein: (map['targetProtein'] as num?)?.toDouble() ?? 0.0,
        targetCarbs: (map['targetCarbs'] as num?)?.toDouble() ?? 0.0,
        targetFat: (map['targetFat'] as num?)?.toDouble() ?? 0.0,
        dailyWaterGoalMl: map['dailyWaterGoalMl'] ?? 0,
        hasProfile: map['hasProfile'] ?? false,
        avatarPath: map['avatarPath'],
        googleEmail: map['googleEmail'],
        facebookName: map['facebookName'],
      );
}

class MealLogEntry {
  String id;
  final String mealType; // Bữa sáng, Bữa trưa, Bữa tối, Ăn xế
  final String title;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final String imageUrl;
  final String time;
  final String loggedDate; // Định dạng YYYY-MM-DD (Ví dụ: 2026-10-24)

  MealLogEntry({
    required this.id,
    required this.mealType,
    required this.title,
    required this.calories,
    this.protein = 25,
    this.carbs = 30,
    this.fat = 10,
    required this.imageUrl,
    required this.time,
    String? loggedDate,
  }) : loggedDate = (loggedDate != null && loggedDate.isNotEmpty)
            ? (loggedDate.length >= 10 ? loggedDate.substring(0, 10) : loggedDate)
            : AppStateService.getTodayDateString();

  bool get isToday => loggedDate == AppStateService.getTodayDateString();

  /// Tên loại bữa ăn hiển thị tự động chuyển đổi theo ngôn ngữ Anh / Việt
  String get displayMealType {
    final isVi = AppStateService.instance.currentLanguage == 'vi';
    final t = mealType.trim().toUpperCase();
    if (t.contains('SÁNG') || t.contains('BREAKFAST')) return isVi ? 'Bữa sáng' : 'Breakfast';
    if (t.contains('TRƯA') || t.contains('LUNCH')) return isVi ? 'Bữa trưa' : 'Lunch';
    if (t.contains('TỐI') || t.contains('DINNER')) return isVi ? 'Bữa tối' : 'Dinner';
    if (t.contains('XẾ') || t.contains('PHỤ') || t.contains('SNACK')) return isVi ? 'Ăn xế' : 'Snack';
    return mealType;
  }

  /// Hiển thị thời gian thân thiện (Hôm nay, Hôm qua, hoặc ngày/tháng cụ thể)
  String get displayTime {
    final today = AppStateService.getTodayDateString();
    if (loggedDate == today) {
      return time.isNotEmpty && time != 'Hôm nay' ? time : 'Hôm nay';
    }
    final yesterday = AppStateService.getYesterdayDateString();
    if (loggedDate == yesterday) {
      return time.isNotEmpty && time != 'Hôm nay' ? 'Hôm qua $time' : 'Hôm qua';
    }
    final parts = loggedDate.split('-');
    if (parts.length == 3) {
      return '${parts[2]}/${parts[1]} ${time.isNotEmpty && time != 'Hôm nay' ? time : ''}'.trim();
    }
    return loggedDate;
  }

  /// Phân giải ảnh đại diện thông minh chính xác theo tên món ăn hoặc tên nguyên liệu
  static String resolveImageForTitle(String title, [String? fallbackUrl]) {
    if (fallbackUrl != null &&
        fallbackUrl.isNotEmpty &&
        !fallbackUrl.contains('photo-1546069901-ba9599a7e63c') &&
        (fallbackUrl.startsWith('http://') || fallbackUrl.startsWith('https://'))) {
      return fallbackUrl;
    }

    final lower = title.toLowerCase();

    // 1. Tinh bột & Ngũ cốc
    if (lower.contains('gạo') || lower.contains('cơm') || lower.contains('rice')) {
      return 'https://images.unsplash.com/photo-1586201375761-83865001e31c?auto=format&fit=crop&w=400&q=80';
    }
    if (lower.contains('yến mạch') || lower.contains('oat')) {
      return 'https://images.unsplash.com/photo-1586444248902-2f64eddc13df?auto=format&fit=crop&w=400&q=80';
    }
    if (lower.contains('khoai lang') || lower.contains('sweet potato')) {
      return 'https://images.unsplash.com/photo-1596097635121-14b63b7a0c19?auto=format&fit=crop&w=400&q=80';
    }
    if (lower.contains('khoai tây') || lower.contains('potato')) {
      return 'https://images.unsplash.com/photo-1518977676601-b53f82aba655?auto=format&fit=crop&w=400&q=80';
    }
    if (lower.contains('bánh mì') || lower.contains('bread') || lower.contains('toast')) {
      return 'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=400&q=80';
    }
    if (lower.contains('mì') || lower.contains('bún') || lower.contains('phở') || lower.contains('pasta') || lower.contains('noodle') || lower.contains('spaghetti')) {
      return 'https://images.unsplash.com/photo-1612927601601-6638404737ce?auto=format&fit=crop&w=400&q=80';
    }

    // 2. Thịt & Trứng
    if (lower.contains('ức gà') || lower.contains('chicken breast')) {
      return 'https://images.unsplash.com/photo-1604503468506-a8da13d82791?auto=format&fit=crop&w=400&q=80';
    }
    if (lower.contains('đùi gà') || lower.contains('má đùi') || lower.contains('cánh gà') || lower.contains('gà') || lower.contains('chicken')) {
      return 'https://images.unsplash.com/photo-1587593810167-a84920ea0781?auto=format&fit=crop&w=400&q=80';
    }
    if (lower.contains('bò') || lower.contains('beef') || lower.contains('steak')) {
      return 'https://images.unsplash.com/photo-1603048588665-791ca8aea617?auto=format&fit=crop&w=400&q=80';
    }
    if (lower.contains('heo') || lower.contains('lợn') || lower.contains('pork') || lower.contains('ba chỉ')) {
      return 'https://images.unsplash.com/photo-1602498456745-e9503b30470b?auto=format&fit=crop&w=400&q=80';
    }
    if (lower.contains('trứng') || lower.contains('egg')) {
      return 'https://images.unsplash.com/photo-1506976785307-8732e854ad03?auto=format&fit=crop&w=400&q=80';
    }

    // 3. Hải sản
    if (lower.contains('cá hồi') || lower.contains('salmon')) {
      return 'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?auto=format&fit=crop&w=400&q=80';
    }
    if (lower.contains('tôm') || lower.contains('shrimp') || lower.contains('prawn')) {
      return 'https://images.unsplash.com/photo-1565680018434-b513d5e5fd47?auto=format&fit=crop&w=400&q=80';
    }
    if (lower.contains('cá') || lower.contains('fish') || lower.contains('tuna') || lower.contains('mực')) {
      return 'https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?auto=format&fit=crop&w=400&q=80';
    }

    // 4. Sữa, Trái cây & Rau củ
    if (lower.contains('sữa chua') || lower.contains('yogurt')) {
      return 'https://images.unsplash.com/photo-1488477181946-6428a0291777?auto=format&fit=crop&w=400&q=80';
    }
    if (lower.contains('sữa') || lower.contains('milk') || lower.contains('whey')) {
      return 'https://images.unsplash.com/photo-1550583724-b2692b85b150?auto=format&fit=crop&w=400&q=80';
    }
    if (lower.contains('chuối') || lower.contains('banana')) {
      return 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?auto=format&fit=crop&w=400&q=80';
    }
    if (lower.contains('táo') || lower.contains('apple')) {
      return 'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?auto=format&fit=crop&w=400&q=80';
    }
    if (lower.contains('bơ') || lower.contains('avocado')) {
      return 'https://images.unsplash.com/photo-1523049673857-eb18f1d7b578?auto=format&fit=crop&w=400&q=80';
    }
    if (lower.contains('salad') || lower.contains('rau') || lower.contains('bông cải') || lower.contains('broccoli')) {
      return 'https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=400&q=80';
    }
    if (lower.contains('cà phê') || lower.contains('coffee') || lower.contains('trà') || lower.contains('tea')) {
      return 'https://images.unsplash.com/photo-1509042239860-f550ce710b93?auto=format&fit=crop&w=400&q=80';
    }

    return 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=400&q=80';
  }

  /// Ảnh hiển thị thực tế (tự động thay thế nếu là placeholder cũ)
  String get displayImageUrl => resolveImageForTitle(title, imageUrl);

  Map<String, dynamic> toJson() => {
        'id': id,
        'mealType': mealType,
        'title': title,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'imageUrl': displayImageUrl,
        'time': time,
        'loggedDate': loggedDate,
      };

  factory MealLogEntry.fromJson(Map<String, dynamic> map) {
    final title = map['title']?.toString() ?? '';
    final rawImg = map['imageUrl']?.toString() ?? '';
    return MealLogEntry(
      id: map['id']?.toString() ?? '',
      mealType: map['mealType']?.toString() ?? '',
      title: title,
      calories: (map['calories'] as num?)?.toInt() ?? 0,
      protein: (map['protein'] as num?)?.toInt() ?? 25,
      carbs: (map['carbs'] as num?)?.toInt() ?? 30,
      fat: (map['fat'] as num?)?.toInt() ?? 10,
      imageUrl: resolveImageForTitle(title, rawImg),
      time: map['time']?.toString() ?? '',
      loggedDate: map['loggedDate']?.toString() ?? map['LoggedDate']?.toString() ?? map['date']?.toString(),
    );
  }
}

class AiNutritionReview {
  final int score;
  final String period;
  final String periodLabel;
  final bool hasData;
  final String summary;
  final List<String> strengths;
  final List<String> improvements;
  final List<String> actionableAdvice;
  final NutritionReviewMetrics metrics;

  AiNutritionReview({
    required this.score,
    required this.period,
    required this.periodLabel,
    required this.hasData,
    required this.summary,
    required this.strengths,
    required this.improvements,
    required this.actionableAdvice,
    required this.metrics,
  });

  factory AiNutritionReview.fromJson(Map<String, dynamic> json) {
    return AiNutritionReview(
      score: (json['score'] as num?)?.toInt() ?? 0,
      period: json['period']?.toString() ?? 'yesterday',
      periodLabel: json['periodLabel']?.toString() ?? 'Hôm qua',
      hasData: json['hasData'] as bool? ?? true,
      summary: json['summary']?.toString() ?? '',
      strengths: (json['strengths'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      improvements: (json['improvements'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      actionableAdvice: (json['actionableAdvice'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      metrics: NutritionReviewMetrics.fromJson(json['metrics'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'score': score,
        'period': period,
        'periodLabel': periodLabel,
        'hasData': hasData,
        'summary': summary,
        'strengths': strengths,
        'improvements': improvements,
        'actionableAdvice': actionableAdvice,
        'metrics': metrics.toJson(),
      };
}

class NutritionReviewMetrics {
  final int totalCalories;
  final int targetCalories;
  final int deltaCalories;
  final int avgCaloriesPerDay;
  final int avgProteinG;
  final int targetProteinG;
  final int avgCarbsG;
  final int targetCarbsG;
  final int avgFatG;
  final int targetFatG;
  final int mealsCount;
  final int daysCount;

  NutritionReviewMetrics({
    this.totalCalories = 0,
    this.targetCalories = 2000,
    this.deltaCalories = 0,
    this.avgCaloriesPerDay = 0,
    this.avgProteinG = 0,
    this.targetProteinG = 90,
    this.avgCarbsG = 0,
    this.targetCarbsG = 220,
    this.avgFatG = 0,
    this.targetFatG = 50,
    this.mealsCount = 0,
    this.daysCount = 1,
  });

  factory NutritionReviewMetrics.fromJson(Map<String, dynamic> json) {
    return NutritionReviewMetrics(
      totalCalories: (json['totalCalories'] as num?)?.toInt() ?? 0,
      targetCalories: (json['targetCalories'] as num?)?.toInt() ?? 2000,
      deltaCalories: (json['deltaCalories'] as num?)?.toInt() ?? 0,
      avgCaloriesPerDay: (json['avgCaloriesPerDay'] as num?)?.toInt() ?? 0,
      avgProteinG: (json['avgProteinG'] as num?)?.toInt() ?? 0,
      targetProteinG: (json['targetProteinG'] as num?)?.toInt() ?? 90,
      avgCarbsG: (json['avgCarbsG'] as num?)?.toInt() ?? 0,
      targetCarbsG: (json['targetCarbsG'] as num?)?.toInt() ?? 220,
      avgFatG: (json['avgFatG'] as num?)?.toInt() ?? 0,
      targetFatG: (json['targetFatG'] as num?)?.toInt() ?? 50,
      mealsCount: (json['mealsCount'] as num?)?.toInt() ?? 0,
      daysCount: (json['daysCount'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'totalCalories': totalCalories,
        'targetCalories': targetCalories,
        'deltaCalories': deltaCalories,
        'avgCaloriesPerDay': avgCaloriesPerDay,
        'avgProteinG': avgProteinG,
        'targetProteinG': targetProteinG,
        'avgCarbsG': avgCarbsG,
        'targetCarbsG': targetCarbsG,
        'avgFatG': avgFatG,
        'targetFatG': targetFatG,
        'mealsCount': mealsCount,
        'daysCount': daysCount,
      };
}

/// Quản lý trạng thái động toàn bộ ứng dụng NutriSnap (hỗ trợ lưu cục bộ SharedPreferences)
class AppStateService extends ChangeNotifier {
  static final AppStateService instance = AppStateService._internal();
  AppStateService._internal();

  static String getTodayDateString() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String getYesterdayDateString() {
    final now = DateTime.now();
    final yest = DateTime(now.year, now.month, now.day - 1);
    final y = yest.year.toString().padLeft(4, '0');
    final m = yest.month.toString().padLeft(2, '0');
    final d = yest.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  // Theo dõi ngày hoạt động và chuyển ngày
  String? lastActiveDate;
  String? lastWaterDate;

  // 1. Hồ sơ người dùng & Mục tiêu dinh dưỡng động
  UserProfile userProfile = UserProfile();

  // Token đăng nhập
  String? authToken;

  // Chế độ Khách / Ngoại tuyến (Guest / Offline Mode)
  bool isGuestMode = false;
  DateTime? guestCreatedAt;
  int? testGuestDaysOverride; // Dành cho việc test mô phỏng ngày thứ 7+

  // Lưu chỉ số màn hình trước đó khi vào Chi tiết món ăn (để nút Back quay lại đúng nơi)
  int previousScreenIndex = 0;
  int currentScreenIndex = 0;

  void setCurrentScreenIndex(int index) {
    if (currentScreenIndex != index) {
      currentScreenIndex = index;
      notifyListeners();
    }
  }

  int get guestUsageDays {
    if (!isGuestMode) return 0;
    if (testGuestDaysOverride != null) return testGuestDaysOverride!;
    if (guestCreatedAt == null) return 1;
    final diff = DateTime.now().difference(guestCreatedAt!).inDays;
    return (diff + 1).clamp(1, 9999);
  }

  // Khóa ứng dụng nếu ở chế độ khách từ ngày thứ 7
  bool get isGuestTrialExpired => isGuestMode && guestUsageDays >= 7;

  void setGuestMode(bool val) {
    isGuestMode = val;
    if (val && guestCreatedAt == null) {
      guestCreatedAt = DateTime.now();
    }
    saveToLocalStorage();
    notifyListeners();
  }

  void setTestGuestDays(int? days) {
    testGuestDaysOverride = days;
    notifyListeners();
  }

  /// Đồng bộ kết quả đăng nhập từ Backend C# (chứa JWT Token thật và thông tin DB)
  void applyLoginData(Map<String, dynamic> data) {
    final token = data['token']?.toString();
    if (token != null && token.isNotEmpty) {
      authToken = token;
    }

    final bool isNew = data['isNewUser'] == true;
    final bool serverHasProfile = data['hasProfile'] == true;

    final rawAge = (data['age'] as num?)?.toInt() ?? 0;
    final rawHeight = (data['heightCm'] as num?)?.toDouble() ?? 0.0;
    final rawWeight = (data['weightKg'] as num?)?.toDouble() ?? 0.0;

    final avatar = data['avatarUrl']?.toString();
    final avatarFormatted = (avatar != null && avatar.isNotEmpty)
        ? (avatar.startsWith('http') ? avatar : '${ApiConstants.baseUrl}$avatar')
        : null;

    // Tạo đối tượng UserProfile hoàn toàn mới cho tài khoản này,
    // loại bỏ triệt để mọi số liệu từ phiên khách hoặc tài khoản trước đó lưu trong bộ nhớ tạm
    userProfile = UserProfile(
      email: data['email']?.toString() ?? '',
      fullName: data['fullName']?.toString() ?? '',
      avatarPath: avatarFormatted,
      googleEmail: data['googleEmail']?.toString(),
      facebookName: data['facebookName']?.toString(),
      age: rawAge,
      gender: data['gender']?.toString() ?? '',
      heightCm: rawHeight,
      weightKg: rawWeight,
      targetWeightKg: (data['targetWeightKg'] as num?)?.toDouble() ?? 0.0,
      goal: data['goal']?.toString() ?? 'LoseWeight',
      dietType: data['dietType']?.toString() ?? 'HighProtein',
      activityLevel: data['activityLevel']?.toString() ?? 'Moderate',
      targetCalories: (data['targetCalories'] as num?)?.toInt() ?? 0,
      targetProtein: (data['targetProtein'] as num?)?.toDouble() ?? 0.0,
      targetCarbs: (data['targetCarbs'] as num?)?.toDouble() ?? 0.0,
      targetFat: (data['targetFat'] as num?)?.toDouble() ?? 0.0,
      dailyWaterGoalMl: (data['dailyWaterGoalMl'] as num?)?.toInt() ?? 0,
      hasProfile: !isNew && serverHasProfile && rawHeight > 0 && rawWeight > 0 && rawAge > 0,
    );

    isGuestMode = false; // Đã liên kết tài khoản -> Hết trạng thái Khách
    testGuestDaysOverride = null;
    saveToLocalStorage();
    notifyListeners();

    // Tự động kéo nhật ký món ăn & nước uống từ Cloud Backend
    syncMealLogsFromServer();
    fetchDashboardToday();
  }

  /// Đồng bộ kết quả đăng nhập / liên kết mạng xã hội từ Backend C#
  void applySocialLoginData(Map<String, dynamic> data) {
    applyLoginData(data);
  }

  /// Liên kết tài khoản Google
  void linkGoogleAccount({required String email}) {
    userProfile.googleEmail = email;
    if (userProfile.fullName == 'Người dùng NutriSnap' || userProfile.fullName.isEmpty) {
      userProfile.fullName = email.split('@').first;
    }
    userProfile.email = email;
    userProfile.hasProfile = true;
    isGuestMode = false; // Đã liên kết tài khoản -> Hết trạng thái Khách
    testGuestDaysOverride = null;
    authToken ??= 'google_auth_${DateTime.now().millisecondsSinceEpoch}';
    saveToLocalStorage();
    notifyListeners();
  }

  /// Hủy liên kết Google trên máy và gửi lệnh đồng bộ lên Backend C#
  Future<void> unlinkGoogleAccount() async {
    userProfile.googleEmail = null;
    saveToLocalStorage();
    notifyListeners();

    try {
      if (authToken != null && !authToken!.startsWith('guest_')) {
        await http.post(
          Uri.parse('${ApiConstants.baseUrl}/api/user/unlink-social'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $authToken',
          },
          body: jsonEncode({'provider': 'google'}),
        );
      }
    } catch (e) {
      debugPrint('[Unlink Google Error] $e');
    }
  }

  /// Liên kết tài khoản Facebook
  void linkFacebookAccount({required String name, String? email}) {
    userProfile.facebookName = name;
    if (email != null && email.isNotEmpty) {
      userProfile.email = email;
    }
    if (userProfile.fullName == 'Người dùng NutriSnap' || userProfile.fullName.isEmpty) {
      userProfile.fullName = name;
    }
    userProfile.hasProfile = true;
    isGuestMode = false; // Đã liên kết tài khoản -> Hết trạng thái Khách
    testGuestDaysOverride = null;
    authToken ??= 'facebook_auth_${DateTime.now().millisecondsSinceEpoch}';
    saveToLocalStorage();
    notifyListeners();
  }

  /// Hủy liên kết Facebook trên máy và gửi lệnh đồng bộ lên Backend C#
  Future<void> unlinkFacebookAccount() async {
    userProfile.facebookName = null;
    saveToLocalStorage();
    notifyListeners();

    try {
      if (authToken != null && !authToken!.startsWith('guest_')) {
        await http.post(
          Uri.parse('${ApiConstants.baseUrl}/api/user/unlink-social'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $authToken',
          },
          body: jsonEncode({'provider': 'facebook'}),
        );
      }
    } catch (e) {
      debugPrint('[Unlink Facebook Error] $e');
    }
  }

  /// Gửi yêu cầu đổi email đăng ký mới (hệ thống gửi OTP 6 số qua email mới)
  Future<Map<String, dynamic>> requestChangeEmail(String newEmail) async {
    try {
      final token = authToken;
      if (token == null || token.isEmpty) {
        return {'success': false, 'message': 'Vui lòng đăng nhập để thực hiện đổi email!'};
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}/api/user/request-change-email');
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'newEmail': newEmail.trim()}),
          )
          .timeout(const Duration(seconds: 15));

      final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Mã xác nhận 6 số đã được gửi tới email mới!',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Không thể gửi mã xác nhận (${response.statusCode})',
        };
      }
    } catch (e) {
      debugPrint('[Request Change Email Error] $e');
      return {'success': false, 'message': 'Không thể kết nối đến máy chủ: $e'};
    }
  }

  /// Xác nhận mã OTP và hoàn tất đổi email đăng ký mới
  Future<Map<String, dynamic>> confirmChangeEmail({
    required String newEmail,
    required String otpCode,
  }) async {
    try {
      final token = authToken;
      if (token == null || token.isEmpty) {
        return {'success': false, 'message': 'Vui lòng đăng nhập để thực hiện đổi email!'};
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}/api/user/confirm-change-email');
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'newEmail': newEmail.trim(),
              'otpCode': otpCode.trim(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200) {
        final updatedEmail = data['newEmail']?.toString() ?? newEmail.trim();
        userProfile.email = updatedEmail;

        final newToken = data['token']?.toString();
        if (newToken != null && newToken.isNotEmpty) {
          authToken = newToken;
        }

        await saveToLocalStorage();
        notifyListeners();
        return {
          'success': true,
          'message': data['message'] ?? 'Đổi email đăng ký thành công!',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Xác nhận mã OTP thất bại (${response.statusCode})',
        };
      }
    } catch (e) {
      debugPrint('[Confirm Change Email Error] $e');
      return {'success': false, 'message': 'Không thể kết nối đến máy chủ: $e'};
    }
  }

  // Trạng thái kết nối mạng ngoại tuyến
  bool isOffline = false;

  void setOffline(bool val) {
    if (isOffline != val) {
      isOffline = val;
      notifyListeners();
    }
  }

  // 2. Món ăn đang chọn xem chi tiết
  MealItem? selectedMeal;

  // 3. Nước uống (ml) - Bắt đầu từ 0 cho tài khoản mới
  int waterIntakeMl = 0;

  // Chuỗi ngày đăng nhập
  int streakDays = 1;

  int get waterGoalMl => userProfile.dailyWaterGoalMl;

  void addWater(int amountMl) {
    final today = getTodayDateString();
    if (lastWaterDate != today) {
      waterIntakeMl = 0;
      lastWaterDate = today;
    }
    waterIntakeMl = (waterIntakeMl + amountMl).clamp(0, 6000);
    saveToLocalStorage();
    notifyListeners();

    // Đồng bộ lên Cloud Backend C# nếu đã đăng nhập tài khoản thật
    if (authToken != null && !isGuestMode && !authToken!.startsWith('guest_') && !authToken!.startsWith('mock_')) {
      _syncAddWaterToServer(amountMl);
    }
  }

  Future<void> _syncAddWaterToServer(int amountMl) async {
    try {
      final uri = Uri.parse(ApiConstants.addWater(amountMl));
      await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('[_syncAddWaterToServer Error] $e');
    }
  }

  void resetWater() {
    waterIntakeMl = 0;
    lastWaterDate = getTodayDateString();
    saveToLocalStorage();
    notifyListeners();
  }

  /// Kiểm tra chuyển ngày mới và tự động reset trạng thái Hôm Nay:
  /// - Lượng nước uống trở về 0ml
  /// - Nhật ký Hôm nay bắt đầu ngày mới (0 kcal đã nạp)
  /// - Cập nhật chuỗi Streak đăng nhập
  /// - Đồng bộ lại Dashboard từ Backend nếu online
  Future<void> checkAndResetForNewDay() async {
    final today = getTodayDateString();
    if (lastActiveDate == null) {
      lastActiveDate = today;
      lastWaterDate = today;
      await saveToLocalStorage();
      return;
    }

    if (lastActiveDate != today) {
      debugPrint('[AppStateService] ☀️ Phát hiện chuyển sang ngày mới: $today (Ngày trước: $lastActiveDate)');

      // 1. Cập nhật Streak
      final last = DateTime.tryParse(lastActiveDate!);
      final now = DateTime.now();
      if (last != null) {
        final lastDayMidnight = DateTime(last.year, last.month, last.day);
        final todayMidnight = DateTime(now.year, now.month, now.day);
        final diffDays = todayMidnight.difference(lastDayMidnight).inDays;

        if (diffDays == 1) {
          streakDays += 1;
        } else if (diffDays > 1) {
          streakDays = 1;
        }
      }

      // 2. Tự động reset nước của ngày mới về 0
      waterIntakeMl = 0;
      lastWaterDate = today;

      // 3. Cập nhật ngày hoạt động mới
      lastActiveDate = today;

      // 4. Lưu lại LocalStorage ngay lập tức
      await saveToLocalStorage();

      // 5. Nếu có tài khoản online, gọi fetchDashboardToday để lấy dữ liệu trắng của ngày mới từ server
      if (authToken != null && !isGuestMode && !authToken!.startsWith('guest_') && !authToken!.startsWith('mock_')) {
        await fetchDashboardToday();
        await syncMealLogsFromServer();
      }

      notifyListeners();
    }
  }

  // Ngôn ngữ ứng dụng: 'vi' (Mặc định) hoặc 'en'
  String currentLanguage = 'vi';

  Future<void> setLanguage(String lang) async {
    if (currentLanguage == lang) return;
    currentLanguage = lang;
    await saveToLocalStorage();
    notifyListeners();
  }

  // 4. Danh sách nhật ký bữa ăn - Bắt đầu rỗng cho tài khoản mới
  final List<MealLogEntry> mealLogs = [];

  /// Danh sách bữa ăn của HÔM NAY
  List<MealLogEntry> get todayMealLogs {
    final today = getTodayDateString();
    return mealLogs.where((item) => item.loggedDate == today).toList();
  }

  int get totalCaloriesLogged => todayMealLogs.fold(0, (sum, item) => sum + item.calories);
  int get dailyCalorieGoal => userProfile.targetCalories;
  int get remainingCalories => (dailyCalorieGoal - totalCaloriesLogged).clamp(0, dailyCalorieGoal);

  int get totalProteinLogged => todayMealLogs.fold(0, (sum, item) => sum + item.protein);
  int get totalCarbsLogged => todayMealLogs.fold(0, (sum, item) => sum + item.carbs);
  int get totalFatLogged => todayMealLogs.fold(0, (sum, item) => sum + item.fat);

  /// Cập nhật hồ sơ và tự động tính toán lại dinh dưỡng
  void updateProfileMetrics({
    required String fullName,
    required String gender,
    required int age,
    required double heightCm,
    required double weightKg,
    required double targetWeightKg,
    required String goal,
    required String dietType,
    required String activityLevel,
  }) {
    // 1. BMR (Mifflin-St Jeor)
    double bmr;
    if (gender == 'Nam') {
      bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age) + 5;
    } else {
      bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age) - 161;
    }

    // 2. TDEE
    double activityMultiplier = 1.375;
    if (activityLevel == 'Sedentary') activityMultiplier = 1.2;
    if (activityLevel == 'Active') activityMultiplier = 1.55;

    double tdee = bmr * activityMultiplier;

    // 3. Target Calories theo Goal
    int targetCal = tdee.round();
    if (goal == 'LoseWeight') {
      targetCal -= 400; // Thâm hụt calo an toàn (-400 kcal)
    } else if (goal == 'GainWeight') {
      targetCal += 400; // Thặng dư calo xây cơ (+400 kcal)
    }
    if (targetCal < 1200) targetCal = 1200;

    // 4. Phân bổ Macro theo Diet Type
    double pro, carb, fat;
    if (dietType == 'HighProtein') {
      pro = (targetCal * 0.35) / 4;
      carb = (targetCal * 0.40) / 4;
      fat = (targetCal * 0.25) / 9;
    } else if (dietType == 'LowCarb') {
      pro = (targetCal * 0.30) / 4;
      carb = (targetCal * 0.15) / 4;
      fat = (targetCal * 0.55) / 9;
    } else if (dietType == 'Vegetarian') {
      pro = (targetCal * 0.22) / 4;
      carb = (targetCal * 0.55) / 4;
      fat = (targetCal * 0.23) / 9;
    } else {
      pro = (targetCal * 0.25) / 4;
      carb = (targetCal * 0.50) / 4;
      fat = (targetCal * 0.25) / 9;
    }

    // Nước: 35ml / kg
    final waterGoal = (weightKg * 35).round();

    userProfile = UserProfile(
      fullName: fullName,
      email: userProfile.email,
      age: age,
      gender: gender,
      heightCm: heightCm,
      weightKg: weightKg,
      targetWeightKg: targetWeightKg,
      goal: goal,
      dietType: dietType,
      activityLevel: activityLevel,
      targetCalories: targetCal,
      targetProtein: double.parse(pro.toStringAsFixed(1)),
      targetCarbs: double.parse(carb.toStringAsFixed(1)),
      targetFat: double.parse(fat.toStringAsFixed(1)),
      dailyWaterGoalMl: waterGoal,
      hasProfile: true,
      avatarPath: userProfile.avatarPath,
      googleEmail: userProfile.googleEmail,
      facebookName: userProfile.facebookName,
    );

    saveToLocalStorage();
    notifyListeners();

    // Tự động đẩy chỉ số mới lên máy chủ Backend C#
    syncProfileToServer();
  }

  /// Đồng bộ chỉ số cơ thể lên Backend C# khi có tài khoản thật
  Future<void> syncProfileToServer() async {
    final token = authToken;
    if (token == null || token.isEmpty || token.startsWith('mock_') || token.startsWith('guest_')) {
      return;
    }
    try {
      final uri = Uri.parse(ApiConstants.profile);
      await http
          .put(
            uri,
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'fullName': userProfile.fullName,
              'age': userProfile.age,
              'gender': userProfile.gender,
              'heightCm': userProfile.heightCm,
              'weightKg': userProfile.weightKg,
              'targetWeightKg': userProfile.targetWeightKg,
              'goal': userProfile.goal,
              'dietType': userProfile.dietType,
              'activityLevel': userProfile.activityLevel,
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('[syncProfileToServer Error] $e');
    }
  }

  Future<void> updateAvatar(String? path) async {
    userProfile.avatarPath = path;
    await saveToLocalStorage();
    notifyListeners();

    // Đồng bộ lên Database Backend C# nếu đã đăng nhập và là file local
    if (authToken != null && path != null && !path.startsWith('http')) {
      try {
        final uri = Uri.parse('${ApiConstants.baseUrl}/api/user/avatar');
        final request = http.MultipartRequest('POST', uri);
        request.headers['Authorization'] = 'Bearer $authToken';
        request.files.add(await http.MultipartFile.fromPath('file', path));
        final streamedResponse = await request.send().timeout(const Duration(seconds: 15));
        if (streamedResponse.statusCode == 200) {
          final res = await http.Response.fromStream(streamedResponse);
          final data = jsonDecode(utf8.decode(res.bodyBytes));
          if (data['avatarUrl'] != null) {
            final fullUrl = '${ApiConstants.baseUrl}${data['avatarUrl']}';
            userProfile.avatarPath = fullUrl;
            await saveToLocalStorage();
            notifyListeners();
          }
        }
      } catch (e) {
        debugPrint('Lỗi upload avatar lên database backend: $e');
      }
    }
  }

  void addMealLogFromMeal(MealItem meal, {String mealType = 'BỮA TỐI'}) {
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final todayStr = getTodayDateString();

    final entry = MealLogEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      mealType: mealType,
      title: meal.strMeal,
      calories: meal.estimatedCalories,
      protein: meal.estimatedProtein,
      carbs: meal.estimatedCarbs,
      fat: meal.estimatedFat,
      imageUrl: meal.strMealThumb,
      time: timeStr,
      loggedDate: todayStr,
    );

    mealLogs.insert(0, entry);
    saveToLocalStorage();
    notifyListeners();

    if (authToken != null && !isGuestMode && !authToken!.startsWith('guest_') && !authToken!.startsWith('mock_')) {
      _addMealLogToServer(entry);
    }
  }

  void addCustomEntry({
    required String mealType,
    required String title,
    required int calories,
    int? protein,
    int? carbs,
    int? fat,
    String? imageUrl,
  }) {
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final todayStr = getTodayDateString();

    final entry = MealLogEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      mealType: mealType,
      title: title,
      calories: calories,
      protein: protein ?? (calories * 0.08).round(),
      carbs: carbs ?? (calories * 0.11).round(),
      fat: fat ?? (calories * 0.03).round(),
      imageUrl: MealLogEntry.resolveImageForTitle(title, imageUrl),
      time: timeStr,
      loggedDate: todayStr,
    );

    mealLogs.insert(0, entry);
    saveToLocalStorage();
    notifyListeners();

    if (authToken != null && !isGuestMode && !authToken!.startsWith('guest_') && !authToken!.startsWith('mock_')) {
      _addMealLogToServer(entry);
    }
  }

  void removeMealLog(String id) {
    mealLogs.removeWhere((item) => item.id == id);
    saveToLocalStorage();
    notifyListeners();

    if (authToken != null && !isGuestMode && !authToken!.startsWith('guest_') && !authToken!.startsWith('mock_')) {
      _deleteMealLogFromServer(id);
    }
  }

  /// Gửi bản ghi món ăn lên Backend C# qua POST /api/meallogs/log
  Future<void> _addMealLogToServer(MealLogEntry entry) async {
    final token = authToken;
    if (token == null || token.isEmpty || token.startsWith('mock_') || token.startsWith('guest_')) {
      return;
    }
    try {
      final uri = Uri.parse(ApiConstants.mealLogAdd);
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'mealTitle': entry.title,
              'mealType': entry.mealType,
              'calories': entry.calories,
              'proteinG': entry.protein.toDouble(),
              'carbsG': entry.carbs.toDouble(),
              'fatG': entry.fat.toDouble(),
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data['id'] != null) {
          entry.id = data['id'].toString();
          await saveToLocalStorage();
        }
      }
    } catch (e) {
      debugPrint('[_addMealLogToServer Error] $e');
    }
  }

  /// Xóa bản ghi món ăn trên Backend C# qua DELETE /api/meallogs/{id}
  Future<void> _deleteMealLogFromServer(String id) async {
    final intId = int.tryParse(id);
    if (intId == null) return;
    final token = authToken;
    if (token == null || token.isEmpty || token.startsWith('mock_') || token.startsWith('guest_')) {
      return;
    }
    try {
      final uri = Uri.parse(ApiConstants.mealLogDelete(intId));
      await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('[_deleteMealLogFromServer Error] $e');
    }
  }

  /// Tải toàn bộ lịch sử món ăn từ Cloud Backend C# qua GET /api/meallogs/history
  Future<void> syncMealLogsFromServer() async {
    final token = authToken;
    if (token == null || token.isEmpty || token.startsWith('mock_') || token.startsWith('guest_')) {
      return;
    }
    try {
      final uri = Uri.parse(ApiConstants.mealLogHistory);
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(response.bodyBytes));
        mealLogs.clear();
        final todayStr = getTodayDateString();
        final yesterdayStr = getYesterdayDateString();

        for (final item in list) {
          final id = item['id']?.toString() ?? '';
          final mealTitle = item['mealTitle']?.toString() ?? '';
          final mealType = item['mealType']?.toString() ?? 'BỮA TỐI';
          final calories = (item['calories'] as num?)?.toInt() ?? 0;
          final protein = (item['proteinG'] as num?)?.toInt() ?? 25;
          final carbs = (item['carbsG'] as num?)?.toInt() ?? 30;
          final fat = (item['fatG'] as num?)?.toInt() ?? 10;
          final rawDate = item['loggedDate']?.toString() ?? item['LoggedDate']?.toString() ?? todayStr;
          final loggedDate = rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate;

          String friendlyTime = 'Hôm nay';
          if (loggedDate == todayStr) {
            friendlyTime = 'Hôm nay';
          } else if (loggedDate == yesterdayStr) {
            friendlyTime = 'Hôm qua';
          } else {
            final parts = loggedDate.split('-');
            if (parts.length == 3) {
              friendlyTime = '${parts[2]}/${parts[1]}';
            } else {
              friendlyTime = loggedDate;
            }
          }

          mealLogs.add(MealLogEntry(
            id: id,
            mealType: mealType,
            title: mealTitle,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            imageUrl: MealLogEntry.resolveImageForTitle(mealTitle),
            time: friendlyTime,
            loggedDate: loggedDate,
          ));
        }
        await saveToLocalStorage();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[syncMealLogsFromServer Error] $e');
    }
  }

  /// Tải lượng nước và tổng quan hôm nay từ Cloud Backend C# qua GET /api/dashboard/today
  Future<void> fetchDashboardToday() async {
    final token = authToken;
    if (token == null || token.isEmpty || token.startsWith('mock_') || token.startsWith('guest_')) {
      return;
    }
    try {
      final uri = Uri.parse(ApiConstants.dashboardToday);
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final consumedWater = (data['consumedWaterMl'] as num?)?.toInt();
        if (consumedWater != null) {
          waterIntakeMl = consumedWater;
        }
        lastWaterDate = getTodayDateString();
        await saveToLocalStorage();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[fetchDashboardToday Error] $e');
    }
  }

  /// Lấy báo cáo đánh giá dinh dưỡng từ AI (qua Cloud Backend C# hoặc bộ thuật toán nội bộ)
  /// Cố định 1 lần duy nhất trong ngày, không đổi câu chữ mỗi lần mở app
  Future<AiNutritionReview> fetchAiNutritionReview(String period, {bool forceRefresh = false}) async {
    final token = authToken;
    final normalizedPeriod = period.toLowerCase();
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final localKey = 'nutrisnap_ai_fixed_review_${normalizedPeriod}_${currentLanguage}_$todayStr';

    // 1. Kiểm tra Cache cố định trên thiết bị nếu không bấm 'Tải lại'
    if (!forceRefresh) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cachedJson = prefs.getString(localKey);
        if (cachedJson != null && cachedJson.isNotEmpty) {
          final map = jsonDecode(cachedJson);
          if (map is Map<String, dynamic>) {
            return AiNutritionReview.fromJson(map);
          }
        }
      } catch (e) {
        debugPrint('[Local Review Cache Error] $e');
      }
    }

    // 2. Thử gọi qua Backend C# nếu đã đăng nhập tài khoản thực
    if (token != null &&
        token.isNotEmpty &&
        !token.startsWith('mock_') &&
        !token.startsWith('guest_')) {
      try {
        final uri = Uri.parse(
            '${ApiConstants.aiNutritionReview}?period=$normalizedPeriod&forceRefresh=$forceRefresh&lang=$currentLanguage');
        final response = await http.get(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          if (data is Map<String, dynamic>) {
            final hasData = data['hasData'] as bool? ?? true;
            // CHỈ lưu cố định vào thiết bị nếu ĐÃ CÓ dữ liệu bữa ăn thực tế
            // Đối với tài khoản mới chưa ghi món nào, không khóa để khi vừa thêm món là AI nhận diện ngay!
            if (hasData) {
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString(localKey, jsonEncode(data));
              } catch (_) {}
            }

            return AiNutritionReview.fromJson(data);
          }
        }
      } catch (e) {
        debugPrint('[fetchAiNutritionReview Remote Error] $e');
      }
    }

    // 3. Chế độ ngoại tuyến hoặc Tài khoản Khách: Dùng bộ thuật toán dinh dưỡng nội bộ thông minh
    final localReview = _generateLocalReview(normalizedPeriod);
    if (localReview.hasData) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(localKey, jsonEncode(localReview.toJson()));
      } catch (_) {}
    }
    return localReview;
  }

  AiNutritionReview _generateLocalReview(String period) {
    final isVi = currentLanguage == 'vi';
    final targetCalo = dailyCalorieGoal > 0 ? dailyCalorieGoal : 2000;
    final targetProt = userProfile.targetProtein > 0 ? userProfile.targetProtein.round() : 90;
    final targetCarb = userProfile.targetCarbs > 0 ? userProfile.targetCarbs.round() : 220;
    final targetFatG = userProfile.targetFat > 0 ? userProfile.targetFat.round() : 50;

    String periodLabel = isVi ? 'Hôm qua' : 'Yesterday';
    int daysCount = 1;
    if (period == '7days' || period == 'week') {
      periodLabel = isVi ? '7 ngày qua' : 'Last 7 days';
      daysCount = 7;
    } else if (period == 'month' || period == '30days') {
      periodLabel = isVi ? 'Tháng trước' : 'Last month';
      daysCount = 30;
    }

    if (mealLogs.isEmpty) {
      return AiNutritionReview(
        score: 0,
        period: period,
        periodLabel: periodLabel,
        hasData: false,
        summary: isVi
            ? 'Bạn chưa ghi lại bữa ăn nào trong khoảng thời gian này.'
            : 'No meals logged yet for this period.',
        strengths: [],
        improvements: [],
        actionableAdvice: [
          isVi
              ? 'Hãy bắt đầu chụp ảnh hoặc ghi chép bữa ăn mỗi ngày để Huấn luyện viên AI phân tích chi tiết cho bạn!'
              : 'Start logging your meals to receive personalized AI nutritional insights!',
        ],
        metrics: NutritionReviewMetrics(
          totalCalories: 0,
          targetCalories: targetCalo,
          deltaCalories: -targetCalo,
          avgCaloriesPerDay: 0,
          avgProteinG: 0,
          targetProteinG: targetProt,
          avgCarbsG: 0,
          targetCarbsG: targetCarb,
          avgFatG: 0,
          targetFatG: targetFatG,
          mealsCount: 0,
          daysCount: daysCount,
        ),
      );
    }

    final totalCalo = totalCaloriesLogged;
    final totalProt = totalProteinLogged;
    final totalCarb = totalCarbsLogged;
    final totalFatG = totalFatLogged;

    final avgCalo = daysCount > 1 ? (totalCalo / daysCount).round() : totalCalo;
    final avgProt = daysCount > 1 ? (totalProt / daysCount).round() : totalProt;
    final avgCarb = daysCount > 1 ? (totalCarb / daysCount).round() : totalCarb;
    final avgFat = daysCount > 1 ? (totalFatG / daysCount).round() : totalFatG;
    final deltaCalo = avgCalo - targetCalo;

    int score = 75;
    final strengths = <String>[];
    final improvements = <String>[];
    final advice = <String>[];

    final ratio = targetCalo > 0 ? avgCalo / targetCalo : 1.0;
    if (ratio >= 0.85 && ratio <= 1.10) {
      score += 15;
      strengths.add(isVi
          ? 'Kiểm soát calo rất tốt ($avgCalo / $targetCalo kcal).'
          : 'Great calorie control ($avgCalo / $targetCalo kcal).');
    } else if (ratio > 1.20) {
      score -= 15;
      improvements.add(isVi
          ? 'Lượng calo vượt mục tiêu +$deltaCalo kcal.'
          : 'Calorie intake exceeded goal by +$deltaCalo kcal.');
      advice.add(isVi
          ? 'Hạn chế đồ uống ngọt và thức ăn vặt trong bữa tiếp theo.'
          : 'Cut back on sugary drinks and high-calorie snacks.');
    } else if (ratio < 0.75) {
      score -= 10;
      improvements.add(isVi
          ? 'Năng lượng nạp vào còn khá thấp so với mục tiêu.'
          : 'Calorie intake was quite low compared to goal.');
      advice.add(isVi
          ? 'Bổ sung thêm các loại hạt hoặc sữa chua để bù năng lượng lành mạnh.'
          : 'Add healthy nuts or Greek yogurt for clean energy.');
    }

    if (avgProt >= (targetProt * 0.85)) {
      score += 10;
      strengths.add(isVi
          ? 'Lượng protein đạt chuẩn ($avgProt / $targetProt g).'
          : 'Excellent protein intake ($avgProt / $targetProt g).');
    } else {
      score -= 5;
      improvements.add(isVi
          ? 'Đạm còn thiếu nhẹ ($avgProt / $targetProt g).'
          : 'Protein was slightly below target ($avgProt / $targetProt g).');
      advice.add(isVi
          ? 'Tăng cường ức gà, trứng, cá hoặc đậu phụ vào thực đơn.'
          : 'Add lean poultry, eggs, fish or tofu to your meals.');
    }

    score = score.clamp(45, 98);

    final summary = isVi
        ? (score >= 85
            ? '$periodLabel bạn ăn uống rất xuất sắc, vóc dáng và sức khỏe đang đi đúng lộ trình!'
            : score >= 70
                ? '$periodLabel chế độ ăn tương đối ổn định, chỉ cần điều chỉnh nhẹ theo lời khuyên bên dưới.'
                : '$periodLabel chế độ ăn có sự chênh lệch so với mục tiêu. Hãy xem các gợi ý điều chỉnh!')
        : (score >= 85
            ? '$periodLabel you maintained an excellent diet, right on track with your goals!'
            : '$periodLabel your nutrition is decent, with room for minor adjustments below.');

    if (advice.isEmpty) {
      advice.add(isVi
          ? 'Uống đủ ít nhất 2L nước mỗi ngày để hỗ trợ tiêu hóa và trao đổi chất.'
          : 'Drink at least 2L of water daily to support metabolism.');
    }

    return AiNutritionReview(
      score: score,
      period: period,
      periodLabel: periodLabel,
      hasData: true,
      summary: summary,
      strengths: strengths,
      improvements: improvements,
      actionableAdvice: advice,
      metrics: NutritionReviewMetrics(
        totalCalories: totalCalo,
        targetCalories: targetCalo,
        deltaCalories: deltaCalo,
        avgCaloriesPerDay: avgCalo,
        avgProteinG: avgProt,
        targetProteinG: targetProt,
        avgCarbsG: avgCarb,
        targetCarbsG: targetCarb,
        avgFatG: avgFat,
        targetFatG: targetFatG,
        mealsCount: mealLogs.length,
        daysCount: daysCount,
      ),
    );
  }

  void setSelectedMeal(MealItem meal) {
    selectedMeal = meal;
    notifyListeners();
  }

  /// LƯU CỤC BỘ TRÊN THIẾT BỊ (Shared Preferences) - Cho cả tài khoản Khách & Đã đăng nhập
  Future<void> saveToLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = getTodayDateString();
      await prefs.setString('nutrisnap_user_profile', jsonEncode(userProfile.toJson()));
      await prefs.setString('nutrisnap_last_active_date', lastActiveDate ?? todayStr);
      await prefs.setString('nutrisnap_water_date', lastWaterDate ?? todayStr);
      await prefs.setInt('nutrisnap_water_intake', waterIntakeMl);
      await prefs.setInt('nutrisnap_streak_days', streakDays);
      await prefs.setString('nutrisnap_language', currentLanguage);
      await prefs.setBool('nutrisnap_is_guest_mode', isGuestMode);
      if (guestCreatedAt != null) {
        await prefs.setString('nutrisnap_guest_created_at', guestCreatedAt!.toIso8601String());
      } else {
        await prefs.remove('nutrisnap_guest_created_at');
      }
      final logsJson = jsonEncode(mealLogs.map((e) => e.toJson()).toList());
      await prefs.setString('nutrisnap_meal_logs', logsJson);
      if (authToken != null) {
        await prefs.setString('nutrisnap_auth_token', authToken!);
      } else {
        await prefs.remove('nutrisnap_auth_token');
      }
    } catch (e) {
      debugPrint('Lỗi lưu cục bộ (Local Storage): $e');
    }
  }

  /// TẢI DỮ LIỆU ĐÃ LƯU TRÊN MÁY
  Future<void> loadFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileStr = prefs.getString('nutrisnap_user_profile');
      if (profileStr != null && profileStr.isNotEmpty) {
        final Map<String, dynamic> map = jsonDecode(profileStr);
        userProfile = UserProfile.fromJson(map);
      }

      final todayStr = getTodayDateString();
      lastActiveDate = prefs.getString('nutrisnap_last_active_date');
      lastWaterDate = prefs.getString('nutrisnap_water_date');

      // Kiểm tra lượng nước: Nếu ngày lưu khác hôm nay -> Reset về 0
      if (lastWaterDate == todayStr) {
        waterIntakeMl = prefs.getInt('nutrisnap_water_intake') ?? 0;
      } else {
        waterIntakeMl = 0;
        lastWaterDate = todayStr;
      }

      streakDays = prefs.getInt('nutrisnap_streak_days') ?? 1;
      currentLanguage = prefs.getString('nutrisnap_language') ?? 'vi';
      isGuestMode = prefs.getBool('nutrisnap_is_guest_mode') ?? false;
      final guestCreatedStr = prefs.getString('nutrisnap_guest_created_at');
      if (guestCreatedStr != null && guestCreatedStr.isNotEmpty) {
        guestCreatedAt = DateTime.tryParse(guestCreatedStr);
      }

      final logsStr = prefs.getString('nutrisnap_meal_logs');
      if (logsStr != null && logsStr.isNotEmpty) {
        final List list = jsonDecode(logsStr);
        mealLogs.clear();
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            final entry = MealLogEntry.fromJson(item);
            // Nếu bản ghi cũ chưa có loggedDate trong SharedPreferences:
            // Nếu lastActiveDate lưu trước đó khác today -> bản ghi này thuộc ngày cũ!
            if (item['loggedDate'] == null && lastActiveDate != null && lastActiveDate != todayStr) {
              mealLogs.add(MealLogEntry(
                id: entry.id,
                mealType: entry.mealType,
                title: entry.title,
                calories: entry.calories,
                protein: entry.protein,
                carbs: entry.carbs,
                fat: entry.fat,
                imageUrl: entry.imageUrl,
                time: entry.time,
                loggedDate: lastActiveDate!,
              ));
            } else {
              mealLogs.add(entry);
            }
          }
        }
      }

      authToken = prefs.getString('nutrisnap_auth_token');

      // Tự động kiểm tra reset chuyển ngày và cập nhật streak
      await checkAndResetForNewDay();

      notifyListeners();

      if (authToken != null && !isGuestMode && !authToken!.startsWith('guest_') && !authToken!.startsWith('mock_')) {
        syncMealLogsFromServer();
        fetchDashboardToday();
      }
    } catch (e) {
      debugPrint('Lỗi tải từ cục bộ (Local Storage): $e');
    }
  }

  /// XÓA DỮ LIỆU LƯU TRÊN MÁY (Đăng xuất / Reset hoàn toàn)
  Future<void> clearLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('nutrisnap_user_profile');
      await prefs.remove('nutrisnap_last_active_date');
      await prefs.remove('nutrisnap_water_date');
      await prefs.remove('nutrisnap_water_intake');
      await prefs.remove('nutrisnap_meal_logs');
      await prefs.remove('nutrisnap_auth_token');
      await prefs.remove('nutrisnap_is_guest_mode');
      await prefs.remove('nutrisnap_guest_created_at');
      userProfile = UserProfile();
      waterIntakeMl = 0;
      streakDays = 1;
      mealLogs.clear();
      authToken = null;
      isGuestMode = false;
      guestCreatedAt = null;
      lastActiveDate = null;
      lastWaterDate = null;
      testGuestDaysOverride = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Lỗi xóa local storage: $e');
    }
  }

  void logout() {
    clearLocalStorage();
  }
}

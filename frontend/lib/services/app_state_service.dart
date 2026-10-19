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
  });

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

  Map<String, dynamic> toJson() => {
        'id': id,
        'mealType': mealType,
        'title': title,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'imageUrl': imageUrl,
        'time': time,
      };

  factory MealLogEntry.fromJson(Map<String, dynamic> map) => MealLogEntry(
        id: map['id'] ?? '',
        mealType: map['mealType'] ?? '',
        title: map['title'] ?? '',
        calories: map['calories'] ?? 0,
        protein: map['protein'] ?? 25,
        carbs: map['carbs'] ?? 30,
        fat: map['fat'] ?? 10,
        imageUrl: map['imageUrl'] ?? '',
        time: map['time'] ?? '',
      );
}

/// Quản lý trạng thái động toàn bộ ứng dụng NutriSnap (hỗ trợ lưu cục bộ SharedPreferences)
class AppStateService extends ChangeNotifier {
  static final AppStateService instance = AppStateService._internal();
  AppStateService._internal();

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
    saveToLocalStorage();
    notifyListeners();
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

  int get totalCaloriesLogged => mealLogs.fold(0, (sum, item) => sum + item.calories);
  int get dailyCalorieGoal => userProfile.targetCalories;
  int get remainingCalories => (dailyCalorieGoal - totalCaloriesLogged).clamp(0, dailyCalorieGoal);

  int get totalProteinLogged => mealLogs.fold(0, (sum, item) => sum + item.protein);
  int get totalCarbsLogged => mealLogs.fold(0, (sum, item) => sum + item.carbs);
  int get totalFatLogged => mealLogs.fold(0, (sum, item) => sum + item.fat);

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

    final entry = MealLogEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      mealType: mealType,
      title: title,
      calories: calories,
      protein: protein ?? (calories * 0.08).round(),
      carbs: carbs ?? (calories * 0.11).round(),
      fat: fat ?? (calories * 0.03).round(),
      imageUrl: imageUrl ?? 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=400&q=80',
      time: timeStr,
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
        for (final item in list) {
          final id = item['id']?.toString() ?? '';
          final mealTitle = item['mealTitle']?.toString() ?? '';
          final mealType = item['mealType']?.toString() ?? 'BỮA TỐI';
          final calories = (item['calories'] as num?)?.toInt() ?? 0;
          final protein = (item['proteinG'] as num?)?.toInt() ?? 25;
          final carbs = (item['carbsG'] as num?)?.toInt() ?? 30;
          final fat = (item['fatG'] as num?)?.toInt() ?? 10;

          mealLogs.add(MealLogEntry(
            id: id,
            mealType: mealType,
            title: mealTitle,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            imageUrl: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=400&q=80',
            time: 'Hôm nay',
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
        if (consumedWater != null && consumedWater > 0) {
          waterIntakeMl = consumedWater;
        }
        await saveToLocalStorage();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[fetchDashboardToday Error] $e');
    }
  }

  void setSelectedMeal(MealItem meal) {
    selectedMeal = meal;
    notifyListeners();
  }

  /// LƯU CỤC BỘ TRÊN THIẾT BỊ (Shared Preferences) - Cho cả tài khoản Khách & Đã đăng nhập
  Future<void> saveToLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('nutrisnap_user_profile', jsonEncode(userProfile.toJson()));
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
      waterIntakeMl = prefs.getInt('nutrisnap_water_intake') ?? 0;
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
          mealLogs.add(MealLogEntry.fromJson(item as Map<String, dynamic>));
        }
      }
      authToken = prefs.getString('nutrisnap_auth_token');
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

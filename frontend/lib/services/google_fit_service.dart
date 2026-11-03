import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'app_state_service.dart';
import 'step_tracker_service.dart';

/// Dữ liệu tổng hợp từ Google Fit Fitness API
class GoogleFitData {
  final int steps;
  final double calories;
  final double distanceKm;
  final DateTime syncTime;

  const GoogleFitData({
    required this.steps,
    required this.calories,
    required this.distanceKm,
    required this.syncTime,
  });
}

/// Dịch vụ kết nối và đồng bộ 2 chiều dữ liệu sức khoẻ từ Google Fit (Fitness REST API)
class GoogleFitService extends ChangeNotifier {
  static final GoogleFitService instance = GoogleFitService._internal();

  GoogleFitService._internal();

  static const List<String> _fitnessScopes = [
    'email',
    'https://www.googleapis.com/auth/fitness.activity.read',
    'https://www.googleapis.com/auth/fitness.body.read',
    'https://www.googleapis.com/auth/fitness.body.write',
    'https://www.googleapis.com/auth/fitness.nutrition.write',
  ];

  bool _isLinked = false;
  bool _isSyncing = false;
  String? _linkedEmail;
  DateTime? _lastSyncTime;
  String? _lastError;

  // Dữ liệu số đo mới nhất tìm thấy từ Google Fit
  double? _latestFitWeightKg;
  double? _latestFitHeightCm;
  DateTime? _latestFitWeightTime;

  bool get isLinked => _isLinked;
  bool get isSyncing => _isSyncing;
  String? get linkedEmail => _linkedEmail;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get lastError => _lastError;

  double? get latestFitWeightKg => _latestFitWeightKg;
  double? get latestFitHeightCm => _latestFitHeightCm;
  DateTime? get latestFitWeightTime => _latestFitWeightTime;

  String get _accountKey {
    final email = AppStateService.instance.userProfile.email.trim().toLowerCase();
    if (email.isNotEmpty) {
      return email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    }
    return 'guest';
  }

  /// Khởi tạo trạng thái liên kết từ Cloud UserProfile và SharedPreferences (Local fallback)
  Future<void> init() async {
    try {
      final userProfile = AppStateService.instance.userProfile;
      final prefs = await SharedPreferences.getInstance();

      // 1. Ưu tiên đọc trạng thái liên kết từ Cloud Database của tài khoản
      if (userProfile.isGoogleFitLinked) {
        _isLinked = true;
        _linkedEmail = userProfile.googleFitEmail;
      } else {
        // Dự phòng bộ nhớ cục bộ trên máy hiện tại
        _isLinked = prefs.getBool('nutrisnap_google_fit_linked_$_accountKey') ?? false;
        _linkedEmail = prefs.getString('nutrisnap_google_fit_email_$_accountKey');
      }

      final lastSyncStr = prefs.getString('nutrisnap_google_fit_last_sync_$_accountKey');
      if (lastSyncStr != null) {
        _lastSyncTime = DateTime.tryParse(lastSyncStr);
      }
      notifyListeners();

      // 2. Nếu đã liên kết, thử khôi phục phiên Google ngầm (signInSilently)
      // Giúp khi đổi sang điện thoại khác, ứng dụng vẫn tự động kết nối lại dữ liệu Google Fit!
      if (_isLinked) {
        final token = await _getAccessToken();
        if (token != null && token.isNotEmpty) {
          syncTodayData();
        }
      }
    } catch (e) {
      debugPrint('[GoogleFitService] Init error: $e');
    }
  }

  /// Khởi tạo GoogleSignIn client cho Google Fit
  /// LƯU Ý: KHÔNG truyền serverClientId ở đây vì sẽ kích hoạt luồng xin Server Auth Code cho Web Client
  /// với các scope Fitness nhạy cảm, gây ra lỗi PlatformException(12500, ApiException: 12500).
  /// Bằng cách chỉ truyền scopes, Google Play Services sẽ ủy quyền trực tiếp cho ứng dụng Android!
  GoogleSignIn _getFitnessGoogleSignIn() {
    return GoogleSignIn(
      scopes: _fitnessScopes,
    );
  }

  Future<String?> _getAccessToken() async {
    try {
      final googleSignIn = _getFitnessGoogleSignIn();
      GoogleSignInAccount? account = googleSignIn.currentUser;
      account ??= await googleSignIn.signInSilently();
      if (account == null) return null;
      final auth = await account.authentication;
      return auth.accessToken;
    } catch (e) {
      debugPrint('[GoogleFitService] GetAccessToken error: $e');
      return null;
    }
  }

  /// Mở hộp thoại Google cấp quyền đọc & ghi dữ liệu Google Fit
  Future<bool> linkGoogleFit(BuildContext context) async {
    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    try {
      final googleSignIn = _getFitnessGoogleSignIn();
      try {
        await googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? account = await googleSignIn.signIn();
      if (account == null) {
        _lastError = 'Bạn đã đóng hoặc hủy hộp thoại chọn tài khoản Google.';
        _isSyncing = false;
        notifyListeners();
        return false;
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      final accessToken = auth.accessToken;

      if (accessToken == null || accessToken.isEmpty) {
        _lastError = 'Không nhận được mã truy cập từ Google.';
        _isSyncing = false;
        notifyListeners();
        return false;
      }

      _isLinked = true;
      _linkedEmail = account.email;

      // 1. Lưu cục bộ trên thiết bị hiện tại
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('nutrisnap_google_fit_linked_$_accountKey', true);
      await prefs.setString('nutrisnap_google_fit_email_$_accountKey', account.email);

      // 2. ĐỒNG BỘ LÊN CLOUD DATABASE: Lưu vĩnh viễn vào tài khoản NutriSnap
      // Khi người dùng đăng nhập trên điện thoại khác, trạng thái liên kết sẽ tự động được giữ nguyên!
      await AppStateService.instance.setGoogleFitCloudStatus(isLinked: true, email: account.email);

      notifyListeners();

      // Đồng bộ dữ liệu ngày hôm nay ngay sau khi liên kết
      await _fetchFitnessData(accessToken);
      await _fetchLatestBodyMetrics(accessToken);

      _isSyncing = false;
      notifyListeners();
      return true;
    } catch (e, stack) {
      debugPrint('[GoogleFitService] Link error: $e\n$stack');
      _lastError = 'Lỗi kết nối Google: $e';
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  /// Đồng bộ lại dữ liệu hôm nay từ Google Fit
  Future<bool> syncTodayData() async {
    if (!_isLinked) return false;
    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    try {
      final accessToken = await _getAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        _isSyncing = false;
        notifyListeners();
        return false;
      }

      final success = await _fetchFitnessData(accessToken);
      await _fetchLatestBodyMetrics(accessToken);

      _isSyncing = false;
      notifyListeners();
      return success;
    } catch (e) {
      debugPrint('[GoogleFitService] Sync error: $e');
      _lastError = 'Lỗi đồng bộ: $e';
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  /// Gọi Google Fitness REST API để lấy Bước chân, Calo đốt & Km
  Future<bool> _fetchFitnessData(String accessToken) async {
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final startMillis = midnight.millisecondsSinceEpoch;
      final endMillis = now.millisecondsSinceEpoch;

      final url = Uri.parse('https://www.googleapis.com/fitness/v1/users/me/dataset:aggregate');
      final requestBody = {
        'aggregateBy': [
          // 1. Số bước chân (không giới hạn dataSourceId để nhận diện từ mọi nguồn: điện thoại, đồng hồ)
          {
            'dataTypeName': 'com.google.step_count.delta',
          },
          // 2. Calo tiêu hao chuyên biệt từ hoạt động/vận động (from_activities)
          {
            'dataTypeName': 'com.google.calories.expended',
            'dataSourceId': 'derived:com.google.calories.expended:com.google.android.gms:from_activities',
          },
          // 3. Calo tiêu hao tổng quát (dự phòng trường hợp thiết bị không hỗ trợ from_activities)
          {
            'dataTypeName': 'com.google.calories.expended',
          },
          // 4. Quãng đường di chuyển (km)
          {
            'dataTypeName': 'com.google.distance.delta',
          },
        ],
        'bucketByTime': {'durationMillis': 86400000},
        'startTimeMillis': startMillis,
        'endTimeMillis': endMillis,
      };

      final response = await http
          .post(
            url,
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json;encoding=utf-8',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        int totalSteps = 0;
        double activeCaloriesFromFit = 0.0;
        double generalCaloriesFromFit = 0.0;
        double totalDistanceMeters = 0.0;

        final buckets = data['bucket'] as List?;
        if (buckets != null && buckets.isNotEmpty) {
          for (var bucket in buckets) {
            final datasets = bucket['dataset'] as List?;
            if (datasets != null) {
              for (var ds in datasets) {
                final dsId = ds['dataSourceId']?.toString().toLowerCase() ?? '';
                final points = ds['point'] as List?;
                if (points != null && points.isNotEmpty) {
                  for (var pt in points) {
                    final values = pt['value'] as List?;
                    final ptTypeName = pt['dataTypeName']?.toString().toLowerCase() ?? '';
                    final typeName = ptTypeName.isNotEmpty ? ptTypeName : dsId;

                    if (values != null && values.isNotEmpty) {
                      final firstVal = values[0];
                      if (typeName.contains('step_count')) {
                        totalSteps += (firstVal['intVal'] as num?)?.toInt() ?? 0;
                      } else if (typeName.contains('calories')) {
                        final calVal = (firstVal['fpVal'] as num?)?.toDouble() ?? 0.0;
                        if (dsId.contains('from_activities')) {
                          // Calo tiêu hao chính xác từ vận động/đi bộ do Google Fit ghi nhận
                          activeCaloriesFromFit += calVal;
                        } else {
                          // Calo tổng (có thể gồm cả BMR/chuyển hóa cơ bản)
                          generalCaloriesFromFit += calVal;
                        }
                      } else if (typeName.contains('distance')) {
                        totalDistanceMeters += (firstVal['fpVal'] as num?)?.toDouble() ?? 0.0;
                      }
                    }
                  }
                }
              }
            }
          }
        }

        // TÍNH TOÁN LƯỢNG CALO ĐỐT CHÁY TỪ VẬN ĐỘNG / ĐI BỘ CHUẨN XÁC:
        double? finalCalories;

        if (activeCaloriesFromFit > 0) {
          // Ưu tiên 1: Google Fit trả về đúng calo tiêu hao từ vận động (from_activities)
          finalCalories = activeCaloriesFromFit;
        } else if (generalCaloriesFromFit > 0) {
          // Ưu tiên 2: Phân tách calo vận động từ calo tổng của Fit (loại bỏ BMR nền nếu bị gộp)
          final profile = AppStateService.instance.userProfile;
          final weight = profile.weightKg > 0 ? profile.weightKg : 65.0;
          final height = profile.heightCm > 0 ? profile.heightCm : 168.0;
          final age = profile.age > 0 ? profile.age : 25;
          final isMale = profile.gender == 'Nam';

          // BMR cả ngày theo công thức chuẩn Mifflin-St Jeor (kcal/ngày)
          final dailyBmr = isMale
              ? (10 * weight + 6.25 * height - 5 * age + 5)
              : (10 * weight + 6.25 * height - 5 * age - 161);
          final fractionOfDay = (now.hour + (now.minute / 60.0)) / 24.0;
          final elapsedBmr = dailyBmr * fractionOfDay;

          if (generalCaloriesFromFit > elapsedBmr + 10) {
            // Tách lượng calo đốt do vận động = Tổng calo - BMR tích lũy từ 0h đến thời điểm hiện tại
            final netCal = generalCaloriesFromFit - elapsedBmr;
            finalCalories = netCal > 0 ? netCal : null;
          } else if (generalCaloriesFromFit < 800 && totalSteps > 0) {
            // Nếu generalCalories nhỏ hơn 800 kcal thì đó chính là calo hoạt động
            finalCalories = generalCaloriesFromFit;
          }
        }

        // Ưu tiên 3: Nếu Google Fit trả về bước chân > 0 nhưng calo = 0 hoặc null,
        // tự động tính calo vận động chuẩn xác theo MET dựa trên cân nặng và số bước thực tế
        if ((finalCalories == null || finalCalories <= 0) && totalSteps > 0) {
          final profile = AppStateService.instance.userProfile;
          final weight = profile.weightKg > 0 ? profile.weightKg : 65.0;
          finalCalories = totalSteps * 0.04 * (weight / 70.0);
        }

        final distanceKm = totalDistanceMeters / 1000.0;
        _lastSyncTime = DateTime.now();

        debugPrint('[GoogleFitService] Đồng bộ Fit thành công: Bước=$totalSteps, CaloVậnĐộng=${finalCalories?.toStringAsFixed(1)}, Km=${distanceKm.toStringAsFixed(2)}');

        // Cập nhật số liệu vào StepTrackerService (bao gồm calo vận động chuẩn xác)
        StepTrackerService.instance.applyGoogleFitData(
          steps: totalSteps,
          calories: (finalCalories != null && finalCalories > 0) ? finalCalories : null,
          distanceKm: distanceKm > 0 ? distanceKm : null,
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('nutrisnap_google_fit_last_sync_$_accountKey', _lastSyncTime!.toIso8601String());

        return true;
      } else {
        debugPrint('[GoogleFitService] API Error: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('[GoogleFitService] Parse API error: $e');
      return false;
    }
  }

  /// Lấy số đo Cân nặng & Chiều cao gần nhất từ Google Fit
  Future<Map<String, double>?> fetchLatestBodyMetrics() async {
    final token = await _getAccessToken();
    if (token == null) return null;
    return await _fetchLatestBodyMetrics(token);
  }

  Future<Map<String, double>?> _fetchLatestBodyMetrics(String accessToken) async {
    try {
      final now = DateTime.now();
      final endNs = now.millisecondsSinceEpoch * 1000000;
      final startNs = now.subtract(const Duration(days: 90)).millisecondsSinceEpoch * 1000000;

      double? foundWeight;
      double? foundHeight;

      // 1. Lấy mốc cân nặng gần nhất từ merge_weight (trong vòng 90 ngày)
      try {
        final weightUrl = Uri.parse(
          'https://www.googleapis.com/fitness/v1/users/me/dataSources/derived:com.google.weight:com.google.android.gms:merge_weight/datasets/$startNs-$endNs',
        );
        final res = await http.get(weightUrl, headers: {'Authorization': 'Bearer $accessToken'}).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final points = data['point'] as List?;
          if (points != null && points.isNotEmpty) {
            final lastPoint = points.last;
            final vals = lastPoint['value'] as List?;
            if (vals != null && vals.isNotEmpty) {
              final val = vals[0]['fpVal'];
              if (val is num && val > 0) {
                foundWeight = double.parse(val.toDouble().toStringAsFixed(1));
                final endNsVal = lastPoint['endTimeNanos'];
                if (endNsVal != null) {
                  final ms = int.tryParse(endNsVal.toString()) != null
                      ? (int.parse(endNsVal.toString()) ~/ 1000000)
                      : null;
                  if (ms != null) {
                    _latestFitWeightTime = DateTime.fromMillisecondsSinceEpoch(ms);
                  }
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[GoogleFitService] Fetch weight error: $e');
      }

      // 2. Lấy mốc chiều cao từ merge_height
      try {
        final heightUrl = Uri.parse(
          'https://www.googleapis.com/fitness/v1/users/me/dataSources/derived:com.google.height:com.google.android.gms:merge_height/datasets/0-$endNs',
        );
        final res = await http.get(heightUrl, headers: {'Authorization': 'Bearer $accessToken'}).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final points = data['point'] as List?;
          if (points != null && points.isNotEmpty) {
            final lastPoint = points.last;
            final vals = lastPoint['value'] as List?;
            if (vals != null && vals.isNotEmpty) {
              final val = vals[0]['fpVal'];
              if (val is num && val > 0) {
                // Chiều cao trả về tính bằng mét -> nhân 100 thành cm
                foundHeight = double.parse((val.toDouble() * 100).toStringAsFixed(1));
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[GoogleFitService] Fetch height error: $e');
      }

      if (foundWeight != null || foundHeight != null) {
        _latestFitWeightKg = foundWeight;
        _latestFitHeightCm = foundHeight;
        notifyListeners();
        return {
          if (foundWeight != null) 'weightKg': foundWeight,
          if (foundHeight != null) 'heightCm': foundHeight,
        };
      }
      return null;
    } catch (e) {
      debugPrint('[GoogleFitService] Fetch body metrics error: $e');
      return null;
    }
  }

  // ==========================================
  // CHIỀU 2: ĐẨY DỮ LIỆU TỪ NUTRISNAP ➔ GOOGLE FIT
  // ==========================================

  /// Đẩy bản ghi dinh dưỡng bữa ăn lên Google Fit
  Future<bool> pushMealNutrition({
    required String foodName,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    String? mealType,
    DateTime? time,
  }) async {
    if (!_isLinked) return false;
    try {
      final token = await _getAccessToken();
      if (token == null) return false;

      final mealTime = time ?? DateTime.now();
      final startNs = mealTime.millisecondsSinceEpoch * 1000000;
      final endNs = startNs + (60 * 1000000000); // Khoảng thời gian 1 phút

      int mealTypeInt = 2; // Mặc định là bữa trưa
      final upperMeal = (mealType ?? '').toUpperCase();
      if (upperMeal.contains('SÁNG') || upperMeal.contains('BREAKFAST')) {
        mealTypeInt = 1;
      } else if (upperMeal.contains('TRƯA') || upperMeal.contains('LUNCH')) {
        mealTypeInt = 2;
      } else if (upperMeal.contains('TỐI') || upperMeal.contains('DINNER')) {
        mealTypeInt = 3;
      } else if (upperMeal.contains('NHẸ') || upperMeal.contains('SNACK')) {
        mealTypeInt = 4;
      }

      const dataSourceId = 'raw:com.google.nutrition:com.example.flutter_application_1:NutriSnap:NutriSnapNutrition';
      final patchUrl = Uri.parse('https://www.googleapis.com/fitness/v1/users/me/dataSources/$dataSourceId/datasets/$startNs-$endNs');

      final body = {
        'dataSourceId': dataSourceId,
        'minStartTimeNs': startNs,
        'maxEndTimeNs': endNs,
        'point': [
          {
            'startTimeNanos': startNs,
            'endTimeNanos': endNs,
            'dataTypeName': 'com.google.nutrition',
            'value': [
              {
                'mapVal': [
                  {'key': 'calories', 'value': {'fpVal': calories}},
                  {'key': 'protein', 'value': {'fpVal': protein}},
                  {'key': 'carbs.total', 'value': {'fpVal': carbs}},
                  {'key': 'fat.total', 'value': {'fpVal': fat}},
                ],
              },
              {'intVal': mealTypeInt},
              {'stringVal': foodName},
            ],
          },
        ],
      };

      var res = await http.patch(
        patchUrl,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 404 || res.statusCode == 400) {
        await _createNutritionDataSource(token);
        res = await http.patch(
          patchUrl,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 10));
      }

      debugPrint('[GoogleFitService] Push meal nutrition result: ${res.statusCode}');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[GoogleFitService] Push nutrition error: $e');
      return false;
    }
  }

  Future<void> _createNutritionDataSource(String token) async {
    try {
      final url = Uri.parse('https://www.googleapis.com/fitness/v1/users/me/dataSources');
      final body = {
        'dataStreamName': 'NutriSnapNutrition',
        'type': 'raw',
        'application': {'name': 'NutriSnap', 'version': '1.0'},
        'dataType': {
          'name': 'com.google.nutrition',
          'field': [
            {'name': 'nutrients', 'format': 'map'},
            {'name': 'meal_type', 'format': 'integer'},
            {'name': 'food_item', 'format': 'string'},
          ],
        },
      };
      await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
    } catch (e) {
      debugPrint('[GoogleFitService] Create nutrition dataSource error: $e');
    }
  }

  /// Đẩy lượng nước uống lên Google Fit
  Future<bool> pushHydration(int amountMl) async {
    if (!_isLinked || amountMl <= 0) return false;
    try {
      final token = await _getAccessToken();
      if (token == null) return false;

      final now = DateTime.now();
      final startNs = now.millisecondsSinceEpoch * 1000000;
      final endNs = startNs + (10 * 1000000000);
      final volumeLiters = amountMl / 1000.0;

      const dataSourceId = 'raw:com.google.hydration:com.example.flutter_application_1:NutriSnap:NutriSnapHydration';
      final patchUrl = Uri.parse('https://www.googleapis.com/fitness/v1/users/me/dataSources/$dataSourceId/datasets/$startNs-$endNs');

      final body = {
        'dataSourceId': dataSourceId,
        'minStartTimeNs': startNs,
        'maxEndTimeNs': endNs,
        'point': [
          {
            'startTimeNanos': startNs,
            'endTimeNanos': endNs,
            'dataTypeName': 'com.google.hydration',
            'value': [
              {'fpVal': volumeLiters},
            ],
          },
        ],
      };

      var res = await http.patch(
        patchUrl,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 404 || res.statusCode == 400) {
        await _createHydrationDataSource(token);
        res = await http.patch(
          patchUrl,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 10));
      }

      debugPrint('[GoogleFitService] Push hydration result: ${res.statusCode}');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[GoogleFitService] Push hydration error: $e');
      return false;
    }
  }

  Future<void> _createHydrationDataSource(String token) async {
    try {
      final url = Uri.parse('https://www.googleapis.com/fitness/v1/users/me/dataSources');
      final body = {
        'dataStreamName': 'NutriSnapHydration',
        'type': 'raw',
        'application': {'name': 'NutriSnap', 'version': '1.0'},
        'dataType': {
          'name': 'com.google.hydration',
          'field': [
            {'name': 'volume', 'format': 'floatPoint'},
          ],
        },
      };
      await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
    } catch (e) {
      debugPrint('[GoogleFitService] Create hydration dataSource error: $e');
    }
  }

  /// Đẩy số cân nặng mới lên Google Fit
  Future<bool> pushWeight(double weightKg) async {
    if (!_isLinked || weightKg <= 0) return false;
    try {
      final token = await _getAccessToken();
      if (token == null) return false;

      final now = DateTime.now();
      final startNs = now.millisecondsSinceEpoch * 1000000;
      final endNs = startNs + (10 * 1000000000);

      const dataSourceId = 'raw:com.google.weight:com.example.flutter_application_1:NutriSnap:NutriSnapWeight';
      final patchUrl = Uri.parse('https://www.googleapis.com/fitness/v1/users/me/dataSources/$dataSourceId/datasets/$startNs-$endNs');

      final body = {
        'dataSourceId': dataSourceId,
        'minStartTimeNs': startNs,
        'maxEndTimeNs': endNs,
        'point': [
          {
            'startTimeNanos': startNs,
            'endTimeNanos': endNs,
            'dataTypeName': 'com.google.weight',
            'value': [
              {'fpVal': weightKg},
            ],
          },
        ],
      };

      var res = await http.patch(
        patchUrl,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 404 || res.statusCode == 400) {
        await _createWeightDataSource(token);
        res = await http.patch(
          patchUrl,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 10));
      }

      debugPrint('[GoogleFitService] Push weight result: ${res.statusCode}');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[GoogleFitService] Push weight error: $e');
      return false;
    }
  }

  Future<void> _createWeightDataSource(String token) async {
    try {
      final url = Uri.parse('https://www.googleapis.com/fitness/v1/users/me/dataSources');
      final body = {
        'dataStreamName': 'NutriSnapWeight',
        'type': 'raw',
        'application': {'name': 'NutriSnap', 'version': '1.0'},
        'dataType': {
          'name': 'com.google.weight',
          'field': [
            {'name': 'weight', 'format': 'floatPoint'},
          ],
        },
      };
      await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
    } catch (e) {
      debugPrint('[GoogleFitService] Create weight dataSource error: $e');
    }
  }

  /// Hủy liên kết Google Fit và quay về cảm biến máy nội bộ
  Future<void> unlinkGoogleFit() async {
    _isLinked = false;
    _linkedEmail = null;
    _lastSyncTime = null;
    _latestFitWeightKg = null;
    _latestFitHeightCm = null;
    _latestFitWeightTime = null;
    notifyListeners();

    try {
      final googleSignIn = _getFitnessGoogleSignIn();
      await googleSignIn.signOut();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('nutrisnap_google_fit_linked_$_accountKey');
      await prefs.remove('nutrisnap_google_fit_email_$_accountKey');
      await prefs.remove('nutrisnap_google_fit_last_sync_$_accountKey');

      // Hủy liên kết trên Cloud Database
      await AppStateService.instance.setGoogleFitCloudStatus(isLinked: false);

      StepTrackerService.instance.clearGoogleFitData();
    } catch (e) {
      debugPrint('[GoogleFitService] Unlink error: $e');
    }
  }

  /// Chuyển đổi tài khoản: Nạp lại trạng thái liên kết
  Future<void> reloadForCurrentUser() async {
    _isLinked = false;
    _linkedEmail = null;
    _lastSyncTime = null;
    _latestFitWeightKg = null;
    _latestFitHeightCm = null;
    _latestFitWeightTime = null;
    await init();
  }
}

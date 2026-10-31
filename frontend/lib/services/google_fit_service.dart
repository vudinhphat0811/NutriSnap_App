import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
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

/// Dịch vụ kết nối và đồng bộ dữ liệu sức khoẻ từ Google Fit (Fitness REST API)
class GoogleFitService extends ChangeNotifier {
  static final GoogleFitService instance = GoogleFitService._internal();

  GoogleFitService._internal();

  static const List<String> _fitnessScopes = [
    'email',
    'https://www.googleapis.com/auth/fitness.activity.read',
    'https://www.googleapis.com/auth/fitness.location.read',
  ];

  bool _isLinked = false;
  bool _isSyncing = false;
  String? _linkedEmail;
  DateTime? _lastSyncTime;
  String? _lastError;

  bool get isLinked => _isLinked;
  bool get isSyncing => _isSyncing;
  String? get linkedEmail => _linkedEmail;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get lastError => _lastError;

  String get _accountKey {
    final email = AppStateService.instance.userProfile.email.trim().toLowerCase();
    if (email.isNotEmpty) {
      return email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    }
    return 'guest';
  }

  /// Khởi tạo trạng thái liên kết từ SharedPreferences
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isLinked = prefs.getBool('nutrisnap_google_fit_linked_$_accountKey') ?? false;
      _linkedEmail = prefs.getString('nutrisnap_google_fit_email_$_accountKey');
      final lastSyncStr = prefs.getString('nutrisnap_google_fit_last_sync_$_accountKey');
      if (lastSyncStr != null) {
        _lastSyncTime = DateTime.tryParse(lastSyncStr);
      }
      notifyListeners();

      // Nếu đã liên kết, tự động đồng bộ ngầm dữ liệu mới nhất
      if (_isLinked) {
        syncTodayData();
      }
    } catch (e) {
      debugPrint('[GoogleFitService] Init error: $e');
    }
  }

  GoogleSignIn _getFitnessGoogleSignIn() {
    return GoogleSignIn(
      scopes: _fitnessScopes,
      serverClientId: ApiConstants.googleServerClientId.isNotEmpty ? ApiConstants.googleServerClientId : null,
    );
  }

  /// Mở hộp thoại Google cấp quyền đọc dữ liệu Google Fit
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

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('nutrisnap_google_fit_linked_$_accountKey', true);
      await prefs.setString('nutrisnap_google_fit_email_$_accountKey', account.email);

      notifyListeners();

      // Đồng bộ dữ liệu ngày hôm nay ngay sau khi liên kết
      await _fetchFitnessData(accessToken);
      _isSyncing = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[GoogleFitService] Link error: $e');
      _lastError = 'Lỗi kết nối Google Fit: $e';
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
      final googleSignIn = _getFitnessGoogleSignIn();
      GoogleSignInAccount? account = googleSignIn.currentUser;
      account ??= await googleSignIn.signInSilently();

      if (account == null) {
        _isSyncing = false;
        notifyListeners();
        return false;
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      final accessToken = auth.accessToken;

      if (accessToken == null || accessToken.isEmpty) {
        _isSyncing = false;
        notifyListeners();
        return false;
      }

      final success = await _fetchFitnessData(accessToken);
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

  /// Gọi Google Fitness REST API: POST /fitness/v1/users/me/dataset:aggregate
  Future<bool> _fetchFitnessData(String accessToken) async {
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final startMillis = midnight.millisecondsSinceEpoch;
      final endMillis = now.millisecondsSinceEpoch;

      final url = Uri.parse('https://www.googleapis.com/fitness/v1/users/me/dataset:aggregate');
      final requestBody = {
        'aggregateBy': [
          {
            'dataTypeName': 'com.google.step_count.delta',
            'dataSourceId': 'derived:com.google.step_count.delta:com.google.android.gms:estimated_steps',
          },
          {
            'dataTypeName': 'com.google.calories.expended',
            'dataSourceId': 'derived:com.google.calories.expended:com.google.android.gms:merge_calories_expended',
          },
          {
            'dataTypeName': 'com.google.distance.delta',
            'dataSourceId': 'derived:com.google.distance.delta:com.google.android.gms:merge_distance_delta',
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
        double totalCalories = 0.0;
        double totalDistanceMeters = 0.0;

        final buckets = data['bucket'] as List?;
        if (buckets != null && buckets.isNotEmpty) {
          for (var bucket in buckets) {
            final datasets = bucket['dataset'] as List?;
            if (datasets != null) {
              for (var ds in datasets) {
                final points = ds['point'] as List?;
                if (points != null) {
                  for (var pt in points) {
                    final values = pt['value'] as List?;
                    final dataTypeName = pt['dataTypeName']?.toString() ?? '';
                    if (values != null && values.isNotEmpty) {
                      final firstVal = values[0];
                      if (dataTypeName.contains('step_count')) {
                        totalSteps += (firstVal['intVal'] as num?)?.toInt() ?? 0;
                      } else if (dataTypeName.contains('calories')) {
                        totalCalories += (firstVal['fpVal'] as num?)?.toDouble() ?? 0.0;
                      } else if (dataTypeName.contains('distance')) {
                        totalDistanceMeters += (firstVal['fpVal'] as num?)?.toDouble() ?? 0.0;
                      }
                    }
                  }
                }
              }
            }
          }
        }

        final distanceKm = totalDistanceMeters / 1000.0;
        _lastSyncTime = DateTime.now();

        // Cập nhật số liệu vào StepTrackerService
        StepTrackerService.instance.applyGoogleFitData(
          steps: totalSteps,
          calories: totalCalories > 0 ? totalCalories : null,
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

  /// Hủy liên kết Google Fit và quay về cảm biến máy nội bộ
  Future<void> unlinkGoogleFit() async {
    _isLinked = false;
    _linkedEmail = null;
    _lastSyncTime = null;
    notifyListeners();

    try {
      final googleSignIn = _getFitnessGoogleSignIn();
      await googleSignIn.signOut();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('nutrisnap_google_fit_linked_$_accountKey');
      await prefs.remove('nutrisnap_google_fit_email_$_accountKey');
      await prefs.remove('nutrisnap_google_fit_last_sync_$_accountKey');

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
    await init();
  }
}

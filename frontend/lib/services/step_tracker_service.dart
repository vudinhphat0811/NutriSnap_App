import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_state_service.dart';

/// Dịch vụ Đếm Bước Chân & Theo Dõi Vận Động (Step Tracker & Calorie Burn Service)
class StepTrackerService extends ChangeNotifier {
  static final StepTrackerService instance = StepTrackerService._internal();

  StepTrackerService._internal();

  StreamSubscription<StepCount>? _stepCountSubscription;
  StreamSubscription<PedestrianStatus>? _pedestrianStatusSubscription;

  int _todaySteps = 0;
  int _stepGoal = 6000;
  int _lastRawSensorSteps = 0;
  int _todayBaseSteps = 0;
  String _pedestrianStatus = 'ready'; // 'walking', 'stopped', 'unknown', 'ready'
  bool _isSensorAvailable = true;
  bool _hasPermission = false;
  bool _isInitialized = false;

  bool _isUsingGoogleFit = false;
  double? _googleFitCalories;
  double? _googleFitDistanceKm;

  int get todaySteps => _todaySteps;
  int get stepGoal => _stepGoal;
  int get lastRawSensorSteps => _lastRawSensorSteps;
  double get stepProgress => _stepGoal > 0 ? (_todaySteps / _stepGoal).clamp(0.0, 1.0) : 0.0;
  String get pedestrianStatus => _isUsingGoogleFit ? 'google_fit' : _pedestrianStatus;
  bool get isSensorAvailable => _isSensorAvailable;
  bool get hasPermission => _hasPermission;
  bool get isInitialized => _isInitialized;
  bool get isUsingGoogleFit => _isUsingGoogleFit;

  /// Cập nhật dữ liệu từ Google Fit
  void applyGoogleFitData({required int steps, double? calories, double? distanceKm}) {
    _isUsingGoogleFit = true;
    _todaySteps = steps;
    _googleFitCalories = calories;
    _googleFitDistanceKm = distanceKm;
    notifyListeners();
  }

  /// Xóa dữ liệu Google Fit khi hủy liên kết
  void clearGoogleFitData() {
    _isUsingGoogleFit = false;
    _googleFitCalories = null;
    _googleFitDistanceKm = null;
    notifyListeners();
  }

  /// Quãng đường đã đi (km) - được cá nhân hoá theo chiều cao người dùng (hoặc lấy từ Google Fit)
  double get distanceKm {
    if (_googleFitDistanceKm != null && _googleFitDistanceKm! > 0) {
      return _googleFitDistanceKm!;
    }
    final height = AppStateService.instance.userProfile.heightCm;
    final gender = AppStateService.instance.userProfile.gender;
    final h = height > 0 ? height : 168.0;
    final strideFactor = (gender == 'Nam') ? 0.415 : 0.413;
    final strideM = (h * strideFactor) / 100.0;
    return (_todaySteps * strideM) / 1000.0;
  }

  /// Lượng calo đốt cháy (kcal) - được cá nhân hoá theo cân nặng (hoặc lấy từ Google Fit)
  double get burnedCalories {
    if (_googleFitCalories != null && _googleFitCalories! > 0) {
      return _googleFitCalories!;
    }
    final weight = AppStateService.instance.userProfile.weightKg;
    final w = weight > 0 ? weight : 65.0;
    // Công thức MET đi bộ tiêu chuẩn theo trọng lượng cơ thể
    return _todaySteps * 0.04 * (w / 70.0);
  }

  /// Thời gian vận động ước tính (phút) - trung bình 100 bước/phút
  int get activeMinutes {
    return (_todaySteps / 100).round();
  }

  String get _accountKey {
    final email = AppStateService.instance.userProfile.email.trim().toLowerCase();
    if (email.isNotEmpty) {
      return email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    }
    return 'guest';
  }

  String _getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Khởi tạo dịch vụ
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = _getTodayDateString();
      final savedDate = prefs.getString('nutrisnap_steps_date_$_accountKey');
      _stepGoal = prefs.getInt('nutrisnap_steps_goal_$_accountKey') ?? 6000;

      if (savedDate == todayStr) {
        _todaySteps = prefs.getInt('nutrisnap_steps_today_$_accountKey') ?? 0;
        _todayBaseSteps = prefs.getInt('nutrisnap_steps_base_$_accountKey') ?? 0;
      } else {
        // Ngày mới -> reset về 0
        _todaySteps = 0;
        _todayBaseSteps = 0;
        await prefs.setString('nutrisnap_steps_date_$_accountKey', todayStr);
        await prefs.setInt('nutrisnap_steps_today_$_accountKey', 0);
        await prefs.setInt('nutrisnap_steps_base_$_accountKey', 0);
      }

      _isInitialized = true;
      notifyListeners();

      // Kiểm tra và khởi động lắng nghe cảm biến
      await _checkPermissionAndStartListening();
    } catch (e) {
      debugPrint('[StepTrackerService] Init error: $e');
    }
  }

  /// Kiểm tra quyền và lắng nghe luồng cảm biến phần cứng
  Future<void> _checkPermissionAndStartListening() async {
    try {
      final status = await Permission.activityRecognition.status;
      _hasPermission = status.isGranted;

      if (_hasPermission) {
        _startListening();
      }
    } catch (e) {
      debugPrint('[StepTrackerService] Check permission error: $e');
    }
  }

  /// Yêu cầu cấp quyền nhận diện vận động
  Future<bool> requestPermission() async {
    try {
      final status = await Permission.activityRecognition.request();
      _hasPermission = status.isGranted;
      notifyListeners();

      if (_hasPermission) {
        _startListening();
      }
      return _hasPermission;
    } catch (e) {
      debugPrint('[StepTrackerService] Request permission error: $e');
      return false;
    }
  }

  /// Bắt đầu lắng nghe cảm biến phần cứng Pedometer
  void _startListening() {
    _stepCountSubscription?.cancel();
    _pedestrianStatusSubscription?.cancel();

    try {
      _stepCountSubscription = Pedometer.stepCountStream.listen(
        _onStepCount,
        onError: (error) {
          debugPrint('[StepTrackerService] Pedometer error: $error');
          _isSensorAvailable = false;
          notifyListeners();
        },
        cancelOnError: false,
      );

      _pedestrianStatusSubscription = Pedometer.pedestrianStatusStream.listen(
        _onPedestrianStatusChanged,
        onError: (error) {
          debugPrint('[StepTrackerService] Pedestrian status error: $error');
        },
        cancelOnError: false,
      );

      _isSensorAvailable = true;
    } catch (e) {
      debugPrint('[StepTrackerService] Start listening error: $e');
      _isSensorAvailable = false;
    }
  }

  void _onStepCount(StepCount event) {
    if (_isUsingGoogleFit) return;
    final rawSteps = event.steps;
    _lastRawSensorSteps = rawSteps;
    final todayStr = _getTodayDateString();

    SharedPreferences.getInstance().then((prefs) {
      final savedDate = prefs.getString('nutrisnap_steps_date_$_accountKey');

      if (savedDate != todayStr || _todayBaseSteps == 0) {
        // Thiết lập mốc cơ sở cho ngày hôm nay
        _todayBaseSteps = rawSteps - _todaySteps;
        if (_todayBaseSteps < 0) _todayBaseSteps = rawSteps;
        prefs.setString('nutrisnap_steps_date_$_accountKey', todayStr);
        prefs.setInt('nutrisnap_steps_base_$_accountKey', _todayBaseSteps);
      } else if (rawSteps < _todayBaseSteps) {
        // Trường hợp máy vừa khởi động lại (Reboot) -> cảm biến reset về 0
        _todayBaseSteps = rawSteps - _todaySteps;
        if (_todayBaseSteps < 0) _todayBaseSteps = 0;
        prefs.setInt('nutrisnap_steps_base_$_accountKey', _todayBaseSteps);
      }

      final calculatedSteps = (rawSteps - _todayBaseSteps).clamp(0, 999999);
      if (calculatedSteps != _todaySteps) {
        _todaySteps = calculatedSteps;
        prefs.setInt('nutrisnap_steps_today_$_accountKey', _todaySteps);
        notifyListeners();
      }
    });
  }

  void _onPedestrianStatusChanged(PedestrianStatus event) {
    _pedestrianStatus = event.status;
    notifyListeners();
  }

  /// Cập nhật mục tiêu bước chân hàng ngày
  Future<void> updateGoal(int newGoal) async {
    if (newGoal <= 0) return;
    _stepGoal = newGoal;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('nutrisnap_steps_goal_$_accountKey', _stepGoal);
    } catch (e) {
      debugPrint('[StepTrackerService] Update goal error: $e');
    }
  }

  /// Thêm bước chân thủ công (Hữu ích khi tập máy chạy bộ không cầm điện thoại hoặc test trên máy ảo)
  Future<void> addManualSteps(int steps) async {
    if (steps <= 0) return;
    _todaySteps += steps;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = _getTodayDateString();
      await prefs.setString('nutrisnap_steps_date_$_accountKey', todayStr);
      await prefs.setInt('nutrisnap_steps_today_$_accountKey', _todaySteps);
    } catch (e) {
      debugPrint('[StepTrackerService] Add manual steps error: $e');
    }
  }

  /// Chuyển đổi tài khoản: Nạp lại bước chân cho tài khoản hiện tại
  Future<void> reloadForCurrentUser() async {
    _isInitialized = false;
    _todaySteps = 0;
    _todayBaseSteps = 0;
    await init();
  }

  @override
  void dispose() {
    _stepCountSubscription?.cancel();
    _pedestrianStatusSubscription?.cancel();
    super.dispose();
  }
}

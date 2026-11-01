import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_state_service.dart';

/// Dịch vụ Đếm Bước Chân & Theo Dõi Vận Động (Step Tracker & Calorie Burn Service)
/// Thuật toán đếm bước chuẩn xác, chống trôi số, chống mất bước khi khởi động lại máy hoặc cộng thủ công.
class StepTrackerService extends ChangeNotifier {
  static final StepTrackerService instance = StepTrackerService._internal();

  StepTrackerService._internal();

  StreamSubscription<StepCount>? _stepCountSubscription;
  StreamSubscription<PedestrianStatus>? _pedestrianStatusSubscription;
  SharedPreferences? _prefs;

  int _todaySteps = 0;
  int _sensorSteps = 0;
  int _manualSteps = 0;
  int _stepGoal = 6000;
  int _lastRawSensorSteps = 0;
  int _todayBaseSensorSteps = 0;
  int _bootAccumulatedSensorSteps = 0;
  bool _isBaseSet = false;

  String _pedestrianStatus = 'ready'; // 'walking', 'stopped', 'unknown', 'ready'
  bool _isSensorAvailable = true;
  bool _hasPermission = false;
  bool _isInitialized = false;

  bool _isUsingGoogleFit = false;
  int _googleFitSteps = 0;
  double? _googleFitCalories;
  double? _googleFitDistanceKm;

  int get todaySteps => _isUsingGoogleFit ? _googleFitSteps : _todaySteps;
  int get sensorSteps => _sensorSteps;
  int get manualSteps => _manualSteps;
  int get stepGoal => _stepGoal;
  int get lastRawSensorSteps => _lastRawSensorSteps;
  double get stepProgress => _stepGoal > 0 ? (todaySteps / _stepGoal).clamp(0.0, 1.0) : 0.0;
  String get pedestrianStatus => _isUsingGoogleFit ? 'google_fit' : _pedestrianStatus;
  bool get isSensorAvailable => _isSensorAvailable;
  bool get hasPermission => _hasPermission;
  bool get isInitialized => _isInitialized;
  bool get isUsingGoogleFit => _isUsingGoogleFit;

  /// Cập nhật dữ liệu từ Google Fit
  void applyGoogleFitData({required int steps, double? calories, double? distanceKm}) {
    _isUsingGoogleFit = true;
    _googleFitSteps = steps;
    _googleFitCalories = calories;
    _googleFitDistanceKm = distanceKm;
    notifyListeners();
  }

  /// Xóa dữ liệu Google Fit khi hủy liên kết
  void clearGoogleFitData() {
    _isUsingGoogleFit = false;
    _googleFitSteps = 0;
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
    return (todaySteps * strideM) / 1000.0;
  }

  /// Lượng calo đốt cháy (kcal) - được cá nhân hoá theo cân nặng (hoặc lấy từ Google Fit)
  double get burnedCalories {
    if (_googleFitCalories != null && _googleFitCalories! > 0) {
      return _googleFitCalories!;
    }
    final weight = AppStateService.instance.userProfile.weightKg;
    final w = weight > 0 ? weight : 65.0;
    // Công thức MET đi bộ tiêu chuẩn theo trọng lượng cơ thể
    return todaySteps * 0.04 * (w / 70.0);
  }

  /// Thời gian vận động ước tính (phút) - trung bình 100 bước/phút
  int get activeMinutes {
    return (todaySteps / 100).round();
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
      _prefs ??= await SharedPreferences.getInstance();
      final todayStr = _getTodayDateString();
      final savedDate = _prefs!.getString('nutrisnap_steps_date_$_accountKey');
      _stepGoal = _prefs!.getInt('nutrisnap_steps_goal_$_accountKey') ?? 6000;

      if (savedDate == todayStr) {
        _sensorSteps = _prefs!.getInt('nutrisnap_steps_sensor_$_accountKey') ?? 0;
        _manualSteps = _prefs!.getInt('nutrisnap_steps_manual_$_accountKey') ?? 0;
        _todaySteps = _prefs!.getInt('nutrisnap_steps_today_$_accountKey') ?? (_sensorSteps + _manualSteps);
        _todayBaseSensorSteps = _prefs!.getInt('nutrisnap_steps_base_$_accountKey') ?? 0;
        _bootAccumulatedSensorSteps = _prefs!.getInt('nutrisnap_steps_boot_accum_$_accountKey') ?? 0;
        _isBaseSet = _prefs!.getBool('nutrisnap_steps_base_set_$_accountKey') ?? false;
        _lastRawSensorSteps = _prefs!.getInt('nutrisnap_steps_last_raw_$_accountKey') ?? 0;
      } else {
        // Ngày mới -> reset về 0 hoàn toàn
        _sensorSteps = 0;
        _manualSteps = 0;
        _todaySteps = 0;
        _todayBaseSensorSteps = 0;
        _bootAccumulatedSensorSteps = 0;
        _isBaseSet = false;
        _lastRawSensorSteps = 0;
        await _saveState(forceDate: todayStr);
      }

      _isInitialized = true;
      notifyListeners();

      // Kiểm tra và khởi động lắng nghe cảm biến
      await _checkPermissionAndStartListening();
    } catch (e) {
      debugPrint('[StepTrackerService] Init error: $e');
    }
  }

  /// Lưu trạng thái vào bộ nhớ cục bộ
  Future<void> _saveState({String? forceDate}) async {
    final prefs = _prefs;
    if (prefs == null) return;
    final todayStr = forceDate ?? _getTodayDateString();
    await prefs.setString('nutrisnap_steps_date_$_accountKey', todayStr);
    await prefs.setInt('nutrisnap_steps_today_$_accountKey', _todaySteps);
    await prefs.setInt('nutrisnap_steps_sensor_$_accountKey', _sensorSteps);
    await prefs.setInt('nutrisnap_steps_manual_$_accountKey', _manualSteps);
    await prefs.setInt('nutrisnap_steps_base_$_accountKey', _todayBaseSensorSteps);
    await prefs.setInt('nutrisnap_steps_boot_accum_$_accountKey', _bootAccumulatedSensorSteps);
    await prefs.setBool('nutrisnap_steps_base_set_$_accountKey', _isBaseSet);
    await prefs.setInt('nutrisnap_steps_last_raw_$_accountKey', _lastRawSensorSteps);
  }

  /// Kiểm tra chuyển ngày tự động
  void _checkDayRollover() {
    final prefs = _prefs;
    if (prefs == null) return;
    final todayStr = _getTodayDateString();
    final savedDate = prefs.getString('nutrisnap_steps_date_$_accountKey');
    if (savedDate != null && savedDate != todayStr) {
      _sensorSteps = 0;
      _manualSteps = 0;
      _todaySteps = 0;
      _todayBaseSensorSteps = 0;
      _bootAccumulatedSensorSteps = 0;
      _isBaseSet = false;
      _lastRawSensorSteps = 0;
      _saveState(forceDate: todayStr);
      notifyListeners();
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
    _stepCountSubscription = null;
    _pedestrianStatusSubscription?.cancel();
    _pedestrianStatusSubscription = null;

    runZonedGuarded(() {
      try {
        _stepCountSubscription = Pedometer.stepCountStream.listen(
          _onStepCount,
          onError: (error) {
            debugPrint('[StepTrackerService] Pedometer error: $error');
            _stepCountSubscription?.cancel();
            _stepCountSubscription = null;
            _pedestrianStatusSubscription?.cancel();
            _pedestrianStatusSubscription = null;
            if (_isSensorAvailable) {
              _isSensorAvailable = false;
              notifyListeners();
            }
          },
          cancelOnError: true,
        );

        _isSensorAvailable = true;
      } catch (e) {
        debugPrint('[StepTrackerService] Start listening error: $e');
        _isSensorAvailable = false;
      }
    }, (error, stack) {
      debugPrint('[StepTrackerService] Caught sensor stream error: $error');
      _stepCountSubscription?.cancel();
      _stepCountSubscription = null;
      _pedestrianStatusSubscription?.cancel();
      _pedestrianStatusSubscription = null;
      if (_isSensorAvailable) {
        _isSensorAvailable = false;
        notifyListeners();
      }
    });
  }

  void _startPedestrianStatusListening() {
    if (_pedestrianStatusSubscription != null) return;
    runZonedGuarded(() {
      try {
        _pedestrianStatusSubscription = Pedometer.pedestrianStatusStream.listen(
          _onPedestrianStatusChanged,
          onError: (error) {
            debugPrint('[StepTrackerService] Pedestrian status error: $error');
            _pedestrianStatusSubscription?.cancel();
            _pedestrianStatusSubscription = null;
          },
          cancelOnError: true,
        );
      } catch (e) {
        debugPrint('[StepTrackerService] Start pedestrian status error: $e');
      }
    }, (error, stack) {
      debugPrint('[StepTrackerService] Caught pedestrian status error: $error');
      _pedestrianStatusSubscription?.cancel();
      _pedestrianStatusSubscription = null;
    });
  }

  /// Thuật toán xử lý tín hiệu cảm biến đếm bước chân
  void _onStepCount(StepCount event) {
    if (_isUsingGoogleFit) return;
    final rawSteps = event.steps;

    // Đã xác nhận phần cứng có hỗ trợ cảm biến, an toàn để theo dõi trạng thái di chuyển
    _startPedestrianStatusListening();

    _checkDayRollover();

    // 1. Nếu ngày hôm nay chưa khóa mốc gốc (Base):
    if (!_isBaseSet) {
      _todayBaseSensorSteps = rawSteps;
      _bootAccumulatedSensorSteps = 0;
      _sensorSteps = 0;
      _isBaseSet = true;
      _lastRawSensorSteps = rawSteps;
      _todaySteps = _sensorSteps + _manualSteps;
      _saveState();
      notifyListeners();
      return;
    }

    // 2. Kiểm tra nếu điện thoại vừa khởi động lại (Reboot):
    // rawSteps bị reset về giá trị nhỏ hơn lần đọc trước đó
    if (_lastRawSensorSteps > 0 && rawSteps < _lastRawSensorSteps) {
      _bootAccumulatedSensorSteps = _sensorSteps;
      _todayBaseSensorSteps = rawSteps;
    }

    // 3. Tính toán số bước của đợt hoạt động hiện tại
    int currentSessionSteps = rawSteps - _todayBaseSensorSteps;
    if (currentSessionSteps < 0) {
      // Trường hợp cảm biến lệch âm nhẹ, tự cân chỉnh mốc
      currentSessionSteps = 0;
      _todayBaseSensorSteps = rawSteps;
    }

    final calculatedSensorSteps = _bootAccumulatedSensorSteps + currentSessionSteps;

    // 4. Bộ lọc chống nhảy số glitch bất thường (> 50.000 bước trong 1 event)
    if (calculatedSensorSteps >= _sensorSteps && (calculatedSensorSteps - _sensorSteps) < 50000) {
      _sensorSteps = calculatedSensorSteps;
    }

    _lastRawSensorSteps = rawSteps;
    final newTotal = _sensorSteps + _manualSteps;

    if (newTotal != _todaySteps) {
      _todaySteps = newTotal;
      _saveState();
      notifyListeners();
    }
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
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setInt('nutrisnap_steps_goal_$_accountKey', _stepGoal);
    } catch (e) {
      debugPrint('[StepTrackerService] Update goal error: $e');
    }
  }

  /// Thêm bước chân thủ công (hoàn toàn độc lập, không bao giờ bị cảm biến đè mất)
  Future<void> addManualSteps(int steps) async {
    if (steps <= 0) return;
    _checkDayRollover();
    _manualSteps += steps;
    _todaySteps = _sensorSteps + _manualSteps;
    notifyListeners();
    try {
      await _saveState();
    } catch (e) {
      debugPrint('[StepTrackerService] Add manual steps error: $e');
    }
  }

  /// Đặt lại số bước về 0 cho ngày hiện tại (nếu người dùng muốn hiệu chỉnh lại)
  Future<void> resetTodaySteps() async {
    _sensorSteps = 0;
    _manualSteps = 0;
    _todaySteps = 0;
    _bootAccumulatedSensorSteps = 0;
    _todayBaseSensorSteps = _lastRawSensorSteps;
    _isBaseSet = true;
    notifyListeners();
    await _saveState();
  }

  /// Chuyển đổi tài khoản: Nạp lại bước chân cho tài khoản hiện tại
  Future<void> reloadForCurrentUser() async {
    _isInitialized = false;
    _todaySteps = 0;
    _sensorSteps = 0;
    _manualSteps = 0;
    _todayBaseSensorSteps = 0;
    _bootAccumulatedSensorSteps = 0;
    _isBaseSet = false;
    await init();
  }

  @override
  void dispose() {
    _stepCountSubscription?.cancel();
    _pedestrianStatusSubscription?.cancel();
    super.dispose();
  }
}

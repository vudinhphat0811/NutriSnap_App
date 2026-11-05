import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
import 'app_state_service.dart';

/// Dịch vụ Đếm Bước Chân & Theo Dõi Vận Động (Step Tracker & Calorie Burn Service)
/// Thuật toán đếm bước chuẩn xác, chống trôi số, chống mất bước khi đổi thiết bị,
/// tự động lọc bước ảo khi đi xe máy / đạp xe bằng bộ lọc tốc độ di chuyển GPS,
/// tự động đồng bộ đám mây và reset chính xác lúc 00:00:00 theo giờ Việt Nam (UTC+7).
class StepTrackerService extends ChangeNotifier {
  static final StepTrackerService instance = StepTrackerService._internal();

  StepTrackerService._internal();

  StreamSubscription<StepCount>? _stepCountSubscription;
  StreamSubscription<PedestrianStatus>? _pedestrianStatusSubscription;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _cloudSyncDebounce;
  Timer? _rolloverTimer;
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

  // Bộ lọc thông minh chống bước ảo khi đi xe máy & đạp xe
  bool _isVehicleMode = false;
  bool _isCyclingMode = false;
  double _currentSpeedKmH = 0.0;
  DateTime? _lastHighSpeedTime;
  int _discardedVehicleSteps = 0; // Số bước ảo từ rung lắc xe máy đã được triệt tiêu

  bool _isUsingGoogleFit = false;
  int _googleFitSteps = 0;
  double? _googleFitCalories;
  double? _googleFitDistanceKm;

  int get todaySteps {
    checkDayRollover();
    return _isUsingGoogleFit
        ? (_googleFitSteps > 0 ? _googleFitSteps : _todaySteps)
        : _todaySteps;
  }

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

  // Getters cho chế độ nhận diện phương tiện di chuyển
  bool get isVehicleMode => _isVehicleMode;
  bool get isCyclingMode => _isCyclingMode;
  double get currentSpeedKmH => _currentSpeedKmH;
  int get discardedVehicleSteps => _discardedVehicleSteps;

  /// Cập nhật dữ liệu từ Google Fit
  void applyGoogleFitData({required int steps, double? calories, double? distanceKm}) {
    _isUsingGoogleFit = true;
    _googleFitSteps = steps;
    _googleFitCalories = calories;
    _googleFitDistanceKm = distanceKm;

    final prefs = _prefs;
    if (prefs != null) {
      final todayStr = _getTodayDateString();
      prefs.setString('nutrisnap_fit_date_$_accountKey', todayStr);
      prefs.setInt('nutrisnap_fit_steps_$_accountKey', steps);
      if (calories != null) {
        prefs.setDouble('nutrisnap_fit_cal_$_accountKey', calories);
      }
      if (distanceKm != null) {
        prefs.setDouble('nutrisnap_fit_dist_$_accountKey', distanceKm);
      }
    }

    notifyListeners();
    syncStepsToCloud(immediate: true);
  }

  /// Xóa dữ liệu Google Fit khi hủy liên kết
  void clearGoogleFitData() {
    _isUsingGoogleFit = false;
    _googleFitSteps = 0;
    _googleFitCalories = null;
    _googleFitDistanceKm = null;
    _prefs?.remove('nutrisnap_fit_date_$_accountKey');
    _prefs?.remove('nutrisnap_fit_steps_$_accountKey');
    _prefs?.remove('nutrisnap_fit_cal_$_accountKey');
    _prefs?.remove('nutrisnap_fit_dist_$_accountKey');
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

  /// Lấy ngày hôm nay theo chuẩn múi giờ Việt Nam (UTC+7)
  String _getTodayDateString() {
    return AppStateService.getTodayDateString();
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
        _discardedVehicleSteps = _prefs!.getInt('nutrisnap_steps_discarded_$_accountKey') ?? 0;

        final fitDate = _prefs!.getString('nutrisnap_fit_date_$_accountKey');
        if (fitDate == todayStr) {
          _googleFitSteps = _prefs!.getInt('nutrisnap_fit_steps_$_accountKey') ?? 0;
          _googleFitCalories = _prefs!.getDouble('nutrisnap_fit_cal_$_accountKey');
          _googleFitDistanceKm = _prefs!.getDouble('nutrisnap_fit_dist_$_accountKey');
        }
      } else {
        // Ngày mới -> reset về 0 hoàn toàn theo giờ Việt Nam
        _sensorSteps = 0;
        _manualSteps = 0;
        _todaySteps = 0;
        _todayBaseSensorSteps = 0;
        _bootAccumulatedSensorSteps = 0;
        _isBaseSet = false;
        _lastRawSensorSteps = 0;
        _discardedVehicleSteps = 0;
        await _saveState(forceDate: todayStr);
      }

      _isInitialized = true;
      notifyListeners();

      // Bắt đầu hẹn giờ kiểm tra chuyển ngày 0h VN định kỳ (mỗi 30s)
      _rolloverTimer?.cancel();
      _rolloverTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        checkDayRollover();
      });

      // Kiểm tra và khởi động lắng nghe cảm biến
      await _checkPermissionAndStartListening();

      // Khởi động bộ theo dõi tốc độ di chuyển GPS để lọc xe máy & đạp xe
      _startSpeedTracking();
    } catch (e) {
      debugPrint('[StepTrackerService] Init error: $e');
    }
  }

  /// Khởi động theo dõi tốc độ GPS tiết kiệm pin (Battery-efficient location tracking)
  Future<void> _startSpeedTracking() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      _positionSubscription?.cancel();
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 15,
      );

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(_onPositionUpdate, onError: (e) {
        debugPrint('[StepTrackerService] Location stream error: $e');
      });
    } catch (e) {
      debugPrint('[StepTrackerService] Start speed tracking error: $e');
    }
  }

  /// Xử lý cập nhật vị trí và tốc độ di chuyển
  void _onPositionUpdate(Position position) {
    if (position.speed < 0) return;
    // position.speed có đơn vị m/s -> nhân 3.6 ra km/h
    final speedKmH = position.speed * 3.6;
    _currentSpeedKmH = speedKmH;

    // 1. Nhận diện đi xe máy / ô tô (Tốc độ >= 20 km/h)
    if (speedKmH >= 20.0) {
      _lastHighSpeedTime = DateTime.now();
      if (!_isVehicleMode) {
        _isVehicleMode = true;
        _isCyclingMode = false;
        notifyListeners();
      }
    }
    // 2. Nhận diện đạp xe (Tốc độ từ 12 km/h đến dưới 20 km/h)
    else if (speedKmH >= 12.0 && speedKmH < 20.0) {
      _lastHighSpeedTime = DateTime.now();
      if (!_isCyclingMode) {
        _isCyclingMode = true;
        _isVehicleMode = false;
        notifyListeners();
      }
    }
    // 3. Tốc độ đi bộ bình thường (< 10 km/h)
    else if (speedKmH < 10.0) {
      // Giữ trạng thái xe trong 15 giây (chống trường hợp xe máy dừng đèn đỏ tạm thời bị nhảy lại bước đi bộ)
      if (_lastHighSpeedTime != null) {
        final elapsed = DateTime.now().difference(_lastHighSpeedTime!).inSeconds;
        if (elapsed > 15) {
          if (_isVehicleMode || _isCyclingMode) {
            _isVehicleMode = false;
            _isCyclingMode = false;
            notifyListeners();
          }
        }
      } else {
        if (_isVehicleMode || _isCyclingMode) {
          _isVehicleMode = false;
          _isCyclingMode = false;
          notifyListeners();
        }
      }
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
    await prefs.setInt('nutrisnap_steps_discarded_$_accountKey', _discardedVehicleSteps);
  }

  /// Kiểm tra chuyển ngày tự động theo giờ Việt Nam (00:00:00 UTC+7)
  void checkDayRollover() {
    final prefs = _prefs;
    if (prefs == null) return;
    final todayStr = _getTodayDateString();
    final savedDate = prefs.getString('nutrisnap_steps_date_$_accountKey');
    if (savedDate != null && savedDate != todayStr) {
      debugPrint('[StepTrackerService] ☀️ 0h VN: Reset bước chân sang ngày mới: $todayStr (Cũ: $savedDate)');
      _sensorSteps = 0;
      _manualSteps = 0;
      _todaySteps = 0;
      _bootAccumulatedSensorSteps = 0;
      _discardedVehicleSteps = 0;
      _googleFitSteps = 0;
      _googleFitCalories = null;
      _googleFitDistanceKm = null;
      prefs.remove('nutrisnap_fit_date_$_accountKey');
      prefs.remove('nutrisnap_fit_steps_$_accountKey');
      prefs.remove('nutrisnap_fit_cal_$_accountKey');
      prefs.remove('nutrisnap_fit_dist_$_accountKey');
      if (_lastRawSensorSteps > 0) {
        _todayBaseSensorSteps = _lastRawSensorSteps;
        _isBaseSet = true;
      } else {
        _todayBaseSensorSteps = 0;
        _isBaseSet = false;
      }
      _saveState(forceDate: todayStr);
      notifyListeners();
      // Đồng bộ ngày mới lên server nếu đã đăng nhập
      syncStepsToCloud(immediate: true);
    }
  }

  /// Nhận số bước chân đã lưu trên Đám Mây Cloud Backend (tránh mất số khi đổi thiết bị)
  void applyCloudSteps({required int steps, double? calories, double? distanceKm}) {
    if (_isUsingGoogleFit) return;
    checkDayRollover();
    if (steps > _todaySteps) {
      _todaySteps = steps;
      if (steps > _sensorSteps) {
        _manualSteps = steps - _sensorSteps;
      }
      _saveState();
      notifyListeners();
    } else if (_todaySteps > steps && steps > 0) {
      // Máy hiện tại có nhiều bước hơn trên Cloud -> Đẩy cập nhật lên Cloud
      _scheduleCloudSync();
    }
  }

  /// Lên lịch đồng bộ bước chân lên Cloud (debounce 4 giây để tiết kiệm băng thông)
  void _scheduleCloudSync() {
    _cloudSyncDebounce?.cancel();
    _cloudSyncDebounce = Timer(const Duration(seconds: 4), () {
      syncStepsToCloud();
    });
  }

  /// Gửi số liệu bước chân hôm nay lên Cloud Backend C#
  Future<void> syncStepsToCloud({bool immediate = false}) async {
    final appState = AppStateService.instance;
    final token = appState.authToken;
    if (token == null || token.isEmpty || appState.isGuestMode || token.startsWith('guest_') || token.startsWith('mock_')) {
      return;
    }

    try {
      final uri = Uri.parse(ApiConstants.stepsSync);
      final body = jsonEncode({
        'steps': todaySteps,
        'caloriesBurned': burnedCalories,
        'distanceKm': distanceKm,
        'date': _getTodayDateString(),
      });

      await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('[StepTrackerService] Cloud sync error: $e');
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

    _startPedestrianStatusListening();

    checkDayRollover();

    if (_isVehicleMode || _isCyclingMode) {
      if (_lastRawSensorSteps > 0 && rawSteps > _lastRawSensorSteps) {
        final bumpSteps = rawSteps - _lastRawSensorSteps;
        _todayBaseSensorSteps += bumpSteps;
        _discardedVehicleSteps += bumpSteps;
      }
      _lastRawSensorSteps = rawSteps;
      return;
    }

    // 2. Nếu ngày hôm nay chưa khóa mốc gốc (Base):
    if (!_isBaseSet) {
      _todayBaseSensorSteps = rawSteps;
      _bootAccumulatedSensorSteps = 0;
      _sensorSteps = 0;
      _isBaseSet = true;
      _lastRawSensorSteps = rawSteps;
      _todaySteps = _sensorSteps + _manualSteps;
      _saveState();
      notifyListeners();
      _scheduleCloudSync();
      return;
    }

    // 3. Kiểm tra nếu điện thoại vừa khởi động lại (Reboot):
    // rawSteps bị reset về giá trị nhỏ hơn lần đọc trước đó
    if (_lastRawSensorSteps > 0 && rawSteps < _lastRawSensorSteps) {
      _bootAccumulatedSensorSteps = _sensorSteps;
      _todayBaseSensorSteps = rawSteps;
    }

    // 4. Tính toán số bước của đợt hoạt động hiện tại
    int currentSessionSteps = rawSteps - _todayBaseSensorSteps;
    if (currentSessionSteps < 0) {
      // Trường hợp cảm biến lệch âm nhẹ, tự cân chỉnh mốc
      currentSessionSteps = 0;
      _todayBaseSensorSteps = rawSteps;
    }

    final calculatedSensorSteps = _bootAccumulatedSensorSteps + currentSessionSteps;

    // 5. Bộ lọc chống nhảy số glitch bất thường (> 50.000 bước trong 1 event)
    if (calculatedSensorSteps >= _sensorSteps && (calculatedSensorSteps - _sensorSteps) < 50000) {
      _sensorSteps = calculatedSensorSteps;
    }

    _lastRawSensorSteps = rawSteps;
    final newTotal = _sensorSteps + _manualSteps;

    if (newTotal != _todaySteps) {
      _todaySteps = newTotal;
      _saveState();
      notifyListeners();
      _scheduleCloudSync();
    }
  }

  void _onPedestrianStatusChanged(PedestrianStatus event) {
    if (_pedestrianStatus != event.status) {
      _pedestrianStatus = event.status;
      notifyListeners();
    }
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
    checkDayRollover();
    _manualSteps += steps;
    _todaySteps = _sensorSteps + _manualSteps;
    notifyListeners();
    try {
      await _saveState();
      _scheduleCloudSync();
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
    _discardedVehicleSteps = 0;
    _todayBaseSensorSteps = _lastRawSensorSteps;
    _isBaseSet = true;
    notifyListeners();
    await _saveState();
    await syncStepsToCloud(immediate: true);
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
    _discardedVehicleSteps = 0;
    await init();
  }

  @override
  void dispose() {
    _stepCountSubscription?.cancel();
    _pedestrianStatusSubscription?.cancel();
    _positionSubscription?.cancel();
    _cloudSyncDebounce?.cancel();
    _rolloverTimer?.cancel();
    super.dispose();
  }
}

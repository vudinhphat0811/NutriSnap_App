import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../constants/api_constants.dart';
import '../models/voice_assistant_model.dart';
import '../models/fridge_item_model.dart';
import 'app_state_service.dart';
import 'fridge_service.dart';
import 'step_tracker_service.dart';

class VoiceAssistantService {
  static final VoiceAssistantService instance = VoiceAssistantService._internal();
  VoiceAssistantService._internal();

  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final AudioRecorder _audioRecorder = AudioRecorder();

  bool _isSpeechInitialized = false;
  bool _isListening = false;
  bool isTtsEnabled = true;

  Timer? _silenceTimer;
  Timer? _amplitudeTimer;
  String _currentRecognizedWords = '';
  String? _currentAudioPath;
  int _silentTickCount = 0;
  bool _hasDetectedVoice = false;
  Function(bool isListening)? _currentListeningStateCallback;
  Function(String finalWords, String? audioFilePath)? _currentDoneCallback;

  String? _vietnameseLocaleId;

  bool get isListening => _isListening;
  bool get isSpeechAvailable => _isSpeechInitialized;
  String get currentRecognizedWords => _currentRecognizedWords;

  void _finishAndSubmitCurrentWords() async {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;

    final words = _currentRecognizedWords.trim();
    _currentRecognizedWords = '';

    final wasListening = _isListening;
    _isListening = false;

    if (wasListening) {
      _currentListeningStateCallback?.call(false);
    }

    try {
      await _speech.stop();
    } catch (_) {}

    String? audioPath;
    try {
      if (await _audioRecorder.isRecording()) {
        audioPath = await _audioRecorder.stop();
      }
    } catch (_) {}
    audioPath ??= _currentAudioPath;

    debugPrint('[VoiceAssistant] _finishAndSubmitCurrentWords: text="$words", audioPath=$audioPath');

    if (words.isNotEmpty) {
      _currentDoneCallback?.call(words, null);
    } else if (audioPath != null && File(audioPath).existsSync()) {
      _currentDoneCallback?.call('', audioPath);
    }
  }

  /// Khởi tạo Micro & Bộ đọc Tiếng Việt
  Future<bool> init() async {
    try {
      // 1. Kiểm tra & yêu cầu quyền Microphone
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        debugPrint('[VoiceAssistant] Microphone permission not granted: $status');
        _isSpeechInitialized = false;
        return false;
      }

      // 2. Khởi tạo Speech-To-Text nhận diện tiếng Việt
      if (!_isSpeechInitialized) {
        _isSpeechInitialized = await _speech.initialize(
          onStatus: (status) {
            debugPrint('[VoiceAssistant] Speech status: $status');
            if (status == 'notListening' || status == 'done') {
              if (_currentRecognizedWords.trim().isNotEmpty) {
                _finishAndSubmitCurrentWords();
              }
            }
          },
          onError: (error) {
            debugPrint('[VoiceAssistant] Speech error: ${error.errorMsg}');
            if (_currentRecognizedWords.trim().isNotEmpty) {
              _finishAndSubmitCurrentWords();
            }
          },
          debugLogging: kDebugMode,
        );

        if (_isSpeechInitialized) {
          try {
            final locales = await _speech.locales();
            for (final l in locales) {
              if (l.localeId.toLowerCase().startsWith('vi')) {
                _vietnameseLocaleId = l.localeId;
                break;
              }
            }
            _vietnameseLocaleId ??= 'vi_VN';
            debugPrint('[VoiceAssistant] Selected Speech Locale: $_vietnameseLocaleId');
          } catch (e) {
            _vietnameseLocaleId = 'vi_VN';
          }
        }
      }

      await _tts.setLanguage('vi-VN');
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);

      return true;
    } catch (e) {
      debugPrint('[VoiceAssistant] Init error: $e');
      _isSpeechInitialized = false;
      return false;
    }
  }

  /// Bắt đầu nghe giọng nói tiếng Việt với bộ đếm 2s im lặng tự động chốt câu
  /// Chạy song song Speech-To-Text và Ghi âm dự phòng 100%
  Future<bool> startListening({
    required Function(String recognizedWords) onResult,
    required Function(String finalWords, String? audioFilePath) onDone,
    required Function(bool isListening) onListeningState,
  }) async {
    final ready = await init();
    if (!ready) {
      onListeningState(false);
      return false;
    }

    _currentRecognizedWords = '';
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    _currentListeningStateCallback = onListeningState;
    _currentDoneCallback = onDone;
    _isListening = true;
    _hasDetectedVoice = false;
    _silentTickCount = 0;
    onListeningState(true);

    // 1. Khởi động ghi âm AAC phần cứng ngầm (phòng khi device không có Speech Engine)
    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _currentAudioPath = filePath;

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 16000,
        ),
        path: filePath,
      );

      // Theo dõi biên độ: người dùng nói xong và im lặng 2s -> tự động chốt
      _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) async {
        if (!_isListening) {
          timer.cancel();
          return;
        }

        try {
          final amp = await _audioRecorder.getAmplitude();
          final currentDb = amp.current;

          if (currentDb > -36) {
            _hasDetectedVoice = true;
            _silentTickCount = 0;
          } else if (_hasDetectedVoice) {
            _silentTickCount++;
            // 13 ticks * 150ms ≈ 2 giây im lặng
            if (_silentTickCount >= 13) {
              debugPrint('[VoiceAssistant] 2 giây im lặng (qua Amplitude) -> TỰ ĐỘNG CHỐT CÂU!');
              timer.cancel();
              _finishAndSubmitCurrentWords();
            }
          }
        } catch (_) {}
      });
    } catch (e) {
      debugPrint('[VoiceAssistant] Lỗi bật recorder dự phòng: $e');
    }

    // 2. Chạy Speech-To-Text nhận diện chữ hiển thị ngay trên màn hình
    try {
      if (_isSpeechInitialized) {
        await _speech.listen(
          onResult: (result) {
            final words = result.recognizedWords.trim();
            if (words.isNotEmpty) {
              _hasDetectedVoice = true;
              _silentTickCount = 0;
              _currentRecognizedWords = words;
              onResult(words);

              // Đếm lùi đúng 2 giây im lặng: nếu người dùng nói xong và im lặng 2s -> tự động chốt & gửi
              _silenceTimer?.cancel();
              _silenceTimer = Timer(const Duration(milliseconds: 2000), () {
                debugPrint('[VoiceAssistant] 2s im lặng (qua STT) -> tự động chốt câu: "$_currentRecognizedWords"');
                _finishAndSubmitCurrentWords();
              });
            }

            if (result.finalResult && words.isNotEmpty) {
              _silenceTimer?.cancel();
              _silenceTimer = Timer(const Duration(milliseconds: 600), () {
                _finishAndSubmitCurrentWords();
              });
            }
          },
          listenOptions: SpeechListenOptions(
            localeId: _vietnameseLocaleId ?? 'vi_VN',
            listenFor: const Duration(seconds: 40),
            pauseFor: const Duration(seconds: 4),
            listenMode: ListenMode.dictation,
            cancelOnError: false,
            partialResults: true,
          ),
        );
      }
    } catch (e) {
      debugPrint('[VoiceAssistant] Speech-To-Text listen error: $e');
    }

    return true;
  }

  /// Dừng nghe và lập tức nộp câu lệnh nếu có
  Future<void> stopListeningAndSubmit() async {
    _finishAndSubmitCurrentWords();
  }

  /// Dừng nghe và hủy bộ hẹn giờ im lặng
  Future<void> stopListening() async {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    if (_isListening) {
      try {
        await _speech.stop();
      } catch (_) {}
      try {
        if (await _audioRecorder.isRecording()) {
          await _audioRecorder.stop();
        }
      } catch (_) {}
      _isListening = false;
      _currentListeningStateCallback?.call(false);
    }
  }

  /// Xử lý tệp âm thanh gửi lên Backend AI Gemini chuyển thành chữ và trả lời
  Future<VoiceAssistantResponse> processAudioFile(String audioFilePath) async {
    try {
      final file = File(audioFilePath);
      if (!file.existsSync()) {
        return const VoiceAssistantResponse(
          actionType: 'general_chat',
          userPrompt: 'Lệnh bằng giọng nói',
          spokenReply: 'Không tìm thấy tệp âm thanh vừa ghi. Bạn thử lại nhé!',
        );
      }

      final fileBytes = await file.readAsBytes();
      if (fileBytes.isEmpty) {
        return const VoiceAssistantResponse(
          actionType: 'general_chat',
          userPrompt: 'Lệnh bằng giọng nói',
          spokenReply: 'Âm thanh quá ngắn hoặc chưa có tiếng nói. Bạn thử lại nhé!',
        );
      }

      final base64Audio = base64Encode(fileBytes);
      return await processAudioCommand(base64Audio, 'audio/mp4');
    } catch (e) {
      debugPrint('[VoiceAssistant] Lỗi gửi tệp âm thanh: $e');
      return const VoiceAssistantResponse(
        actionType: 'general_chat',
        userPrompt: 'Lệnh bằng giọng nói',
        spokenReply: 'Đã xảy ra lỗi khi phân tích giọng nói. Bạn thử lại nhé!',
      );
    }
  }

  /// Bắt đầu ghi âm phần cứng microphone (rất nhẹ, chuẩn AAC LC ~20KB)
  Future<bool> startAudioRecording({
    required Function(double amplitudeDb) onAmplitudeChanged,
    required Function() onSilenceTimeout,
  }) async {
    try {
      if (!await _audioRecorder.hasPermission()) {
        return false;
      }

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _currentAudioPath = filePath;

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 16000,
        ),
        path: filePath,
      );

      _isListening = true;
      _hasDetectedVoice = false;
      _silentTickCount = 0;

      // Lắng nghe cường độ âm thanh mỗi 150ms để phát hiện im lặng 2s tự động chốt
      _amplitudeTimer?.cancel();
      _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) async {
        if (!_isListening) {
          timer.cancel();
          return;
        }

        try {
          final amp = await _audioRecorder.getAmplitude();
          final currentDb = amp.current;
          onAmplitudeChanged(currentDb);

          // Nếu cường độ lớn hơn -36 dB nghĩa là người dùng đang nói
          if (currentDb > -36) {
            _hasDetectedVoice = true;
            _silentTickCount = 0;
          } else if (_hasDetectedVoice) {
            // Đã từng nói và hiện đang im lặng (currentDb <= -36)
            _silentTickCount++;
            // 13 ticks * 150ms ≈ 1.95 - 2.0 giây im lặng
            if (_silentTickCount >= 13) {
              debugPrint('[VoiceAssistant] 2s im lặng trong ghi âm -> tự động dừng & gửi!');
              timer.cancel();
              onSilenceTimeout();
            }
          }
        } catch (_) {}
      });

      return true;
    } catch (e) {
      debugPrint('[VoiceAssistant] Lỗi khởi động ghi âm: $e');
      _isListening = false;
      return false;
    }
  }

  /// Dừng ghi âm và gửi tệp âm thanh nhẹ (~20KB) lên Backend Gemini xử lý
  Future<VoiceAssistantResponse> stopAudioRecordingAndProcess() async {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    _isListening = false;

    try {
      final path = await _audioRecorder.stop();
      final audioFilePath = path ?? _currentAudioPath;

      if (audioFilePath == null || !File(audioFilePath).existsSync()) {
        return const VoiceAssistantResponse(
          actionType: 'general_chat',
          userPrompt: '',
          spokenReply: 'Không tìm thấy tệp âm thanh vừa ghi. Bạn thử lại nhé!',
        );
      }

      final fileBytes = await File(audioFilePath).readAsBytes();
      if (fileBytes.isEmpty) {
        return const VoiceAssistantResponse(
          actionType: 'general_chat',
          userPrompt: '',
          spokenReply: 'Âm thanh quá ngắn hoặc chưa có tiếng nói. Bạn thử lại nhé!',
        );
      }

      final base64Audio = base64Encode(fileBytes);
      return await processAudioCommand(base64Audio, 'audio/mp4');
    } catch (e) {
      debugPrint('[VoiceAssistant] Lỗi dừng và gửi âm thanh: $e');
      return const VoiceAssistantResponse(
        actionType: 'general_chat',
        userPrompt: '',
        spokenReply: 'Đã xảy ra lỗi khi xử lý âm thanh. Bạn thử lại nhé!',
      );
    }
  }

  /// Gửi base64 audio lên Backend C# .NET (Gemini 2.0/1.5 Flash nhận diện tiếng Việt)
  Future<VoiceAssistantResponse> processAudioCommand(String base64Audio, String mimeType) async {
    final appState = AppStateService.instance;
    final fridge = FridgeService.instance;
    final stepService = StepTrackerService.instance;

    final requestBody = {
      'audioBase64': base64Audio,
      'audioMimeType': mimeType,
      'userName': appState.userProfile.fullName.isNotEmpty ? appState.userProfile.fullName : 'bạn',
      'userGoal': appState.userProfile.goal,
      'dietType': appState.userProfile.dietType,
      'gender': appState.userProfile.gender,
      'weightKg': appState.userProfile.weightKg,
      'targetWeightKg': appState.userProfile.targetWeightKg,
      'consumedCalories': appState.totalCaloriesLogged,
      'consumedProtein': appState.totalProteinLogged,
      'targetCalories': appState.userProfile.targetCalories,
      'targetProtein': appState.userProfile.targetProtein,
      'remainingCalories': (appState.userProfile.targetCalories - appState.totalCaloriesLogged).clamp(0, 9999),
      'remainingProtein': (appState.userProfile.targetProtein - appState.totalProteinLogged).clamp(0.0, 999.0),
      'remainingCarbs': (appState.userProfile.targetCarbs - appState.totalCarbsLogged).clamp(0.0, 999.0),
      'remainingFat': (appState.userProfile.targetFat - appState.totalFatLogged).clamp(0.0, 999.0),
      'waterConsumedMl': appState.waterIntakeMl,
      'dailyWaterGoalMl': appState.waterGoalMl,
      'todaySteps': stepService.todaySteps,
      'stepGoal': stepService.stepGoal,
      'burnedCalories': stepService.burnedCalories,
      'fridgeItems': fridge.items.map((f) => {
        'id': f.id,
        'name': f.name,
        'category': f.category,
        'quantity': f.quantity,
        'daysUntilExpiry': f.daysRemaining,
      }).toList(),
    };

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.voiceAssistantProcessAudio),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        return VoiceAssistantResponse.fromJson(decoded);
      }
    } catch (e) {
      debugPrint('[VoiceAssistantService] Call Backend process-audio failed: $e');
    }

    return const VoiceAssistantResponse(
      actionType: 'general_chat',
      userPrompt: '',
      spokenReply: 'Tôi chưa nghe rõ câu nói. Bạn vui lòng thử lại nhé!',
    );
  }

  /// Đọc câu trả lời bằng giọng nói tiếng Việt
  Future<void> speak(String text) async {
    if (!isTtsEnabled || text.trim().isEmpty) return;
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      debugPrint('[VoiceAssistant] TTS speak error: $e');
    }
  }

  /// Dừng phát âm thanh
  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  /// Xử lý câu lệnh: Gửi lên Backend (hoặc dự phòng Offline)
  Future<VoiceAssistantResponse> processCommand(String userPrompt) async {
    final appState = AppStateService.instance;
    final fridge = FridgeService.instance;

    final int targetCal = appState.userProfile.targetCalories;
    final double targetPro = appState.userProfile.targetProtein;
    final int consumedCal = appState.totalCaloriesLogged;
    final double consumedPro = appState.totalProteinLogged.toDouble();

    final int remainingCal = targetCal - consumedCal;
    final double remainingPro = (targetPro - consumedPro).clamp(0.0, 999.0);
    final double remainingCarb = (appState.userProfile.targetCarbs - appState.totalCarbsLogged).clamp(0.0, 999.0);
    final double remainingFat = (appState.userProfile.targetFat - appState.totalFatLogged).clamp(0.0, 999.0);

    final fridgeItemsDto = fridge.items.map((item) {
      final days = item.daysRemaining;
      return {
        'id': item.id,
        'name': item.name,
        'category': item.category,
        'quantity': item.quantity,
        'daysUntilExpiry': days,
      };
    }).toList();

    final payload = {
      'userPrompt': userPrompt,
      'remainingCalories': remainingCal,
      'remainingProtein': remainingPro,
      'remainingCarbs': remainingCarb,
      'remainingFat': remainingFat,
      'consumedCalories': consumedCal,
      'consumedProtein': consumedPro,
      'targetCalories': targetCal,
      'targetProtein': targetPro,
      'waterConsumedMl': appState.waterIntakeMl,
      'dailyWaterGoalMl': appState.waterGoalMl,
      'fridgeItems': fridgeItemsDto,
      'userName': appState.userProfile.fullName.isNotEmpty ? appState.userProfile.fullName : 'Bạn',
      'userGoal': appState.userProfile.goal,
      'dietType': appState.userProfile.dietType,
      'gender': appState.userProfile.gender,
      'weightKg': appState.userProfile.weightKg,
      'targetWeightKg': appState.userProfile.targetWeightKg,
      'todaySteps': StepTrackerService.instance.todaySteps,
      'stepGoal': StepTrackerService.instance.stepGoal,
      'burnedCalories': StepTrackerService.instance.burnedCalories,
    };

    // 1. Thử gọi Backend API
    try {
      final url = Uri.parse(ApiConstants.voiceAssistantProcess);
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return VoiceAssistantResponse.fromJson(data);
      }
    } catch (e) {
      debugPrint('[VoiceAssistantService] Backend call failed ($e). Using Offline Rule Engine.');
    }

    // 2. Chế độ dự phòng Offline thông minh (0ms, không cần mạng)
    return _processOffline(userPrompt, remainingCal, remainingPro, remainingCarb, remainingFat, appState, fridge);
  }

  /// Động cơ xử lý ngôn ngữ ngoại tuyến (Offline Rule Engine)
  VoiceAssistantResponse _processOffline(
    String prompt,
    int remainingCal,
    double remainingPro,
    double remainingCarb,
    double remainingFat,
    AppStateService appState,
    FridgeService fridge,
  ) {
    final p = prompt.trim().toLowerCase();

    // 1. Uống nước
    if (p.contains('uống') && (p.contains('nước') || p.contains('ml') || p.contains('cốc') || p.contains('ly'))) {
      int amount = 250;
      final match = RegExp(r'(\d+)\s*(ml)?').firstMatch(p);
      if (match != null) {
        final val = int.tryParse(match.group(1) ?? '250') ?? 250;
        amount = val < 20 ? val * 250 : val;
      } else if (p.contains('1 chai') || p.contains('chai')) {
        amount = 500;
      }

      final newTotal = appState.waterIntakeMl + amount;
      return VoiceAssistantResponse(
        actionType: 'log_water',
        spokenReply: 'Đã ghi nhận thêm ${amount}ml nước! Hôm nay bạn đã uống được $newTotal/${appState.waterGoalMl} ml rồi.',
        waterData: VoiceWaterData(amountMl: amount, newTotalMl: newTotal),
      );
    }

    // 2. Bếp Trưởng Vét Tủ Cân Macro
    if (p.contains('tủ lạnh') && (p.contains('còn gì') || p.contains('ăn gì') || p.contains('nấu gì') || p.contains('đủ đạm') || p.contains('vét tủ')) ||
        p.contains('hôm nay ăn gì') ||
        p.contains('gợi ý món') ||
        p.contains('nấu món gì')) {
      return _generateFridgeRecipeOffline(remainingCal, remainingPro, remainingCarb, remainingFat, fridge);
    }

    // 3. Điều hướng mở màn hình
    if (p.contains('mở') || p.contains('vào') || p.contains('xem')) {
      if (p.contains('tủ lạnh')) {
        return const VoiceAssistantResponse(
          actionType: 'navigate',
          spokenReply: 'Đang mở Tủ Lạnh Thông Minh cho bạn đây!',
          navigateData: VoiceNavigateData(targetScreen: 'fridge'),
        );
      }
      if (p.contains('mã vạch') || p.contains('quét')) {
        return const VoiceAssistantResponse(
          actionType: 'navigate',
          spokenReply: 'Đang mở máy quét mã vạch siêu thị!',
          navigateData: VoiceNavigateData(targetScreen: 'barcode'),
        );
      }
      if (p.contains('đo calo') || p.contains('tính calo') || p.contains('cân')) {
        return const VoiceAssistantResponse(
          actionType: 'navigate',
          spokenReply: 'Đang mở Bộ Tính Calo Nguyên Liệu!',
          navigateData: VoiceNavigateData(targetScreen: 'calculator'),
        );
      }
    }

    // 4. Thêm đồ vào tủ lạnh
    if ((p.contains('thêm') || p.contains('cất') || p.contains('lưu') || p.contains('mua')) && p.contains('tủ')) {
      String clean = p.replaceAll('thêm', '').replaceAll('cất', '').replaceAll('vào tủ lạnh', '').replaceAll('vào tủ', '').trim();
      String itemName = clean.isNotEmpty ? (clean[0].toUpperCase() + clean.substring(1)) : 'Thực phẩm mới';

      return VoiceAssistantResponse(
        actionType: 'add_fridge',
        spokenReply: 'Đã thêm $itemName vào Tủ Lạnh Thông Minh của bạn rồi nhé!',
        fridgeAddData: VoiceFridgeAddData(
          name: itemName,
          category: 'Thực phẩm tươi',
          quantity: '1 phần',
          shelfLifeDays: 4,
          storageLocation: 'fridge',
        ),
      );
    }

    // 5. Kiểm tra bước chân & vận động
    if (p.contains('bước') || p.contains('đi bộ') || p.contains('vận động') || p.contains('chạy bộ')) {
      final stepService = StepTrackerService.instance;
      if (p.contains('cộng') || p.contains('thêm')) {
        final match = RegExp(r'(\d+)\s*(bước)?').firstMatch(p);
        final addAmount = match != null ? (int.tryParse(match.group(1) ?? '1000') ?? 1000) : 1000;
        stepService.addManualSteps(addAmount);
        return VoiceAssistantResponse(
          actionType: 'check_progress',
          spokenReply: 'Đã cộng thêm $addAmount bước vào nhật ký vận động hôm nay của bạn rồi nhé!',
        );
      }

      final namePrefix = appState.userProfile.fullName.isNotEmpty ? '${appState.userProfile.fullName} ơi, ' : '';
      final remaining = (stepService.stepGoal - stepService.todaySteps).clamp(0, 999999);
      final status = remaining > 0
          ? 'bạn còn $remaining bước nữa là đạt mục tiêu ${stepService.stepGoal} bước hôm nay.'
          : 'chúc mừng bạn đã hoàn thành vượt mục tiêu ${stepService.stepGoal} bước rồi!';
      return VoiceAssistantResponse(
        actionType: 'check_progress',
        spokenReply: '${namePrefix}hôm nay bạn đã đi được ${stepService.todaySteps} bước, đốt cháy khoảng ${stepService.burnedCalories.toStringAsFixed(0)} kcal. $status',
      );
    }

    // 6. Kiểm tra tiến độ Calo
    if (p.contains('còn bao nhiêu') || p.contains('đủ chưa') || p.contains('tiến độ') || p.contains('mấy calo')) {
      final namePrefix = appState.userProfile.fullName.isNotEmpty ? '${appState.userProfile.fullName} ơi, ' : '';
      final status = remainingCal > 0
          ? '${namePrefix}bạn còn thiếu $remainingCal kcal và ${remainingPro.round()}g đạm nữa để đạt chỉ tiêu hôm nay.'
          : '${namePrefix}bạn đã nạp đủ ${appState.totalCaloriesLogged} kcal cho hôm nay rồi nhé!';
      return VoiceAssistantResponse(
        actionType: 'check_progress',
        spokenReply: 'Hôm nay bạn đã nạp ${appState.totalCaloriesLogged}/${appState.userProfile.targetCalories} kcal. $status',
      );
    }

    // 6. Ghi nhật ký bữa ăn
    return _parseMealLogOffline(p);
  }

  VoiceAssistantResponse _generateFridgeRecipeOffline(
    int remainingCal,
    double remainingPro,
    double remainingCarb,
    double remainingFat,
    FridgeService fridge,
  ) {
    final appState = AppStateService.instance;
    final isVegetarian = appState.userProfile.dietType.toLowerCase().contains('vegetarian') ||
        appState.userProfile.dietType.toLowerCase().contains('chay');

    final items = List<FridgeItemModel>.from(fridge.items)
      ..sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));

    String mainName = isVegetarian ? 'Đậu hũ non' : 'Ức gà';
    String vegName = 'Bông cải';
    String title = isVegetarian ? 'Đậu hũ non sốt nấm cà chua' : 'Ức gà áp chảo sốt tiêu đen';
    final used = <VoiceRecipeIngredient>[];

    final cal = remainingCal > 150 ? remainingCal.clamp(250, 480) : 320;
    final pro = remainingPro > 10 ? remainingPro.clamp(20.0, 40.0) : 28.0;

    if (items.isNotEmpty) {
      mainName = items.first.name;
      used.add(VoiceRecipeIngredient(name: mainName, amount: items.first.quantity, inFridge: true));
      if (items.length > 1) {
        vegName = items[1].name;
        used.add(VoiceRecipeIngredient(name: vegName, amount: items[1].quantity, inFridge: true));
        title = '$mainName xào $vegName';
      } else {
        title = '$mainName áp chảo sốt tỏi';
      }
    } else {
      used.add(const VoiceRecipeIngredient(name: 'Ức gà', amount: '150g', inFridge: false));
      used.add(const VoiceRecipeIngredient(name: 'Rau xanh', amount: '100g', inFridge: false));
    }

    final namePrefix = appState.userProfile.fullName.isNotEmpty ? '${appState.userProfile.fullName} ơi! ' : '';

    return VoiceAssistantResponse(
      actionType: 'fridge_recipe',
      spokenReply: '${namePrefix}Tôi gợi ý món $title! Món này tận dụng ngay $mainName trong tủ lạnh, cung cấp $cal kcal và ${pro.round()}g đạm, vừa khít lượng còn thiếu của bạn!',
      recipeData: VoiceFridgeRecipeData(
        recipeTitle: title,
        matchExplanation: 'Món ăn tận dụng $mainName trong tủ lạnh, bù đắp vừa khít $cal kcal và ${pro.round()}g đạm còn thiếu hôm nay.',
        prepTimeMinutes: 15,
        calories: cal,
        protein: pro,
        carbs: remainingCarb > 0 ? (remainingCarb * 0.4).clamp(10.0, 50.0) : 25.0,
        fat: remainingFat > 0 ? (remainingFat * 0.4).clamp(5.0, 20.0) : 8.0,
        ingredientsUsed: used,
        cookingSteps: [
          'Sơ chế sạch $mainName và các nguyên liệu cắt vừa ăn',
          'Làm nóng chảo với 1 muỗng cà phê dầu ăn, phi thơm hành tỏi',
          'Cho $mainName vào đảo chín tới, nêm gia vị vừa ăn và thưởng thức nóng',
        ],
      ),
    );
  }

  VoiceAssistantResponse _parseMealLogOffline(String p) {
    String mealType = 'Trưa';
    if (p.contains('sáng')) mealType = 'Sáng';
    if (p.contains('tối')) mealType = 'Tối';
    if (p.contains('phụ') || p.contains('xế') || p.contains('chiều')) mealType = 'Phụ';

    int cal = 450;
    double pro = 22;
    double carb = 55;
    double fat = 14;
    String title = 'Bữa ăn dinh dưỡng';

    if (p.contains('phở bò')) {
      title = 'Phở bò truyền thống';
      cal = 520; pro = 26; carb = 65; fat = 15;
    } else if (p.contains('cơm tấm') || p.contains('sườn')) {
      title = 'Cơm tấm sườn nướng';
      cal = 650; pro = 28; carb = 80; fat = 22;
    } else if (p.contains('bún bò')) {
      title = 'Bún bò Huế';
      cal = 580; pro = 29; carb = 68; fat = 18;
    } else if (p.contains('bánh mì')) {
      title = 'Bánh mì kẹp thịt';
      cal = 420; pro = 18; carb = 48; fat = 16;
    } else if (p.contains('ức gà')) {
      title = 'Ức gà áp chảo';
      cal = 220; pro = 38; carb = 2; fat = 4;
    } else if (p.contains('trứng')) {
      title = 'Trứng luộc / ốp la';
      cal = 160; pro = 13; carb = 2; fat = 11;
    } else if (p.contains('chuối') || p.contains('sữa chua')) {
      title = 'Sữa chua hoa quả';
      cal = 180; pro = 6; carb = 32; fat = 3;
      mealType = 'Phụ';
    } else {
      final clean = p.replaceAll(RegExp(r'(trưa|sáng|tối|vừa|ăn|uống|nay|hôm nay|đã)'), '').trim();
      if (clean.isNotEmpty) {
        title = clean[0].toUpperCase() + clean.substring(1);
      }
    }

    return VoiceAssistantResponse(
      actionType: 'log_meal',
      spokenReply: 'Đã nhận diện: $title (~$cal kcal, ${pro.round()}g đạm). Bạn có muốn lưu vào Bữa $mealType hôm nay không?',
      mealData: VoiceMealData(
        mealType: mealType,
        title: title,
        calories: cal,
        protein: pro,
        carbs: carb,
        fat: fat,
        items: [title],
      ),
    );
  }

  /// Thực thi hành động Ghi nhận bữa ăn vào Nhật ký
  void executeMealLog(VoiceMealData meal) {
    AppStateService.instance.addCustomEntry(
      mealType: 'Bữa ${meal.mealType}',
      title: meal.title,
      calories: meal.calories,
      protein: meal.protein.round(),
      carbs: meal.carbs.round(),
      fat: meal.fat.round(),
    );
  }

  /// Thực thi hành động Bếp Trưởng: Trừ tủ lạnh + Ghi nhật ký
  void executeFridgeRecipe(VoiceFridgeRecipeData recipe) {
    // 1. Trừ hoặc tiêu thụ các nguyên liệu trong tủ lạnh
    final fridge = FridgeService.instance;
    for (final ing in recipe.ingredientsUsed) {
      if (ing.inFridge) {
        final matchItem = fridge.items.where((item) =>
            item.name.toLowerCase().contains(ing.name.toLowerCase()) ||
            ing.name.toLowerCase().contains(item.name.toLowerCase())).firstOrNull;
        if (matchItem != null) {
          fridge.consumeItem(matchItem.id, logToMealJournal: false);
        }
      }
    }

    // 2. Ghi nhận món vào Nhật ký ăn uống hôm nay
    AppStateService.instance.addCustomEntry(
      mealType: 'Bữa Ăn Từ Tủ Lạnh',
      title: '🍽️ ${recipe.recipeTitle}',
      calories: recipe.calories,
      protein: recipe.protein.round(),
      carbs: recipe.carbs.round(),
      fat: recipe.fat.round(),
    );
  }

  /// Thực thi ghi nhận nước
  void executeWaterLog(int amountMl) {
    AppStateService.instance.addWater(amountMl);
  }

  /// Thực thi thêm đồ vào tủ lạnh
  void executeFridgeAdd(VoiceFridgeAddData item) {
    final now = DateTime.now();
    FridgeService.instance.addItem(
      FridgeItemModel(
        id: 'voice_${DateTime.now().millisecondsSinceEpoch}',
        name: item.name,
        category: item.category,
        categoryIcon: '🥗',
        quantity: item.quantity,
        storageLocation: item.storageLocation,
        manufacturingDate: now,
        expirationDate: now.add(Duration(days: item.shelfLifeDays)),
        addedAt: now,
        notes: 'Thêm bằng Trợ lý Giọng nói AI',
      ),
    );
  }
}

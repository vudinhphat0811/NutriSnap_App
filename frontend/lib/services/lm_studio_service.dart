import 'dart:typed_data';
import 'ai_vision_service.dart';

export 'ai_vision_service.dart';

class LMStudioService {
  final AIVisionService _service = AIVisionService();

  String? get lastUsedProvider => _service.lastUsedProvider;

  Future<String> recognizeIngredient(Uint8List imageBytes) {
    return _service.recognizeIngredient(imageBytes);
  }

  Future<IngredientAnalysisResult> analyzeIngredient(Uint8List imageBytes) {
    return _service.analyzeIngredient(imageBytes);
  }

  Future<Map<String, dynamic>?> checkAiStatus() {
    return _service.checkAiStatus();
  }
}
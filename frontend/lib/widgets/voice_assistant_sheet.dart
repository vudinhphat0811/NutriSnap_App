import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/voice_assistant_model.dart';
import '../services/voice_assistant_service.dart';

class VoiceAssistantSheet extends StatefulWidget {
  final String? initialPrompt;
  final Function(String screen)? onNavigate;

  const VoiceAssistantSheet({super.key, this.initialPrompt, this.onNavigate});

  static Future<void> show(BuildContext context, {String? initialPrompt, Function(String screen)? onNavigate}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VoiceAssistantSheet(
        initialPrompt: initialPrompt,
        onNavigate: onNavigate,
      ),
    );
  }

  @override
  State<VoiceAssistantSheet> createState() => _VoiceAssistantSheetState();
}

class _VoiceAssistantSheetState extends State<VoiceAssistantSheet> with SingleTickerProviderStateMixin {
  final VoiceAssistantService _voiceService = VoiceAssistantService.instance;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _isListening = false;
  bool _isProcessing = false;
  bool _isTextMode = false;
  String _liveSpeechText = '';

  final List<_ChatMessage> _messages = [];

  final List<String> _quickSuggestions = [
    'Hôm nay ăn gì từ tủ lạnh?',
    'Trưa nay ăn 1 tô phở bò',
    'Vừa uống 300ml nước',
    'Còn bao nhiêu calo hôm nay?',
    'Cất 500g ức gà vào tủ',
    'Mở máy quét mã vạch',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _voiceService.init();

    // Tin nhắn chào mừng ban đầu
    _messages.add(
      _ChatMessage(
        isUser: false,
        text: 'Xin chào! Tôi là Trợ Lý Dinh Dưỡng & Bếp Trưởng AI của bạn. Bạn có thể bấm mic nói hoặc gõ câu hỏi để tôi hỗ trợ nhé!',
      ),
    );

    if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleSendPrompt(widget.initialPrompt!);
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _voiceService.stopListening();
    _voiceService.stopSpeaking();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _voiceService.stopListeningAndSubmit();
      if (mounted) {
        setState(() => _isListening = false);
      }
    } else {
      setState(() {
        _liveSpeechText = '';
        _isListening = true;
      });

      final started = await _voiceService.startListening(
        onResult: (words) {
          if (mounted) {
            setState(() {
              _liveSpeechText = words;
            });
          }
        },
        onDone: (words, audioPath) async {
          if (!mounted) return;

          if (words.trim().isNotEmpty) {
            // Case 1: Nhận diện được chữ trực tiếp từ thiết bị
            _handleSendPrompt(words.trim());
          } else if (audioPath != null && audioPath.isNotEmpty) {
            // Case 2: Thiết bị không nhận diện được chữ -> Backend Gemini phiên âm tệp ghi âm
            setState(() {
              _isListening = false;
              _isProcessing = true;
              _liveSpeechText = 'Đang chuyển đổi giọng nói thành tin nhắn...';
            });
            _scrollToBottom();

            final response = await _voiceService.processAudioFile(audioPath);
            if (!mounted) return;

            final userPromptText = (response.userPrompt != null && response.userPrompt!.isNotEmpty)
                ? response.userPrompt!
                : 'Lệnh bằng giọng nói';

            setState(() {
              _isProcessing = false;
              _liveSpeechText = '';
              // LẬP TỨC CHUYỂN THÀNH TIN NHẮN NGƯỜI DÙNG VÀO HỘI THOẠI:
              _messages.add(_ChatMessage(isUser: true, text: userPromptText));
              // VÀ TIN NHẮN TRẢ LỜI CỦA AI:
              _messages.add(_ChatMessage(
                isUser: false,
                text: response.spokenReply,
                response: response,
              ));
            });
            _scrollToBottom();

            _voiceService.speak(response.spokenReply);

            if (response.actionType == 'navigate' && response.navigateData != null) {
              final screen = response.navigateData!.targetScreen;
              Future.delayed(const Duration(milliseconds: 1500), () {
                if (mounted) {
                  Navigator.pop(context);
                  widget.onNavigate?.call(screen);
                }
              });
            }
          }
        },
        onListeningState: (listening) {
          if (mounted) {
            setState(() => _isListening = listening);
          }
        },
      );

      if (!started && mounted) {
        setState(() {
          _isListening = false;
          _isTextMode = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể kích hoạt Micro/Nhận diện giọng nói. Vui lòng cấp quyền Microphone hoặc gõ phím bên dưới.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _handleSendPrompt(String prompt) async {
    if (prompt.trim().isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(isUser: true, text: prompt));
      _isProcessing = true;
      _liveSpeechText = '';
    });
    _scrollToBottom();

    final response = await _voiceService.processCommand(prompt);

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _messages.add(_ChatMessage(
          isUser: false,
          text: response.spokenReply,
          response: response,
        ));
      });
      _scrollToBottom();
    }

    // Tự động đọc bằng giọng nói tiếng Việt
    _voiceService.speak(response.spokenReply);

    // Nếu là lệnh chuyển trang
    if (response.actionType == 'navigate' && response.navigateData != null) {
      final screen = response.navigateData!.targetScreen;
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          Navigator.pop(context);
          widget.onNavigate?.call(screen);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // 1. Header Trợ Lý Giọng Nói
          _buildHeader(),

          // 2. Danh sách tin nhắn hội thoại
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (ctx, i) => _buildMessageBubble(_messages[i]),
            ),
          ),

          // 3. Banner hiển thị lời nói trực tiếp (Real-time live transcript)
          if (_isListening || _isProcessing) _buildLiveTranscriptBanner(),

          // 4. Các gợi ý câu lệnh nhanh (Quick Suggestion Chips)
          _buildQuickSuggestions(),

          // 5. Thanh điều khiển Microphone & Nhập văn bản
          Padding(
            padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset + 8 : 16),
            child: _buildBottomControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Thanh gạt nhỏ ở đỉnh
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF047857)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trợ Lý Dinh Dưỡng AI',
                      style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: AppColors.textBlack),
                    ),
                    Text(
                      'Bếp Trưởng Vét Tủ & Ghi Nhớ Bằng Giọng Nói',
                      style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              // Nút bật/tắt đọc giọng nói (TTS)
              IconButton(
                icon: Icon(
                  _voiceService.isTtsEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  color: _voiceService.isTtsEnabled ? AppColors.primary : const Color(0xFF94A3B8),
                  size: 22,
                ),
                tooltip: _voiceService.isTtsEnabled ? 'Tắt đọc âm thanh' : 'Bật đọc âm thanh',
                onPressed: () {
                  setState(() {
                    _voiceService.isTtsEnabled = !_voiceService.isTtsEnabled;
                    if (!_voiceService.isTtsEnabled) {
                      _voiceService.stopSpeaking();
                    }
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF16A34A), Color(0xFF15803D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(
            msg.text,
            style: const TextStyle(fontSize: 13.5, color: Colors.white, height: 1.35),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.88),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Lời thoại AI
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                ),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
              child: Text(
                msg.text,
                style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), height: 1.4),
              ),
            ),

            // Các thẻ hành động tương tác thông minh (Action Cards)
            if (msg.response != null) ...[
              const SizedBox(height: 8),
              if (msg.response!.actionType == 'fridge_recipe' && msg.response!.recipeData != null)
                _buildFridgeRecipeCard(msg.response!.recipeData!),
              if (msg.response!.actionType == 'log_meal' && msg.response!.mealData != null)
                _buildMealLogCard(msg.response!.mealData!),
              if (msg.response!.actionType == 'log_water' && msg.response!.waterData != null)
                _buildWaterLogCard(msg.response!.waterData!),
              if (msg.response!.actionType == 'add_fridge' && msg.response!.fridgeAddData != null)
                _buildFridgeAddCard(msg.response!.fridgeAddData!),
            ],
          ],
        ),
      ),
    );
  }

  /// 🍳 THẺ BẾP TRƯỞNG VÉT TỦ CÂN MACRO
  Widget _buildFridgeRecipeCard(VoiceFridgeRecipeData recipe) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF86EFAC), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.soup_kitchen_rounded, color: Color(0xFF15803D), size: 20),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'BẾP TRƯỞNG VÉT TỦ CÂN MACRO',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF15803D), letterSpacing: 0.5),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                child: Text('⏱️ ${recipe.prepTimeMinutes} phút', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            recipe.recipeTitle,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          Text(
            recipe.matchExplanation,
            style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 8),

          // Macros
          Row(
            children: [
              _buildMacroTag('🔥 ${recipe.calories} kcal', const Color(0xFF15803D)),
              const SizedBox(width: 6),
              _buildMacroTag('💪 ${recipe.protein.toStringAsFixed(1)}g Đạm', const Color(0xFFDC2626)),
              const SizedBox(width: 6),
              _buildMacroTag('🌾 ${recipe.carbs.toStringAsFixed(1)}g Carb', const Color(0xFFD97706)),
              const SizedBox(width: 6),
              _buildMacroTag('🥑 ${recipe.fat.toStringAsFixed(1)}g Béo', const Color(0xFF0284C7)),
            ],
          ),

          const SizedBox(height: 10),
          const Text('Nguyên liệu từ tủ lạnh:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: recipe.ingredientsUsed.map((ing) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ing.inFridge ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ing.inFridge ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1)),
                ),
                child: Text(
                  '${ing.inFridge ? "🧊 " : ""}${ing.name} (${ing.amount})',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: ing.inFridge ? const Color(0xFF15803D) : const Color(0xFF475569)),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 12),
          // Nút hành động 1-chạm: Nấu & Trừ tủ lạnh & Lưu nhật ký
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton.icon(
              onPressed: () {
                _voiceService.executeFridgeRecipe(recipe);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ Đã trừ nguyên liệu trong tủ lạnh và lưu ${recipe.calories} kcal vào nhật ký!'),
                    backgroundColor: const Color(0xFF16A34A),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              icon: const Icon(Icons.done_all_rounded, size: 16),
              label: const Text(
                'Nấu Món Này (Trừ Tủ Lạnh & Lưu Nhật Ký)',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🍱 THẺ GHI NHẬN BỮA ĂN (MEAL LOG)
  Widget _buildMealLogCard(VoiceMealData meal) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bookmark_add_outlined, color: AppColors.primary, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'GỢI Ý GHI BỮA ${meal.mealType.toUpperCase()}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary),
                ),
              ),
              Text(
                '🔥 ${meal.calories} kcal',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF15803D)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(meal.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildMacroTag('Đạm: ${meal.protein.toStringAsFixed(1)}g', const Color(0xFFDC2626)),
              const SizedBox(width: 6),
              _buildMacroTag('Carb: ${meal.carbs.toStringAsFixed(1)}g', const Color(0xFFD97706)),
              const SizedBox(width: 6),
              _buildMacroTag('Béo: ${meal.fat.toStringAsFixed(1)}g', const Color(0xFF0284C7)),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: ElevatedButton.icon(
              onPressed: () {
                _voiceService.executeMealLog(meal);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ Đã lưu ${meal.title} (${meal.calories} kcal) vào Bữa ${meal.mealType}!'),
                    backgroundColor: const Color(0xFF16A34A),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              icon: const Icon(Icons.check_rounded, size: 16),
              label: Text('Xác nhận lưu vào Bữa ${meal.mealType}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  /// 💧 THẺ GHI NHẬN NƯỚC UỐNG
  Widget _buildWaterLogCard(VoiceWaterData water) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Color(0xFFDBEAFE), shape: BoxShape.circle),
            child: const Icon(Icons.water_drop_rounded, color: Color(0xFF2563EB), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Đã uống +${water.amountMl}ml nước', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                Text('Tiến độ hôm nay: ${water.newTotalMl} ml', style: const TextStyle(fontSize: 11, color: Color(0xFF3B82F6))),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              _voiceService.executeWaterLog(water.amountMl);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('💧 Đã ghi nhận +${water.amountMl}ml nước vào mục tiêu!'),
                  backgroundColor: const Color(0xFF2563EB),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Ghi nhận', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// 🧊 THẺ THÊM ĐỒ VÀO TỦ LẠNH
  Widget _buildFridgeAddCard(VoiceFridgeAddData item) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF99F6E4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Color(0xFFCCFBF1), shape: BoxShape.circle),
            child: const Icon(Icons.kitchen_rounded, color: Color(0xFF0D9488), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF134E4A))),
                Text('HSD ước tính: ${item.shelfLifeDays} ngày • ${item.quantity}', style: const TextStyle(fontSize: 11, color: Color(0xFF0F766E))),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              _voiceService.executeFridgeAdd(item);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('🧊 Đã thêm ${item.name} vào Tủ Lạnh Thông Minh!'),
                  backgroundColor: const Color(0xFF0D9488),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Cất vào tủ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildLiveTranscriptBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        children: [
          if (_isListening)
            ScaleTransition(
              scale: _pulseAnimation,
              child: const Icon(Icons.mic_rounded, color: Colors.redAccent, size: 18),
            )
          else
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isListening
                      ? (_liveSpeechText.isEmpty ? 'Đang lắng nghe bạn nói...' : _liveSpeechText)
                      : 'AI đang phân tích câu lệnh...',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: _liveSpeechText.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                    fontStyle: _liveSpeechText.isEmpty ? FontStyle.italic : FontStyle.normal,
                    color: _isListening ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_isListening && _liveSpeechText.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text(
                      'Dừng nói 2s để tự động chốt câu...',
                      style: TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSuggestions() {
    return Container(
      height: 36,
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _quickSuggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final s = _quickSuggestions[i];
          return ActionChip(
            label: Text(s, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFFCBD5E1)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            onPressed: () => _handleSendPrompt(s),
          );
        },
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Nút chuyển chế độ Gõ phím vs Nói
          IconButton(
            icon: Icon(_isTextMode ? Icons.mic_rounded : Icons.keyboard_rounded, color: const Color(0xFF64748B)),
            tooltip: _isTextMode ? 'Chuyển sang Giọng nói' : 'Chuyển sang Nhập chữ',
            onPressed: () {
              setState(() {
                _isTextMode = !_isTextMode;
                if (_isTextMode) {
                  _voiceService.stopListening();
                  _isListening = false;
                }
              });
            },
          ),

          // Ô nhập chữ hoặc Nút Mic lớn
          if (_isTextMode)
            Expanded(
              child: TextField(
                controller: _textController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Nhập món ăn hoặc câu lệnh...',
                  hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send_rounded, color: AppColors.primary, size: 20),
                    onPressed: () {
                      final text = _textController.text.trim();
                      if (text.isNotEmpty) {
                        _textController.clear();
                        _handleSendPrompt(text);
                      }
                    },
                  ),
                ),
                onSubmitted: (text) {
                  if (text.trim().isNotEmpty) {
                    _textController.clear();
                    _handleSendPrompt(text.trim());
                  }
                },
              ),
            )
          else
            Expanded(
              child: Center(
                child: GestureDetector(
                  onTap: _toggleListening,
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (ctx, child) {
                      return Transform.scale(
                        scale: _isListening ? _pulseAnimation.value : 1.0,
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: _isListening
                                  ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                                  : [const Color(0xFF10B981), const Color(0xFF047857)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (_isListening ? const Color(0xFFEF4444) : const Color(0xFF10B981)).withValues(alpha: 0.4),
                                blurRadius: _isListening ? 16 : 8,
                                spreadRadius: _isListening ? 4 : 1,
                              ),
                            ],
                          ),
                          child: Icon(
                            _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

          if (!_isTextMode)
            const SizedBox(width: 48), // Cân bằng không gian
        ],
      ),
    );
  }
}

class _ChatMessage {
  final bool isUser;
  final String text;
  final VoiceAssistantResponse? response;

  _ChatMessage({required this.isUser, required this.text, this.response});
}

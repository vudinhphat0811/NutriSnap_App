import 'package:flutter/material.dart';

/// Widget chạy chữ hiệu ứng Biển LED (Marquee Text)
/// - Nếu chữ ngắn vừa với không gian: hiển thị tĩnh bình thường, tiết kiệm tài nguyên.
/// - Nếu chữ dài quá giới hạn: tự động cuộn chữ mượt mà từ phải sang trái giống biển quảng cáo LED.
class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final double velocity; // Tốc độ trượt (pixels/giây)
  final Duration pauseDuration; // Thời gian dừng ở 2 đầu

  const MarqueeText({
    super.key,
    required this.text,
    this.style,
    this.velocity = 28.0,
    this.pauseDuration = const Duration(milliseconds: 1400),
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> {
  late ScrollController _scrollController;
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startLoopIfNeeded());
  }

  @override
  void didUpdateWidget(covariant MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _stopLoop();
      WidgetsBinding.instance.addPostFrameCallback((_) => _startLoopIfNeeded());
    }
  }

  void _startLoopIfNeeded() async {
    if (!mounted || !_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return; // Vừa vặn, không cần cuộn

    _isScrolling = true;
    while (_isScrolling && mounted) {
      await Future.delayed(widget.pauseDuration);
      if (!_isScrolling || !mounted || !_scrollController.hasClients) break;

      final currentMax = _scrollController.position.maxScrollExtent;
      if (currentMax <= 0) break;

      final duration = Duration(milliseconds: (currentMax / widget.velocity * 1000).toInt());
      await _scrollController.animateTo(
        currentMax,
        duration: duration,
        curve: Curves.linear,
      );

      await Future.delayed(widget.pauseDuration);
      if (!_isScrolling || !mounted || !_scrollController.hasClients) break;

      // Trượt nhẹ nhàng về đầu để bắt đầu lại chu kỳ mới
      await _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
  }

  void _stopLoop() {
    _isScrolling = false;
  }

  @override
  void dispose() {
    _isScrolling = false;
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(
        widget.text,
        style: widget.style,
        maxLines: 1,
      ),
    );
  }
}

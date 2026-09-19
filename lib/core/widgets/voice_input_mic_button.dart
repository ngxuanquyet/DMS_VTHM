import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../theme/app_colors.dart';

/// Nút micro nhận diện giọng nói (Push-To-Talk) dùng trong các form nhập liệu:
/// - Khi click nhanh (bấm rồi nhả luôn): Hiển thị SnackBar hướng dẫn "Nhấn và giữ biểu tượng mic để nói, thả tay ra khi nói xong."
/// - Khi nhấn giữ (Long Press): Bắt đầu ghi âm và nhận diện giọng nói tiếng Việt.
/// - Khi thả tay ra: Dừng ghi âm và truyền kết quả text vào callback [onTextRecognized].
class VoiceInputMicButton extends StatefulWidget {
  final ValueChanged<String> onTextRecognized;
  final String? fieldName;
  final double size;
  final Color? color;
  final String? currentText;
  final bool appendText;

  const VoiceInputMicButton({
    super.key,
    required this.onTextRecognized,
    this.fieldName,
    this.size = 20,
    this.color,
    this.currentText,
    this.appendText = true,
  });

  @override
  State<VoiceInputMicButton> createState() => _VoiceInputMicButtonState();
}

class _VoiceInputMicButtonState extends State<VoiceInputMicButton>
    with SingleTickerProviderStateMixin {
  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  String _recognizedText = '';

  late AnimationController _pulseController;
  late Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.28).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initSpeech();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    if (_isListening) {
      _speechToText.stop();
    }
    super.dispose();
  }

  Future<void> _initSpeech() async {
    if (kIsWeb) {
      _isInitialized = true;
      return;
    }

    try {
      final available = await _speechToText.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'notListening' || status == 'done') {
            if (_isListening) {
              _stopListening();
            }
          }
        },
        onError: (error) {
          if (!mounted) return;
          setState(() => _isListening = false);
          _pulseController.stop();
        },
      );
      if (mounted) {
        setState(() => _isInitialized = available);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isInitialized = false);
      }
    }
  }

  void _showGuidanceSnackBar() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.mic_none_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Nhấn và giữ biểu tượng mic để nói, thả tay ra khi nói xong.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.secondary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _startListening() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isListening = true;
      _recognizedText = '';
    });
    _pulseController.repeat(reverse: true);

    if (kIsWeb) {
      // Giả lập giọng nói trên môi trường Web demo
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted && _isListening) {
          _recognizedText = 'Đại lý Vật liệu Xây dựng VTHM';
        }
      });
      return;
    }

    if (!_isInitialized) {
      await _initSpeech();
      if (!_isInitialized) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không thể kích hoạt quyền micro. Vui lòng kiểm tra cài đặt thiết bị.'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
          _stopListening();
        }
        return;
      }
    }

    try {
      await _speechToText.listen(
        onResult: (SpeechRecognitionResult result) {
          if (!mounted) return;
          _recognizedText = result.recognizedWords;
        },
        listenOptions: SpeechListenOptions(
          localeId: 'vi_VN',
          listenMode: ListenMode.dictation,
          cancelOnError: true,
          partialResults: true,
        ),
      );
    } catch (_) {
      if (mounted) {
        _stopListening();
      }
    }
  }

  Future<void> _stopListening() async {
    if (!_isListening) return;

    HapticFeedback.lightImpact();
    _pulseController.stop();
    _pulseController.reset();

    if (!kIsWeb) {
      try {
        await _speechToText.stop();
      } catch (_) {}
    }

    if (!mounted) return;

    final resultText = _recognizedText.trim();
    setState(() {
      _isListening = false;
    });

    if (resultText.isNotEmpty) {
      final String finalText;
      if (widget.appendText &&
          widget.currentText != null &&
          widget.currentText!.trim().isNotEmpty) {
        finalText = '${widget.currentText!.trim()} $resultText';
      } else {
        finalText = resultText;
      }

      widget.onTextRecognized(finalText);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Đã nhận diện: "$resultText"',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = widget.color ?? (isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _showGuidanceSnackBar,
      onLongPressStart: (_) => _startListening(),
      onLongPressEnd: (_) => _stopListening(),
      onLongPressCancel: () => _stopListening(),
      child: AnimatedBuilder(
        animation: _pulseScale,
        builder: (context, child) {
          return Transform.scale(
            scale: _isListening ? _pulseScale.value : 1.0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isListening
                    ? AppColors.error.withValues(alpha: 0.18)
                    : Colors.transparent,
              ),
              child: Icon(
                _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                size: widget.size,
                color: _isListening ? AppColors.error : defaultColor,
              ),
            ),
          );
        },
      ),
    );
  }
}

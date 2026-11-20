import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../localization/app_language.dart';
import '../localization/app_strings.dart';
import '../localization/language_provider.dart';
import '../theme/app_colors.dart';
import 'microphone_permission_dialog.dart';

/// Nút micro nhận diện giọng nói dùng trong các form nhập liệu:
/// - Khi chạm nhanh: Hiển thị SnackBar hướng dẫn kèm nút "Nói ngay" cho phép ghi âm rảnh tay (Tap-to-talk).
/// - Khi nhấn giữ (Long Press): Kích hoạt ghi âm Push-To-Talk, hiển thị bảng nổi ghi âm (Floating HUD Overlay)
///   với sóng âm thanh động, nhãn trường đang nhập, và chữ nhận diện chạy theo thời gian thực (Live Transcription).
/// - Khắc phục triệt để lỗi chỉ nhận được chữ đầu: sử dụng `onDevice: false` (ép buộc dùng engine online của Google
///   giống như màn cá nhân) và cơ chế bộ đệm chờ kết quả cuối cùng (Graceful Finalization) khi thả tay.
class VoiceInputMicButton extends StatefulWidget {
  final ValueChanged<String> onTextRecognized;
  final String? fieldName;
  final double size;
  final Color? color;
  final String? currentText;
  final bool appendText;
  final AppStrings? strings;

  const VoiceInputMicButton({
    super.key,
    required this.onTextRecognized,
    this.fieldName,
    this.size = 20,
    this.color,
    this.currentText,
    this.appendText = true,
    this.strings,
  });

  @override
  State<VoiceInputMicButton> createState() => _VoiceInputMicButtonState();
}

class _VoiceInputMicButtonState extends State<VoiceInputMicButton>
    with TickerProviderStateMixin {
  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  bool _isFinalizing = false;
  bool _isTapMode = false;
  String _recognizedText = '';
  double _soundLevel = 0.0;

  late AnimationController _pulseController;
  late Animation<double> _pulseScale;
  late AnimationController _waveController;

  OverlayEntry? _overlayEntry;

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

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _initSpeech();
  }

  @override
  void dispose() {
    _removeOverlay();
    _pulseController.dispose();
    _waveController.dispose();
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
            if (_isListening && !_isFinalizing) {
              if (_isTapMode) {
                _stopListening();
              }
            }
          }
        },
        onError: (error) {
          if (!mounted) return;
          if (_isListening && !_isFinalizing) {
            _cancelListening();
          }
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

  AppStrings _resolveStrings() {
    if (widget.strings != null) return widget.strings!;
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      return container.read(stringsProvider);
    } catch (_) {
      return const AppStrings(AppLanguage.vi);
    }
  }

  void _showGuidanceSnackBar() {
    final s = _resolveStrings();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.mic_none_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                s.holdMicGuidance,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: s.speakNow,
          textColor: Colors.amberAccent,
          onPressed: () {
            _startListening(isTapMode: true);
          },
        ),
        backgroundColor: AppColors.secondary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showOverlay() {
    _removeOverlay();
    final overlayState = Overlay.of(context);
    final s = _resolveStrings();

    _overlayEntry = OverlayEntry(
      builder: (ctx) {
        return VoiceRecordingOverlay(
          strings: s,
          fieldName: widget.fieldName,
          recognizedText: _recognizedText,
          soundLevel: _soundLevel,
          isFinalizing: _isFinalizing,
          isTapMode: _isTapMode,
          waveAnimation: _waveController,
          onDonePressed: () => _stopListening(),
          onCancelPressed: () => _cancelListening(),
        );
      },
    );

    overlayState.insert(_overlayEntry!);
  }

  void _updateOverlay() {
    _overlayEntry?.markNeedsBuild();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _startListening({bool isTapMode = false}) async {
    if (_isListening || _isFinalizing) return;

    if (!kIsWeb && !WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      final hasPermission = await MicrophonePermissionDialog.checkAndRequestPermission(
        context,
        strings: _resolveStrings(),
      );
      if (!hasPermission || !mounted) {
        return;
      }
    }

    HapticFeedback.heavyImpact();
    setState(() {
      _isListening = true;
      _isFinalizing = false;
      _isTapMode = isTapMode;
      _recognizedText = '';
      _soundLevel = 0.0;
    });

    _pulseController.repeat(reverse: true);
    _waveController.repeat();
    _showOverlay();

    if (kIsWeb) {
      // Giả lập giọng nói trên web cho demo
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted && _isListening) {
          setState(() {
            _recognizedText = 'Đại lý VLXD';
            _soundLevel = 5.0;
          });
          _updateOverlay();
        }
      });
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted && _isListening) {
          setState(() {
            _recognizedText = 'Đại lý Vật liệu Xây dựng VTHM';
            _soundLevel = 8.0;
          });
          _updateOverlay();
        }
      });
      return;
    }

    if (!_isInitialized) {
      await _initSpeech();
      if (!_isInitialized) {
        if (mounted) {
          final s = _resolveStrings();
          _removeOverlay();
          setState(() => _isListening = false);
          _pulseController.stop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(s.isVietnamese
                  ? 'Không thể kích hoạt quyền micro. Vui lòng kiểm tra cài đặt thiết bị.'
                  : 'Unable to access microphone permission. Please check device settings.'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }

    try {
      await _speechToText.listen(
        onResult: (SpeechRecognitionResult result) {
          if (!mounted || !_isListening) return;
          setState(() {
            _recognizedText = result.recognizedWords;
          });
          _updateOverlay();
        },
        onSoundLevelChange: (level) {
          if (!mounted || !_isListening) return;
          setState(() {
            _soundLevel = level;
          });
          _updateOverlay();
        },
        listenOptions: SpeechListenOptions(
          localeId: 'vi_VN',
          listenMode: ListenMode.dictation,
          cancelOnError: true,
          partialResults: true,
          // CRITICAL: onDevice: false buộc hệ điều hành sử dụng mô hình nhận diện giọng nói
          // trực tuyến chuẩn Google (giống màn hình cá nhân), giải quyết triệt để lỗi chỉ nghe được 1 chữ!
          onDevice: false,
        ),
      );
    } catch (_) {
      if (mounted) {
        _cancelListening();
      }
    }
  }

  Future<void> _stopListening() async {
    if (!_isListening || _isFinalizing) return;

    HapticFeedback.lightImpact();
    setState(() {
      _isFinalizing = true;
    });
    _updateOverlay();

    _pulseController.stop();
    _pulseController.reset();
    _waveController.stop();
    _waveController.reset();

    // 1. Đệm thêm một khoảnh khắc ngắn (150ms) để không bị đứt âm tiết cuối cùng khi thả ngón tay
    await Future.delayed(const Duration(milliseconds: 150));

    if (!kIsWeb) {
      try {
        await _speechToText.stop();
      } catch (_) {}
      // 2. Chờ Speech Recognition Engine hoàn tất phân tích gói âm thanh cuối cùng (350ms)
      await Future.delayed(const Duration(milliseconds: 350));
    } else {
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (!mounted) return;

    final resultText = _recognizedText.trim();
    _removeOverlay();

    setState(() {
      _isListening = false;
      _isFinalizing = false;
      _isTapMode = false;
    });

    final s = _resolveStrings();
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
                  '${s.recognizedPrefix}"$resultText"',
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

  void _cancelListening() {
    HapticFeedback.selectionClick();
    _pulseController.stop();
    _pulseController.reset();
    _waveController.stop();
    _waveController.reset();
    _removeOverlay();

    if (!kIsWeb) {
      try {
        _speechToText.stop();
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _isListening = false;
        _isFinalizing = false;
        _isTapMode = false;
        _recognizedText = '';
        _soundLevel = 0.0;
      });
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
      onLongPressCancel: _cancelListening,
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
                    ? AppColors.error.withValues(alpha: 0.22)
                    : Colors.transparent,
                boxShadow: _isListening
                    ? [
                        BoxShadow(
                          color: AppColors.error.withValues(alpha: 0.4),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
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

/// Bảng điều khiển nổi hiển thị trạng thái đang ghi âm giọng nói (Floating Voice HUD Overlay)
/// Thẻ ghi âm nổi (chữ nhận diện + sóng âm + Huỷ / Hoàn tất) — mở cho test chụp giao diện sáng / tối.
@visibleForTesting
class VoiceRecordingOverlay extends StatelessWidget {
  final AppStrings strings;
  final String? fieldName;
  final String recognizedText;
  final double soundLevel;
  final bool isFinalizing;
  final bool isTapMode;
  final Animation<double> waveAnimation;
  final VoidCallback onDonePressed;
  final VoidCallback onCancelPressed;

  const VoiceRecordingOverlay({
    required this.strings,
    required this.fieldName,
    required this.recognizedText,
    required this.soundLevel,
    required this.isFinalizing,
    required this.isTapMode,
    required this.waveAnimation,
    required this.onDonePressed,
    required this.onCancelPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    // Theo chế độ sáng/tối của app (20/11/2026: thẻ đen cứng lạc tone ở chế độ sáng) — chỉ dùng token màu của app.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerLowest;
    final borderColor = isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant;
    final textColor = isDark ? AppColors.darkOnSurface : AppColors.onSurface;
    final mutedColor = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;
    final boxColor = isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLow;
    final accent = isDark ? AppColors.primaryFixedDim : AppColors.primary;
    // Đỏ của app tối quá trên nền tối ⇒ chế độ tối dùng tông đỏ nhạt cho chữ / chấm ghi âm / nút Huỷ.
    final danger = isDark ? AppColors.errorContainer : AppColors.error;

    return Stack(
      children: [
        // Lớp nền làm mờ nhẹ toàn màn hình
        Positioned.fill(
          child: GestureDetector(
            onTap: isTapMode ? onCancelPressed : null,
            child: Container(color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.25)),
          ),
        ),

        // Thẻ ghi âm nổi ở phần dưới màn hình, trên bàn phím
        Positioned(
          left: 16,
          right: 16,
          bottom: bottomInset > 0 ? bottomInset + 16 : 32,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hàng tiêu đề: nhãn đang ghi (chấm nhấp nháy) + tên trường
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isFinalizing ? AppColors.warning : AppColors.error).withValues(alpha: isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedBuilder(
                              animation: waveAnimation,
                              builder: (context, child) {
                                return Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isFinalizing
                                        ? AppColors.warning
                                        : danger.withValues(alpha: waveAnimation.value > 0.5 ? 1 : 0.3),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isFinalizing ? strings.recFinalizing : strings.recRecording,
                              style: TextStyle(
                                color: isFinalizing ? AppColors.warning : danger,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Tên trường đang nhập — dùng hết phần còn lại của hàng, dài quá mới cắt
                      if (fieldName != null && fieldName!.isNotEmpty)
                        Expanded(
                          child: Text(
                            '${strings.inputForFieldPrefix}$fieldName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(color: mutedColor, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Sóng âm — một màu chủ đạo của app, cột giữa đậm hơn
                  SizedBox(
                    height: 38,
                    child: AnimatedBuilder(
                      animation: waveAnimation,
                      builder: (context, child) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(15, (index) {
                            // Tính chiều cao sóng dựa theo sin wave + soundLevel
                            final phase = (index / 15.0) * 2 * 3.14159;
                            final wave = (waveAnimation.value * 2 * 3.14159) + phase;
                            final baseHeight = isFinalizing ? 6.0 : (8.0 + 16.0 * (0.5 + 0.5 * (wave.abs() % 1.0)));
                            final levelBoost = (soundLevel.clamp(-2.0, 10.0) + 2.0) * 1.5;
                            final height = (baseHeight + (isFinalizing ? 0 : levelBoost)).clamp(4.0, 36.0);

                            final isCenter = (index >= 5 && index <= 9);
                            final barColor = isFinalizing ? AppColors.warning : accent;
                            return Container(
                              width: 3.5,
                              height: height,
                              margin: const EdgeInsets.symmetric(horizontal: 2.5),
                              decoration: BoxDecoration(
                                color: isCenter ? barColor : barColor.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Chữ nhận diện thời gian thực
                  Container(
                    constraints: const BoxConstraints(minHeight: 52, maxHeight: 110),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: boxColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SingleChildScrollView(
                      reverse: true,
                      child: recognizedText.isEmpty
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.graphic_eq_rounded, size: 18, color: mutedColor),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    isFinalizing ? strings.voiceRecognizing : strings.speakIntoMicHint,
                                    style: TextStyle(color: mutedColor, fontSize: 13, fontStyle: FontStyle.italic),
                                  ),
                                ),
                              ],
                            )
                          : SelectableText(
                              recognizedText,
                              style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w600, height: 1.4),
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Hàng chân: Huỷ + Hoàn tất (chế độ chạm) hoặc hướng dẫn thả tay (chế độ nhấn giữ)
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: onCancelPressed,
                        icon: Icon(Icons.close_rounded, size: 16, color: danger),
                        label: Text(strings.cancel, style: TextStyle(color: danger, fontSize: 13)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const Spacer(),
                      if (isTapMode)
                        ElevatedButton.icon(
                          onPressed: onDonePressed,
                          icon: const Icon(Icons.check_rounded, size: 16, color: AppColors.onPrimary),
                          label: Text(
                            strings.completeActionCaps,
                            style: const TextStyle(color: AppColors.onPrimary, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        )
                      else
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.touch_app_rounded, size: 15, color: mutedColor),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  isFinalizing ? strings.updatingInput : strings.releaseToInsertText,
                                  style: TextStyle(color: mutedColor, fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

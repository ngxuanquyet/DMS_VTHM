import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/top_app_bar.dart';

class VoiceToTextScreen extends ConsumerStatefulWidget {
  const VoiceToTextScreen({super.key});

  @override
  ConsumerState<VoiceToTextScreen> createState() => _VoiceToTextScreenState();
}

class _VoiceToTextScreenState extends ConsumerState<VoiceToTextScreen>
    with SingleTickerProviderStateMixin {
  final SpeechToText _speechToText = SpeechToText();

  bool _isInitialized = false;
  bool _isListening = false;
  String _recognizedText = '';
  double _confidence = 0.0;
  String _selectedLocale = 'vi_VN';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initSpeech();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speechToText.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    if (kIsWeb) {
      setState(() {
        _isInitialized = true;
      });
      return;
    }

    try {
      final available = await _speechToText.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
      );

      if (mounted) {
        setState(() {
          _isInitialized = available;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isInitialized = false;
        });
      }
    }
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;
    setState(() {
      if (status == 'listening') {
        _isListening = true;
      } else if (status == 'notListening' || status == 'done') {
        _isListening = false;
      }
    });
  }

  void _onSpeechError(SpeechRecognitionError error) {
    if (!mounted) return;
    setState(() {
      _isListening = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lỗi nhận diện giọng nói: ${error.errorMsg}'),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Future<void> _startListening() async {
    if (kIsWeb) {
      // Mock for web demo
      setState(() {
        _isListening = true;
      });

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _recognizedText =
                'Hôm nay tôi đã đi thị trường ghé thăm Đại lý Vật liệu xây dựng Thành Công và kiểm tra tồn kho sản phẩm gạch men.';
            _confidence = 0.96;
            _isListening = false;
          });
        }
      });
      return;
    }

    if (!_isInitialized) {
      await _initSpeech();
      if (!_isInitialized) return;
    }

    try {
      await _speechToText.listen(
        onResult: _onSpeechResult,
        listenOptions: SpeechListenOptions(
          localeId: _selectedLocale,
          listenMode: ListenMode.dictation,
          cancelOnError: true,
          partialResults: true,
          onDevice: false,
        ),
      );

      setState(() {
        _isListening = true;
      });
    } catch (_) {
      setState(() {
        _isListening = false;
      });
    }
  }

  Future<void> _stopListening() async {
    await _speechToText.stop();
    setState(() {
      _isListening = false;
    });
  }

  void _toggleListening() {
    if (_isListening) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    setState(() {
      _recognizedText = result.recognizedWords;
      if (result.hasConfidenceRating && result.confidence > 0) {
        _confidence = result.confidence;
      }
    });
  }

  void _copyToClipboard(String text) {
    if (text.trim().isEmpty) return;
    final strings = ref.read(stringsProvider);
    Clipboard.setData(ClipboardData(text: text));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(strings.textCopied),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _clearText() {
    setState(() {
      _recognizedText = '';
      _confidence = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surface,
      appBar: VthmTopAppBar(
        title: strings.voiceToTextTitle,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Controls Bar (Language & Status)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.marginMobile,
                vertical: 12,
              ),
              child: Row(
                children: [
                  // Language Selector Dropdown Chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceContainer
                          : AppColors.surfaceContainerLowest,
                      borderRadius: AppRadius.roundedLg,
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkOutlineVariant
                            : AppColors.outlineVariant,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.language_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedLocale,
                            isDense: true,
                            dropdownColor: isDark
                                ? AppColors.darkSurfaceContainer
                                : AppColors.surfaceContainerLowest,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                            items: [
                              DropdownMenuItem(
                                value: 'vi_VN',
                                child: Text(
                                  strings.vietnameseLocale,
                                  style: AppTypography.labelLarge(
                                    color: isDark
                                        ? AppColors.darkOnSurface
                                        : AppColors.onSurface,
                                  ).copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'en_US',
                                child: Text(
                                  strings.englishLocale,
                                  style: AppTypography.labelLarge(
                                    color: isDark
                                        ? AppColors.darkOnSurface
                                        : AppColors.onSurface,
                                  ).copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                            onChanged: _isListening
                                ? null
                                : (val) {
                                    if (val != null) {
                                      setState(() {
                                        _selectedLocale = val;
                                      });
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),

                  // Listening / Ready Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isListening
                          ? AppColors.errorContainer.withValues(alpha: 0.3)
                          : AppColors.primaryContainer.withValues(alpha: 0.25),
                      borderRadius: AppRadius.roundedFull,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isListening ? AppColors.error : AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isListening ? strings.listening : 'Sẵn sàng',
                          style: AppTypography.labelSmall(
                            color: _isListening ? AppColors.error : AppColors.primary,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Main Display Area (Transcribed Speech Output)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.marginMobile,
                  vertical: 4,
                ),
                child: AppCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Row of Display Card
                      Row(
                        children: [
                          Icon(
                            Icons.record_voice_over_rounded,
                            size: 20,
                            color: isDark
                                ? AppColors.darkOnSurfaceVariant
                                : AppColors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            strings.speechRecognized,
                            style: AppTypography.titleMedium(
                              color: isDark
                                  ? AppColors.darkOnSurface
                                  : AppColors.onSurface,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),

                          // Confidence score badge (if available)
                          if (_confidence > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer.withValues(alpha: 0.25),
                                borderRadius: AppRadius.roundedSm,
                              ),
                              child: Text(
                                '${strings.confidenceScore}: ${(_confidence * 100).toInt()}%',
                                style: AppTypography.labelSmall(
                                  color: AppColors.primary,
                                ).copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),

                      // Text Output Area with Scroll
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: _recognizedText.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 48.0),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.graphic_eq_rounded,
                                          size: 54,
                                          color: (isDark
                                                  ? AppColors.darkOutline
                                                  : AppColors.outline)
                                              .withValues(alpha: 0.45),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          strings.noSpeechYet,
                                          textAlign: TextAlign.center,
                                          style: AppTypography.bodyMedium(
                                            color: isDark
                                                ? AppColors.darkOnSurfaceVariant
                                                : AppColors.onSurfaceVariant,
                                          ).copyWith(height: 1.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : SelectableText(
                                  _recognizedText,
                                  style: AppTypography.headlineSmall(
                                    color: isDark
                                        ? AppColors.darkOnSurface
                                        : AppColors.onSurface,
                                  ).copyWith(
                                    height: 1.6,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 19,
                                  ),
                                ),
                        ),
                      ),

                      // Bottom action bar inside display card
                      if (_recognizedText.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Divider(height: 1),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              '${_recognizedText.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length} từ',
                              style: AppTypography.labelSmall(
                                color: isDark
                                    ? AppColors.darkOnSurfaceVariant
                                    : AppColors.onSurfaceVariant,
                              ),
                            ),
                            const Spacer(),

                            // Copy button
                            TextButton.icon(
                              onPressed: () => _copyToClipboard(_recognizedText),
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              label: Text(strings.copyText),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                            const SizedBox(width: 4),

                            // Clear button
                            TextButton.icon(
                              onPressed: _clearText,
                              icon: const Icon(Icons.delete_outline_rounded, size: 16),
                              label: Text(strings.clearText),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.error,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Microphone Voice Control Section
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.marginMobile,
                vertical: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated Mic Button with Ripple Aura
                  GestureDetector(
                    onTap: _toggleListening,
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        final scale = _isListening ? _pulseAnimation.value : 1.0;
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer Wave Ring
                            if (_isListening)
                              Container(
                                width: 96 * scale,
                                height: 96 * scale,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary.withValues(alpha: 0.18),
                                ),
                              ),

                            // Inner Glow Ring
                            if (_isListening)
                              Container(
                                width: 82 * scale,
                                height: 82 * scale,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary.withValues(alpha: 0.35),
                                ),
                              ),

                            // Main Mic Circle
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: _isListening
                                      ? [
                                          AppColors.error,
                                          const Color(0xFFB71C1C),
                                        ]
                                      : [
                                          AppColors.primary,
                                          AppColors.primaryContainer,
                                        ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (_isListening
                                            ? AppColors.error
                                            : AppColors.primary)
                                        .withValues(alpha: 0.38),
                                    blurRadius: 18,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  _isListening
                                      ? Icons.stop_rounded
                                      : Icons.mic_rounded,
                                  color: Colors.white,
                                  size: 34,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Prompt Text
                  Text(
                    _isListening ? strings.listening : strings.tapToSpeak,
                    style: AppTypography.titleMedium(
                      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),

                  // Helper Subtitle
                  Text(
                    _isListening
                        ? 'Đang nghe bằng Native Speech Engine...'
                        : 'Sử dụng công cụ nhận diện giọng nói thiết bị',
                    style: AppTypography.bodySmall(
                      color: isDark
                          ? AppColors.darkOnSurfaceVariant
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

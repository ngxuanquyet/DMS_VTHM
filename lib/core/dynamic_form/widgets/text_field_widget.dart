import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/map/goong_api_service.dart';
import '../../../core/map/goong_config.dart';
import '../../../core/map/goong_models.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/voice_input_mic_button.dart';
import '../models/dynamic_form_field.dart';
import 'dynamic_form_field_wrapper.dart';

class DynamicTextFieldWidget extends StatefulWidget {
  final DynamicFormField field;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? errorText;
  final FocusNode? focusNode;

  const DynamicTextFieldWidget({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
    this.errorText,
    this.focusNode,
  });

  @override
  State<DynamicTextFieldWidget> createState() => _DynamicTextFieldWidgetState();
}

class _DynamicTextFieldWidgetState extends State<DynamicTextFieldWidget> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _isInternalFocusNode = false;
  bool _isFocused = false;

  final GoongApiService _goongService = GoongApiService();
  Timer? _debounceTimer;
  List<GoongPrediction> _suggestions = [];
  bool _isSearchingSuggestions = false;

  bool get _isAddressField =>
      widget.field.code == 'address' ||
      widget.field.code == 'delivery_address' ||
      widget.field.label.toLowerCase().contains('địa chỉ');

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value ?? '');
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode();
      _isInternalFocusNode = true;
    }
    _isFocused = _focusNode.hasFocus;
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted && _isFocused != _focusNode.hasFocus) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    }
  }

  @override
  void didUpdateWidget(covariant DynamicTextFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Không ghi đè khi ô đang focus để tránh làm mất dấu cách (space) lúc gõ phím
    if (!_focusNode.hasFocus && widget.value != oldWidget.value && widget.value != _controller.text) {
      _controller.text = widget.value ?? '';
    }
    if (widget.focusNode != oldWidget.focusNode) {
      _focusNode.removeListener(_onFocusChange);
      if (_isInternalFocusNode) {
        _focusNode.dispose();
      }
      if (widget.focusNode != null) {
        _focusNode = widget.focusNode!;
        _isInternalFocusNode = false;
      } else {
        _focusNode = FocusNode();
        _isInternalFocusNode = true;
      }
      _isFocused = _focusNode.hasFocus;
      _focusNode.addListener(_onFocusChange);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _focusNode.removeListener(_onFocusChange);
    if (_isInternalFocusNode) {
      _focusNode.dispose();
    }
    _controller.dispose();
    super.dispose();
  }

  GoongLatLng _getNearAnchor() {
    final cached = LocationService.currentCachedPosition;
    if (cached != null) {
      return GoongLatLng(cached.latitude, cached.longitude);
    }
    return const GoongLatLng(GoongConfig.fallbackLat, GoongConfig.fallbackLng);
  }

  void _onAddressSearch(String text) {
    if (!_isAddressField) return;

    _debounceTimer?.cancel();
    final trimmed = text.trim();
    if (trimmed.length < 2) {
      if (_suggestions.isNotEmpty || _isSearchingSuggestions) {
        setState(() {
          _suggestions = [];
          _isSearchingSuggestions = false;
        });
      }
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() {
        _isSearchingSuggestions = true;
      });

      try {
        final anchor = _getNearAnchor();
        final results = await _goongService.autocomplete(trimmed, near: anchor, limit: 6);
        if (!mounted) return;
        setState(() {
          _suggestions = results;
          _isSearchingSuggestions = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _suggestions = [];
          _isSearchingSuggestions = false;
        });
      }
    });
  }

  void _selectSuggestion(GoongPrediction prediction) {
    _debounceTimer?.cancel();
    final chosen = prediction.description;
    setState(() {
      _controller.text = chosen;
      _suggestions = [];
      _isSearchingSuggestions = false;
    });
    widget.onChanged(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DynamicFormFieldWrapper(
      field: widget.field,
      errorText: widget.errorText,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: widget.field.isReadOnly
                  ? (isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerHigh)
                  : (isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest),
              borderRadius: AppRadius.roundedMd,
              border: Border.all(
                color: widget.errorText != null
                    ? AppColors.error
                    : (_isFocused
                        ? AppColors.primary
                        : (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant)),
                width: _isFocused ? 1.5 : 1.0,
              ),
            ),
            child: TextField(
              focusNode: _focusNode,
              controller: _controller,
              readOnly: widget.field.isReadOnly,
              onChanged: (val) {
                // Không gọi trim() ở đây để cho phép người dùng gõ dấu space bình thường
                widget.onChanged(val.isNotEmpty ? val : null);
                _onAddressSearch(val);
              },
              style: AppTypography.bodyMedium(
                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
              ),
              decoration: InputDecoration(
                hintText: widget.field.placeholder ?? 'Nhập ${widget.field.label.toLowerCase()}...',
                hintStyle: AppTypography.bodySmall(
                  color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline,
                ),
                prefixText: widget.field.prefixText != null ? '${widget.field.prefixText} ' : null,
                suffixText: widget.field.suffixText,
                prefixIcon: const Icon(Icons.edit_note_rounded, size: 18),
                suffixIcon: !widget.field.isReadOnly
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_controller.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              tooltip: 'Xóa nội dung',
                              onPressed: () {
                                _debounceTimer?.cancel();
                                setState(() {
                                  _controller.clear();
                                  _suggestions = [];
                                  _isSearchingSuggestions = false;
                                });
                                widget.onChanged(null);
                              },
                            ),
                          VoiceInputMicButton(
                            currentText: _controller.text,
                            fieldName: widget.field.label,
                            onTextRecognized: (newText) {
                              setState(() {
                                _controller.text = newText;
                              });
                              widget.onChanged(newText.isNotEmpty ? newText : null);
                              _onAddressSearch(newText);
                            },
                          ),
                          const SizedBox(width: 4),
                        ],
                      )
                    : null,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                filled: false,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),

          // Gợi ý địa chỉ từ Goong Map Autocomplete v2 nếu là ô địa chỉ
          if (_isAddressField && _isSearchingSuggestions)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Row(
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Đang tìm gợi ý địa điểm gần bạn (Goong Maps)...',
                    style: AppTypography.bodySmall(
                      color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                    ).copyWith(fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),

          if (_isAddressField && _suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4, bottom: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceContainer : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 6, 4),
                    child: Row(
                      children: [
                        const Icon(Icons.near_me_outlined, size: 13, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Gợi ý địa điểm gần bạn (Goong Maps v2)',
                            style: AppTypography.labelSmall(
                              color: AppColors.primary,
                            ).copyWith(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _suggestions = [];
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: const Padding(
                            padding: EdgeInsets.all(2.0),
                            child: Icon(Icons.close_rounded, size: 14, color: AppColors.outline),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ..._suggestions.map((p) => InkWell(
                    onTap: () => _selectSuggestion(p),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Icons.location_on_outlined, size: 15, color: AppColors.primary),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.mainText.isNotEmpty ? p.mainText : p.description,
                                  style: AppTypography.bodySmall(
                                    color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                                  ).copyWith(fontWeight: FontWeight.w600, fontSize: 12),
                                ),
                                if (p.secondaryText.isNotEmpty)
                                  Text(
                                    p.secondaryText,
                                    style: AppTypography.bodySmall(
                                      color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                                    ).copyWith(fontSize: 11),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

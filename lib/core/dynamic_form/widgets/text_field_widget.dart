import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/map/goong_api_service.dart';
import '../../../core/map/goong_config.dart';
import '../../../core/map/goong_models.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/voice_input_mic_button.dart';
import '../models/dynamic_form_field.dart';
import '../../widgets/form_fields/form_field_parts.dart';
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
  late FocusNode _focusNode; // đổi được trong didUpdateWidget khi màn chứa đổi focusNode
  bool _isInternalFocusNode = false;

  final GoongApiService _goongService = GoongApiService();
  Timer? _debounceTimer;
  List<GoongPrediction> _suggestions = [];
  bool _isSearchingSuggestions = false;

  // 🔴 Chỉ CỘT CỨNG địa chỉ của điểm bán (mã cố định server) — ô động không đoán theo nhãn/mã (chủ hệ thống chốt 05/11/2026:
  // vẽ theo LOẠI TRƯỜNG, không theo tên).
  bool get _isAddressField => widget.field.code == 'address' || widget.field.code == 'delivery_address';

  // Cột cứng SĐT / email của điểm bán (mã cố định server). Ô động có nhãn "Loại điện thoại"… từng bị khoá chỉ gõ số — không
  // đoán theo nhãn/mã nữa (05/11/2026).
  bool get _isPhoneField => widget.field.code == 'phone';

  bool get _isEmailField => widget.field.code == 'email';

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
  }

  @override
  void didUpdateWidget(covariant DynamicTextFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Không ghi đè khi ô đang focus để tránh làm mất dấu cách (space) lúc gõ phím
    if (!_focusNode.hasFocus && widget.value != oldWidget.value && widget.value != _controller.text) {
      _controller.text = widget.value ?? '';
    }
    if (widget.focusNode != oldWidget.focusNode) {
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
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            focusNode: _focusNode,
            controller: _controller,
            readOnly: widget.field.isReadOnly,
            keyboardType: _isPhoneField
                ? TextInputType.phone
                : (_isEmailField
                    ? TextInputType.emailAddress
                    : (_isAddressField
                        ? TextInputType.streetAddress
                        : TextInputType.text)),
            inputFormatters: _isPhoneField
                ? [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d+ ()-]')),
                  ]
                : null,
            textInputAction: TextInputAction.next,
            onChanged: (val) {
              // Không gọi trim() ở đây để cho phép người dùng gõ dấu space bình thường
              widget.onChanged(val.isNotEmpty ? val : null);
              _onAddressSearch(val);
            },
            style: formFieldTextStyle(isDark),
            decoration: formFieldDecoration(
              isDark: isDark,
              readOnly: widget.field.isReadOnly,
              errorText: widget.errorText,
              hintText: widget.field.placeholder ??
                  (_isPhoneField
                      ? 'Nhập số điện thoại...'
                      : 'Nhập ${widget.field.label.toLowerCase()}...'),
              prefixText: widget.field.prefixText != null ? '${widget.field.prefixText} ' : null,
              suffixText: widget.field.suffixText,
              // Biểu tượng loại ô (điện thoại / email / chữ) — gợi ý bàn phím sẽ mở.
              prefixIcon: _isPhoneField
                  ? const Icon(Icons.phone_outlined, size: 18)
                  : (_isEmailField
                      ? const Icon(Icons.email_outlined, size: 18)
                      : const Icon(Icons.edit_note_rounded, size: 18)),
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

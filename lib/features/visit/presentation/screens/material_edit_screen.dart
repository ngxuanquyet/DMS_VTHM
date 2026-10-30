import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/localization/language_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/top_app_bar.dart';
import '../../../forms/domain/entities/market_form_entity.dart';
import '../../../forms/presentation/viewmodels/forms_view_model.dart';
import '../../../forms/presentation/widgets/dynamic_renderer/market_form_renderer.dart';
import '../../data/models/visit_material_model.dart';
import '../widgets/material_condition_badges.dart';

/// Gửi một thao tác; trả `null` khi xong (đã gửi hoặc đã xếp hàng đợi), hoặc câu lỗi của server cho đúng dòng này.
typedef MaterialSubmitter = Future<String?> Function(MaterialOperation op);

/// Mã ô ảnh dựng thêm vào bộ vẽ biểu mẫu (không trùng mã ô của schema chi tiết).
const String materialPhotoFieldCode = '__material_photos';
const String _reasonCode = '__material_reason';

MarketFormBlockEntity _syntheticBlock(String code, String label, String inputType,
        {bool required = false, int maxFiles = 10}) =>
    MarketFormBlockEntity(
      ref: code,
      type: 'field',
      required: required,
      resolved: MarketFormResolvedEntity(code: code, label: label, inputType: inputType, maxFiles: maxFiles),
    );

/// Form kiểm / sửa / khai một loại vật tư: số lượng theo từng tình trạng (tổng tự cộng), chi tiết theo `schema` của
/// loại (vẽ bằng [MarketFormRenderer] — bộ vẽ biểu mẫu thị trường), ảnh (ô ảnh của cùng bộ vẽ ⇒ `POST /dms/form-photos`).
class MaterialEditScreen extends ConsumerStatefulWidget {
  final OutletMaterialType type;

  /// null hoặc dòng trống (`id == null`) ⇒ thao tác `add`.
  final OutletMaterialItem? item;
  final List<MaterialCondition> conditions;
  final MaterialSubmitter onSubmit;

  const MaterialEditScreen({
    super.key,
    required this.type,
    required this.item,
    required this.conditions,
    required this.onSubmit,
  });

  @override
  ConsumerState<MaterialEditScreen> createState() => _MaterialEditScreenState();
}

class _MaterialEditScreenState extends ConsumerState<MaterialEditScreen> {
  final GlobalKey<MarketFormRendererState> _rendererKey = GlobalKey();
  final Map<String, TextEditingController> _countControllers = {};

  /// Số ở tình trạng ĐÃ TẮT (không còn trong danh mục) của dòng hiện có — hiện chỉ đọc. Server không nhận số khác 0 ở
  /// mã đã tắt, nên "Lưu" gửi 0 TƯỜNG MINH cho các mã này (không lặng lẽ bỏ khoá); "✓ Không đổi" giữ nguyên.
  final Map<String, int> _retiredCounts = {};
  late final List<MarketFormBlockEntity> _blocks;
  bool _submitting = false;
  String? _error;

  bool get _isNew => widget.item == null || widget.item!.isBlank;

  @override
  void initState() {
    super.initState();
    final counts = widget.item?.conditionCounts ?? const <String, int>{};
    for (final c in widget.conditions) {
      final v = counts[c.code] ?? 0;
      _countControllers[c.code] = TextEditingController(text: v > 0 ? '$v' : '');
    }
    final known = widget.conditions.map((c) => c.code).toSet();
    counts.forEach((code, n) {
      if (!known.contains(code) && n > 0) _retiredCounts[code] = n;
    });
    _blocks = [
      ...widget.type.detailBlocks,
      // Tối thiểu KHÔNG giao cho bộ vẽ (nó đòi cả khi số lượng 0) — chỉ ghi lên nhãn; `_save` kiểm đúng luật server.
      _syntheticBlock(materialPhotoFieldCode, ref.read(stringsProvider).materialsPhotosLabel(widget.type.minPhotos), 'image',
          maxFiles: widget.type.maxPhotos),
    ];
  }

  @override
  void dispose() {
    for (final c in _countControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, int> get _counts {
    final out = <String, int>{};
    _countControllers.forEach((code, c) {
      final n = int.tryParse(c.text.trim()) ?? 0;
      if (n > 0) out[code] = n;
    });
    return out;
  }

  int get _total => _counts.values.fold(0, (a, b) => a + b);

  void _step(String code, int delta) {
    final c = _countControllers[code]!;
    final n = ((int.tryParse(c.text.trim()) ?? 0) + delta).clamp(0, 99999);
    setState(() => c.text = n > 0 ? '$n' : '');
  }

  Future<void> _send(MaterialOperation op) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final err = await widget.onSubmit(op);
    if (!mounted) return;
    if (err == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _submitting = false;
        _error = err;
      });
    }
  }

  Future<void> _confirmUnchanged() => _send(MaterialOperation(
        clientUuid: const Uuid().v4(),
        materialTypeId: widget.type.id,
        action: MaterialAction.confirm,
        clickedAtServerMs: serverClockNowMs(),
      ));

  /// Mã các ô ảnh trong schema chi tiết — chỉ chúng được đổi đường dẫn ảnh ra token khi gửi.
  List<String> get _detailPhotoFields => widget.type.detailBlocks
      .where((b) => b.isImage || b.resolved.inputType.toLowerCase() == 'file')
      .map((b) => b.resolved.code)
      .toList();

  Future<void> _save() async {
    final strings = ref.read(stringsProvider);
    final answers = _rendererKey.currentState?.validateAndGetAnswers();
    if (answers == null) {
      setState(() => _error = strings.materialsCheckForm);
      return;
    }
    final photos = (answers.remove(materialPhotoFieldCode) as List?)?.map((e) => e.toString()).toList() ?? <String>[];
    if (_total > 0 && photos.length < widget.type.minPhotos) {
      setState(() => _error = strings.materialsPhotoMin(widget.type.minPhotos));
      return;
    }
    // `update`: chỉ gửi ô chi tiết muốn đổi (ô không gửi giữ nguyên) — so với giá trị lần trước.
    final old = widget.item?.details ?? const <String, dynamic>{};
    final details = _isNew
        ? answers
        : Map<String, dynamic>.fromEntries(
            answers.entries.where((e) => jsonEncode(e.value) != jsonEncode(old[e.key])),
          );
    await _send(MaterialOperation(
      clientUuid: const Uuid().v4(),
      materialTypeId: widget.type.id,
      action: _isNew ? MaterialAction.add : MaterialAction.update,
      conditionCounts: {..._counts, for (final code in _retiredCounts.keys) code: 0},
      details: details,
      photos: photos,
      detailPhotoFields: _detailPhotoFields,
      clickedAtServerMs: serverClockNowMs(),
    ));
  }

  Future<void> _openRemove() async {
    final removed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _MaterialRemoveScreen(type: widget.type, onSubmit: widget.onSubmit),
      ),
    );
    if (removed == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final item = widget.item;
    final canRemove = !_isNew && (item?.quantity ?? 0) > 0;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surface,
      appBar: VthmTopAppBar(
        title: widget.type.name,
        showBackButton: true,
        showAvatar: false,
        showLogo: false,
        trailing: canRemove
            ? TextButton(
                onPressed: _submitting ? null : _openRemove,
                child: Text(strings.materialsRemove, style: const TextStyle(color: Colors.white)),
              )
            : const SizedBox.shrink(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.marginMobile),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.type.name,
                    style: AppTypography.titleMedium(
                      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  strings.materialsTotal(_total),
                  style: AppTypography.titleMedium(
                    color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...widget.conditions.map((c) => _buildCountRow(c, isDark)),
            ..._retiredCounts.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      ConditionDot(color: conditionColor('dark')),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${e.key}: ${e.value} — ${strings.materialsDisabledCondition}',
                          style: AppTypography.bodyMedium(
                            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
            if (widget.type.detailBlocks.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                strings.materialsDetails,
                style: AppTypography.labelLarge(
                  color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              const Divider(),
            ],
            const SizedBox(height: 8),
            MarketFormRenderer(
              key: _rendererKey,
              blocks: _blocks,
              initialAnswers: item?.details ?? const {},
              onUploadPhoto: (file) => ref.read(formsApiServiceProvider).uploadPhoto(file),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.marginMobile),
          child: Row(
            children: [
              if (!_isNew) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting ? null : _confirmUnchanged,
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                    child: Text(strings.materialsUnchanged),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: _submitting ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(strings.materialsSave),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountRow(MaterialCondition c, bool isDark) {
    final controller = _countControllers[c.code]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          ConditionDot(color: conditionColor(c.color)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              c.name,
              style: AppTypography.bodyMedium(color: isDark ? AppColors.darkOnSurface : AppColors.onSurface),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: _submitting ? null : () => _step(c.code, -1),
          ),
          SizedBox(
            width: 64,
            child: TextField(
              controller: controller,
              enabled: !_submitting,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
              decoration: const InputDecoration(hintText: '0', isDense: true, border: OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _submitting ? null : () => _step(c.code, 1),
          ),
        ],
      ),
    );
  }
}

/// Gỡ / thu hồi (đưa về 0): bắt buộc lý do + ít nhất một ảnh — hai ô dựng trên cùng bộ vẽ biểu mẫu.
class _MaterialRemoveScreen extends ConsumerStatefulWidget {
  final OutletMaterialType type;
  final MaterialSubmitter onSubmit;

  const _MaterialRemoveScreen({required this.type, required this.onSubmit});

  @override
  ConsumerState<_MaterialRemoveScreen> createState() => _MaterialRemoveScreenState();
}

class _MaterialRemoveScreenState extends ConsumerState<_MaterialRemoveScreen> {
  final GlobalKey<MarketFormRendererState> _rendererKey = GlobalKey();
  late final List<MarketFormBlockEntity> _blocks;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final strings = ref.read(stringsProvider);
    _blocks = [
      _syntheticBlock(_reasonCode, strings.materialsRemoveReason, 'textarea', required: true),
      _syntheticBlock(materialPhotoFieldCode, strings.materialsRemovePhotos, 'image',
          required: true, maxFiles: widget.type.maxPhotos),
    ];
  }

  Future<void> _submit() async {
    final strings = ref.read(stringsProvider);
    final answers = _rendererKey.currentState?.validateAndGetAnswers();
    final photos = (answers?[materialPhotoFieldCode] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
    final reason = answers?[_reasonCode]?.toString().trim() ?? '';
    if (answers == null || reason.isEmpty || photos.isEmpty) {
      setState(() => _error = strings.materialsCheckForm);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final err = await widget.onSubmit(MaterialOperation(
      clientUuid: const Uuid().v4(),
      materialTypeId: widget.type.id,
      action: MaterialAction.remove,
      reason: reason,
      photos: photos,
      clickedAtServerMs: serverClockNowMs(),
    ));
    if (!mounted) return;
    if (err == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _submitting = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surface,
      appBar: VthmTopAppBar(
        title: strings.materialsRemoveTitle,
        showBackButton: true,
        showAvatar: false,
        showLogo: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.marginMobile),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.type.name,
              style: AppTypography.titleMedium(
                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            MarketFormRenderer(
              key: _rendererKey,
              blocks: _blocks,
              onUploadPhoto: (file) => ref.read(formsApiServiceProvider).uploadPhoto(file),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.marginMobile),
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(strings.materialsRemoveConfirm),
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/connectivity_provider.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/account_key.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/draft_restored_banner.dart';
import '../../../../core/widgets/form_fields/form_template_parts.dart';
import '../../../../core/dynamic_form/repeat_group.dart' show RepeatGroupSpec;
import '../../../../core/dynamic_form/widgets/display_matrix_field_widget.dart'
    show DisplayMatrixCustom;
import '../../data/models/market_form_submission_model.dart';
import '../../data/services/form_draft_store.dart';
import '../../data/services/form_suggest_store.dart';
import '../../domain/entities/market_form_entity.dart';
import '../viewmodels/forms_view_model.dart';
import '../widgets/dynamic_renderer/market_form_renderer.dart';

class MarketFormFillArgs {
  final MarketFormConfigEntity config;
  final String kind; // 'survey' | 'collect'
  final int? customerId;
  final int? visitId;
  final String? dealerName;
  final String? customerCode;
  final String? customerAddress;
  final Map<String, dynamic>? initialAnswers;
  final Map<String, dynamic>? customerContext;
  final bool? lockCustomer;

  /// clientUuid của lượt viếng thăm (phiếu khảo sát) — thành `parentUuid` của mục hàng đợi: tra mã server khi lượt
  /// còn offline, và để check-out offline của lượt chờ phiếu gửi xong (server đếm phiếu bắt buộc ở cổng check-out).
  final String? visitClientUuid;

  /// Tuyến để tự điền ô `ref_dms_route` theo thứ tự ưu tiên (tuyến của lượt, rồi tuyến của điểm bán).
  final List<int> routeIds;

  /// Ô động của hồ sơ điểm bán (bản trên máy) — số hiện trạng làm gợi ý mờ ở ô ma trận cập nhật hồ sơ (#24789).
  final Map<String, dynamic> customerData;

  const MarketFormFillArgs({
    required this.config,
    required this.kind,
    this.customerId,
    this.visitId,
    this.dealerName,
    this.customerCode,
    this.customerAddress,
    this.initialAnswers,
    this.customerContext,
    this.lockCustomer,
    this.visitClientUuid,
    this.routeIds = const [],
    this.customerData = const {},
  });

  /// Kiểm tra xem có cần cố định (khoá) trường khách hàng không
  /// Tự động khoá nếu là khảo sát trong lượt viếng thăm (kind == 'survey' và có customerId)
  bool get isCustomerLocked =>
      lockCustomer ?? (kind == 'survey' && customerId != null);

  /// Dựng ngữ cảnh @customer.* từ các thuộc tính điểm bán theo spec 20/10/2026 (§2)
  static Map<String, dynamic> buildCustomerContext({
    int? typeId,
    List<int>? channelIds,
    List<String>? territoryCodes,
    int? regionId,
  }) {
    return {
      '@customer': {
        'type_id': typeId,
        'channel_ids': channelIds ?? <int>[],
        'territory_codes': territoryCodes ?? <String>[],
        'region_id': regionId,
      },
    };
  }
}

class MarketFormFillScreen extends ConsumerStatefulWidget {
  final MarketFormFillArgs args;

  const MarketFormFillScreen({super.key, required this.args});

  @override
  ConsumerState<MarketFormFillScreen> createState() =>
      _MarketFormFillScreenState();
}

class _MarketFormFillScreenState extends ConsumerState<MarketFormFillScreen>
    with WidgetsBindingObserver {
  GlobalKey<MarketFormRendererState> _rendererKey = GlobalKey();
  bool _isSubmitting = false;
  bool _isExiting = false;

  /// Nháp phiếu THU THẬP (chủ hệ thống chốt 20/11/2026): mỗi biểu mẫu một nháp, ngăn riêng theo tài khoản
  /// ([FormDraftStore.collectSlot]) — chưa rõ tài khoản thì tắt nháp ở [initState].
  late final bool _isCollectDraft =
      widget.args.kind == 'collect' && widget.args.initialAnswers == null;

  /// Nháp ([FormDraftStore]): phiếu khảo sát trong lượt viếng thăm, hoặc phiếu thu thập — mở mới (không mang sẵn câu trả lời).
  late bool _draftEnabled =
      _isCollectDraft ||
      (widget.args.kind == 'survey' &&
          widget.args.initialAnswers == null &&
          ((widget.args.visitClientUuid?.isNotEmpty ?? false) ||
              (widget.args.visitId ?? 0) > 0));
  late bool _draftLoaded = !_draftEnabled;

  /// Ngăn lưu nháp: ngăn lượt viếng thăm (mặc định) hoặc ngăn thu thập của tài khoản.
  String? _draftSlot;

  /// Gợi ý từ các phiếu đã nộp cho ô chữ bật `suggest_from_history` ([FormSuggestStore]).
  Map<String, List<String>> _suggestions = const {};
  late final Set<String> _suggestCodes = FormSuggestStore.enabledCodes(
    widget.args.config.schema.blocks,
  );
  Map<String, dynamic>? _draftAnswers;

  /// Câu trả lời tự điền từ phiếu cũ khi chạm một gợi ý ([_fillFromSuggestion]) — dựng lại biểu mẫu với bộ này.
  Map<String, dynamic>? _seedAnswers;
  DateTime? _draftSavedAt;
  Map<String, dynamic>? _pendingDraft;

  /// Ảnh khôi phục từ nháp: token → tệp gốc ([FormDraftStore] `token_files`) — renderer chỉ còn token của chúng.
  Map<String, String> _draftTokenFiles = {};
  Map<String, String> _pendingTokenFiles = {};
  Timer? _draftTimer;
  Map<String, String> _draftPhotoMemo = {};

  /// Tăng khi "Xoá nháp, làm lại" — kết quả của lần ghi bắt đầu TRƯỚC đó không được ghi đè [_lastDraftSaveOk].
  int _draftGen = 0;

  /// Lần ghi nháp gần nhất có thành công không — hỏng thì rời màn phải hỏi như khi chưa có nháp.
  bool _lastDraftSaveOk = true;

  int get _visitId => _isCollectDraft
      ? FormDraftStore.collectVisitId
      : widget.args.visitId ?? 0;
  String get _visitUuid => _isCollectDraft
      ? FormDraftStore.collectUuid
      : widget.args.visitClientUuid ?? '';
  int get _configId => widget.args.config.configId;

  @override
  void initState() {
    super.initState();
    if (_suggestCodes.isNotEmpty) _loadSuggestions();
    if (!_draftEnabled) return;
    WidgetsBinding.instance.addObserver(this);
    _openDraft();
  }

  /// Bản lưu trong máy dùng NGAY (mất mạng không phải chờ trần tải), rồi thay bằng bản mới từ server khi có.
  Future<void> _loadSuggestions() async {
    try {
      final store = ref.read(formSuggestStoreProvider);
      final formId = widget.args.config.formId;
      final cached = await store.cached(formId);
      if (mounted && cached.isNotEmpty) setState(() => _suggestions = cached);
      final fresh = await store.load(formId);
      if (mounted) setState(() => _suggestions = fresh);
    } catch (e) {
      // Không có gợi ý thì ô vẫn là ô chữ thường — không làm hỏng màn điền phiếu.
      debugPrint('[MarketFormFill] Không nạp được gợi ý: $e');
    }
  }

  Future<void> _openDraft() async {
    if (_isCollectDraft) {
      final account = cacheAccountKey(await SharedPreferences.getInstance());
      if (!mounted) return;
      if (account == null) {
        WidgetsBinding.instance.removeObserver(this);
        setState(() {
          _draftEnabled = false;
          _draftLoaded = true;
        });
        return;
      }
      _draftSlot = FormDraftStore.collectSlot(account);
    }
    final d = await FormDraftStore.load(
      visitId: _visitId,
      clientUuid: _visitUuid,
      configId: _configId,
      slotKey: _slot!,
    );
    if (!mounted) return;
    setState(() {
      _draftAnswers = d?.answers;
      _draftSavedAt = d?.savedAt;
      _draftTokenFiles = d?.tokenFiles ?? {};
      _draftLoaded = true;
    });
  }

  /// Ngăn nháp đang dùng; `null` = phiếu thu thập chưa rõ ngăn (đang đọc tài khoản) ⇒ KHÔNG ghi / xoá gì — rơi về ngăn
  /// lượt là ghi đè cả ngăn của lượt đang mở (mất nháp khảo sát).
  String? get _slot => _isCollectDraft ? _draftSlot : FormDraftStore.visitSlot;

  @override
  void dispose() {
    if (_draftEnabled) {
      WidgetsBinding.instance.removeObserver(this);
      _flushDraft();
    }
    super.dispose();
  }

  /// App xuống nền / sắp bị đóng ⇒ ghi nháp ngay, không đợi nhịp tự lưu.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _flushDraft();
  }

  void _onAnswersChanged(Map<String, dynamic> answers) {
    if (!_draftEnabled || _isSubmitting || _isExiting) return;
    _pendingDraft = answers;
    // Chụp lúc đổi: lúc ghi ở dispose, renderer (con) đã bị gỡ.
    _pendingTokenFiles = {
      ..._draftTokenFiles,
      ...?_rendererKey.currentState?.uploadedPhotoFiles,
    };
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(seconds: 1), _flushDraft);
  }

  /// Ghi nháp đang chờ (nhịp tự lưu / app xuống nền / rời màn); kết quả vào [_lastDraftSaveOk].
  void _flushDraft() {
    _draftTimer?.cancel();
    final pending = _pendingDraft;
    if (pending == null) return;
    _pendingDraft = null;
    // Bản chụp ĐỘC LẬP (cả map lồng), chụp đồng bộ tại đây: biểu mẫu sửa tại chỗ giá trị ma trận / nhóm lặp trong lúc kho
    // nháp còn chờ chép tệp. Không mã hoá được ⇒ coi như không lưu được.
    final Map<String, dynamic> answers;
    try {
      answers = jsonDecode(jsonEncode(pending)) as Map<String, dynamic>;
    } catch (_) {
      _lastDraftSaveOk = false;
      return;
    }
    final slot = _slot;
    if (slot == null) return;
    // Kho nháp ghi nối tiếp ⇒ các lần ghi xong theo thứ tự gọi, [_lastDraftSaveOk] là kết quả lần mới nhất.
    final gen = _draftGen;
    _saveDraft(slot, gen, answers);
  }

  Future<void> _saveDraft(
    String slot,
    int gen,
    Map<String, dynamic> answers,
  ) async {
    // Bị đăng xuất khi màn còn mở (logout đã xoá ngăn + ảnh nháp của người này) ⇒ không ghi lại nháp của tài khoản cũ.
    if (_isCollectDraft &&
        slot !=
            FormDraftStore.collectSlot(
              cacheAccountKey(await SharedPreferences.getInstance()) ?? '',
            )) {
      if (gen == _draftGen) _lastDraftSaveOk = false;
      return;
    }
    FormDraftStore.save(
      visitId: _visitId,
      clientUuid: _visitUuid,
      configId: _configId,
      answers: answers,
      photoMemo: _draftPhotoMemo,
      tokenFiles: _pendingTokenFiles,
      slotKey: slot,
    ).then((ok) {
      if (gen == _draftGen) _lastDraftSaveOk = ok;
    });
  }

  void _discardDraft() {
    _draftTimer?.cancel();
    _pendingDraft = null;
    final slot = _slot;
    if (slot != null)
      FormDraftStore.remove(
        visitId: _visitId,
        clientUuid: _visitUuid,
        configId: _configId,
        slotKey: slot,
      );
  }

  /// "Xoá nháp, làm lại": bỏ nháp rồi dựng lại biểu mẫu trống.
  void _restartWithoutDraft() {
    // Ảnh đang tải lên của biểu mẫu cũ: dựng lại lúc này là lượt tải xong ghi nháp mới mang ảnh cũ.
    if (_rendererKey.currentState?.hasUploadingPhotos ?? false) {
      AppSnackBar.showInvalid(
        context,
        'Ảnh đang được xử lý, vui lòng chờ xong rồi làm lại.',
      );
      return;
    }
    _discardDraft();
    _draftGen++;
    _lastDraftSaveOk = true;
    // Map MỚI: lần ghi cũ còn chạy vẫn ghi vào map của nó, không lẫn vào biểu mẫu mới.
    _draftPhotoMemo = {};
    _draftTokenFiles = {};
    setState(() {
      _draftAnswers = null;
      _seedAnswers = null;
      _draftSavedAt = null;
      _rendererKey = GlobalKey();
    });
  }

  /// Chạm gợi ý ô [code] ⇒ điền CẢ phiếu theo phiếu cũ mới nhất mang giá trị đó (chủ hệ thống chốt 24/11/2026): chép mọi ô
  /// trừ ảnh / tệp (server đã bỏ); ảnh đã chụp trong phiếu đang điền giữ nguyên. Đã nhập ô khác ⇒ hỏi trước khi ghi đè.
  Future<void> _fillFromSuggestion(String code, String value) async {
    // Chỉ phiếu THU THẬP (Khảo sát NPP — chốt 24/11/2026): phiếu khảo sát gắn điểm bán của lượt, chép phiếu cũ là mang ô
    // điểm bán / tuyến của lượt khác sang. Phiếu mở kèm câu trả lời sẵn (sửa / xem lại) — bộ đó thắng, không dựng lại.
    if (widget.args.kind != 'collect' || widget.args.initialAnswers != null)
      return;
    final fill = await ref
        .read(formSuggestStoreProvider)
        .fillFor(widget.args.config.formId, code, value);
    final renderer = _rendererKey.currentState;
    if (!mounted || fill == null || fill.isEmpty || renderer == null) return;
    if (renderer.hasUploadingPhotos) {
      AppSnackBar.showInvalid(
        context,
        'Ảnh đang được xử lý, chờ xong rồi chọn lại để điền theo phiếu cũ.',
      );
      return;
    }
    final current = renderer.currentAnswers;
    // Ô mang ảnh của phiếu đang điền — giữ nguyên ([_keepPhotos]); server đã bỏ ảnh khỏi phiếu cũ.
    final kept = _keepPhotos(current, fill);
    final others = {
      for (final e in current.entries)
        if (e.key != code &&
            !kept.containsKey(e.key) &&
            !renderer.isAutoDefault(e.key))
          e.key: e.value,
    };
    if (_hasEnteredData(others) && await _confirmOverwrite(value) != true)
      return;
    if (!mounted || !identical(renderer, _rendererKey.currentState)) return;

    final seed = <String, dynamic>{...fill, ...kept, code: value};
    // Dòng bảng lặp chép từ phiếu cũ mang `line_id` của phiếu đó — khoá dòng phải riêng từng phiếu ⇒ cấp mới.
    for (final b in widget.args.config.schema.blocks) {
      final c = b.resolved.code;
      final rows = seed[c];
      if (!b.resolved.isRepeatGroup || kept.containsKey(c) || rows is! List)
        continue;
      seed[c] = [
        for (final r in rows)
          if (r is Map) {...r, 'line_id': RepeatGroupSpec.newLineId()} else r,
      ];
    }
    // Tệp gốc của ảnh đã tải lên — renderer mới chỉ nhận token, nháp cần tệp này ([FormDraftStore] `token_files`).
    _draftTokenFiles = {..._draftTokenFiles, ...renderer.uploadedPhotoFiles};
    setState(() {
      _seedAnswers = seed;
      _rendererKey = GlobalKey();
    });
    _onAnswersChanged(seed);
    AppSnackBar.showSuccess(
      context,
      'Đã điền theo phiếu gần nhất của «$value» — kiểm tra lại trước khi nộp.',
    );
  }

  /// Giá trị ô mang ẢNH của phiếu đang điền cần giữ khi tự điền: ô ảnh / tệp; ảnh (`photos`) của ô ma trận trưng bày ghép vào
  /// giá trị lấy từ phiếu cũ; bảng lặp có ô con ảnh / tệp đã có dòng thì giữ cả bảng (không thay dòng đang chụp ảnh dở —
  /// bảng đó vì thế không được tự điền).
  Map<String, dynamic> _keepPhotos(
    Map<String, dynamic> current,
    Map<String, dynamic> fill,
  ) {
    bool laAnh(Object? t) =>
        const {'image', 'file'}.contains('$t'.toLowerCase());
    final out = <String, dynamic>{};
    for (final b in widget.args.config.schema.blocks) {
      final c = b.resolved.code;
      final cur = current[c];
      if (cur == null) continue;
      final type = b.resolved.inputType.toLowerCase();
      if (laAnh(type)) {
        out[c] = cur;
      } else if (type == 'display_matrix' &&
          cur is Map &&
          cur['photos'] != null) {
        // Loại tự thêm (`custom`): HỢP của phiếu cũ (đi kèm số đếm lấy từ phiếu cũ) và phiếu đang điền (đi kèm ảnh giữ lại) —
        // thiếu bên nào thì renderer bỏ hàng / ảnh của loại lạ bên đó.
        final custom = DisplayMatrixCustom.fromValue(fill[c])
            .merge(DisplayMatrixCustom.fromValue(cur));
        out[c] = {
          ...?(fill[c] is Map ? fill[c] as Map : null),
          'photos': cur['photos'],
          if (!custom.isEmpty) 'custom': custom.toJson(),
          // Mã SKU nhân viên đã chọn ở phiếu đang điền giữ lại như ảnh (tự điền không đè lựa chọn vừa làm).
          if (cur['skus'] != null) 'skus': cur['skus'],
        };
      } else if (b.resolved.isRepeatGroup && cur is List && cur.isNotEmpty) {
        final coAnh = b.resolved.groupItems.any((i) {
          final r = i is Map && i['resolved'] is Map
              ? i['resolved'] as Map
              : (i is Map ? i : const {});
          return laAnh(r['input_type']);
        });
        if (coAnh) out[c] = cur;
      }
    }
    return out;
  }

  Future<bool?> _confirmOverwrite(String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark
            ? AppColors.darkSurfaceContainer
            : AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Điền theo phiếu cũ?',
          style: AppTypography.titleLarge(
            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Các ô bạn đã nhập sẽ được thay bằng nội dung phiếu gần nhất của «$value» (ảnh đã chụp giữ nguyên).',
          style: AppTypography.bodyMedium(
            color: isDark
                ? AppColors.darkOnSurfaceVariant
                : AppColors.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Chỉ điền tên',
              style: AppTypography.labelLarge(
                color: isDark
                    ? AppColors.darkOnSurfaceVariant
                    : AppColors.onSurfaceVariant,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Điền theo phiếu cũ'),
          ),
        ],
      ),
    );
  }

  void _safePop([bool result = false]) {
    if (!mounted) return;
    setState(() => _isExiting = true);
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(result);
    } else {
      try {
        context.pop(result);
      } catch (_) {}
    }
  }

  bool _hasEnteredData([Map<String, dynamic>? answers]) {
    final ans = answers ?? _rendererKey.currentState?.currentAnswers ?? {};
    if (ans.isEmpty) return false;
    for (final val in ans.values) {
      if (val == null) continue;
      if (val is String && val.trim().isNotEmpty) return true;
      if (val is List && val.isNotEmpty) return true;
      if (val is Map && val.isNotEmpty) return true;
      if (val is num) return true;
      if (val is bool) return true;
    }
    return false;
  }

  Future<void> _handleExit() async {
    if (_isSubmitting || _isExiting) return;

    // Ảnh đang đóng dấu / tải lên chưa vào câu trả lời (cũng chưa vào nháp) — rời lúc này là mất ảnh.
    if (_draftEnabled &&
        (_rendererKey.currentState?.hasUploadingPhotos ?? false)) {
      AppSnackBar.showInvalid(
        context,
        'Ảnh đang được xử lý, vui lòng chờ xong rồi thoát.',
      );
      return;
    }

    if (!_hasEnteredData()) {
      // Biểu mẫu trống (kể cả người dùng xoá trắng nháp) ⇒ không giữ nháp nào.
      if (_draftEnabled) _discardDraft();
      _safePop(false);
      return;
    }
    // Có nháp tự lưu ⇒ rời màn không mất gì, khỏi hỏi (phần còn chờ ghi nốt ở dispose) — trừ khi lần ghi gần nhất hỏng:
    // khi đó hỏi như chưa có nháp.
    if (_draftEnabled && _lastDraftSaveOk) {
      _safePop(false);
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark
            ? AppColors.darkSurfaceContainer
            : AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.error,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Rời khỏi biểu mẫu?',
                style: AppTypography.titleLarge(
                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Text(
          'Dữ liệu bạn đã nhập sẽ không được lưu. Bạn có chắc chắn muốn rời khỏi không?',
          style: AppTypography.bodyMedium(
            color: isDark
                ? AppColors.darkOnSurfaceVariant
                : AppColors.onSurfaceVariant,
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Tiếp tục điền',
              style: AppTypography.labelLarge(
                color: isDark
                    ? AppColors.darkOnSurfaceVariant
                    : AppColors.onSurfaceVariant,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Rời khỏi',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Người dùng đã chấp nhận bỏ phần vừa nhập ⇒ nháp cũ hơn (lần ghi trước) cũng không khôi phục lại.
      if (_draftEnabled) _discardDraft();
      _safePop(false);
    }
  }

  Future<void> _handleSubmit() async {
    // Ảnh đang đóng dấu / tải lên: câu trả lời còn mang ảnh GỐC chưa đóng dấu — nộp lúc này là gửi ảnh sai.
    if (_rendererKey.currentState?.hasUploadingPhotos ?? false) {
      AppSnackBar.showInvalid(
        context,
        'Ảnh đang được xử lý, vui lòng chờ xong rồi nộp.',
      );
      return;
    }
    final answers = _rendererKey.currentState?.validateAndGetAnswers();
    if (answers == null) {
      // Báo ĐÚNG lý do (vd ma trận SOS thiếu ảnh / chưa đủ số thương hiệu), không chỉ câu chung.
      AppSnackBar.showInvalid(
        context,
        _rendererKey.currentState?.firstErrorMessage ??
            'Vui lòng kiểm tra và điền đầy đủ các thông tin bắt buộc.',
      );
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark
            ? AppColors.darkSurfaceContainer
            : AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.send_rounded, color: AppColors.primary, size: 24),
            const SizedBox(width: 10),
            Text(
              'Xác nhận nộp phiếu',
              style: AppTypography.titleLarge(
                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn nộp biểu mẫu này không?\n\nLưu ý: Sau khi nộp thành công, thông tin sẽ được chốt và không thể chỉnh sửa.',
          style: AppTypography.bodyMedium(
            color: isDark
                ? AppColors.darkOnSurfaceVariant
                : AppColors.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Kiểm tra lại',
              style: AppTypography.labelLarge(
                color: isDark
                    ? AppColors.darkOnSurfaceVariant
                    : AppColors.onSurfaceVariant,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Nộp phiếu'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // 1. Lấy vị trí GPS hiện tại
      double? lat;
      double? lng;
      String? address;

      try {
        final position = await ref
            .read(locationServiceProvider)
            .checkAndGetLocation(context);
        if (position != null) {
          lat = position.latitude;
          lng = position.longitude;
        }
      } catch (_) {}

      // 2. Tạo submission DTO
      final localPhotos = _rendererKey.currentState?.getLocalPhotoPaths();
      final submission = MarketFormSubmissionModel(
        configId: widget.args.config.configId,
        visitId: widget.args.kind == 'survey' ? widget.args.visitId : null,
        customerId: widget.args.customerId,
        answers: answers,
        submitLat: lat,
        submitLng: lng,
        submitAddress: address,
        localPhotoPaths: localPhotos,
        tokenFiles: _draftTokenFiles,
        parentUuid: widget.args.kind == 'survey'
            ? widget.args.visitClientUuid
            : null,
        schemaToken: widget.args.config.schemaToken,
        outletFieldCodes: _rendererKey.currentState
            ?.outletFieldCodes()
            .toList(),
      );

      final isOnline = ref.read(connectivityProvider).isOnline;
      final submitUseCase = ref.read(submitMarketFormUseCaseProvider);

      final result = await submitUseCase(submission, isOffline: !isOnline);

      // Kích hoạt đồng bộ nền để tải các ảnh đang chờ lên server
      ref.read(syncServiceProvider).syncQueue();

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        if (result.success && _suggestCodes.isNotEmpty) {
          unawaited(
            ref
                .read(formSuggestStoreProvider)
                .remember(widget.args.config.formId, answers, _suggestCodes),
          );
        }

        if (mounted) {
          if (result.success) {
            if (_draftEnabled) _discardDraft();
            AppSnackBar.showSuccess(context, result.message);
            _safePop(true);
          } else {
            AppSnackBar.showError(context, result.message);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        AppSnackBar.showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOnline = ref.watch(connectivityProvider).isOnline;
    final config = widget.args.config;
    final subtitle =
        (widget.args.dealerName != null &&
            widget.args.dealerName!.trim().isNotEmpty)
        ? widget.args.dealerName!.trim()
        : (widget.args.kind == 'survey'
              ? 'Khảo sát điểm bán'
              : 'Thu thập thị trường');
    final formTag = config.code.trim().isNotEmpty
        ? 'Form #${config.code.trim()}'
        : 'Form #${config.configId}';

    return PopScope(
      canPop: _isExiting,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _isExiting) return;
        _handleExit();
      },
      child: Scaffold(
        backgroundColor: FormTemplateTokens.pageBg(isDark),
        appBar: FormTemplateAppBar(
          title: config.name,
          subtitle: subtitle,
          onBack: _handleExit,
          isOnline: isOnline,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FormHeroCard(
                categoryIcon: widget.args.kind == 'survey'
                    ? Icons.storefront_outlined
                    : Icons.assignment_outlined,
                categoryLabel: widget.args.kind == 'survey'
                    ? 'Khảo sát điểm bán'
                    : 'Thu thập thị trường',
                requiredTag:
                    config.isRequired ? 'Bắt buộc trước khi Check-out' : null,
                codeTag: formTag,
                title: config.name,
                description: config.descriptionText,
                footerText: widget.args.dealerName,
              ),
              const SizedBox(height: 16),

              if (_draftSavedAt != null) ...[
                DraftRestoredBanner(
                  savedAt: _draftSavedAt!,
                  onRestart: _isSubmitting ? null : _restartWithoutDraft,
                ),
                const SizedBox(height: 16),
              ],

              // Form Renderer
              if (!_draftLoaded)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: AppLoading()),
                )
              else
                MarketFormRenderer(
                  key: _rendererKey,
                  blocks: config.schema.blocks,
                  initialAnswers:
                      widget.args.initialAnswers ??
                      _seedAnswers ??
                      _draftAnswers ??
                      const {},
                  onChanged: _draftEnabled ? _onAnswersChanged : null,
                  customerContext: widget.args.customerContext ?? const {},
                  defaultCustomerId: widget.args.customerId,
                  defaultCustomerName: widget.args.dealerName,
                  defaultCustomerCode: widget.args.customerCode,
                  defaultCustomerAddress: widget.args.customerAddress,
                  lockCustomer: widget.args.isCustomerLocked,
                  defaultRouteIds: widget.args.routeIds,
                  customerData: widget.args.customerData,
                  onUploadPhoto: (file) =>
                      ref.read(formsApiServiceProvider).uploadPhoto(file),
                  suggestions: _suggestions,
                  onSuggestionSelected: _fillFromSuggestion,
                ),
              const SizedBox(height: 80),
            ],
          ),
        ),
        bottomNavigationBar: FormBottomDock(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: isDark
                  ? null
                  : const [
                      BoxShadow(
                        color: Color(0x40166534),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: FormTemplateTokens.accentGreen,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: _isSubmitting ? null : _handleSubmit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: AppLoading(size: 24),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send_rounded, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'NỘP BIỂU MẪU',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

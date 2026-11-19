import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/connectivity_provider.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/top_app_bar.dart';
import '../../data/models/market_form_submission_model.dart';
import '../../data/services/form_draft_store.dart';
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
      }
    };
  }
}

class MarketFormFillScreen extends ConsumerStatefulWidget {
  final MarketFormFillArgs args;

  const MarketFormFillScreen({
    super.key,
    required this.args,
  });

  @override
  ConsumerState<MarketFormFillScreen> createState() => _MarketFormFillScreenState();
}

class _MarketFormFillScreenState extends ConsumerState<MarketFormFillScreen> with WidgetsBindingObserver {
  GlobalKey<MarketFormRendererState> _rendererKey = GlobalKey();
  bool _isSubmitting = false;
  bool _isExiting = false;

  /// Nháp ([FormDraftStore]) chỉ cho phiếu khảo sát trong lượt viếng thăm, mở mới (không mang sẵn câu trả lời).
  late final bool _draftEnabled = widget.args.kind == 'survey' &&
      widget.args.initialAnswers == null &&
      ((widget.args.visitClientUuid?.isNotEmpty ?? false) || (widget.args.visitId ?? 0) > 0);
  late bool _draftLoaded = !_draftEnabled;
  Map<String, dynamic>? _draftAnswers;
  DateTime? _draftSavedAt;
  Map<String, dynamic>? _pendingDraft;
  Timer? _draftTimer;
  Map<String, String> _draftPhotoMemo = {};

  /// Tăng khi "Xoá nháp, làm lại" — kết quả của lần ghi bắt đầu TRƯỚC đó không được ghi đè [_lastDraftSaveOk].
  int _draftGen = 0;

  /// Lần ghi nháp gần nhất có thành công không — hỏng thì rời màn phải hỏi như khi chưa có nháp.
  bool _lastDraftSaveOk = true;

  int get _visitId => widget.args.visitId ?? 0;
  String get _visitUuid => widget.args.visitClientUuid ?? '';
  int get _configId => widget.args.config.configId;

  @override
  void initState() {
    super.initState();
    if (!_draftEnabled) return;
    WidgetsBinding.instance.addObserver(this);
    FormDraftStore.load(visitId: _visitId, clientUuid: _visitUuid, configId: _configId).then((d) {
      if (!mounted) return;
      setState(() {
        _draftAnswers = d?.answers;
        _draftSavedAt = d?.savedAt;
        _draftLoaded = true;
      });
    });
  }

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
    // Kho nháp ghi nối tiếp ⇒ các lần ghi xong theo thứ tự gọi, [_lastDraftSaveOk] là kết quả lần mới nhất.
    final gen = _draftGen;
    FormDraftStore.save(
      visitId: _visitId,
      clientUuid: _visitUuid,
      configId: _configId,
      answers: answers,
      photoMemo: _draftPhotoMemo,
    ).then((ok) {
      if (gen == _draftGen) _lastDraftSaveOk = ok;
    });
  }

  void _discardDraft() {
    _draftTimer?.cancel();
    _pendingDraft = null;
    FormDraftStore.remove(visitId: _visitId, clientUuid: _visitUuid, configId: _configId);
  }

  /// "Xoá nháp, làm lại": bỏ nháp rồi dựng lại biểu mẫu trống.
  void _restartWithoutDraft() {
    // Ảnh đang tải lên của biểu mẫu cũ: dựng lại lúc này là lượt tải xong ghi nháp mới mang ảnh cũ.
    if (_rendererKey.currentState?.hasUploadingPhotos ?? false) {
      AppSnackBar.showInvalid(context, 'Ảnh đang được xử lý, vui lòng chờ xong rồi làm lại.');
      return;
    }
    _discardDraft();
    _draftGen++;
    _lastDraftSaveOk = true;
    // Map MỚI: lần ghi cũ còn chạy vẫn ghi vào map của nó, không lẫn vào biểu mẫu mới.
    _draftPhotoMemo = {};
    setState(() {
      _draftAnswers = null;
      _draftSavedAt = null;
      _rendererKey = GlobalKey();
    });
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
    if (_draftEnabled && (_rendererKey.currentState?.hasUploadingPhotos ?? false)) {
      AppSnackBar.showInvalid(context, 'Ảnh đang được xử lý, vui lòng chờ xong rồi thoát.');
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
        backgroundColor: isDark ? AppColors.darkSurfaceContainer : AppColors.surface,
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
            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Tiếp tục điền',
              style: AppTypography.labelLarge(
                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
      AppSnackBar.showInvalid(context, 'Ảnh đang được xử lý, vui lòng chờ xong rồi nộp.');
      return;
    }
    final answers = _rendererKey.currentState?.validateAndGetAnswers();
    if (answers == null) {
      AppSnackBar.showInvalid(context, 'Vui lòng kiểm tra và điền đầy đủ các thông tin bắt buộc.');
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceContainer : AppColors.surface,
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
            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Kiểm tra lại',
              style: AppTypography.labelLarge(
                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        final position = await ref.read(locationServiceProvider).checkAndGetLocation(context);
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
        parentUuid: widget.args.kind == 'survey' ? widget.args.visitClientUuid : null,
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

        if (result.success) {
          // Thành công
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

  Widget _buildDraftBanner(bool isDark) {
    final at = _draftSavedAt!;
    final now = DateTime.now();
    // Lượt vắt qua nửa đêm: nháp của hôm trước ghi kèm ngày.
    final hhmm = DateFormat(at.year == now.year && at.month == now.month && at.day == now.day ? 'HH:mm' : 'HH:mm dd/MM')
        .format(at);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.history_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Đã khôi phục nháp lúc $hhmm',
              style: AppTypography.bodyMedium(
                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
              ).copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          TextButton(
            onPressed: _isSubmitting ? null : _restartWithoutDraft,
            child: const Text('Xoá nháp, làm lại'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOnline = ref.watch(connectivityProvider).isOnline;
    final config = widget.args.config;

    return PopScope(
      canPop: _isExiting,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _isExiting) return;
        _handleExit();
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.surface,
        appBar: VthmTopAppBar(
          title: config.name,
          showBackButton: true,
          showAvatar: false,
          showLogo: false,
          onBackPressed: _handleExit,
          trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isOnline
                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                : AppColors.error.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isOnline ? Icons.wifi : Icons.wifi_off,
                size: 14,
                color: isOnline ? const Color(0xFF10B981) : AppColors.error,
              ),
              const SizedBox(width: 4),
              Text(
                isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isOnline ? const Color(0xFF10B981) : AppColors.error,
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.marginMobile,
          vertical: AppSpacing.stackMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceContainerLowest
                    : AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (widget.args.kind == 'survey'
                                  ? AppColors.primary
                                  : AppColors.secondary)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.args.kind == 'survey' ? 'Khảo sát điểm bán' : 'Thu thập thị trường',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: widget.args.kind == 'survey'
                                ? (isDark ? AppColors.primaryFixedDim : AppColors.primary)
                                : AppColors.secondary,
                          ),
                        ),
                      ),
                      if (config.isRequired) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Bắt buộc trước khi Check-out',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    config.name,
                    style: AppTypography.titleLarge(
                      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (config.descriptionText != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      config.descriptionText!,
                      style: AppTypography.bodyMedium(
                        color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (widget.args.dealerName != null &&
                      widget.args.dealerName!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.storefront_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.args.dealerName!,
                            style: AppTypography.bodyMedium(
                              color: isDark
                                  ? AppColors.darkOnSurfaceVariant
                                  : AppColors.onSurfaceVariant,
                            ).copyWith(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.stackLg),

            if (_draftSavedAt != null) ...[
              _buildDraftBanner(isDark),
              const SizedBox(height: AppSpacing.stackLg),
            ],

            // Form Renderer
            if (!_draftLoaded)
              const Padding(padding: EdgeInsets.symmetric(vertical: 32), child: Center(child: AppLoading()))
            else
              MarketFormRenderer(
                key: _rendererKey,
                blocks: config.schema.blocks,
                initialAnswers: widget.args.initialAnswers ?? _draftAnswers ?? const {},
                onChanged: _draftEnabled ? _onAnswersChanged : null,
                customerContext: widget.args.customerContext ?? const {},
                defaultCustomerId: widget.args.customerId,
                defaultCustomerName: widget.args.dealerName,
                defaultCustomerCode: widget.args.customerCode,
                defaultCustomerAddress: widget.args.customerAddress,
                lockCustomer: widget.args.isCustomerLocked,
                defaultRouteIds: widget.args.routeIds,
                customerData: widget.args.customerData,
                onUploadPhoto: (file) => ref.read(formsApiServiceProvider).uploadPhoto(file),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.marginMobile,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceContainer : AppColors.surface,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
            ),
          ),
        ),
        child: SafeArea(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 1,
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
                          letterSpacing: 0.5,
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

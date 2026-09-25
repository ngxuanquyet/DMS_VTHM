import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/network/connectivity_provider.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../data/models/form_draft_model.dart';
import '../../data/services/form_draft_service.dart';
import '../../domain/entities/market_form_entity.dart';
import '../screens/market_form_fill_screen.dart';
import '../viewmodels/forms_view_model.dart';

class MarketFormDraftsSheet extends ConsumerStatefulWidget {
  const MarketFormDraftsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const MarketFormDraftsSheet(),
    );
  }

  @override
  ConsumerState<MarketFormDraftsSheet> createState() =>
      _MarketFormDraftsSheetState();
}

class _MarketFormDraftsSheetState extends ConsumerState<MarketFormDraftsSheet> {
  bool _isUploading = false;

  Future<void> _handleDeleteDraft(FormDraft draft) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            isDark ? AppColors.darkSurfaceContainer : AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 24),
            SizedBox(width: 8),
            Text('Xóa bản nháp?'),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa bản nháp của biểu mẫu "${draft.configName}" không?',
          style: AppTypography.bodyMedium(
            color: isDark
                ? AppColors.darkOnSurfaceVariant
                : AppColors.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(formDraftServiceProvider).deleteDraft(draft.id);
      ref.invalidate(formDraftsListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa bản nháp thành công.'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleResumeDraft(
    FormDraft draft,
    List<MarketFormConfigEntity> availableForms,
  ) async {
    // Tìm cấu hình biểu mẫu tương ứng
    final config = availableForms.firstWhere(
      (f) => f.configId == draft.configId,
      orElse: () => MarketFormConfigEntity(
        configId: draft.configId,
        formId: 0,
        code: draft.configCode,
        name: draft.configName,
        kind: draft.kind,
        isRequired: false,
        sortOrder: 0,
        schema: const MarketFormSchemaEntity(blocks: []),
      ),
    );

    if (config.schema.blocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không tìm thấy cấu hình biểu mẫu này trên máy. Vui lòng nhấn Đồng bộ biểu mẫu trước.',
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.of(context).pop(); // Đóng bottom sheet

    await context.push<bool>(
      '/forms/fill',
      extra: MarketFormFillArgs(
        config: config,
        kind: draft.kind,
        customerId: draft.customerId,
        visitId: draft.visitId,
        dealerName: draft.dealerName,
        initialAnswers: draft.answers,
        draftId: draft.id,
      ),
    );
  }

  Future<void> _handleUploadQueue() async {
    final isOnline = ref.read(connectivityProvider).isOnline;
    if (!isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.wifi_off_rounded, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('Không có kết nối internet để tải lên.'),
              ),
            ],
          ),
          backgroundColor: Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      await ref.read(syncServiceProvider).syncQueue();
      ref.invalidate(formSubmissionEntriesProvider);
      ref.invalidate(pendingSyncCountProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('Đồng bộ phiếu ngoại tuyến thành công!'),
              ],
            ),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tải lên: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final draftsAsync = ref.watch(formDraftsListProvider);
    final offlineSubmissionsAsync = ref.watch(formSubmissionEntriesProvider);
    final formsState = ref.watch(formsViewModelProvider);
    final availableForms = formsState.marketForms;
    final isOnline = ref.watch(connectivityProvider).isOnline;

    final drafts = draftsAsync.valueOrNull ?? [];
    final offlineSubmissions = offlineSubmissionsAsync.valueOrNull ?? [];
    final pendingOfflineList = offlineSubmissions
        .where((entry) => entry.state == 'pending' || entry.state == 'sending' || entry.state == 'dead')
        .toList();

    final totalCount = drafts.length + pendingOfflineList.length;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainer : AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle Bar
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.drafts_rounded,
                        color: Color(0xFF6366F1),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Bản nháp & Chờ gửi',
                              style: AppTypography.titleMedium(
                                color: isDark
                                    ? AppColors.darkOnSurface
                                    : AppColors.onSurface,
                              ).copyWith(fontWeight: FontWeight.w700),
                            ),
                            if (totalCount > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$totalCount',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Quản lý bản nháp và phiếu đã nộp ngoại tuyến',
                          style: AppTypography.labelSmall(
                            color: isDark
                                ? AppColors.darkOnSurfaceVariant
                                : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: (isDark
                      ? AppColors.darkOutlineVariant
                      : AppColors.outlineVariant)
                  .withValues(alpha: 0.5),
            ),

            // Content List
            Flexible(
              child: totalCount == 0
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 60,
                        horizontal: 32,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkSurfaceContainerLowest
                                  : AppColors.surfaceContainerHigh,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.drafts_outlined,
                              size: 32,
                              color: isDark
                                  ? AppColors.darkOutline
                                  : AppColors.outlineVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Chưa có bản nháp hoặc phiếu nào',
                            style: AppTypography.titleMedium(
                              color: isDark
                                  ? AppColors.darkOnSurface
                                  : AppColors.onSurface,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Khi bạn lưu nháp hoặc nộp phiếu trong chế độ offline, dữ liệu sẽ được lưu tại đây.',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodySmall(
                              color: isDark
                                  ? AppColors.darkOnSurfaceVariant
                                  : AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      children: [
                        // PHẦN 1: Bản nháp cục bộ
                        if (drafts.isNotEmpty) ...[
                          Row(
                            children: [
                              const Icon(
                                Icons.bookmark_added_rounded,
                                size: 16,
                                color: Color(0xFF6366F1),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'BẢN NHÁP ĐANG LƯU (${drafts.length})',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6366F1),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...drafts.map((draft) {
                            final timeStr = DateFormat('HH:mm · dd/MM/yyyy')
                                .format(draft.updatedAt);
                            final answeredCount = draft.answers.length;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              color: isDark
                                  ? AppColors.darkSurfaceContainerLowest
                                  : AppColors.surfaceContainerLowest,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isDark
                                      ? AppColors.darkOutlineVariant
                                      : AppColors.outlineVariant,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            draft.configName,
                                            style: AppTypography.titleMedium(
                                              color: isDark
                                                  ? AppColors.darkOnSurface
                                                  : AppColors.onSurface,
                                            ).copyWith(
                                                fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            size: 18,
                                            color: AppColors.error,
                                          ),
                                          tooltip: 'Xóa bản nháp',
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () =>
                                              _handleDeleteDraft(draft),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Mã: ${draft.configCode} · Đã điền $answeredCount trường',
                                      style: AppTypography.bodySmall(
                                        color: isDark
                                            ? AppColors.darkOnSurfaceVariant
                                            : AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                    if (draft.dealerName != null &&
                                        draft.dealerName!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Điểm bán: ${draft.dealerName}',
                                        style: AppTypography.labelSmall(
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          timeStr,
                                          style: AppTypography.labelSmall(
                                            color: isDark
                                                ? AppColors.darkOutline
                                                : AppColors.outline,
                                          ),
                                        ),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF6366F1),
                                            foregroundColor: Colors.white,
                                            visualDensity:
                                                VisualDensity.compact,
                                            padding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.edit_rounded,
                                            size: 14,
                                          ),
                                          label: const Text(
                                            'Tiếp tục điền',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          onPressed: () => _handleResumeDraft(
                                            draft,
                                            availableForms,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 16),
                        ],

                        // PHẦN 2: Phiếu chờ đồng bộ ngoại tuyến
                        if (pendingOfflineList.isNotEmpty) ...[
                          Row(
                            children: [
                              const Icon(
                                Icons.cloud_upload_rounded,
                                size: 16,
                                color: Color(0xFFEA580C),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'PHIẾU CHỜ TẢI LÊN MÁY CHỦ (${pendingOfflineList.length})',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFEA580C),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...pendingOfflineList.map((entry) {
                            String formName = 'Phiếu biểu mẫu #${entry.id}';
                            try {
                              final payload =
                                  jsonDecode(entry.payload) as Map<String, dynamic>;
                              final cfgId = payload['config_id'] as int?;
                              if (cfgId != null) {
                                final match = availableForms
                                    .where((f) => f.configId == cfgId)
                                    .firstOrNull;
                                if (match != null) {
                                  formName = match.name;
                                }
                              }
                            } catch (_) {}

                            final timeStr = DateFormat('HH:mm · dd/MM/yyyy')
                                .format(DateTime.fromMillisecondsSinceEpoch(
                                    entry.createdAt));

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              color: isDark
                                  ? AppColors.darkSurfaceContainerLowest
                                  : AppColors.surfaceContainerLowest,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: entry.state == 'dead'
                                      ? AppColors.error
                                      : const Color(0xFFEA580C).withValues(alpha: 0.4),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            formName,
                                            style: AppTypography.titleMedium(
                                              color: isDark
                                                  ? AppColors.darkOnSurface
                                                  : AppColors.onSurface,
                                            ).copyWith(
                                                fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: entry.state == 'dead'
                                                ? AppColors.error
                                                    .withValues(alpha: 0.15)
                                                : const Color(0xFFEA580C)
                                                    .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            entry.state == 'dead'
                                                ? 'Lỗi gửi'
                                                : 'Chờ tải lên',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: entry.state == 'dead'
                                                  ? AppColors.error
                                                  : const Color(0xFFEA580C),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Mã định danh: ${entry.clientUuid}',
                                      style: AppTypography.labelSmall(
                                        color: isDark
                                            ? AppColors.darkOnSurfaceVariant
                                            : AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                    if (entry.lastError != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Lỗi: ${entry.lastError}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.error,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Text(
                                      timeStr,
                                      style: AppTypography.labelSmall(
                                        color: isDark
                                            ? AppColors.darkOutline
                                            : AppColors.outline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
            ),

            // Bottom Action (Tải lên tất cả nếu có phiếu offline)
            if (pendingOfflineList.isNotEmpty)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceContainer
                      : AppColors.surface,
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? AppColors.darkOutlineVariant
                          : AppColors.outlineVariant,
                    ),
                  ),
                ),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _isUploading || !isOnline
                      ? null
                      : _handleUploadQueue,
                  icon: _isUploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: AppLoading(size: 18),
                        )
                      : const Icon(Icons.cloud_upload_rounded, size: 18),
                  label: Text(
                    _isUploading
                        ? 'Đang gửi...'
                        : (isOnline
                            ? 'TẢI LÊN TẤT CẢ (${pendingOfflineList.length})'
                            : 'KHÔNG CÓ MẠNG ĐỂ TẢI LÊN'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

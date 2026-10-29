import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/app_fullscreen_image_viewer.dart';
import '../../../forms/data/models/market_form_model.dart';
import '../../domain/entities/visit_history_entity.dart';
import '../../domain/usecases/visit_usecases.dart';
import 'visit_kind_badge.dart';

/// Modal bottom sheet hiển thị chi tiết một lượt viếng thăm lịch sử (§2.4 SPEC 16/10/2026)
/// Hiển thị ảnh (ghép URL tương đối / MobiWork) và các biểu mẫu đã nộp kèm câu hỏi & câu trả lời.
Future<void> showVisitHistoryDetailSheet(
  BuildContext context, {
  required int customerId,
  required int visitId,
  VisitHistoryItemEntity? initialItem,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _VisitHistoryDetailSheet(
      customerId: customerId,
      visitId: visitId,
      initialItem: initialItem,
    ),
  );
}

class _VisitHistoryDetailSheet extends ConsumerStatefulWidget {
  final int customerId;
  final int visitId;
  final VisitHistoryItemEntity? initialItem;

  const _VisitHistoryDetailSheet({
    required this.customerId,
    required this.visitId,
    this.initialItem,
  });

  @override
  ConsumerState<_VisitHistoryDetailSheet> createState() =>
      _VisitHistoryDetailSheetState();
}

class _VisitHistoryDetailSheetState
    extends ConsumerState<_VisitHistoryDetailSheet> {
  bool _isLoading = true;
  String? _errorMessage;
  VisitHistoryDetailEntity? _detail;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final detail = await ref
          .read(getCustomerVisitHistoryDetailUseCaseProvider)
          .call(widget.customerId, widget.visitId);
      if (mounted) {
        setState(() {
          _detail = detail;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('AppException: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initialItem = widget.initialItem;
    final detailItem = _detail?.item;
    final item = detailItem ?? initialItem;

    final effectiveNote = (detailItem?.note != null && detailItem!.note!.trim().isNotEmpty)
        ? detailItem.note
        : initialItem?.note;
    final effectiveClosedNote = (detailItem?.closedNote != null && detailItem!.closedNote!.trim().isNotEmpty)
        ? detailItem.closedNote
        : initialItem?.closedNote;
    final isClosedStore = detailItem?.isClosedStore ?? initialItem?.isClosedStore ?? false;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2420) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chi tiết lượt viếng thăm',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF181C1B),
                        ),
                      ),
                      if (item?.customerName != null &&
                          item!.customerName!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.customerName!,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),

          // Content
          Expanded(
            child: _isLoading && _detail == null
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(color: Color(0xFF006E15)),
                    ),
                  )
                : _errorMessage != null && _detail == null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 40,
                                color: Color(0xFFDC2626),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadDetail,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF006E15),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Thử lại'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        children: [
                          // 1. Tóm tắt nhân viên & thời gian
                          _buildSummaryCard(item, isDark),
                          const SizedBox(height: 14),

                          // 2. Ghi chú chuyến ghé (luôn hiển thị rõ ràng)
                          _buildNotesSection(
                            note: effectiveNote,
                            closedNote: effectiveClosedNote,
                            isClosedStore: isClosedStore,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 16),

                          // 3. Hình ảnh viếng thăm (nếu có)
                          if (_detail != null && _detail!.photoUrls.isNotEmpty) ...[
                            _buildPhotosSection(_detail!, isDark),
                            const SizedBox(height: 16),
                          ],

                          // 4. Các biểu mẫu đã nộp (nếu có)
                          if (_detail != null && _detail!.forms.isNotEmpty) ...[
                            _buildFormsSection(_detail!, isDark),
                            const SizedBox(height: 16),
                          ] else if (_detail != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.assignment_outlined,
                                    size: 18,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Không có biểu mẫu nào được nộp trong lượt này',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(VisitHistoryItemEntity? item, bool isDark) {
    if (item == null) return const SizedBox.shrink();

    final isClosed = item.isClosedStore;
    final statusColor = isClosed ? const Color(0xFFD97706) : const Color(0xFF006E15);
    final statusBg = isClosed
        ? (isDark ? const Color(0x33D97706) : const Color(0xFFFEF3C7))
        : (isDark ? const Color(0x33006E15) : const Color(0xFFE8F5E9));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF28302A) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Nhân viên
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF006E15),
                    child: Text(
                      item.employeeName.isNotEmpty
                          ? item.employeeName.characters.first.toUpperCase()
                          : 'NV',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.employeeName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      if (item.visitDate != null)
                        Text(
                          item.visitDate!,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              // Kết quả viếng thăm badge (+ nhãn "Tạo điểm bán" bên dưới cho lượt new_outlet)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor, width: 0.8),
                    ),
                    child: Text(
                      item.visitResultLabel ?? (isClosed ? 'Đóng cửa' : 'Mở cửa'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                  if (item.isNewOutlet) ...[
                    const SizedBox(height: 4),
                    VisitKindBadge(
                      label: item.visitKindLabel,
                      color: item.visitKindBootstrapColor,
                      fontSize: 10,
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Giờ vào - Giờ ra - Thời lượng
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTimeColumn('Giờ vào', item.checkinAt, isDark),
              Container(width: 1, height: 28, color: isDark ? Colors.white12 : const Color(0xFFE5E7EB)),
              _buildTimeColumn('Giờ ra', item.checkoutAt ?? (item.isOpen ? 'Đang mở' : '—'), isDark),
              Container(width: 1, height: 28, color: isDark ? Colors.white12 : const Color(0xFFE5E7EB)),
              _buildTimeColumn('Thời gian', item.formattedDuration, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection({
    required String? note,
    required String? closedNote,
    required bool isClosedStore,
    required bool isDark,
  }) {
    final hasNote = note != null && note.trim().isNotEmpty;
    final hasClosedNote = closedNote != null && closedNote.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF28302A) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.sticky_note_2_outlined,
                size: 16,
                color: Color(0xFF006E15),
              ),
              const SizedBox(width: 6),
              Text(
                'Ghi chú chuyến ghé',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 1. Lý do đóng cửa (nếu có hoặc nếu là cửa hàng đóng)
          if (hasClosedNote || isClosedStore) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0x28F59E0B) : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: Color(0xFFD97706),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lý do đóng cửa / Không bán được:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasClosedNote ? closedNote : 'Cửa hàng đóng cửa (không có ghi chú chi tiết)',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : const Color(0xFF78350F),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (hasNote) const SizedBox(height: 10),
          ],

          // 2. Ghi chú của nhân viên viếng thăm
          if (hasNote) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.format_quote_rounded,
                      size: 16,
                      color: isDark ? Colors.white70 : const Color(0xFF006E15),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ghi chú của NVBH:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 2),
                        SelectableText(
                          note,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: isDark ? Colors.white : const Color(0xFF1F2937),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 3. Nếu cả 2 đều không có
          if (!hasNote && !hasClosedNote && !isClosedStore) ...[
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 6),
                Text(
                  'Không có ghi chú nào cho lượt viếng thăm này',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeColumn(String label, String? timeValue, bool isDark) {
    String displayTime = '—';
    if (timeValue != null) {
      if (timeValue.contains(' ') && timeValue.length >= 16) {
        // "2026-09-30 08:57:13+07" -> lấy "08:57"
        final parts = timeValue.split(' ');
        if (parts.length >= 2) {
          final timePart = parts[1];
          if (timePart.length >= 5) {
            displayTime = timePart.substring(0, 5);
          }
        }
      } else {
        displayTime = timeValue;
      }
    }

    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white54 : const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          displayTime,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotosSection(VisitHistoryDetailEntity detail, bool isDark) {
    final fullUrls = detail.fullPhotoUrls;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.photo_library_outlined, size: 18, color: Color(0xFF006E15)),
            const SizedBox(width: 6),
            Text(
              'Hình ảnh viếng thăm (${fullUrls.length})',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: fullUrls.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, idx) {
              final url = fullUrls[idx];
              return GestureDetector(
                onTap: () => AppFullScreenImageViewer.openUrls(
                  context,
                  urls: fullUrls,
                  initialIndex: idx,
                  titles: fullUrls
                      .asMap()
                      .entries
                      .map((e) =>
                          'Ảnh viếng thăm #${detail.item.id} (${e.key + 1}/${fullUrls.length})')
                      .toList(),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 100,
                    height: 100,
                    color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.grey,
                      ),
                      cacheWidth: 300,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFormsSection(VisitHistoryDetailEntity detail, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.assignment_turned_in_outlined, size: 18, color: Color(0xFF006E15)),
            const SizedBox(width: 6),
            Text(
              'Biểu mẫu đã nộp (${detail.forms.length})',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...detail.forms.map((form) => _buildFormItemCard(form, isDark)),
      ],
    );
  }

  Widget _buildFormItemCard(VisitHistoryFormEntity form, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF28302A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  form.formName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
              ),
              if (form.kind != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: form.kind == 'survey'
                        ? const Color(0xFFEFF6FF)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    form.kind == 'survey' ? 'Khảo sát' : 'Thu thập',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: form.kind == 'survey'
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF4B5563),
                    ),
                  ),
                ),
            ],
          ),
          if (form.submittedAt != null) ...[
            const SizedBox(height: 3),
            Text(
              'Nộp lúc: ${form.submittedAt}',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : const Color(0xFF6B7280),
              ),
            ),
          ],
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Render các câu hỏi và câu trả lời
          ..._buildAnswersList(form, isDark),
        ],
      ),
    );
  }

  List<Widget> _buildAnswersList(VisitHistoryFormEntity form, bool isDark) {
    if (form.answers.isEmpty) {
      return [
        Text(
          'Không có câu trả lời nào',
          style: TextStyle(
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
      ];
    }

    // Tra tên câu hỏi + nhãn lựa chọn từ schema snapshot — snapshot là `blocks[].resolved` (cùng
    // khuôn biểu mẫu lúc nộp), đọc bằng chính MarketFormSchemaModel của màn điền phiếu.
    final schemaFields = <String, String>{};
    final optionLabels = <String, Map<String, String>>{};
    if (form.formSchemaSnapshot != null) {
      final schema = MarketFormSchemaModel.fromJson(form.formSchemaSnapshot!);
      for (final block in schema.blocks) {
        final r = block.resolved;
        if (r.code.isEmpty) continue;
        if (r.label.isNotEmpty) schemaFields[r.code] = r.label;
        final options = r.config is Map ? r.config['options'] : null;
        if (options is List) {
          optionLabels[r.code] = {
            for (final o in options.whereType<Map>())
              if (o['value'] != null) o['value'].toString(): (o['label'] ?? o['value']).toString(),
          };
        }
      }
    }

    return form.answers.entries.map((entry) {
      final code = entry.key;
      final val = entry.value;
      final questionLabel = schemaFields[code] ?? code;

      // Tra nhãn nếu là kiểu khách hàng hoặc có answerLabels
      final opts = optionLabels[code] ?? const <String, String>{};
      String displayValue = opts[val.toString()] ?? val.toString();
      if (form.answerLabels != null &&
          form.answerLabels!.containsKey(val.toString())) {
        displayValue = form.answerLabels![val.toString()].toString();
      } else if (val is List) {
        displayValue = val.map((v) => opts[v.toString()] ?? v.toString()).join(', ');
      }

      // Kiểm tra xem có phải ảnh (trong answerPhotos) không
      final List<String> photoUrls = [];
      if (form.answerPhotos != null) {
        if (val is String && form.answerPhotos!.containsKey(val)) {
          final p = form.answerPhotos![val].toString();
          photoUrls.add(p.startsWith('http') ? p : '${AppConstants.baseUrl}/$p');
        } else if (val is List) {
          for (final token in val) {
            if (form.answerPhotos!.containsKey(token.toString())) {
              final p = form.answerPhotos![token.toString()].toString();
              photoUrls.add(p.startsWith('http') ? p : '${AppConstants.baseUrl}/$p');
            }
          }
        }
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              questionLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 2),
            if (photoUrls.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: photoUrls.map((pUrl) {
                  final initialIdx = photoUrls.indexOf(pUrl).clamp(0, photoUrls.length - 1);
                  return GestureDetector(
                    onTap: () => AppFullScreenImageViewer.openUrls(
                      context,
                      urls: photoUrls,
                      initialIndex: initialIdx,
                      titles: photoUrls
                          .map((_) => '${form.formName} • $questionLabel')
                          .toList(),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        pUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 24),
                        cacheWidth: 300,
                      ),
                    ),
                  );
                }).toList(),
              )
            else
              Text(
                displayValue,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
          ],
        ),
      );
    }).toList();
  }
}

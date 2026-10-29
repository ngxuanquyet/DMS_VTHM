import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../errors/app_exceptions.dart';
import '../services/erp_partner_options_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_loading.dart';

/// Ô "Khách hàng pháp nhân" (`ref_erp_partner`) — chọn khách ERP Bravo, TÌM TRÊN SERVER.
/// Dùng chung cho phiếu thị trường (MarketFormRenderer) và hồ sơ điểm bán (DynamicFormBuilder).
///
/// 🔴 Giá trị là MÃ khách dạng CHUỖI (thường có số 0 đầu) — không bao giờ parse sang số.
/// Widget luôn làm việc với danh sách mã [selectedCodes]; nơi gọi tự quy về một chuỗi (ô chọn một)
/// hoặc mảng chuỗi (ô chọn nhiều) trước khi lưu.
/// Giá trị ngoại lệ admin khai (mã `"_:<tên>"`, vd "Khách lẻ") chỉ hiện TÊN, có nhãn "Giá trị khác".
class ErpPartnerFieldWidget extends ConsumerStatefulWidget {
  /// Mã ô (`code`) — bắt buộc gửi lên server ở tham số `field`
  final String fieldCode;
  final String label;
  final String? description;
  final bool isRequired;
  final bool isReadOnly;

  /// Ô cho chọn nhiều khách (server cấu hình `multiple`)
  final bool multiple;

  /// Các mã đang chọn (ô chọn một: tối đa 1 phần tử)
  final List<String> selectedCodes;

  final String? errorText;
  final ValueChanged<List<String>> onChanged;

  const ErpPartnerFieldWidget({
    super.key,
    required this.fieldCode,
    required this.label,
    required this.selectedCodes,
    required this.onChanged,
    this.description,
    this.isRequired = false,
    this.isReadOnly = false,
    this.multiple = false,
    this.errorText,
  });

  /// Quy giá trị đang lưu (chuỗi / mảng / null) về danh sách mã CHUỖI
  static List<String> codesFromValue(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value
          .where((e) => e != null)
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    final str = value.toString().trim();
    return str.isEmpty ? const [] : [str];
  }

  /// Quy danh sách mã về giá trị lưu: ô chọn nhiều → mảng chuỗi, ô chọn một → một chuỗi; rỗng → null
  static dynamic valueFromCodes(List<String> codes, {required bool multiple}) {
    if (codes.isEmpty) return null;
    return multiple ? List<String>.from(codes) : codes.first;
  }

  @override
  ConsumerState<ErpPartnerFieldWidget> createState() => _ErpPartnerFieldWidgetState();
}

class _ErpPartnerFieldWidgetState extends ConsumerState<ErpPartnerFieldWidget> {
  /// Thông tin khách đã biết theo mã (từ lần chọn hoặc tra nhãn `ids=`)
  final Map<String, ErpPartnerOption> _known = {};

  /// Mã đã gửi đi tra nhãn — tránh gọi lặp mỗi lần build
  final Set<String> _lookupRequested = {};

  /// Mã khách đã chọn đang sổ thẻ xem đủ kênh/địa chỉ
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _resolveMissingLabels();
  }

  @override
  void didUpdateWidget(covariant ErpPartnerFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _resolveMissingLabels();
  }

  /// Tra nhãn cho các mã đang lưu mà chưa biết tên (mở lại phiếu/hồ sơ). Lỗi mạng thì lặng lẽ hiện mã.
  Future<void> _resolveMissingLabels() async {
    final missing = widget.selectedCodes
        .where((c) => !_known.containsKey(c) && !_lookupRequested.contains(c))
        .toList();
    if (missing.isEmpty || widget.fieldCode.isEmpty) return;
    _lookupRequested.addAll(missing);
    try {
      final items = await ref
          .read(erpPartnerOptionsServiceProvider)
          .lookup(field: widget.fieldCode, codes: missing);
      if (!mounted) return;
      setState(() {
        for (final item in items) {
          _known[item.code] = item;
        }
      });
    } catch (_) {
      // Không có mạng / server lỗi: vẫn hiện mã đang lưu, không chặn người dùng
    }
  }

  /// Tên khách; chưa tra được (offline) thì hiện chính mã (ngoại lệ `"_:<tên>"` hiện phần tên)
  String _nameOf(String code) {
    final known = _known[code];
    return (known != null && known.name.isNotEmpty) ? known.name : ErpPartnerOption.fallbackLabel(code);
  }

  /// Nhãn đầy đủ `"<tên> (<mã>)"` (ngoại lệ chỉ tên); chưa tra được thì hiện nhãn dự phòng
  String _labelOf(String code) => _known[code]?.displayLabel ?? ErpPartnerOption.fallbackLabel(code);

  /// Khách ERP đã biết kênh/địa chỉ thì mới có gì để sổ ra xem
  bool _canExpand(String code) {
    final known = _known[code];
    return known != null && !known.isExtra && (known.address != null || known.channelName != null);
  }

  void _toggleExpanded(String code) {
    setState(() {
      if (!_expanded.remove(code)) _expanded.add(code);
    });
  }

  void _openPicker(BuildContext context) {
    if (widget.isReadOnly) return;
    final initialSelected = widget.selectedCodes
        .map((c) => _known[c] ?? ErpPartnerOption.placeholder(c))
        .toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ErpPartnerPickerSheet(
        title: widget.label.isNotEmpty ? widget.label : 'Chọn khách hàng',
        fieldCode: widget.fieldCode,
        multiple: widget.multiple,
        initialSelected: initialSelected,
        onDone: (items) {
          setState(() {
            for (final item in items) {
              if (item.name.isNotEmpty) _known[item.code] = item;
            }
          });
          widget.onChanged(items.map((e) => e.code).toList());
        },
      ),
    );
  }

  void _removeCode(String code) {
    widget.onChanged(widget.selectedCodes.where((c) => c != code).toList());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasError = widget.errorText != null;
    final isLocked = widget.isReadOnly;
    final codes = widget.selectedCodes;
    final hasValue = codes.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(isDark),
        const SizedBox(height: 6),
        InkWell(
          onTap: isLocked ? null : () => _openPicker(context),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isLocked
                  ? (isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerLow)
                  : (isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasError
                    ? AppColors.error
                    : (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
                width: hasError ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: hasValue
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : (isDark
                            ? AppColors.darkOutlineVariant.withValues(alpha: 0.3)
                            : Colors.grey.withValues(alpha: 0.12)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.business_rounded,
                    size: 20,
                    color: hasValue
                        ? AppColors.primary
                        : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: !hasValue
                      ? Text(
                          'Chạm để tìm khách hàng...',
                          style: AppTypography.bodyMedium(
                            color: isDark
                                ? AppColors.darkOnSurfaceVariant.withValues(alpha: 0.6)
                                : AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                        )
                      : (widget.multiple
                          ? Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: codes
                                  .map((c) => _buildChip(c, isDark, isLocked))
                                  .toList(),
                            )
                          : _buildSingleValue(codes.first, isDark)),
                ),
                if (!isLocked) ...[
                  if (hasValue) ...[
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                      onPressed: () => widget.onChanged(const []),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Icon(
                    Icons.arrow_drop_down,
                    color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Text(
            widget.errorText!,
            style: const TextStyle(color: AppColors.error, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildSingleValue(String code, bool isDark) {
    final known = _known[code];
    final address = known?.address;
    final isExtra = known?.isExtra ?? ErpPartnerOption.isExtraCode(code);
    final canExpand = _canExpand(code);
    final expanded = canExpand && _expanded.contains(code);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _nameOf(code),
          style: AppTypography.titleMedium(
            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            // Ngoại lệ không có mã ERP — thay huy hiệu mã bằng nhãn "Giá trị khác"
            if (isExtra) const _ExtraTag() else _codeBadge(code, isDark),
            const SizedBox(width: 6),
            Expanded(
              child: (address != null && !expanded)
                  ? Text(
                      address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall(
                        color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            if (canExpand)
              _ExpandToggle(
                key: Key('erp-partner-selected-expand-$code'),
                expanded: expanded,
                isDark: isDark,
                onPressed: () => _toggleExpanded(code),
              ),
          ],
        ),
        if (expanded && known != null) ...[
          const SizedBox(height: 4),
          _PartnerDetails(item: known, isDark: isDark),
        ],
      ],
    );
  }

  Widget _buildChip(String code, bool isDark, bool isLocked) {
    final known = _known[code];
    final canExpand = _canExpand(code);
    final expanded = canExpand && _expanded.contains(code);
    return Container(
      padding: EdgeInsets.only(left: 8, right: isLocked && !canExpand ? 8 : 4, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  _labelOf(code),
                  maxLines: expanded ? null : 2,
                  overflow: expanded ? null : TextOverflow.ellipsis,
                  style: AppTypography.bodySmall(
                    color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (canExpand)
                _ExpandToggle(
                  key: Key('erp-partner-selected-expand-$code'),
                  expanded: expanded,
                  isDark: isDark,
                  compact: true,
                  onPressed: () => _toggleExpanded(code),
                ),
              if (!isLocked) ...[
                const SizedBox(width: 2),
                GestureDetector(
                  onTap: () => _removeCode(code),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          if (expanded && known != null) ...[
            const SizedBox(height: 4),
            _PartnerDetails(item: known, isDark: isDark),
          ],
        ],
      ),
    );
  }

  Widget _codeBadge(String code, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        code,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildLabel(bool isDark) {
    final description = widget.description;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: widget.label,
            style: AppTypography.titleMedium(
              color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
            ).copyWith(fontWeight: FontWeight.w600),
            children: [
              if (widget.isRequired)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700),
                ),
            ],
          ),
        ),
        if (description != null && description.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            description,
            style: AppTypography.bodySmall(
              color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// Bottom Sheet tìm khách hàng pháp nhân trên server: gõ có debounce, cuộn cuối danh sách thì tải trang tiếp.
class _ErpPartnerPickerSheet extends ConsumerStatefulWidget {
  final String title;
  final String fieldCode;
  final bool multiple;
  final List<ErpPartnerOption> initialSelected;
  final ValueChanged<List<ErpPartnerOption>> onDone;

  const _ErpPartnerPickerSheet({
    required this.title,
    required this.fieldCode,
    required this.multiple,
    required this.initialSelected,
    required this.onDone,
  });

  @override
  ConsumerState<_ErpPartnerPickerSheet> createState() => _ErpPartnerPickerSheetState();
}

class _ErpPartnerPickerSheetState extends ConsumerState<_ErpPartnerPickerSheet> {
  static const Duration _debounceDuration = Duration(milliseconds: 400);

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  /// Đang chọn (giữ thứ tự chọn) — chỉ dùng ở chế độ chọn nhiều
  final Map<String, ErpPartnerOption> _selected = {};

  /// Mã khách đang sổ thẻ xem đủ thông tin — mỗi thẻ mở/đóng độc lập
  final Set<String> _expanded = {};

  final List<ErpPartnerOption> _items = [];
  int _page = 0;
  bool _hasMore = false;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;

  /// Số thứ tự lượt gọi — bỏ kết quả về muộn của từ khoá cũ
  int _requestSeq = 0;

  @override
  void initState() {
    super.initState();
    for (final item in widget.initialSelected) {
      _selected[item.code] = item;
    }
    _scrollController.addListener(_onScroll);
    // Mở sheet là tải ngay trang 1 (chưa có từ khoá); initState chưa được setState nên gán thẳng cờ tải
    _isLoading = true;
    _load(reset: true, fromInitState: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _onQueryChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () => _load(reset: true));
    setState(() {}); // cập nhật nút xoá từ khoá
  }

  String _errorMessage(Object e) {
    if (e is AppException && e.message.trim().isNotEmpty) return e.message;
    return 'Không tải được danh sách khách hàng. Vui lòng thử lại.';
  }

  Future<void> _load({required bool reset, bool fromInitState = false}) async {
    final seq = ++_requestSeq;
    final nextPage = reset ? 1 : _page + 1;
    if (!fromInitState) {
      setState(() {
        _error = null;
        if (reset) {
          _isLoading = true;
          _isLoadingMore = false;
        } else {
          _isLoadingMore = true;
        }
      });
    }
    try {
      final result = await ref.read(erpPartnerOptionsServiceProvider).search(
            field: widget.fieldCode,
            query: _searchController.text,
            page: nextPage,
          );
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        if (reset) _items.clear();
        final existing = _items.map((e) => e.code).toSet();
        _items.addAll(result.items.where((e) => !existing.contains(e.code)));
        _page = nextPage;
        _hasMore = result.hasMore;
        _isLoading = false;
        _isLoadingMore = false;
      });
      if (reset && _scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    } catch (e) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        if (reset) _items.clear();
        _error = _errorMessage(e);
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _loadMore() {
    if (_isLoading || _isLoadingMore || !_hasMore || _error != null) return;
    _load(reset: false);
  }

  void _onTapItem(ErpPartnerOption item) {
    if (widget.multiple) {
      setState(() {
        if (_selected.containsKey(item.code)) {
          _selected.remove(item.code);
        } else {
          // Loại trừ (server cũng chặn trộn — 400): chọn ngoại lệ thì bỏ mọi lựa chọn khác;
          // đang có ngoại lệ mà chọn khách ERP thì bỏ ngoại lệ
          if (item.isExtra) {
            _selected.clear();
          } else {
            _selected.removeWhere((_, v) => v.isExtra);
          }
          _selected[item.code] = item;
        }
      });
      return;
    }
    widget.onDone([item]);
    Navigator.of(context).pop();
  }

  void _confirmMultiple() {
    widget.onDone(_selected.values.toList());
    Navigator.of(context).pop();
  }

  bool _isSelected(ErpPartnerOption item) {
    if (widget.multiple) return _selected.containsKey(item.code);
    return widget.initialSelected.any((e) => e.code == item.code);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainer : AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          // Đẩy sheet lên khi bàn phím mở để ô tìm kiếm không bị che
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkOutline : AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header: Title & Close
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: AppTypography.titleLarge(
                          color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onQueryChanged,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) {
                    _debounce?.cancel();
                    _load(reset: true);
                  },
                  decoration: InputDecoration(
                    hintText: 'Tìm theo tên, mã, tên viết tắt hoặc địa chỉ...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.darkOnSurfaceVariant.withValues(alpha: 0.7)
                          : AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _debounce?.cancel();
                              _load(reset: true);
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark
                        ? AppColors.darkSurfaceContainerLowest
                        : AppColors.surfaceContainerLowest,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // Content List
              Flexible(child: _buildContent(isDark)),

              // Chế độ chọn nhiều: nút xác nhận
              if (widget.multiple)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _confirmMultiple,
                      child: Text(
                        _selected.isEmpty ? 'Xong' : 'Xong (đã chọn ${_selected.length})',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: AppLoading(size: 48)),
      );
    }

    if (_error != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 44,
                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium(
                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ô này cần kết nối mạng để tìm khách hàng.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall(
                  color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _load(reset: true),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      final q = _searchController.text.trim();
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            q.isEmpty
                ? 'Chưa có khách hàng nào cho ô này.'
                : 'Không tìm thấy khách hàng phù hợp với "$q"',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium(
              color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final showFooter = _hasMore || _isLoadingMore || _error != null;
    return ListView.separated(
      controller: _scrollController,
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _items.length + (showFooter ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, index) {
        if (index >= _items.length) return _buildFooter(isDark);
        return _buildItem(_items[index], isDark);
      },
    );
  }

  Widget _buildFooter(bool isDark) {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
            TextButton.icon(
              onPressed: () => _load(reset: false),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }
    if (_isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: AppLoading(size: 32)),
      );
    }
    // Còn trang sau: nút tải thêm (phòng khi danh sách ngắn chưa đủ cuộn để tự tải)
    return Center(
      child: TextButton(
        onPressed: _loadMore,
        child: const Text('Tải thêm'),
      ),
    );
  }

  void _toggleExpanded(String code) {
    setState(() {
      if (!_expanded.remove(code)) _expanded.add(code);
    });
  }

  Widget _buildItem(ErpPartnerOption item, bool isDark) {
    final isSelected = _isSelected(item);
    final expanded = !item.isExtra && _expanded.contains(item.code);
    final subtitleParts = [
      if (item.channelName != null) item.channelName!,
      if (item.address != null) item.address!,
    ];

    return InkWell(
      onTap: () => _onTapItem(item),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : (isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : (isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainer),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                // Giá trị ngoại lệ dùng icon nhãn để nhận ra không phải khách ERP
                item.isExtra ? Icons.label_outline_rounded : Icons.business_rounded,
                size: 20,
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name.isNotEmpty ? item.name : ErpPartnerOption.fallbackLabel(item.code),
                    style: AppTypography.titleMedium(
                      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                    ).copyWith(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (item.isExtra)
                    const _ExtraTag()
                  else
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.code,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (subtitleParts.isNotEmpty && !expanded) ...[
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              subtitleParts.join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodySmall(
                                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  if (expanded) ...[
                    const SizedBox(height: 6),
                    _PartnerDetails(
                      key: Key('erp-partner-details-${item.code}'),
                      item: item,
                      isDark: isDark,
                    ),
                  ],
                ],
              ),
            ),
            // Nút sổ thẻ: vùng chạm riêng (InkWell/IconButton trong cùng thắng) — bấm KHÔNG chọn khách. Chỉ hiện khi có kênh
            // hoặc địa chỉ để xem (cùng luật `_canExpand` của ô đã chọn) — sổ ra hai dòng "—" là nút vô nghĩa.
            if (!item.isExtra && subtitleParts.isNotEmpty) ...[
              const SizedBox(width: 4),
              _ExpandToggle(
                key: Key('erp-partner-expand-${item.code}'),
                expanded: expanded,
                isDark: isDark,
                onPressed: () => _toggleExpanded(item.code),
              ),
            ],
            if (widget.multiple) ...[
              const SizedBox(width: 8),
              Icon(
                isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
                size: 22,
              ),
            ] else if (isSelected) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22),
            ],
          ],
        ),
      ),
    );
  }
}

/// Nút mũi tên sổ/thu thẻ khách (xoay lên khi đang mở). Là vùng chạm RIÊNG: bấm không chọn khách
/// trong danh sách, không mở ô chọn ở ô đã chọn.
class _ExpandToggle extends StatelessWidget {
  final bool expanded;
  final bool isDark;
  final VoidCallback onPressed;

  /// Bản nhỏ cho chip ô chọn nhiều
  final bool compact;

  const _ExpandToggle({
    super.key,
    required this.expanded,
    required this.isDark,
    required this.onPressed,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = compact ? 24.0 : 32.0;
    return IconButton(
      tooltip: expanded ? 'Thu gọn' : 'Xem đầy đủ thông tin',
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: BoxConstraints.tightFor(width: size, height: size),
      iconSize: compact ? 18 : 22,
      color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
      icon: AnimatedRotation(
        turns: expanded ? 0.5 : 0,
        duration: const Duration(milliseconds: 200),
        child: const Icon(Icons.keyboard_arrow_down),
      ),
    );
  }
}

/// Phần sổ ra của thẻ khách ERP: kênh + địa chỉ đầy đủ, xuống nhiều dòng (không cắt `…`)
class _PartnerDetails extends StatelessWidget {
  final ErpPartnerOption item;
  final bool isDark;

  const _PartnerDetails({super.key, required this.item, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _line(Icons.hub_outlined, 'Kênh', item.channelName),
        const SizedBox(height: 2),
        _line(Icons.location_on_outlined, 'Địa chỉ', item.address),
      ],
    );
  }

  Widget _line(IconData icon, String label, String? value) {
    final color = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
              children: [
                TextSpan(
                  text: value ?? '—',
                  style: const TextStyle(fontWeight: FontWeight.w400),
                ),
              ],
            ),
            style: AppTypography.bodySmall(color: color),
          ),
        ),
      ],
    );
  }
}

/// Nhãn nhỏ "Giá trị khác" — đánh dấu giá trị ngoại lệ (không phải khách ERP, không có mã)
class _ExtraTag extends StatelessWidget {
  const _ExtraTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'Giá trị khác',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

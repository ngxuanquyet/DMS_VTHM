import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/widgets/app_loading.dart';
import '../../../data/models/route_customer_model.dart';
import '../../../data/services/route_customers_service.dart';
import '../../../domain/entities/market_form_entity.dart';

class RefCustomerFieldWidget extends ConsumerStatefulWidget {
  final MarketFormBlockEntity block;
  final int? selectedId;
  final String? errorText;
  final ValueChanged<int?> onChanged;
  final String? defaultCustomerName;

  const RefCustomerFieldWidget({
    super.key,
    required this.block,
    required this.selectedId,
    required this.onChanged,
    this.errorText,
    this.defaultCustomerName,
  });

  @override
  ConsumerState<RefCustomerFieldWidget> createState() =>
      _RefCustomerFieldWidgetState();
}

class _RefCustomerFieldWidgetState
    extends ConsumerState<RefCustomerFieldWidget> {
  void _openPicker(
    BuildContext context,
    RouteCustomersData data,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RouteCustomerPickerSheet(
        title: widget.block.resolved.label.isNotEmpty
            ? widget.block.resolved.label
            : 'Chọn điểm bán',
        data: data,
        selectedId: widget.selectedId,
        onSelected: (item) {
          widget.onChanged(item?.id);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final block = widget.block;
    final label = block.resolved.label.isNotEmpty
        ? block.resolved.label
        : block.resolved.code;
    final description = block.resolved.description;

    final customersAsync = ref.watch(routeCustomersListProvider);

    return customersAsync.when(
      data: (data) => _buildField(context, data, isDark, label, description),
      loading: () => _buildLoadingField(isDark, label, description),
      error: (_, __) => _buildField(
        context,
        const RouteCustomersData(items: []),
        isDark,
        label,
        description,
      ),
    );
  }

  Widget _buildLoadingField(bool isDark, String label, String? description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label, description, isDark),
        const SizedBox(height: 6),
        Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurfaceContainerLowest
                : AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark
                  ? AppColors.darkOutlineVariant
                  : AppColors.outlineVariant,
            ),
          ),
          child: const Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: AppLoading(size: 18),
              ),
              SizedBox(width: 10),
              Text(
                'Đang tải danh sách điểm bán...',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildField(
    BuildContext context,
    RouteCustomersData data,
    bool isDark,
    String label,
    String? description,
  ) {
    RouteCustomerItem? selectedItem;
    if (widget.selectedId != null) {
      try {
        selectedItem = data.items.firstWhere((e) => e.id == widget.selectedId);
      } catch (_) {
        selectedItem = null;
      }
    }

    final hasError = widget.errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label, description, isDark),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _openPicker(context, data, isDark),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurfaceContainerLowest
                  : AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasError
                    ? AppColors.error
                    : (isDark
                        ? AppColors.darkOutlineVariant
                        : AppColors.outlineVariant),
                width: hasError ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: (selectedItem != null || widget.selectedId != null)
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : (isDark
                            ? AppColors.darkOutlineVariant.withValues(alpha: 0.3)
                            : Colors.grey.withValues(alpha: 0.12)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.storefront_rounded,
                    size: 20,
                    color: (selectedItem != null || widget.selectedId != null)
                        ? AppColors.primary
                        : (isDark
                            ? AppColors.darkOnSurfaceVariant
                            : AppColors.onSurfaceVariant),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: (selectedItem != null)
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedItem.name,
                              style: AppTypography.titleMedium(
                                color: isDark
                                    ? AppColors.darkOnSurface
                                    : AppColors.onSurface,
                              ).copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppColors.darkSurfaceContainer
                                        : AppColors.surfaceContainer,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    selectedItem.code,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? AppColors.darkOnSurfaceVariant
                                          : AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                if (selectedItem.address != null &&
                                    selectedItem.address!.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      selectedItem.address!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.bodySmall(
                                        color: isDark
                                            ? AppColors.darkOnSurfaceVariant
                                            : AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        )
                      : (widget.selectedId != null &&
                              widget.defaultCustomerName != null)
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.defaultCustomerName!,
                                  style: AppTypography.titleMedium(
                                    color: isDark
                                        ? AppColors.darkOnSurface
                                        : AppColors.onSurface,
                                  ).copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Mã ID: ${widget.selectedId}',
                                  style: AppTypography.bodySmall(
                                    color: isDark
                                        ? AppColors.darkOnSurfaceVariant
                                        : AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              'Chạm để chọn điểm bán / khách hàng...',
                              style: AppTypography.bodyMedium(
                                color: isDark
                                    ? AppColors.darkOnSurfaceVariant
                                        .withValues(alpha: 0.6)
                                    : AppColors.onSurfaceVariant
                                        .withValues(alpha: 0.6),
                              ),
                            ),
                ),
                if (selectedItem != null || widget.selectedId != null) ...[
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    color: isDark
                        ? AppColors.darkOnSurfaceVariant
                        : AppColors.onSurfaceVariant,
                    onPressed: () => widget.onChanged(null),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(
                  Icons.arrow_drop_down,
                  color: isDark
                      ? AppColors.darkOnSurfaceVariant
                      : AppColors.onSurfaceVariant,
                ),
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

  Widget _buildLabel(String label, String? description, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: label,
                  style: AppTypography.titleMedium(
                    color:
                        isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                  ).copyWith(fontWeight: FontWeight.w600),
                  children: [
                    if (widget.block.required)
                      const TextSpan(
                        text: ' *',
                        style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (description != null && description.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            description,
            style: AppTypography.bodySmall(
              color: isDark
                  ? AppColors.darkOnSurfaceVariant
                  : AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// Bottom Sheet tìm kiếm và chọn Điểm bán thuộc tuyến
class _RouteCustomerPickerSheet extends StatefulWidget {
  final String title;
  final RouteCustomersData data;
  final int? selectedId;
  final ValueChanged<RouteCustomerItem?> onSelected;

  const _RouteCustomerPickerSheet({
    required this.title,
    required this.data,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  State<_RouteCustomerPickerSheet> createState() =>
      _RouteCustomerPickerSheetState();
}

class _RouteCustomerPickerSheetState extends State<_RouteCustomerPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<RouteCustomerItem> get _filteredItems {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.data.items;
    }
    return widget.data.items.where((item) {
      final nameMatches = item.name.toLowerCase().contains(query);
      final codeMatches = item.code.toLowerCase().contains(query);
      final addressMatches =
          item.address != null && item.address!.toLowerCase().contains(query);
      return nameMatches || codeMatches || addressMatches;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredItems;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainer : AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
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
                        color: isDark
                            ? AppColors.darkOnSurface
                            : AppColors.onSurface,
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
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Tìm theo tên hoặc mã điểm bán...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkOnSurfaceVariant.withValues(alpha: 0.7)
                        : AppColors.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark
                      ? AppColors.darkSurfaceContainerLowest
                      : AppColors.surfaceContainerLowest,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark
                          ? AppColors.darkOutlineVariant
                          : AppColors.outlineVariant,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark
                          ? AppColors.darkOutlineVariant
                          : AppColors.outlineVariant,
                    ),
                  ),
                ),
              ),
            ),

            // Cảnh báo truncated nếu danh sách chạm trần 2.000 dòng (§1b)
            if (widget.data.truncated) ...[
              Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Color(0xFFD97706), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Danh sách điểm bán đã đạt giới hạn 2.000 và được rút gọn. Vui lòng nhập từ khóa để tìm chính xác.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFD97706),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 6),

            // Content List
            Expanded(
              child: widget.data.items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.route_outlined,
                              size: 48,
                              color: isDark
                                  ? AppColors.darkOnSurfaceVariant
                                  : AppColors.onSurfaceVariant,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Bạn chưa được giao tuyến nào.',
                              style: AppTypography.titleMedium(
                                color: isDark
                                    ? AppColors.darkOnSurface
                                    : AppColors.onSurface,
                              ).copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Vui lòng liên hệ quản trị viên để được gán tuyến bán hàng.',
                              textAlign: TextAlign.center,
                              style: AppTypography.bodySmall(
                                color: isDark
                                    ? AppColors.darkOnSurfaceVariant
                                    : AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Không tìm thấy điểm bán phù hợp với "$_searchQuery"',
                              style: AppTypography.bodyMedium(
                                color: isDark
                                    ? AppColors.darkOnSurfaceVariant
                                    : AppColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (ctx, index) {
                            final item = filtered[index];
                            final isSelected = item.id == widget.selectedId;

                            return InkWell(
                              onTap: () {
                                widget.onSelected(item);
                                Navigator.of(context).pop();
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary
                                          .withValues(alpha: 0.08)
                                      : (isDark
                                          ? AppColors
                                              .darkSurfaceContainerLowest
                                          : AppColors
                                              .surfaceContainerLowest),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : (isDark
                                            ? AppColors.darkOutlineVariant
                                            : AppColors.outlineVariant),
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.primary
                                                .withValues(alpha: 0.15)
                                            : (isDark
                                                ? AppColors
                                                    .darkSurfaceContainer
                                                : AppColors
                                                    .surfaceContainer),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.storefront_rounded,
                                        size: 20,
                                        color: isSelected
                                            ? AppColors.primary
                                            : (isDark
                                                ? AppColors
                                                    .darkOnSurfaceVariant
                                                : AppColors
                                                    .onSurfaceVariant),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: AppTypography.titleMedium(
                                              color: isDark
                                                  ? AppColors.darkOnSurface
                                                  : AppColors.onSurface,
                                            ).copyWith(
                                              fontWeight: isSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 1.5),
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? AppColors
                                                          .darkSurfaceContainer
                                                      : AppColors
                                                          .surfaceContainer,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          4),
                                                ),
                                                child: Text(
                                                  item.code,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    color: isDark
                                                        ? AppColors
                                                            .darkOnSurfaceVariant
                                                        : AppColors
                                                            .onSurfaceVariant,
                                                  ),
                                                ),
                                              ),
                                              if (item.address != null &&
                                                  item.address!.isNotEmpty) ...[
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    item.address!,
                                                    maxLines: 1,
                                                    overflow: TextOverflow
                                                        .ellipsis,
                                                    style: AppTypography
                                                        .bodySmall(
                                                      color: isDark
                                                          ? AppColors
                                                              .darkOnSurfaceVariant
                                                          : AppColors
                                                              .onSurfaceVariant,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected) ...[
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: AppColors.primary,
                                        size: 22,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

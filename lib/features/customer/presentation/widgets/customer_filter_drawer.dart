import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../viewmodels/customer_view_model.dart';

class CustomerFilterDrawer extends StatefulWidget {
  final CustomerState state;
  final CustomerViewModel vm;

  const CustomerFilterDrawer({
    super.key,
    required this.state,
    required this.vm,
  });

  @override
  State<CustomerFilterDrawer> createState() => _CustomerFilterDrawerState();
}

class _CustomerFilterDrawerState extends State<CustomerFilterDrawer> {
  late CustomerFilterTab _selectedTab;
  late String? _selectedRoute;
  late String? _selectedType;
  late String? _selectedChannel;
  late bool _isSortedByDistance;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.state.selectedTab;
    _selectedRoute = widget.state.selectedRoute;
    _selectedType = widget.state.selectedCustomerType;
    _selectedChannel = widget.state.selectedChannel;
    _isSortedByDistance = widget.state.isSortedByDistance;
  }

  int get _currentActiveCount {
    int count = 0;
    if (_selectedTab != CustomerFilterTab.all) count++;
    if (_selectedRoute != null && _selectedRoute != 'Tất cả tuyến') count++;
    if (_selectedType != null && _selectedType != 'Tất cả loại') count++;
    if (_selectedChannel != null && _selectedChannel != 'Tất cả kênh') count++;
    if (_isSortedByDistance) count++;
    return count;
  }

  void _handleReset() {
    setState(() {
      _selectedTab = CustomerFilterTab.all;
      _selectedRoute = null;
      _selectedType = null;
      _selectedChannel = null;
      _isSortedByDistance = false;
    });
    widget.vm.resetFilters();
    if (widget.state.isSortedByDistance) {
      widget.vm.toggleSortByDistance(false);
    }
    Navigator.of(context).pop();
  }

  void _handleApply() {
    widget.vm.selectTab(_selectedTab);
    widget.vm.selectRoute(_selectedRoute);
    widget.vm.selectCustomerType(_selectedType);
    widget.vm.selectChannel(_selectedChannel);
    if (widget.state.isSortedByDistance != _isSortedByDistance) {
      widget.vm.toggleSortByDistance(_isSortedByDistance);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = (screenWidth * 0.85).clamp(300.0, 380.0);

    return Drawer(
      width: drawerWidth,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      surfaceTintColor: Colors.transparent,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bộ lọc khách hàng',
                          style: AppTypography.titleMedium(
                            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (_currentActiveCount > 0)
                          Text(
                            'Đang áp dụng $_currentActiveCount tiêu chí',
                            style: AppTypography.bodySmall(
                              color: AppColors.primary,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Drawer Body (Scrollable filter sections)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                children: [
                  // Section 1: Trạng thái ghé thăm & Đồng bộ
                  _buildSectionTitle(
                    title: 'Trạng thái điểm bán',
                    icon: Icons.checklist_rounded,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildTabChip(
                        label: 'Tất cả (${widget.state.totalCount})',
                        tab: CustomerFilterTab.all,
                        isDark: isDark,
                      ),
                      _buildTabChip(
                        label: 'Chờ đồng bộ (${widget.state.pendingSyncCount})',
                        tab: CustomerFilterTab.pendingSync,
                        activeColor: const Color(0xFFD97706),
                        icon: Icons.cloud_upload_outlined,
                        isDark: isDark,
                      ),
                      _buildTabChip(
                        label: 'Hôm nay (${widget.state.todayCount})',
                        tab: CustomerFilterTab.today,
                        isDark: isDark,
                      ),
                      _buildTabChip(
                        label: 'Đã ghé (${widget.state.visitedCount})',
                        tab: CustomerFilterTab.visited,
                        activeColor: const Color(0xFF10B981),
                        icon: Icons.check_circle_outline_rounded,
                        isDark: isDark,
                      ),
                      _buildTabChip(
                        label: 'Chưa ghé (${widget.state.pendingCount})',
                        tab: CustomerFilterTab.pending,
                        isDark: isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // Section 2: Tuyến khách hàng
                  _buildSectionTitle(
                    title: 'Tuyến khách hàng',
                    icon: Icons.alt_route_rounded,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _buildDropdown(
                    value: _selectedRoute,
                    items: widget.state.availableRoutes,
                    hint: 'Tất cả tuyến',
                    isDark: isDark,
                    onChanged: (val) {
                      setState(() {
                        _selectedRoute = (val == 'Tất cả tuyến') ? null : val;
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  // Section 3: Loại khách hàng
                  _buildSectionTitle(
                    title: 'Loại khách hàng',
                    icon: Icons.category_outlined,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _buildDropdown(
                    value: _selectedType,
                    items: widget.state.availableCustomerTypes,
                    hint: 'Tất cả loại',
                    isDark: isDark,
                    onChanged: (val) {
                      setState(() {
                        _selectedType = (val == 'Tất cả loại') ? null : val;
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  // Section 4: Kênh phân phối
                  _buildSectionTitle(
                    title: 'Kênh phân phối',
                    icon: Icons.storefront_outlined,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _buildDropdown(
                    value: _selectedChannel,
                    items: widget.state.availableChannels,
                    hint: 'Tất cả kênh',
                    isDark: isDark,
                    onChanged: (val) {
                      setState(() {
                        _selectedChannel = (val == 'Tất cả kênh') ? null : val;
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  // Section 5: Sắp xếp theo vị trí GPS
                  _buildSectionTitle(
                    title: 'Sắp xếp khoảng cách',
                    icon: Icons.near_me_rounded,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceContainer : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: SwitchListTile(
                        value: _isSortedByDistance,
                        activeThumbColor: AppColors.primary,
                        title: Text(
                          'Theo vị trí gần nhất',
                          style: AppTypography.bodyMedium(
                            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Ưu tiên điểm bán gần tọa độ hiện tại',
                          style: AppTypography.bodySmall(
                            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                          ),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _isSortedByDistance = val;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Drawer Footer (Reset & Apply buttons)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceContainer : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    offset: const Offset(0, -2),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _handleReset,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                          color: isDark ? AppColors.darkOutline : AppColors.outlineVariant,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Đặt lại',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _handleApply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Áp dụng',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
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

  Widget _buildSectionTitle({
    required String title,
    required IconData icon,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: AppTypography.bodyMedium(
            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _buildTabChip({
    required String label,
    required CustomerFilterTab tab,
    Color? activeColor,
    IconData? icon,
    required bool isDark,
  }) {
    final isSelected = _selectedTab == tab;
    final color = activeColor ?? AppColors.primary;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedTab = tab;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: isDark ? 0.25 : 0.12)
              : (isDark ? AppColors.darkSurfaceContainer : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? color
                : (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: isSelected
                    ? color
                    : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : color)
                    : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String hint,
    required bool isDark,
    required ValueChanged<String?> onChanged,
  }) {
    final currentValue = (value != null && items.contains(value))
        ? value
        : (items.contains(hint) ? hint : (items.isNotEmpty ? items.first : null));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainer : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (value != null && value != hint)
              ? AppColors.primary
              : (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
          width: (value != null && value != hint) ? 1.5 : 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentValue,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: (value != null && value != hint)
                ? AppColors.primary
                : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline),
          ),
          dropdownColor: isDark ? AppColors.darkSurfaceContainer : Colors.white,
          borderRadius: BorderRadius.circular(12),
          style: AppTypography.bodyMedium(
            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
          ).copyWith(
            fontWeight: (value != null && value != hint) ? FontWeight.w600 : FontWeight.w400,
          ),
          items: items.map((item) {
            final isItemActive = (value == item) || (value == null && item == hint);
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                style: TextStyle(
                  color: isItemActive
                      ? AppColors.primary
                      : (isDark ? AppColors.darkOnSurface : AppColors.onSurface),
                  fontWeight: isItemActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

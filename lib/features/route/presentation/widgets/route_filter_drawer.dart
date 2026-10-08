import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../states/route_state.dart';
import '../viewmodels/route_view_model.dart';

class RouteFilterDrawer extends StatefulWidget {
  final RouteState state;
  final RouteViewModel vm;

  const RouteFilterDrawer({
    super.key,
    required this.state,
    required this.vm,
  });

  @override
  State<RouteFilterDrawer> createState() => _RouteFilterDrawerState();
}

class _RouteFilterDrawerState extends State<RouteFilterDrawer> {
  late String _selectedRoute;
  late String? _selectedVisitStatus;
  late String? _selectedCustomerStatus;
  late String? _selectedCustomerType;

  @override
  void initState() {
    super.initState();
    _selectedRoute = widget.state.selectedRoute;
    _selectedVisitStatus = widget.state.selectedVisitStatus;
    _selectedCustomerStatus = widget.state.selectedCustomerStatus;
    _selectedCustomerType = widget.state.selectedCustomerType;
  }

  int get _currentActiveCount {
    int count = 0;
    if (_selectedRoute != 'Tất cả tuyến' && _selectedRoute.isNotEmpty) {
      count++;
    }
    if (_selectedVisitStatus != null &&
        _selectedVisitStatus != 'all' &&
        _selectedVisitStatus != 'Tất cả') {
      count++;
    }
    if (_selectedCustomerStatus != null &&
        _selectedCustomerStatus != 'all' &&
        _selectedCustomerStatus != 'Tất cả') {
      count++;
    }
    if (_selectedCustomerType != null &&
        _selectedCustomerType != 'all' &&
        _selectedCustomerType != 'Tất cả' &&
        _selectedCustomerType != 'Tất cả loại') {
      count++;
    }
    return count;
  }

  void _handleReset() {
    setState(() {
      _selectedRoute = 'Tất cả tuyến';
      _selectedVisitStatus = null;
      _selectedCustomerStatus = null;
      _selectedCustomerType = null;
    });
    widget.vm.resetFilters();
    Navigator.of(context).pop();
  }

  void _handleApply() {
    widget.vm.applyFilters(
      route: _selectedRoute,
      visitStatus: _selectedVisitStatus,
      customerStatus: _selectedCustomerStatus,
      customerType: _selectedCustomerType,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = (screenWidth * 0.85).clamp(300.0, 380.0);

    final routeList = <String>[
      'Tất cả tuyến',
      ...widget.state.availableRoutes.where((r) => r != 'Tất cả tuyến'),
    ];

    final typeList = <String>[
      'Tất cả loại',
      ...widget.state.availableCustomerTypes.where((t) => t != 'Tất cả loại'),
    ];

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
                    color: isDark
                        ? AppColors.darkOutlineVariant
                        : AppColors.outlineVariant,
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
                          'Bộ lọc lộ trình',
                          style: AppTypography.titleMedium(
                            color: isDark
                                ? AppColors.darkOnSurface
                                : AppColors.onSurface,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (_currentActiveCount > 0)
                          Text(
                            'Đang chọn $_currentActiveCount tiêu chí',
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

            // Drawer Body
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                children: [
                  // Section 1: Trạng thái viếng thăm
                  _buildSectionTitle(
                    title: 'Trạng thái viếng thăm',
                    icon: Icons.checklist_rounded,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildVisitStatusChip(
                        label: 'Tất cả',
                        value: 'all',
                        isDark: isDark,
                      ),
                      _buildVisitStatusChip(
                        label: 'Đã ghé',
                        value: 'completed',
                        activeColor: const Color(0xFF10B981),
                        icon: Icons.check_circle_outline_rounded,
                        isDark: isDark,
                      ),
                      _buildVisitStatusChip(
                        label: 'Đang ghé',
                        value: 'inProgress',
                        activeColor: const Color(0xFF0284C7),
                        icon: Icons.access_time_rounded,
                        isDark: isDark,
                      ),
                      _buildVisitStatusChip(
                        label: 'Chưa ghé',
                        value: 'pending',
                        activeColor: const Color(0xFFD97706),
                        icon: Icons.pending_outlined,
                        isDark: isDark,
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // Section 2: Tuyến bán hàng
                  _buildSectionTitle(
                    title: 'Tuyến bán hàng',
                    icon: Icons.alt_route_rounded,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _buildDropdown(
                    value: _selectedRoute,
                    items: routeList,
                    hint: 'Tất cả tuyến',
                    isDark: isDark,
                    onChanged: (val) {
                      setState(() {
                        _selectedRoute = val ?? 'Tất cả tuyến';
                      });
                    },
                  ),

                  const SizedBox(height: 22),

                  // Section 3: Trạng thái khách hàng
                  _buildSectionTitle(
                    title: 'Trạng thái khách hàng',
                    icon: Icons.verified_user_outlined,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildCustomerStatusChip(
                        label: 'Tất cả',
                        value: 'all',
                        isDark: isDark,
                      ),
                      _buildCustomerStatusChip(
                        label: 'Đang hoạt động',
                        value: 'active',
                        activeColor: const Color(0xFF10B981),
                        icon: Icons.check_circle_outline_rounded,
                        isDark: isDark,
                      ),
                      _buildCustomerStatusChip(
                        label: 'Ngừng hoạt động',
                        value: 'inactive',
                        activeColor: const Color(0xFFDC2626),
                        icon: Icons.block_outlined,
                        isDark: isDark,
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // Section 4: Loại khách hàng
                  _buildSectionTitle(
                    title: 'Loại khách hàng',
                    icon: Icons.category_outlined,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _buildDropdown(
                    value: _selectedCustomerType ?? 'Tất cả loại',
                    items: typeList,
                    hint: 'Tất cả loại',
                    isDark: isDark,
                    onChanged: (val) {
                      setState(() {
                        _selectedCustomerType = (val == 'Tất cả loại' || val == null) ? null : val;
                      });
                    },
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
                    color: isDark
                        ? AppColors.darkOutlineVariant
                        : AppColors.outlineVariant,
                  ),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    offset: Offset(0, -2),
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
                          color: isDark
                              ? AppColors.darkOutline
                              : AppColors.outlineVariant,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Đặt lại',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkOnSurface
                              : AppColors.onSurface,
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
        Icon(
          icon,
          size: 16,
          color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
        ),
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

  Widget _buildVisitStatusChip({
    required String label,
    required String value,
    Color? activeColor,
    IconData? icon,
    required bool isDark,
  }) {
    final isSelected = (_selectedVisitStatus == null && value == 'all') ||
        _selectedVisitStatus == value;
    final color = activeColor ?? AppColors.primary;

    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? Colors.white
                  : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : (isDark ? AppColors.darkOnSurface : AppColors.onSurface),
            ),
          ),
        ],
      ),
      onSelected: (_) {
        setState(() {
          _selectedVisitStatus = value == 'all' ? null : value;
        });
      },
      selectedColor: color,
      backgroundColor: isDark ? AppColors.darkSurfaceContainer : const Color(0xFFF1F5F9),
      side: BorderSide(
        color: isSelected
            ? color
            : (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      showCheckmark: false,
    );
  }

  Widget _buildCustomerStatusChip({
    required String label,
    required String value,
    Color? activeColor,
    IconData? icon,
    required bool isDark,
  }) {
    final isSelected = (_selectedCustomerStatus == null && value == 'all') ||
        _selectedCustomerStatus == value;
    final color = activeColor ?? AppColors.primary;

    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? Colors.white
                  : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : (isDark ? AppColors.darkOnSurface : AppColors.onSurface),
            ),
          ),
        ],
      ),
      onSelected: (_) {
        setState(() {
          _selectedCustomerStatus = value == 'all' ? null : value;
        });
      },
      selectedColor: color,
      backgroundColor: isDark ? AppColors.darkSurfaceContainer : const Color(0xFFF1F5F9),
      side: BorderSide(
        color: isSelected
            ? color
            : (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      showCheckmark: false,
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String hint,
    required bool isDark,
    required ValueChanged<String?> onChanged,
  }) {
    final effectiveValue = items.contains(value) ? value : items.firstOrNull;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainer : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: effectiveValue,
          isExpanded: true,
          menuMaxHeight: 300,
          hint: Text(
            hint,
            style: AppTypography.bodySmall(
              color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
            ),
          ),
          dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
          ),
          style: AppTypography.bodyMedium(
            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
          ),
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyMedium(
                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
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

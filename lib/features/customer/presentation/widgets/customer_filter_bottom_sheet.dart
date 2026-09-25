import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../viewmodels/customer_view_model.dart';

class CustomerFilterBottomSheet extends StatefulWidget {
  final CustomerState state;
  final Function(String? route, String? type, String? channel) onApply;
  final VoidCallback onReset;

  const CustomerFilterBottomSheet({
    super.key,
    required this.state,
    required this.onApply,
    required this.onReset,
  });

  static Future<void> show(
    BuildContext context, {
    required CustomerState state,
    required Function(String? route, String? type, String? channel) onApply,
    required VoidCallback onReset,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CustomerFilterBottomSheet(
        state: state,
        onApply: onApply,
        onReset: onReset,
      ),
    );
  }

  @override
  State<CustomerFilterBottomSheet> createState() => _CustomerFilterBottomSheetState();
}

class _CustomerFilterBottomSheetState extends State<CustomerFilterBottomSheet> {
  late String? _selectedRoute;
  late String? _selectedType;
  late String? _selectedChannel;

  @override
  void initState() {
    super.initState();
    _selectedRoute = widget.state.selectedRoute;
    _selectedType = widget.state.selectedCustomerType;
    _selectedChannel = widget.state.selectedChannel;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bộ lọc nâng cao',
                style: AppTypography.titleLarge(
                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                ).copyWith(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tuyến khách hàng
          _buildDropdownSection(
            title: 'Tuyến khách hàng',
            icon: Icons.alt_route_rounded,
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
          const SizedBox(height: 16),

          // Loại khách hàng
          _buildDropdownSection(
            title: 'Loại khách hàng',
            icon: Icons.category_outlined,
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
          const SizedBox(height: 16),

          // Kênh bán hàng
          _buildDropdownSection(
            title: 'Kênh bán hàng',
            icon: Icons.storefront_outlined,
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
          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    widget.onReset();
                    Navigator.of(context).pop();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: BorderSide(
                      color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Thiết lập lại',
                    style: TextStyle(
                      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(_selectedRoute, _selectedType, _selectedChannel);
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Áp dụng',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownSection({
    required String title,
    required IconData icon,
    required String? value,
    required List<String> items,
    required String hint,
    required bool isDark,
    required ValueChanged<String?> onChanged,
  }) {
    final effectiveValue = (value != null && items.contains(value)) ? value : items.firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: AppTypography.labelLarge(
                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceContainerLowest : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: effectiveValue,
              isExpanded: true,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline,
              ),
              dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
              style: AppTypography.bodyMedium(
                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
              ),
              items: items.map((item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    style: TextStyle(
                      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                      fontWeight: item == effectiveValue ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

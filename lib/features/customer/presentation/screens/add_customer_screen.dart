import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/dynamic_form/dynamic_form_builder.dart';
import '../../../../core/dynamic_form/models/dynamic_form_field.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../data/repositories/customer_repository_impl.dart';
import '../viewmodels/customer_view_model.dart';

/// Provider lấy schema form khách hàng từ API (hoặc cache)
final customerFormSchemaProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(customerRepositoryProvider);
  return repo.getCustomerFormSchema(forceRefresh: true);
});

class AddCustomerScreen extends ConsumerStatefulWidget {
  const AddCustomerScreen({super.key});

  @override
  ConsumerState<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends ConsumerState<AddCustomerScreen> {
  final GlobalKey<DynamicFormBuilderState> _formKey = GlobalKey<DynamicFormBuilderState>();
  bool _isSubmitting = false;

  Future<void> _handleSubmit(Map<String, dynamic> formData) async {
    if (formData['name'] == null || formData['name'].toString().trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tên khách hàng là bắt buộc.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(customerRepositoryProvider);
      
      // Chuẩn bị payload dữ liệu submit
      final payload = Map<String, dynamic>.from(formData);
      
      // Xóa các trường read-only nếu code tự sinh từ backend
      if (payload['code'] == null || payload['code'].toString().isEmpty) {
        payload.remove('code');
      }

      await repo.createCustomer(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('Thêm mới điểm bán thành công!'),
              ],
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Refresh danh sách khách hàng ở màn hình chính
        ref.read(customerViewModelProvider.notifier).loadCustomers(isRefresh: true);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi thêm điểm bán: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final schemaAsync = ref.watch(customerFormSchemaProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thêm mới điểm bán',
              style: AppTypography.titleLarge(
                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            schemaAsync.maybeWhen(
              data: (schemaData) {
                final formName = schemaData['data']?['form']?['name']?.toString() ?? 'Hồ sơ điểm bán';
                final version = schemaData['data']?['version']?.toString() ?? '';
                return Text(
                  '$formName ${version.isNotEmpty ? "• v.$version" : ""}',
                  style: AppTypography.labelSmall(
                    color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                  ).copyWith(fontSize: 11),
                );
              },
              orElse: () => Text(
                'Đang tải cấu hình biểu mẫu...',
                style: AppTypography.labelSmall(
                  color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                ).copyWith(fontSize: 11),
              ),
            ),
          ],
        ),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surfaceContainerLowest,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Tải lại cấu hình form',
            onPressed: () => ref.invalidate(customerFormSchemaProvider),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
            height: 1,
          ),
        ),
      ),
      body: schemaAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primaryContainer),
              SizedBox(height: 16),
              Text('Đang tải cấu hình trường nhập liệu động...'),
            ],
          ),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 56, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  'Không thể tải cấu hình form từ hệ thống',
                  style: AppTypography.titleMedium(
                    color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  err.toString(),
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall(
                    color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                AppButton(
                  text: 'Thử lại',
                  icon: Icons.refresh_rounded,
                  onPressed: () => ref.invalidate(customerFormSchemaProvider),
                ),
              ],
            ),
          ),
        ),
        data: (schemaData) {
          final fieldsJson = schemaData['data']?['fields'] as List? ?? [];
          final fields = fieldsJson
              .map((f) => DynamicFormField.fromJson(f as Map<String, dynamic>))
              .toList();

          if (fields.isEmpty) {
            return const Center(
              child: Text('Không có trường dữ liệu nào trong cấu hình form.'),
            );
          }

          return SafeArea(
            child: Column(
              children: [
                // Main Form Content
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.all(16),
                    child: DynamicFormBuilder(
                      key: _formKey,
                      fields: fields,
                      initialData: const {
                        'status': 'active', // Mặc định trạng thái đang hoạt động
                      },
                      onSubmit: _handleSubmit,
                    ),
                  ),
                ),

                // Bottom Fixed Action Bar
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.surfaceContainerLowest,
                    border: Border(
                      top: BorderSide(
                        color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                        width: 1,
                      ),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0a000000),
                        offset: Offset(0, -4),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: SizedBox(
                          height: 46,
                          child: OutlinedButton(
                            onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedMd),
                            ),
                            child: const Text('HỦY BỎ'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: AppButton(
                          text: 'LƯU ĐIỂM BÁN',
                          isLoading: _isSubmitting,
                          icon: Icons.check_circle_outline_rounded,
                          height: 46,
                          onPressed: () {
                            if (_formKey.currentState != null &&
                                _formKey.currentState!.validate()) {
                              _handleSubmit(_formKey.currentState!.getFormData());
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/dynamic_form/dynamic_form.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';

class DynamicFormDemoScreen extends StatefulWidget {
  const DynamicFormDemoScreen({super.key});

  @override
  State<DynamicFormDemoScreen> createState() => _DynamicFormDemoScreenState();
}

class _DynamicFormDemoScreenState extends State<DynamicFormDemoScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final GlobalKey<DynamicFormBuilderState> _formKey = GlobalKey<DynamicFormBuilderState>();

  Map<String, dynamic> _currentFormData = {};
  bool _isSubmitting = false;

  // Mock API Response đặc tả 10 kiểu trường động phổ biến trong nghiệp vụ DMS/CRM
  final List<DynamicFormField> _mockFields = [
    // 1. Nhóm Thông tin cơ bản
    const DynamicFormField(
      code: 'store_name',
      label: '1. Tên điểm bán / Cửa hàng',
      type: DynamicFormFieldType.text,
      placeholder: 'VD: Đại lý Tạp hóa Mai Linh',
      helperText: 'Nhập tên đầy đủ của điểm bán hoặc biển hiệu',
      isRequired: true,
      section: 'I. THÔNG TIN ĐIỂM BÁN',
    ),
    const DynamicFormField(
      code: 'store_notes',
      label: '2. Ghi chú khảo sát (Văn bản dài)',
      type: DynamicFormFieldType.longText,
      placeholder: 'Nhập đặc điểm nhận diện, thói quen nhập hàng, ý kiến chủ tiệm...',
      helperText: 'Mô tả chi tiết tình hình thực tế',
      isRequired: false,
      section: 'I. THÔNG TIN ĐIỂM BÁN',
    ),
    const DynamicFormField(
      code: 'monthly_revenue',
      label: '3. Doanh thu ước tính hàng tháng (Kiểu số)',
      type: DynamicFormFieldType.number,
      placeholder: '50000000',
      suffixText: 'VNĐ',
      min: 0,
      step: 5000000,
      helperText: 'Nhập số tiền hoặc dùng nút + / - để tăng giảm nhanh',
      isRequired: false,
      section: 'I. THÔNG TIN ĐIỂM BÁN',
    ),

    // 2. Nhóm Phân loại & Lựa chọn
    const DynamicFormField(
      code: 'store_type',
      label: '4. Loại hình điểm bán (Lựa chọn 1)',
      type: DynamicFormFieldType.singleChoice,
      isRequired: true,
      options: [
        DynamicFormOption(label: 'Đại lý C1', value: 'c1'),
        DynamicFormOption(label: 'Đại lý C2', value: 'c2'),
        DynamicFormOption(label: 'Tạp hóa truyền thống (GT)', value: 'gt'),
        DynamicFormOption(label: 'Siêu thị mini (MT)', value: 'mt'),
      ],
      helperText: 'Chọn 1 loại hình kinh doanh chính',
      section: 'II. PHÂN LOẠI & LỰA CHỌN',
    ),
    const DynamicFormField(
      code: 'product_categories',
      label: '5. Các ngành hàng đang bán (Lựa chọn nhiều)',
      type: DynamicFormFieldType.multipleChoice,
      isRequired: true,
      options: [
        DynamicFormOption(label: 'Sữa & Bột dinh dưỡng', value: 'milk'),
        DynamicFormOption(label: 'Bánh kẹo & Snack', value: 'snack'),
        DynamicFormOption(label: 'Nước giải khát', value: 'beverage'),
        DynamicFormOption(label: 'Gia vị & Đồ khô', value: 'dry_food'),
        DynamicFormOption(label: 'Hóa mỹ phẩm', value: 'cosmetics'),
      ],
      helperText: 'Bấm chọn một hoặc nhiều ngành hàng',
      section: 'II. PHÂN LOẠI & LỰA CHỌN',
    ),

    // 3. Nhóm Thời gian & Đánh giá
    const DynamicFormField(
      code: 'survey_date',
      label: '6. Ngày khảo sát (Chọn ngày)',
      type: DynamicFormFieldType.date,
      placeholder: 'YYYY-MM-DD',
      isRequired: true,
      section: 'III. THỜI GIAN & ĐÁNH GIÁ',
    ),
    const DynamicFormField(
      code: 'open_time',
      label: '7. Giờ mở cửa hàng ngày (Chọn giờ)',
      type: DynamicFormFieldType.time,
      placeholder: 'HH:mm',
      isRequired: false,
      section: 'III. THỜI GIAN & ĐÁNH GIÁ',
    ),
    const DynamicFormField(
      code: 'is_posm_passed',
      label: '8. Trưng bày POSM đạt chuẩn (Công tắc Bật/Tắt)',
      type: DynamicFormFieldType.boolean,
      helperText: 'Gạt công tắc sang BẬT nếu điểm bán trưng bày đủ và đúng quy chuẩn',
      section: 'III. THỜI GIAN & ĐÁNH GIÁ',
    ),
    const DynamicFormField(
      code: 'potential_rating',
      label: '9. Đánh giá tiềm năng phát triển (1 - 5 Sao)',
      type: DynamicFormFieldType.rating,
      min: 1,
      max: 5,
      helperText: 'Chạm vào các ngôi sao để xếp hạng tiềm năng',
      section: 'III. THỜI GIAN & ĐÁNH GIÁ',
    ),

    // 4. Nhóm Tọa độ & Hình ảnh
    const DynamicFormField(
      code: 'store_gps',
      label: '10. Tọa độ vị trí thực tế (Lấy GPS tự động)',
      type: DynamicFormFieldType.gps,
      isRequired: false,
      helperText: 'Chạm nút "Lấy tọa độ GPS" để định vị chuẩn xác',
      section: 'IV. ĐỊNH VỊ & ẢNH CHỤP',
    ),
    const DynamicFormField(
      code: 'store_photos',
      label: '11. Ảnh chụp mặt tiền & kệ hàng (Camera/Thư viện)',
      type: DynamicFormFieldType.photo,
      maxPhotos: 4,
      isRequired: false,
      helperText: 'Chụp tối đa 4 ảnh thực tế tại cửa hàng',
      section: 'IV. ĐỊNH VỊ & ẢNH CHỤP',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleSubmit(Map<String, dynamic> formData) async {
    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() => _isSubmitting = false);

    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final jsonPretty = const JsonEncoder.withIndent('  ').convert(formData);

          return SafeArea(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.8,
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Form Submit Thành Công!',
                          style: AppTypography.titleMedium(
                            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Payload JSON thu thập được từ các UI field động sẵn sàng gửi lên Backend API:',
                    style: AppTypography.bodySmall(
                      color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E2421) : const Color(0xFF263238),
                        borderRadius: AppRadius.roundedMd,
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          jsonPretty,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Color(0xFF8DFB85),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedMd),
                    ),
                    child: const Text('ĐÓNG', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surface,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        title: Text(
          '🧪 Demo UI Form Động',
          style: AppTypography.titleMedium(
            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.dynamic_form_rounded, size: 20), text: 'UI Form Trực Quan'),
            Tab(icon: Icon(Icons.code_rounded, size: 20), text: 'JSON Live Payload'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Render các Field động trong Form hoàn chỉnh
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: AppRadius.roundedMd,
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb_outline_rounded, color: AppColors.primary, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Mỗi ô bên dưới được sinh tự động từ cấu hình JSON (type, label, options, validation...). Thử nhập liệu và bấm Lưu ở cuối form.',
                          style: AppTypography.bodySmall(
                            color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Master Dynamic Form Builder
                DynamicFormBuilder(
                  key: _formKey,
                  fields: _mockFields,
                  initialData: const {
                    'store_name': 'Đại lý Sữa & Bánh Kẹo Hùng Vương',
                    'monthly_revenue': 35000000,
                    'store_type': 'c2',
                    'product_categories': ['milk', 'snack'],
                    'is_posm_passed': true,
                    'potential_rating': 4,
                  },
                  onChanged: (data) {
                    setState(() {
                      _currentFormData = data;
                    });
                  },
                  submitButtonText: 'LƯU DỮ LIỆU KHẢO SÁT',
                  isSubmitting: _isSubmitting,
                  onSubmit: (data) async => _handleSubmit(data),
                ),
              ],
            ),
          ),

          // Tab 2: Xem JSON Live Preview
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dữ liệu JSON thu thập tức thì (Live Output):',
                  style: AppTypography.titleMedium(
                    color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                AppCard(
                  child: SelectableText(
                    const JsonEncoder.withIndent('  ').convert(_currentFormData),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: isDark ? AppColors.primaryFixedDim : AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Cấu trúc Field Definition từ API Server:',
                  style: AppTypography.titleMedium(
                    color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                AppCard(
                  child: SelectableText(
                    const JsonEncoder.withIndent('  ').convert(
                      _mockFields.map((f) => {
                        'code': f.code,
                        'label': f.label,
                        'type': f.type.name,
                        'required': f.isRequired,
                        'options_count': f.options.length,
                        'section': f.section,
                      }).toList(),
                    ),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

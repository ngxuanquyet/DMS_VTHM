import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/map/app_map_location_card.dart';
import '../../../../core/services/anti_fraud_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/voice_input_mic_button.dart';
import '../states/position_declaration_state.dart';
import '../viewmodels/position_declaration_view_model.dart';

class PositionDeclarationScreen extends ConsumerStatefulWidget {
  const PositionDeclarationScreen({super.key});

  @override
  ConsumerState<PositionDeclarationScreen> createState() =>
      _PositionDeclarationScreenState();
}

class _PositionDeclarationScreenState
    extends ConsumerState<PositionDeclarationScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(positionDeclarationViewModelProvider.notifier)
          .fetchCurrentLocation(context);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(positionDeclarationViewModelProvider);
    final vm = ref.read(positionDeclarationViewModelProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Lắng nghe lỗi hoặc thông báo thành công
    ref.listen<PositionDeclarationState>(positionDeclarationViewModelProvider,
        (prev, next) {
      if (next.errorMessage != null &&
          next.errorMessage != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(next.errorMessage!)),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        vm.clearMessage();
      } else if (next.successMessage != null &&
          next.successMessage != prev?.successMessage) {
        _titleController.clear();
        _noteController.clear();

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
                SizedBox(width: 10),
                Text('Thành công', style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            content: Text(
              next.successMessage!,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  context.push('/position-declaration/history');
                },
                child: const Text(
                  'XEM LỊCH SỬ',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  if (mounted && Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('ĐÓNG'),
              ),
            ],
          ),
        );
        vm.clearMessage();
      }
    });

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.surfaceVariant,
      appBar: AppBar(
        title: const Text(
          'Khai báo vị trí',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        foregroundColor: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Lịch sử khai báo',
            onPressed: () {
              context.push('/position-declaration/history');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.marginMobile,
          vertical: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. CHỌN LÝ DO KHAI BÁO (§2)
            _buildSectionHeader('1. Lý do khai báo', isDark, isRequired: true),
            const SizedBox(height: 8),
            _buildReasonSelector(context, state, vm, isDark),
            const SizedBox(height: 18),

            // 2. VỊ TRÍ HIỆN TẠI TRÊN BẢN ĐỒ (§4)
            AppMapLocationCard(
              title: '2. Vị trí hiện tại',
              isRequired: true,
              lat: state.lat,
              lng: state.lng,
              accuracyM: state.accuracyM,
              initialAddress: state.address,
              mapHeight: 220,
              showStyleSwitcher: true,
              locateButtonText: 'LẤY VỊ TRÍ HIỆN TẠI',
              updateButtonText: 'CẬP NHẬT LẠI VỊ TRÍ',
              onLocationChanged: (newLat, newLng, newAddress) {
                vm.setLocation(
                  lat: newLat,
                  lng: newLng,
                  address: newAddress,
                );
              },
              onCleared: () {
                vm.clearLocation();
              },
            ),
            const SizedBox(height: 10),

            // 3. ẢNH CHỤP CHỨNG MINH (§3)
            _buildSectionHeader(
              '3. Ảnh chụp chứng minh',
              isDark,
              isRequired: true,
              badge: state.photos.isNotEmpty
                  ? 'Chỉ chụp từ camera (${state.photos.length}/10)'
                  : 'Chỉ chụp từ camera',
            ),
            const SizedBox(height: 8),
            _buildPhotoSection(context, state, vm, isDark),
            const SizedBox(height: 18),

            // 4. MÔ TẢ & GHI CHÚ
            _buildSectionHeader('4. Thông tin bổ sung', isDark, isRequired: false),
            const SizedBox(height: 8),
            _buildAdditionalInfoCard(isDark),
            const SizedBox(height: 28),

            // 5. NÚT GỬI KHAI BÁO
            _buildSubmitButton(context, state, vm),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    bool isDark, {
    bool isRequired = false,
    String? badge,
  }) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
          ),
        ),
        if (isRequired)
          const Text(
            ' *',
            style: TextStyle(
              color: AppColors.error,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReasonSelector(
    BuildContext context,
    PositionDeclarationState state,
    PositionDeclarationViewModel vm,
    bool isDark,
  ) {
    final selected = state.selectedReason;

    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: () => _showReasonPickerModal(context, state, vm, isDark),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: selected != null
                  ? selected.colorValue.withValues(alpha: 0.15)
                  : AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.category_rounded,
              size: 20,
              color: selected != null ? selected.colorValue : AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selected != null ? selected.displayName : 'Chọn lý do khai báo',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: selected != null
                        ? (isDark ? Colors.white : AppColors.onSurface)
                        : (isDark
                            ? AppColors.darkOnSurfaceVariant
                            : AppColors.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  selected != null
                      ? 'Nhấn để thay đổi lý do'
                      : 'Bắt buộc chọn từ danh mục quản trị',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkOnSurfaceVariant
                        : AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_drop_down_rounded, size: 28, color: AppColors.primary),
        ],
      ),
    );
  }

  void _showReasonPickerModal(
    BuildContext context,
    PositionDeclarationState state,
    PositionDeclarationViewModel vm,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Chọn lý do khai báo',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                if (state.reasons.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(
                      child: Text('Chưa có danh mục lý do khả dụng'),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: state.reasons.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final reason = state.reasons[index];
                        final isSelected =
                            state.selectedReason?.id == reason.id;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 4,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: reason.colorValue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: reason.colorValue.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              reason.code,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: reason.colorValue,
                              ),
                            ),
                          ),
                          title: Text(
                            reason.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? AppColors.primary
                                  : (isDark
                                      ? AppColors.darkOnSurface
                                      : AppColors.onSurface),
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle_rounded,
                                  color: AppColors.primary)
                              : null,
                          onTap: () {
                            vm.selectReason(reason);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }


  Widget _buildPhotoSection(
    BuildContext context,
    PositionDeclarationState state,
    PositionDeclarationViewModel vm,
    bool isDark,
  ) {
    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Nút chụp ảnh từ CAMERA (theo §3)
          InkWell(
            onTap: state.photos.length >= 10
                ? null
                : () => vm.takePhotoFromCamera(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 90,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  style: BorderStyle.solid,
                ),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_rounded,
                      size: 28, color: AppColors.primary),
                  SizedBox(height: 6),
                  Text(
                    'Chụp ảnh',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Hiển thị gợi ý nếu chưa có ảnh nào
          if (state.photos.isEmpty) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceContainer
                    : AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? AppColors.darkOutlineVariant
                      : AppColors.outlineVariant,
                ),
              ),
              child: Center(
                child: Text(
                  'Bắt buộc chụp ít nhất 1 ảnh\nchứng minh tại địa điểm',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkOnSurfaceVariant
                        : AppColors.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ],

          // Danh sách ảnh đã chụp
          for (int i = 0; i < state.photos.length; i++) ...[
            const SizedBox(width: 10),
            Stack(
              children: [
                Container(
                  width: 90,
                  height: 96,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkOutlineVariant
                          : AppColors.outlineVariant,
                    ),
                    image: DecorationImage(
                      image: FileImage(state.photos[i]),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => vm.removePhoto(i),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdditionalInfoCard(bool isDark) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _titleController,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: 'Tiêu đề / Mục đích (tùy chọn)',
              hintText: 'vd: Đi họp tại chi nhánh Cần Thơ',
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              suffixIcon: VoiceInputMicButton(
                fieldName: 'Tiêu đề',
                currentText: _titleController.text,
                onTextRecognized: (text) {
                  _titleController.text = text;
                  _titleController.selection = TextSelection.fromPosition(
                    TextPosition(offset: text.length),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            maxLength: 1000,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Ghi chú thêm (tùy chọn)',
              hintText: 'Nhập nội dung chi tiết công việc nếu có...',
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              suffixIcon: VoiceInputMicButton(
                fieldName: 'Ghi chú',
                currentText: _noteController.text,
                onTextRecognized: (text) {
                  _noteController.text = text;
                  _noteController.selection = TextSelection.fromPosition(
                    TextPosition(offset: text.length),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(
    BuildContext context,
    PositionDeclarationState state,
    PositionDeclarationViewModel vm,
  ) {
    final isSubmitting =
        state.status == PositionDeclarationStatus.submitting;

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: isSubmitting
            ? null
            : () async {
                if (state.selectedReason == null) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vui lòng chọn một lý do khai báo trước khi gửi.'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                if (state.lat == null || state.lng == null) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vui lòng xác định vị trí GPS trước khi gửi khai báo.'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                if (state.photos.isEmpty) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.camera_alt_outlined, color: Colors.white, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text('Vui lòng chụp ít nhất 1 ảnh chứng minh trước khi gửi khai báo.'),
                          ),
                        ],
                      ),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 3),
                    ),
                  );
                  vm.setPhotoRequiredError();
                  return;
                }

                // 🔴 KIỂM TRA CHỐNG GIAN LẬN TRƯỚC KHI GỬI KHAI BÁO VỊ TRÍ
                final pos = Position(
                  latitude: state.lat!,
                  longitude: state.lng!,
                  timestamp: DateTime.now(),
                  accuracy: state.accuracyM ?? 0,
                  altitude: 0,
                  altitudeAccuracy: 0,
                  heading: 0,
                  headingAccuracy: 0,
                  speed: 0,
                  speedAccuracy: 0,
                  isMocked: state.isMockLocation ?? false,
                );

                final fraudCheck = await ref.read(antiFraudServiceProvider).validateAction(
                  context,
                  position: pos,
                  actionType: AntiFraudActionType.positionDeclaration,
                  actionTitle: 'Khai báo vị trí',
                );
                if (!fraudCheck.isAllowed) return;

                vm.submitDeclaration(
                  title: _titleController.text,
                  note: _noteController.text,
                );
              },
        icon: isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.send_rounded, size: 20),
        label: Text(
          isSubmitting ? 'ĐANG GỬI KHAI BÁO...' : 'GỬI KHAI BÁO VỊ TRÍ',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

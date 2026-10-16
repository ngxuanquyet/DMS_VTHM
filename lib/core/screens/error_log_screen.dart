import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/error_record.dart';
import '../services/error_tracker_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/app_snackbar.dart';

/// Màn hình quản lý và tra cứu nhật ký lỗi (Incident & Error Log Inspector)
class ErrorLogScreen extends StatefulWidget {
  const ErrorLogScreen({super.key});

  @override
  State<ErrorLogScreen> createState() => _ErrorLogScreenState();
}

class _ErrorLogScreenState extends State<ErrorLogScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedModule = 'ALL';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ErrorRecord> get _filteredErrors {
    final all = ErrorTrackerService.instance.recentErrors;
    return all.where((e) {
      if (_selectedModule != 'ALL' && e.module != _selectedModule) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final idMatch = e.id.toLowerCase().contains(_searchQuery);
        final msgMatch = e.message.toLowerCase().contains(_searchQuery);
        final epMatch = e.endpoint?.toLowerCase().contains(_searchQuery) ?? false;
        final codeMatch = e.serverCode?.toLowerCase().contains(_searchQuery) ?? false;
        return idMatch || msgMatch || epMatch || codeMatch;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final errors = _filteredErrors;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nhật ký lỗi hệ thống',
              style: AppTypography.titleMedium(
                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              'Tra cứu mã lỗi & Cảnh báo Telegram',
              style: AppTypography.bodySmall(
                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
              ).copyWith(fontSize: 11),
            ),
          ],
        ),
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.telegram_rounded, color: Color(0xFF0088CC)),
            tooltip: 'Cấu hình Telegram Bot',
            onPressed: () => _openTelegramConfigDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.error),
            tooltip: 'Xóa toàn bộ nhật ký',
            onPressed: () => _confirmClearLogs(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Thanh tìm kiếm
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm theo Mã lỗi (ERR-...), thông báo hoặc endpoint...',
                hintStyle: AppTypography.bodySmall(
                  color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline,
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerLowest,
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

          // Bộ lọc phân hệ (Module Filter Chips)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip('ALL', 'Tất cả (${ErrorTrackerService.instance.recentErrors.length})'),
                _buildFilterChip('AUTH', 'Auth / Quyền'),
                _buildFilterChip('VISIT', 'Viếng thăm'),
                _buildFilterChip('CUST', 'Điểm bán'),
                _buildFilterChip('ATTEND', 'Chấm công'),
                _buildFilterChip('LOC', 'Vị trí'),
                _buildFilterChip('NET', 'Mạng / Timeout'),
                _buildFilterChip('SYS', 'Hệ thống'),
              ],
            ),
          ),
          const Divider(height: 12),

          // Danh sách lỗi
          Expanded(
            child: errors.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_outlined,
                          size: 48,
                          color: isDark ? AppColors.darkOutline : AppColors.outline,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty || _selectedModule != 'ALL'
                              ? 'Không tìm thấy lỗi phù hợp'
                              : 'Chưa có bản ghi lỗi nào trong phiên làm việc',
                          style: AppTypography.bodyMedium(
                            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: errors.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = errors[index];
                      return _buildErrorCard(context, item, isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String module, String label) {
    final isSelected = _selectedModule == module;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: isSelected,
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : null,
          ),
        ),
        backgroundColor: Colors.transparent,
        selectedColor: AppColors.primary,
        onSelected: (_) {
          setState(() => _selectedModule = module);
        },
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, ErrorRecord item, bool isDark) {
    final is5xx = item.statusCode != null && item.statusCode! >= 500;
    final isForbidden = item.statusCode == 403;

    Color badgeColor = AppColors.error;
    if (item.module == 'NET') badgeColor = Colors.orange;
    if (isForbidden) badgeColor = Colors.purple;
    if (is5xx) badgeColor = Colors.red.shade900;

    return Card(
      elevation: 0,
      color: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
          width: 0.8,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showErrorDetailModal(context, item),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hàng trên: Mã lỗi, Status Code, Thời gian
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      item.id,
                      style: TextStyle(
                        color: badgeColor,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (item.statusCode != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'HTTP ${item.statusCode}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  const Spacer(),
                  Text(
                    _formatShortTime(item.timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.outline,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Thông báo lỗi
              Text(
                item.message,
                style: AppTypography.bodyMedium(
                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                ).copyWith(fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              if (item.endpoint != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${item.method ?? 'GET'} ${item.endpoint}',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorDetailModal(BuildContext context, ErrorRecord item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceContainer : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chi tiết sự cố lỗi',
                            style: AppTypography.titleMedium(
                              color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                          SelectableText(
                            item.id,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 20, color: AppColors.primary),
                      tooltip: 'Sao chép mã lỗi',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: item.id));
                        AppSnackBar.showSuccess(context, 'Đã sao chép mã lỗi: ${item.id}');
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Nội dung chi tiết
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildSectionHeader('1. Thông báo lỗi', Icons.error_outline_rounded),
                    _buildBox(item.message, isCode: false),

                    if (item.endpoint != null) ...[
                      const SizedBox(height: 16),
                      _buildSectionHeader('2. API Endpoint & HTTP Status', Icons.link_rounded),
                      _buildBox('${item.method ?? 'GET'} ${item.endpoint}\nStatus Code: ${item.statusCode ?? 'N/A'}${item.serverCode != null ? ' | Code: ${item.serverCode}' : ''}'),
                    ],

                    if (item.responseData != null) ...[
                      const SizedBox(height: 16),
                      _buildSectionHeader('3. Phản hồi máy chủ (Response Body)', Icons.receipt_long_rounded),
                      _buildBox(_formatJson(item.responseData)),
                    ],

                    if (item.requestData != null) ...[
                      const SizedBox(height: 16),
                      _buildSectionHeader('4. Dữ liệu gửi lên (Request Body)', Icons.upload_rounded),
                      _buildBox(_formatJson(item.requestData)),
                    ],

                    if (item.curlCommand != null && item.curlCommand!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionHeader('5. Lệnh cURL (Tái hiện lỗi)', Icons.terminal_rounded),
                          TextButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: item.curlCommand!));
                              AppSnackBar.showSuccess(context, 'Đã sao chép lệnh cURL!');
                            },
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            label: const Text('Chép cURL', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      _buildBox(item.curlCommand!),
                    ],

                    if (item.stackTrace != null && item.stackTrace!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildSectionHeader('6. Stack Trace', Icons.bug_report_rounded),
                      _buildBox(item.stackTrace!),
                    ],

                    const SizedBox(height: 16),
                    _buildSectionHeader('7. Ngữ cảnh & Thiết bị', Icons.info_outline_rounded),
                    _buildBox(
                      'Thời gian: ${item.timestamp.toLocal()}\n'
                      'Tài khoản: ${item.username ?? 'Chưa xác định'}\n'
                      'Thiết bị: ${item.deviceInfo ?? 'Không rõ'}\n'
                      'Toạ độ GPS: ${item.lat != null ? '${item.lat}, ${item.lng}' : 'Không có'}\n'
                      'Đã gửi Telegram: ${item.sentToTelegram ? 'Có' : 'Chưa'}',
                      isCode: false,
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildBox(String text, {bool isCode = true}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
          width: 0.8,
        ),
      ),
      child: SelectableText(
        text,
        style: TextStyle(
          fontSize: 12,
          fontFamily: isCode ? 'monospace' : null,
          height: 1.4,
        ),
      ),
    );
  }

  void _openTelegramConfigDialog(BuildContext context) async {
    final config = await ErrorTrackerService.instance.getTelegramConfig();
    final tokenCtrl = TextEditingController(text: config['botToken'] as String? ?? '');
    final chatCtrl = TextEditingController(text: config['chatId'] as String? ?? '');
    bool isEnabled = config['enabled'] as bool? ?? true;
    bool isTesting = false;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.telegram_rounded, color: Color(0xFF0088CC), size: 28),
              SizedBox(width: 8),
              Text('Cấu hình Telegram Bot', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Bật bắn cảnh báo lỗi về Telegram', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  value: isEnabled,
                  onChanged: (val) => setDialogState(() => isEnabled = val),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: tokenCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Bot Token',
                    hintText: 'VD: 123456789:ABCdefGHIjkl...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: chatCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Chat ID / Group ID',
                    hintText: 'VD: -100123456789 hoặc 987654321',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: isTesting
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send_rounded, size: 16),
                    label: const Text('Gửi tin nhắn kiểm tra thử'),
                    onPressed: isTesting
                        ? null
                        : () async {
                            setDialogState(() => isTesting = true);
                            try {
                              final ok = await ErrorTrackerService.instance.testTelegramConnection(
                                botToken: tokenCtrl.text.trim(),
                                chatId: chatCtrl.text.trim(),
                              );
                              if (ok && context.mounted) {
                                AppSnackBar.showSuccess(context, 'Gửi tin nhắn kiểm tra thành công! Hãy kiểm tra Telegram.');
                              }
                            } catch (e) {
                              if (context.mounted) {
                                AppSnackBar.showError(context, e);
                              }
                            } finally {
                              setDialogState(() => isTesting = false);
                            }
                          },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Đóng'),
            ),
            ElevatedButton(
              onPressed: () async {
                await ErrorTrackerService.instance.saveTelegramConfig(
                  botToken: tokenCtrl.text.trim(),
                  chatId: chatCtrl.text.trim(),
                  enabled: isEnabled,
                );
                if (context.mounted) {
                  Navigator.of(ctx).pop();
                  AppSnackBar.showSuccess(context, 'Đã lưu cấu hình Telegram thành công!');
                }
              },
              child: const Text('Lưu cấu hình'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmClearLogs(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa nhật ký'),
        content: const Text('Bạn có chắc chắn muốn xóa toàn bộ lịch sử lỗi trong máy không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              await ErrorTrackerService.instance.clearErrors();
              if (context.mounted) {
                Navigator.of(ctx).pop();
                setState(() {});
                AppSnackBar.showSuccess(context, 'Đã xóa toàn bộ nhật ký lỗi!');
              }
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatShortTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    final s = local.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _formatJson(dynamic data) {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(data);
    } catch (_) {
      return data.toString();
    }
  }
}

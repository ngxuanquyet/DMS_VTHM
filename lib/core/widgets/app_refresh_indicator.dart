import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/connectivity_provider.dart';
import '../network/refresh_outcome.dart';
import 'app_snackbar.dart';

/// Kéo xuống để làm mới — dùng cho MỌI màn thay `RefreshIndicator`, để báo kết quả làm mới thống nhất và ĐÚNG theo
/// server (app offline-first: repository nuốt lỗi server rồi trả dữ liệu trong máy, nên màn hình tự đoán sẽ sai):
/// - có lời gọi API không lấy được dữ liệu (mất mạng, quá giờ, mọi phản hồi lỗi) ⇒ "Không tải được dữ liệu mới…";
/// - không lời gọi nào hỏng ⇒ "Làm mới thành công" (kể cả màn chỉ đọc dữ liệu trong máy, vd Trang chủ) — trừ khi đang
///   ngoại tuyến mà không gọi được gì ⇒ "Đang ngoại tuyến…".
/// Đẩy hàng đợi đồng bộ trong lúc làm mới không tính ([RefreshOutcome.untracked]).
/// [onRefresh] ném lỗi thì không báo (lỗi đi tiếp như `RefreshIndicator`). Đếm lời gọi: [RefreshOutcome].
class AppRefreshIndicator extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  final Color? color;
  final Color? backgroundColor;
  final double elevation;

  const AppRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
    this.color,
    this.backgroundColor,
    this.elevation = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: color,
      backgroundColor: backgroundColor,
      elevation: elevation,
      onRefresh: () async {
        // Lấy trước khi chờ: nhiều màn đổi sang vòng tải khi làm mới ⇒ widget này bị gỡ khỏi cây lúc lượt chờ xong.
        final messenger = ScaffoldMessenger.maybeOf(context);
        final container = ProviderScope.containerOf(context, listen: false);
        final outcome = await RefreshOutcome.track(onRefresh);
        if (messenger == null || !messenger.mounted) return;
        if (outcome.failed > 0) {
          AppSnackBar.showWarningOn(messenger, 'Không tải được dữ liệu mới. Vui lòng thử lại.');
        } else if (outcome.reached == 0 && !container.read(connectivityProvider).isOnline) {
          AppSnackBar.showWarningOn(messenger, 'Đang ngoại tuyến — chưa làm mới được dữ liệu');
        } else {
          AppSnackBar.showSuccessOn(messenger, 'Làm mới thành công');
        }
      },
      child: child,
    );
  }
}

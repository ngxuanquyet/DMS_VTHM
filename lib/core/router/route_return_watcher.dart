import 'package:go_router/go_router.dart';

/// Gọi [onReturn] mỗi khi đường dẫn hiện tại CHUYỂN VỀ [path] từ một đường dẫn khác — chuyển tab trong
/// StatefulShellRoute, hoặc đóng một màn phủ lên (check-in, chấm công, chi tiết…). Màn trong shell được giữ nguyên khi
/// rời đi nên `initState` không chạy lại; cần cái này để biết "người dùng vừa quay lại".
class RouteReturnWatcher {
  final GoRouterDelegate _delegate;
  final String path;
  final void Function() onReturn;
  String? _lastPath;

  RouteReturnWatcher(this._delegate, {required this.path, required this.onReturn}) {
    _lastPath = _currentPath();
    _delegate.addListener(_onChanged);
  }

  /// Màn ĐANG ở trên cùng — `last`, không phải `uri`: màn mở bằng `push` (check-in, chấm công…) không đổi `uri`.
  String? _currentPath() {
    final config = _delegate.currentConfiguration;
    return config.isEmpty ? null : config.last.matchedLocation;
  }

  void _onChanged() {
    final current = _currentPath();
    final cameBack = current == path && _lastPath != path;
    _lastPath = current;
    if (cameBack) onReturn();
  }

  /// Màn [path] đang ở trên cùng (vd để biết có nên làm mới khi app quay lại từ nền).
  bool get isAtPath => _currentPath() == path;

  void dispose() => _delegate.removeListener(_onChanged);
}

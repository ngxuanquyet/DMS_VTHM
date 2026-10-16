import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/customer_entity.dart';
import 'customer_view_model.dart';

const String kReadRejectedCustomerKeysPref = 'read_rejected_customer_keys_v1';

class RejectedReadStatusNotifier extends StateNotifier<Set<String>> {
  RejectedReadStatusNotifier() : super(<String>{}) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(kReadRejectedCustomerKeysPref) ?? [];
      if (mounted) {
        state = list.toSet();
      }
    } catch (_) {}
  }

  /// Đánh dấu tất cả các điểm bán bị từ chối được truyền vào là ĐÃ ĐỌC (readed)
  Future<void> markAllAsRead(Iterable<CustomerEntity> rejectedCustomers) async {
    final updated = Set<String>.from(state);
    for (final c in rejectedCustomers) {
      final key = getCustomerKey(c);
      if (key.isNotEmpty) {
        updated.add(key);
      }
    }
    state = updated;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(kReadRejectedCustomerKeysPref, updated.toList());
    } catch (_) {}
  }

  /// Đánh dấu một key cụ thể là đã đọc
  Future<void> markKeyAsRead(String key) async {
    if (key.isEmpty || state.contains(key)) return;
    final updated = Set<String>.from(state)..add(key);
    state = updated;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(kReadRejectedCustomerKeysPref, updated.toList());
    } catch (_) {}
  }

  /// Xóa trạng thái đọc (dùng cho debug hoặc test)
  Future<void> clearReadStatus() async {
    state = <String>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(kReadRejectedCustomerKeysPref);
    } catch (_) {}
  }

  static String getCustomerKey(CustomerEntity c) {
    if (c.id > 0) return 'id_${c.id}';
    if (c.clientUuid != null && c.clientUuid!.isNotEmpty) return 'uuid_${c.clientUuid}';
    if (c.code.isNotEmpty) return 'code_${c.code}';
    return '';
  }
}

final rejectedReadStatusProvider =
    StateNotifierProvider<RejectedReadStatusNotifier, Set<String>>((ref) {
  return RejectedReadStatusNotifier();
});

/// Provider tính số lượng điểm bán bị từ chối chưa đọc (unread)
final unreadRejectedCountProvider = Provider<int>((ref) {
  final customerState = ref.watch(customerViewModelProvider);
  final readKeys = ref.watch(rejectedReadStatusProvider);

  final rejected = customerState.allCustomers.where((c) => c.isRejectedApproval);
  int unread = 0;
  for (final c in rejected) {
    final key = RejectedReadStatusNotifier.getCustomerKey(c);
    if (key.isNotEmpty && !readKeys.contains(key)) {
      unread++;
    }
  }
  return unread;
});

/// Provider kiểm tra xem có điểm bán bị từ chối nào chưa đọc hay không
final hasUnreadRejectedProvider = Provider<bool>((ref) {
  return ref.watch(unreadRejectedCountProvider) > 0;
});

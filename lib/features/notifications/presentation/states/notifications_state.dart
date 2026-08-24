import '../../domain/entities/notification_entity.dart';

enum NotificationStatus { initial, loading, loaded, error }

class NotificationsState {
  final NotificationStatus status;
  final NotificationDataEntity? data;
  final int selectedFilterIndex; // 0: Tất cả, 1: Chưa đọc, 2: Công việc, 3: Hệ thống
  final String? errorMessage;

  const NotificationsState({
    this.status = NotificationStatus.initial,
    this.data,
    this.selectedFilterIndex = 0,
    this.errorMessage,
  });

  List<NotificationEntity> filterList(List<NotificationEntity> list) {
    switch (selectedFilterIndex) {
      case 1: // Chưa đọc
        return list.where((n) => !n.isRead).toList();
      case 2: // Công việc
        return list.where((n) => n.category == 'work').toList();
      case 3: // Hệ thống
        return list.where((n) => n.category == 'system').toList();
      default: // Tất cả
        return list;
    }
  }

  List<NotificationEntity> get filteredToday => data != null ? filterList(data!.today) : [];
  List<NotificationEntity> get filteredEarlier => data != null ? filterList(data!.earlier) : [];

  NotificationsState copyWith({
    NotificationStatus? status,
    NotificationDataEntity? data,
    int? selectedFilterIndex,
    String? errorMessage,
  }) {
    return NotificationsState(
      status: status ?? this.status,
      data: data ?? this.data,
      selectedFilterIndex: selectedFilterIndex ?? this.selectedFilterIndex,
      errorMessage: errorMessage,
    );
  }
}

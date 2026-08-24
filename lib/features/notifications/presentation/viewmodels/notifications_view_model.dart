import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/repositories/notifications_repository_impl.dart';
import '../../data/services/notifications_api_service.dart';
import '../../domain/entities/notification_entity.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../../domain/usecases/notifications_usecases.dart';
import '../states/notifications_state.dart';

final notificationsApiServiceProvider = Provider<NotificationsApiService>((ref) {
  return NotificationsApiService(ref.read(apiClientProvider));
});

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepositoryImpl(ref.read(notificationsApiServiceProvider));
});

final getNotificationsUseCaseProvider = Provider<GetNotificationsUseCase>((ref) {
  return GetNotificationsUseCase(ref.read(notificationsRepositoryProvider));
});

final markAllReadUseCaseProvider = Provider<MarkAllReadUseCase>((ref) {
  return MarkAllReadUseCase(ref.read(notificationsRepositoryProvider));
});

final notificationsViewModelProvider =
    StateNotifierProvider.autoDispose<NotificationsViewModel, NotificationsState>((ref) {
  return NotificationsViewModel(
    getNotificationsUseCase: ref.read(getNotificationsUseCaseProvider),
    markAllReadUseCase: ref.read(markAllReadUseCaseProvider),
  );
});

class NotificationsViewModel extends StateNotifier<NotificationsState> {
  final GetNotificationsUseCase getNotificationsUseCase;
  final MarkAllReadUseCase markAllReadUseCase;

  NotificationsViewModel({
    required this.getNotificationsUseCase,
    required this.markAllReadUseCase,
  }) : super(const NotificationsState()) {
    loadNotifications();
  }

  void selectFilter(int index) {
    state = state.copyWith(selectedFilterIndex: index);
  }

  Future<void> loadNotifications() async {
    state = state.copyWith(status: NotificationStatus.loading);
    try {
      final data = await getNotificationsUseCase();
      state = state.copyWith(
        status: NotificationStatus.loaded,
        data: data,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        status: NotificationStatus.error,
        errorMessage: e.toString().replaceAll('AppException: ', ''),
      );
    }
  }

  Future<void> markAllAsRead() async {
    await markAllReadUseCase();
    if (state.data != null) {
      final updatedData = NotificationDataEntity(
        today: state.data!.today.map((e) => e.copyWith(isRead: true)).toList(),
        earlier: state.data!.earlier.map((e) => e.copyWith(isRead: true)).toList(),
      );
      state = state.copyWith(data: updatedData);
    }
  }
}

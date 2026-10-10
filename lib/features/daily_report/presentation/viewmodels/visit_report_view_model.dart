import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vthm_dms/features/visit/data/repositories/visit_repository_impl.dart';
import 'package:vthm_dms/features/visit/domain/entities/visit_entity.dart';
import 'package:vthm_dms/features/visit/domain/repositories/visit_repository.dart';

class VisitReportState {
  final DateTime selectedDate;
  final List<VisitEntity> visits;
  final bool isLoading;
  final String? errorMessage;
  final String selectedFilter; // 'all' | 'visited' | 'closed' | 'in_progress'

  const VisitReportState({
    required this.selectedDate,
    this.visits = const [],
    this.isLoading = false,
    this.errorMessage,
    this.selectedFilter = 'all',
  });

  int get totalVisits => visits.length;

  int get visitedCount => visits.where((v) {
        if (v.visitResult == 'visited') return true;
        return v.isCompleted && v.visitResult != 'closed';
      }).length;

  int get closedCount =>
      visits.where((v) => v.visitResult == 'closed').length;

  int get inProgressCount => visits.where((v) => v.isOpen).length;

  int get totalDurationSeconds =>
      visits.fold(0, (sum, v) => sum + (v.durationSeconds ?? 0));

  String get formattedDuration {
    final sec = totalDurationSeconds;
    if (sec <= 0) return '0 phút';
    final hours = sec ~/ 3600;
    final minutes = (sec % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '$minutes phút';
  }

  int get totalPhotos => visits.fold(0, (sum, v) => sum + v.photoCount);

  int get totalForms => visits.fold(0, (sum, v) => sum + v.formCount);

  List<VisitEntity> get filteredVisits {
    return visits.where((v) {
      if (v.isCancelled) return false; // Theo §2 HUY-LUOT-VIENG-THAM: ẩn hẳn khỏi báo cáo
      if (selectedFilter == 'visited') {
        return v.visitResult == 'visited' ||
            (v.isCompleted && v.visitResult != 'closed');
      }
      if (selectedFilter == 'closed') {
        return v.visitResult == 'closed';
      }
      if (selectedFilter == 'in_progress') {
        return v.isOpen;
      }
      return true;
    }).toList();
  }

  VisitReportState copyWith({
    DateTime? selectedDate,
    List<VisitEntity>? visits,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    String? selectedFilter,
  }) {
    return VisitReportState(
      selectedDate: selectedDate ?? this.selectedDate,
      visits: visits ?? this.visits,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      selectedFilter: selectedFilter ?? this.selectedFilter,
    );
  }
}

final visitReportViewModelProvider =
    StateNotifierProvider<VisitReportViewModel, VisitReportState>((ref) {
  return VisitReportViewModel(
    visitRepository: ref.watch(visitRepositoryProvider),
  );
});

class VisitReportViewModel extends StateNotifier<VisitReportState> {
  final VisitRepository visitRepository;

  VisitReportViewModel({
    required this.visitRepository,
  })  : super(VisitReportState(selectedDate: DateTime.now())) {
    loadVisits();
  }

  Future<void> loadVisits({bool forceRefresh = false}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final visits = await visitRepository.getVisitsByDate(
        state.selectedDate,
        forceRefresh: forceRefresh,
      );
      state = state.copyWith(
        visits: visits,
        isLoading: false,
      );
    } catch (e) {
      // Trong trường hợp lỗi API, vẫn đọc dữ liệu cục bộ đã lưu
      final all = await visitRepository.getAllLocalVisits();
      state = state.copyWith(
        visits: all,
        isLoading: false,
        errorMessage: 'Đang hiển thị dữ liệu lưu cục bộ',
      );
    }
  }

  void setDate(DateTime date) {
    if (state.selectedDate.year == date.year &&
        state.selectedDate.month == date.month &&
        state.selectedDate.day == date.day) {
      return;
    }
    state = state.copyWith(selectedDate: date);
    loadVisits();
  }

  void setFilter(String filter) {
    state = state.copyWith(selectedFilter: filter);
  }
}

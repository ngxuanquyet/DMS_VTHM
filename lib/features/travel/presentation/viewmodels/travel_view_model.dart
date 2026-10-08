import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/travel_day_entity.dart';
import '../../domain/repositories/travel_repository.dart';
import '../../data/repositories/travel_repository_impl.dart';
import '../states/travel_state.dart';

final travelViewModelProvider =
    StateNotifierProvider<TravelViewModel, TravelState>((ref) {
  return TravelViewModel(ref.watch(travelRepositoryProvider));
});

class TravelViewModel extends StateNotifier<TravelState> {
  final TravelRepository _repository;

  TravelViewModel(this._repository) : super(const TravelState()) {
    _initDefaultDateRange();
    loadMyTravel();
  }

  void _initDefaultDateRange() {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

    state = state.copyWith(
      fromDate: firstDayOfMonth,
      toDate: lastDayOfMonth,
      filterPreset: DateFilterPreset.thisMonth,
    );
  }

  /// Tải danh sách quãng đường theo ngày của tôi (§4.1)
  Future<void> loadMyTravel({bool refresh = false}) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final fromStr = state.fromDate != null
          ? DateFormat('yyyy-MM-dd').format(state.fromDate!)
          : null;
      final toStr = state.toDate != null
          ? DateFormat('yyyy-MM-dd').format(state.toDate!)
          : null;

      final result = await _repository.getMyTravel(
        from: fromStr,
        to: toStr,
        page: 1,
        perPage: 50,
        sort: '-work_date',
        forceRefresh: refresh,
      );

      state = state.copyWith(
        isLoading: false,
        days: result,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Tải chi tiết các chặng trong 1 ngày (§4.2)
  Future<void> loadLegsForDay(TravelDayEntity day, {bool refresh = false}) async {
    state = state.copyWith(
      isLoadingLegs: true,
      selectedDay: day,
      currentDayLegs: const [],
      clearError: true,
    );

    try {
      final legs = await _repository.getTravelLegs(
        userId: day.userId,
        workDate: day.workDate,
        forceRefresh: refresh,
      );

      state = state.copyWith(
        isLoadingLegs: false,
        currentDayLegs: legs,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingLegs: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Thay đổi bộ lọc thời gian
  void setFilterPreset(DateFilterPreset preset) {
    final now = DateTime.now();
    DateTime? from;
    DateTime? to;

    switch (preset) {
      case DateFilterPreset.thisMonth:
        from = DateTime(now.year, now.month, 1);
        to = DateTime(now.year, now.month + 1, 0);
        break;
      case DateFilterPreset.lastMonth:
        from = DateTime(now.year, now.month - 1, 1);
        to = DateTime(now.year, now.month, 0);
        break;
      case DateFilterPreset.last7Days:
        from = now.subtract(const Duration(days: 6));
        to = now;
        break;
      case DateFilterPreset.all:
        from = null;
        to = null;
        break;
      case DateFilterPreset.custom:
        // Giữ nguyên range hiện tại
        from = state.fromDate;
        to = state.toDate;
        break;
    }

    state = state.copyWith(
      filterPreset: preset,
      fromDate: from,
      toDate: to,
    );

    loadMyTravel(refresh: true);
  }

  /// Thiết lập khoảng ngày tùy chọn
  void setCustomDateRange(DateTime from, DateTime to) {
    state = state.copyWith(
      filterPreset: DateFilterPreset.custom,
      fromDate: from,
      toDate: to,
    );

    loadMyTravel(refresh: true);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

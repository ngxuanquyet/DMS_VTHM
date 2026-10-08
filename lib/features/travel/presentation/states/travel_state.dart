import '../../domain/entities/travel_day_entity.dart';
import '../../domain/entities/travel_leg_entity.dart';

enum DateFilterPreset {
  thisMonth,
  lastMonth,
  last7Days,
  all,
  custom,
}

class TravelState {
  final bool isLoading;
  final bool isLoadingLegs;
  final List<TravelDayEntity> days;
  final List<TravelLegEntity> currentDayLegs;
  final TravelDayEntity? selectedDay;
  final DateTime? fromDate;
  final DateTime? toDate;
  final DateFilterPreset filterPreset;
  final String? errorMessage;

  const TravelState({
    this.isLoading = false,
    this.isLoadingLegs = false,
    this.days = const [],
    this.currentDayLegs = const [],
    this.selectedDay,
    this.fromDate,
    this.toDate,
    this.filterPreset = DateFilterPreset.thisMonth,
    this.errorMessage,
  });

  /// Tổng số km của các ngày đã chốt hoàn toàn (is_complete = true)
  double get totalFinalizedKm {
    return days.fold(0.0, (sum, d) {
      if (d.isComplete && d.roadKm != null) {
        return sum + d.roadKm!.toDouble();
      }
      return sum;
    });
  }

  /// Tổng số km tạm tính của các ngày chưa chốt (is_complete = false)
  double get totalPendingKm {
    return days.fold(0.0, (sum, d) {
      if (!d.isComplete && d.roadKm != null) {
        return sum + d.roadKm!.toDouble();
      }
      return sum;
    });
  }

  /// Tổng số ngày có dữ liệu
  int get totalDays => days.length;

  /// Số ngày đã chốt
  int get completedDaysCount => days.where((d) => d.isComplete).length;

  /// Số ngày còn chặng chưa tính (chưa chốt)
  int get pendingDaysCount => days.where((d) => !d.isComplete && d.legCount > 0).length;

  /// Tổng số chặng thiếu mốc (0 km)
  int get totalMissingAnchorsCount =>
      days.fold(0, (sum, d) => sum + d.legMissingCount);

  /// Tổng số chặng lỗi/chờ tính
  int get totalErrorLegsCount =>
      days.fold(0, (sum, d) => sum + d.legErrorCount);

  TravelState copyWith({
    bool? isLoading,
    bool? isLoadingLegs,
    List<TravelDayEntity>? days,
    List<TravelLegEntity>? currentDayLegs,
    TravelDayEntity? selectedDay,
    DateTime? fromDate,
    DateTime? toDate,
    DateFilterPreset? filterPreset,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TravelState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingLegs: isLoadingLegs ?? this.isLoadingLegs,
      days: days ?? this.days,
      currentDayLegs: currentDayLegs ?? this.currentDayLegs,
      selectedDay: selectedDay ?? this.selectedDay,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      filterPreset: filterPreset ?? this.filterPreset,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

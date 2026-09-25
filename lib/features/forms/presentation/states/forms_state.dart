import '../../domain/entities/form_entity.dart';
import '../../domain/entities/market_form_entity.dart';

enum FormsStatus { initial, loading, loaded, error }

class FormsState {
  final FormsStatus status;
  final List<MarketFormConfigEntity> marketForms;
  final List<FormItemEntity> allForms;
  final int selectedTabIndex; // 0: Tất cả, 1: Chưa nộp, 2: Đã nộp
  final String searchQuery;
  final Set<int> submittedConfigIds;
  final String? errorMessage;

  const FormsState({
    this.status = FormsStatus.initial,
    this.marketForms = const [],
    this.allForms = const [],
    this.selectedTabIndex = 0,
    this.searchQuery = '',
    this.submittedConfigIds = const {},
    this.errorMessage,
  });

  List<MarketFormConfigEntity> get filteredMarketForms {
    var list = marketForms;
    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      list = list.where((f) =>
          f.name.toLowerCase().contains(q) ||
          f.code.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  List<FormItemEntity> get filteredForms {
    switch (selectedTabIndex) {
      case 1:
        return allForms.where((f) => f.status == FormStatusType.inProgress).toList();
      case 2:
        return allForms.where((f) => f.status == FormStatusType.completed).toList();
      default:
        return allForms;
    }
  }

  FormsState copyWith({
    FormsStatus? status,
    List<MarketFormConfigEntity>? marketForms,
    List<FormItemEntity>? allForms,
    int? selectedTabIndex,
    String? searchQuery,
    Set<int>? submittedConfigIds,
    String? errorMessage,
  }) {
    return FormsState(
      status: status ?? this.status,
      marketForms: marketForms ?? this.marketForms,
      allForms: allForms ?? this.allForms,
      selectedTabIndex: selectedTabIndex ?? this.selectedTabIndex,
      searchQuery: searchQuery ?? this.searchQuery,
      submittedConfigIds: submittedConfigIds ?? this.submittedConfigIds,
      errorMessage: errorMessage,
    );
  }
}

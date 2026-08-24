import '../../domain/entities/form_entity.dart';

enum FormsStatus { initial, loading, loaded, error }

class FormsState {
  final FormsStatus status;
  final List<FormItemEntity> allForms;
  final int selectedTabIndex; // 0: Cần làm, 1: Đang thực hiện, 2: Hoàn thành
  final String? errorMessage;

  const FormsState({
    this.status = FormsStatus.initial,
    this.allForms = const [],
    this.selectedTabIndex = 0,
    this.errorMessage,
  });

  List<FormItemEntity> get filteredForms {
    switch (selectedTabIndex) {
      case 0:
        return allForms.where((f) => f.status == FormStatusType.todo).toList();
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
    List<FormItemEntity>? allForms,
    int? selectedTabIndex,
    String? errorMessage,
  }) {
    return FormsState(
      status: status ?? this.status,
      allForms: allForms ?? this.allForms,
      selectedTabIndex: selectedTabIndex ?? this.selectedTabIndex,
      errorMessage: errorMessage,
    );
  }
}

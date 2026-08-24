import '../../domain/entities/form_entity.dart';

class FormItemModel {
  final String id;
  final String title;
  final String dealerName;
  final String deadline;
  final String status;
  final String statusLabel;
  final int questionsCount;
  final int answeredCount;
  final double progressPercent;

  const FormItemModel({
    required this.id,
    required this.title,
    required this.dealerName,
    required this.deadline,
    required this.status,
    required this.statusLabel,
    required this.questionsCount,
    required this.answeredCount,
    required this.progressPercent,
  });

  factory FormItemModel.fromJson(Map<String, dynamic> json) {
    return FormItemModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      dealerName: json['dealerName'] as String? ?? '',
      deadline: json['deadline'] as String? ?? '',
      status: json['status'] as String? ?? 'todo',
      statusLabel: json['statusLabel'] as String? ?? '',
      questionsCount: (json['questionsCount'] as num?)?.toInt() ?? 0,
      answeredCount: (json['answeredCount'] as num?)?.toInt() ?? 0,
      progressPercent: (json['progressPercent'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'dealerName': dealerName,
        'deadline': deadline,
        'status': status,
        'statusLabel': statusLabel,
        'questionsCount': questionsCount,
        'answeredCount': answeredCount,
        'progressPercent': progressPercent,
      };

  FormItemEntity toEntity() {
    FormStatusType type;
    switch (status) {
      case 'in_progress':
        type = FormStatusType.inProgress;
        break;
      case 'completed':
        type = FormStatusType.completed;
        break;
      default:
        type = FormStatusType.todo;
    }

    return FormItemEntity(
      id: id,
      title: title,
      dealerName: dealerName,
      deadline: deadline,
      status: type,
      statusLabel: statusLabel,
      questionsCount: questionsCount,
      answeredCount: answeredCount,
      progressPercent: progressPercent,
    );
  }
}

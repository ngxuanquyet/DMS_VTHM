enum FormStatusType { todo, inProgress, completed }

class FormItemEntity {
  final String id;
  final String title;
  final String dealerName;
  final String deadline;
  final FormStatusType status;
  final String statusLabel;
  final int questionsCount;
  final int answeredCount;
  final double progressPercent;

  const FormItemEntity({
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
}

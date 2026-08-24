import '../../domain/entities/notification_entity.dart';

class NotificationModel {
  final String id;
  final String type;
  final String title;
  final String message;
  final String timeAgo;
  final bool isRead;
  final String category;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timeAgo,
    this.isRead = false,
    this.category = 'work',
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'system',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      timeAgo: json['timeAgo'] as String? ?? '',
      isRead: json['isRead'] as bool? ?? false,
      category: json['category'] as String? ?? 'work',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'message': message,
        'timeAgo': timeAgo,
        'isRead': isRead,
        'category': category,
      };

  NotificationEntity toEntity() => NotificationEntity(
        id: id,
        type: type,
        title: title,
        message: message,
        timeAgo: timeAgo,
        isRead: isRead,
        category: category,
      );
}

class NotificationDataModel {
  final List<NotificationModel> today;
  final List<NotificationModel> earlier;

  const NotificationDataModel({
    required this.today,
    required this.earlier,
  });

  factory NotificationDataModel.fromJson(Map<String, dynamic> json) {
    return NotificationDataModel(
      today: (json['today'] as List<dynamic>? ?? [])
          .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      earlier: (json['earlier'] as List<dynamic>? ?? [])
          .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'today': today.map((e) => e.toJson()).toList(),
        'earlier': earlier.map((e) => e.toJson()).toList(),
      };

  NotificationDataEntity toEntity() => NotificationDataEntity(
        today: today.map((e) => e.toEntity()).toList(),
        earlier: earlier.map((e) => e.toEntity()).toList(),
      );
}

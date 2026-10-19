import '../../domain/entities/notification_entity.dart';

class NotificationModel {
  final String id;
  final String type;
  final String title;
  final String message;
  final String timeAgo;
  final bool isRead;
  final String category;
  final String? routePath;
  final DateTime? createdAt;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timeAgo,
    this.isRead = false,
    this.category = 'work',
    this.routePath,
    this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'] is Map<String, dynamic> ? json['data'] as Map<String, dynamic> : null;
    final resolvedPath = (json['routePath'] ?? json['link'] ?? json['url'] ?? rawData?['link'] ?? rawData?['routePath']) as String?;
    final resolvedMessage = (json['message'] ?? json['body'] ?? rawData?['message'] ?? rawData?['body'] ?? '') as String;
    final resolvedType = (json['type'] ?? rawData?['type'] ?? 'system') as String;

    return NotificationModel(
      id: json['id'] as String? ?? '',
      type: resolvedType,
      title: json['title'] as String? ?? '',
      message: resolvedMessage,
      timeAgo: json['timeAgo'] as String? ?? '',
      isRead: json['isRead'] as bool? ?? false,
      category: json['category'] as String? ?? 'work',
      routePath: resolvedPath,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
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
        if (routePath != null) 'routePath': routePath,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      };

  NotificationEntity toEntity() => NotificationEntity(
        id: id,
        type: type,
        title: title,
        message: message,
        timeAgo: timeAgo,
        isRead: isRead,
        category: category,
        routePath: routePath,
        createdAt: createdAt,
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

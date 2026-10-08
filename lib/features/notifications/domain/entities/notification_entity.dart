class NotificationEntity {
  final String id;
  final String type; // attendance | route | form | checkin | system
  final String title;
  final String message;
  final String timeAgo;
  final bool isRead;
  final String category; // work | system

  final String? routePath;
  final DateTime? createdAt;

  const NotificationEntity({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timeAgo,
    required this.isRead,
    required this.category,
    this.routePath,
    this.createdAt,
  });

  NotificationEntity copyWith({
    String? id,
    String? type,
    String? title,
    String? message,
    String? timeAgo,
    bool? isRead,
    String? category,
    String? routePath,
    DateTime? createdAt,
  }) {
    return NotificationEntity(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      timeAgo: timeAgo ?? this.timeAgo,
      isRead: isRead ?? this.isRead,
      category: category ?? this.category,
      routePath: routePath ?? this.routePath,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class NotificationDataEntity {
  final List<NotificationEntity> today;
  final List<NotificationEntity> earlier;

  const NotificationDataEntity({
    required this.today,
    required this.earlier,
  });
}

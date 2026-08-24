import '../../domain/entities/route_entity.dart';

class DealerModel {
  final String id;
  final String order;
  final String name;
  final String address;
  final String status;
  final String statusLabel;
  final String? visitedTime;
  final bool isVip;

  const DealerModel({
    required this.id,
    required this.order,
    required this.name,
    required this.address,
    required this.status,
    required this.statusLabel,
    this.visitedTime,
    this.isVip = false,
  });

  factory DealerModel.fromJson(Map<String, dynamic> json) {
    return DealerModel(
      id: json['id'] as String? ?? '',
      order: json['order'] as String? ?? '',
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      statusLabel: json['statusLabel'] as String? ?? '',
      visitedTime: json['visitedTime'] as String?,
      isVip: json['isVip'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'order': order,
        'name': name,
        'address': address,
        'status': status,
        'statusLabel': statusLabel,
        'visitedTime': visitedTime,
        'isVip': isVip,
      };

  DealerEntity toEntity() {
    DealerVisitStatus visitStatus;
    switch (status) {
      case 'completed':
        visitStatus = DealerVisitStatus.completed;
        break;
      case 'in_progress':
        visitStatus = DealerVisitStatus.inProgress;
        break;
      default:
        visitStatus = DealerVisitStatus.pending;
    }

    return DealerEntity(
      id: id,
      order: order,
      name: name,
      address: address,
      status: visitStatus,
      statusLabel: statusLabel,
      visitedTime: visitedTime,
      isVip: isVip,
    );
  }
}

class RouteDetailModel {
  final String id;
  final String title;
  final int totalDealers;
  final int completedDealers;
  final int pendingDealers;
  final double progressPercent;
  final List<DealerModel> dealers;

  const RouteDetailModel({
    required this.id,
    required this.title,
    required this.totalDealers,
    required this.completedDealers,
    required this.pendingDealers,
    required this.progressPercent,
    required this.dealers,
  });

  factory RouteDetailModel.fromJson(Map<String, dynamic> json) {
    return RouteDetailModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      totalDealers: (json['totalDealers'] as num?)?.toInt() ?? 0,
      completedDealers: (json['completedDealers'] as num?)?.toInt() ?? 0,
      pendingDealers: (json['pendingDealers'] as num?)?.toInt() ?? 0,
      progressPercent: (json['progressPercent'] as num?)?.toDouble() ?? 0.0,
      dealers: (json['dealers'] as List<dynamic>? ?? [])
          .map((e) => DealerModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'totalDealers': totalDealers,
        'completedDealers': completedDealers,
        'pendingDealers': pendingDealers,
        'progressPercent': progressPercent,
        'dealers': dealers.map((e) => e.toJson()).toList(),
      };

  RouteDetailEntity toEntity() => RouteDetailEntity(
        id: id,
        title: title,
        totalDealers: totalDealers,
        completedDealers: completedDealers,
        pendingDealers: pendingDealers,
        progressPercent: progressPercent,
        dealers: dealers.map((e) => e.toEntity()).toList(),
      );
}

class CheckinDealerModel {
  final String id;
  final String name;
  final String address;
  final bool isVip;
  final int distanceMeters;
  final String visitDuration;

  const CheckinDealerModel({
    required this.id,
    required this.name,
    required this.address,
    this.isVip = false,
    required this.distanceMeters,
    required this.visitDuration,
  });

  factory CheckinDealerModel.fromJson(Map<String, dynamic> json) {
    return CheckinDealerModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      isVip: json['isVip'] as bool? ?? false,
      distanceMeters: (json['distanceMeters'] as num?)?.toInt() ?? 0,
      visitDuration: json['visitDuration'] as String? ?? '00:00:00',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'isVip': isVip,
        'distanceMeters': distanceMeters,
        'visitDuration': visitDuration,
      };

  CheckinDealerEntity toEntity() => CheckinDealerEntity(
        id: id,
        name: name,
        address: address,
        isVip: isVip,
        distanceMeters: distanceMeters,
        visitDuration: visitDuration,
      );
}

class CheckinTaskModel {
  final String id;
  final String title;
  final String subtitle;
  final int completed;
  final int total;
  final String type;
  final bool isError;

  const CheckinTaskModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.completed,
    required this.total,
    required this.type,
    this.isError = false,
  });

  factory CheckinTaskModel.fromJson(Map<String, dynamic> json) {
    return CheckinTaskModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      completed: (json['completed'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
      type: json['type'] as String? ?? 'form',
      isError: json['isError'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'completed': completed,
        'total': total,
        'type': type,
        'isError': isError,
      };

  CheckinTaskEntity toEntity() => CheckinTaskEntity(
        id: id,
        title: title,
        subtitle: subtitle,
        completed: completed,
        total: total,
        type: type,
        isError: isError,
      );
}

class DealerCheckinDataModel {
  final CheckinDealerModel dealer;
  final List<CheckinTaskModel> tasks;

  const DealerCheckinDataModel({
    required this.dealer,
    required this.tasks,
  });

  factory DealerCheckinDataModel.fromJson(Map<String, dynamic> json) {
    return DealerCheckinDataModel(
      dealer: CheckinDealerModel.fromJson(
        json['dealer'] as Map<String, dynamic>? ?? {},
      ),
      tasks: (json['tasks'] as List<dynamic>? ?? [])
          .map((e) => CheckinTaskModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'dealer': dealer.toJson(),
        'tasks': tasks.map((e) => e.toJson()).toList(),
      };

  DealerCheckinDataEntity toEntity() => DealerCheckinDataEntity(
        dealer: dealer.toEntity(),
        tasks: tasks.map((e) => e.toEntity()).toList(),
      );
}

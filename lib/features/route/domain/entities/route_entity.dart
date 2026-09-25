enum DealerVisitStatus { completed, inProgress, pending }

class DealerEntity {
  final String id;
  final String order;
  final String name;
  final String? code;
  final String? phone;
  final String? contactPerson;
  final String? type;
  final String address;
  final DealerVisitStatus status;
  final String statusLabel;
  final String? visitedTime;
  final bool isVip;
  final double? lat;
  final double? lng;
  final dynamic customer;

  const DealerEntity({
    required this.id,
    required this.order,
    required this.name,
    this.code,
    this.phone,
    this.contactPerson,
    this.type,
    required this.address,
    required this.status,
    required this.statusLabel,
    this.visitedTime,
    required this.isVip,
    this.lat,
    this.lng,
    this.customer,
  });
}

class RouteDetailEntity {
  final String id;
  final String title;
  final int totalDealers;
  final int completedDealers;
  final int pendingDealers;
  final double progressPercent;
  final List<DealerEntity> dealers;

  const RouteDetailEntity({
    required this.id,
    required this.title,
    required this.totalDealers,
    required this.completedDealers,
    required this.pendingDealers,
    required this.progressPercent,
    required this.dealers,
  });
}

class CheckinDealerEntity {
  final String id;
  final String name;
  final String address;
  final bool isVip;
  final int distanceMeters;
  final String visitDuration;
  final double? lat;
  final double? lng;

  const CheckinDealerEntity({
    required this.id,
    required this.name,
    required this.address,
    required this.isVip,
    required this.distanceMeters,
    required this.visitDuration,
    this.lat,
    this.lng,
  });
}

class CheckinTaskEntity {
  final String id;
  final String title;
  final String subtitle;
  final int completed;
  final int total;
  final String type; // form | photo | note
  final bool isError;

  const CheckinTaskEntity({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.completed,
    required this.total,
    required this.type,
    this.isError = false,
  });
}

class DealerCheckinDataEntity {
  final CheckinDealerEntity dealer;
  final List<CheckinTaskEntity> tasks;

  const DealerCheckinDataEntity({
    required this.dealer,
    required this.tasks,
  });
}

/// Tuyến đường của chính nhân viên thị trường (GET /dms/routes/mine)
class UserRouteEntity {
  final int id;
  final String name;
  final String? code;
  final int? visitDayOfWeek;
  final int? saleGroupId;
  final bool isActive;

  const UserRouteEntity({
    required this.id,
    required this.name,
    this.code,
    this.visitDayOfWeek,
    this.saleGroupId,
    this.isActive = true,
  });

  /// Tên thứ trong tuần (1: Thứ 2, 2: Thứ 3, ..., 7: Chủ nhật)
  String get dayOfWeekName {
    switch (visitDayOfWeek) {
      case 1:
        return 'Thứ 2';
      case 2:
        return 'Thứ 3';
      case 3:
        return 'Thứ 4';
      case 4:
        return 'Thứ 5';
      case 5:
        return 'Thứ 6';
      case 6:
        return 'Thứ 7';
      case 7:
        return 'Chủ nhật';
      default:
        return '';
    }
  }

  factory UserRouteEntity.fromJson(Map<String, dynamic> json) {
    final rawName = json['name']?.toString() ?? json['title']?.toString() ?? json['code']?.toString() ?? '';
    return UserRouteEntity(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: rawName,
      code: json['code']?.toString(),
      visitDayOfWeek: json['visit_day_of_week'] is int
          ? json['visit_day_of_week'] as int
          : int.tryParse(json['visit_day_of_week']?.toString() ?? ''),
      saleGroupId: json['sale_group_id'] is int
          ? json['sale_group_id'] as int
          : int.tryParse(json['sale_group_id']?.toString() ?? ''),
      isActive: json['is_active'] == null
          ? true
          : (json['is_active'] == true ||
              json['is_active'] == 1 ||
              json['status'] == 'active' ||
              json['status'] == 1),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (code != null) 'code': code,
      if (visitDayOfWeek != null) 'visit_day_of_week': visitDayOfWeek,
      if (saleGroupId != null) 'sale_group_id': saleGroupId,
      'is_active': isActive,
    };
  }
}


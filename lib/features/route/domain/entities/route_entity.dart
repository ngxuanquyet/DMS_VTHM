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

  const CheckinDealerEntity({
    required this.id,
    required this.name,
    required this.address,
    required this.isVip,
    required this.distanceMeters,
    required this.visitDuration,
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

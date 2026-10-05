enum DailyActivityType {
  attendanceIn,
  attendanceOut,
  checkIn,
  checkOut,
  positionDeclaration,
  formSubmission,
}

class DailyActivityEntity {
  final String id;
  final String time;
  final String title;
  final String subtitle;
  final DailyActivityType type;
  final String? customerName;
  final String? customerAddress;
  final double? lat;
  final double? lng;
  final List<String> photos;
  final String? notes;
  final bool isSynced;
  final bool isHighlight;

  const DailyActivityEntity({
    required this.id,
    required this.time,
    required this.title,
    required this.subtitle,
    required this.type,
    this.customerName,
    this.customerAddress,
    this.lat,
    this.lng,
    this.photos = const [],
    this.notes,
    this.isSynced = true,
    this.isHighlight = false,
  });
}

// DTO cho điểm bán thuộc tuyến được giao cho nhân viên (GET /dms/routes/customers)
// Theo đặc tả API-BIEU-MAU-THI-TRUONG-2026-09-23.md (§1b)

class RouteCustomerItem {
  final int id;
  final String code;
  final String name;
  final String? address;
  final double? lat;
  final double? lng;

  const RouteCustomerItem({
    required this.id,
    required this.code,
    required this.name,
    this.address,
    this.lat,
    this.lng,
  });

  bool get hasCoordinates =>
      lat != null && lng != null && lat != 0 && lng != 0;

  factory RouteCustomerItem.fromJson(Map<String, dynamic> json) {
    return RouteCustomerItem(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id'].toString()) ?? 0,
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString(),
      lat: (json['lat'] ?? json['latitude']) is num
          ? (json['lat'] ?? json['latitude'] as num).toDouble()
          : double.tryParse(
              (json['lat'] ?? json['latitude'])?.toString() ?? ''),
      lng: (json['lng'] ?? json['longitude']) is num
          ? (json['lng'] ?? json['longitude'] as num).toDouble()
          : double.tryParse(
              (json['lng'] ?? json['longitude'])?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      if (address != null) 'address': address,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    };
  }

  RouteCustomerItem copyWith({
    int? id,
    String? code,
    String? name,
    String? address,
    double? lat,
    double? lng,
  }) {
    return RouteCustomerItem(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      address: address ?? this.address,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RouteCustomerItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class RouteCustomersData {
  final List<RouteCustomerItem> items;
  final bool truncated;

  const RouteCustomersData({
    required this.items,
    this.truncated = false,
  });

  factory RouteCustomersData.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List<dynamic>? ?? [];
    return RouteCustomersData(
      items: list
          .whereType<Map<String, dynamic>>()
          .map((item) => RouteCustomerItem.fromJson(item))
          .toList(),
      truncated: json['truncated'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((e) => e.toJson()).toList(),
      'truncated': truncated,
    };
  }
}

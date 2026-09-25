// DTO cho điểm bán thuộc tuyến được giao cho nhân viên (GET /dms/routes/customers)
// Theo đặc tả API-BIEU-MAU-THI-TRUONG-2026-09-23.md (§1b)

class RouteCustomerItem {
  final int id;
  final String code;
  final String name;
  final String? address;

  const RouteCustomerItem({
    required this.id,
    required this.code,
    required this.name,
    this.address,
  });

  factory RouteCustomerItem.fromJson(Map<String, dynamic> json) {
    return RouteCustomerItem(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id'].toString()) ?? 0,
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      if (address != null) 'address': address,
    };
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

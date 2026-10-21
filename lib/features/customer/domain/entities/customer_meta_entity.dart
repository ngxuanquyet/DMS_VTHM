import 'customer_dynamic_column.dart';

class CustomerCategoryItem {
  final int id;
  final String code;
  final String name;
  final String? color;

  const CustomerCategoryItem({
    required this.id,
    required this.code,
    required this.name,
    this.color,
  });

  factory CustomerCategoryItem.fromJson(Map<String, dynamic> json) {
    return CustomerCategoryItem(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      color: json['color']?.toString(),
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      if (color != null) 'color': color,
    };
  }
}

class CustomerProvinceItem {
  final String provinceName;
  final int? count;

  const CustomerProvinceItem({
    required this.provinceName,
    this.count,
  });

  factory CustomerProvinceItem.fromJson(Map<String, dynamic> json) {
    return CustomerProvinceItem(
      provinceName: json['province_name']?.toString() ?? '',
      count: json['cnt'] is int ? json['cnt'] as int : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'province_name': provinceName,
      if (count != null) 'cnt': count,
    };
  }
}

/// Kênh + tuyến tự khai ĐIỀN SẴN khi tạo điểm bán (`GET /crm/customers/meta` → `createChoices`): theo phòng người đăng
/// nhập, chỉ là tiện ích — người dùng chọn tuỳ ý trong toàn danh mục (chủ hệ thống chốt 21/10/2026). Server vẫn gửi khoá
/// `pairs` (luôn `null`), app không đọc.
class CustomerCreateChoices {
  final List<int> defaultChannelIds;
  final String? defaultTerritoryCode;

  const CustomerCreateChoices({this.defaultChannelIds = const [], this.defaultTerritoryCode});

  factory CustomerCreateChoices.fromJson(Map<String, dynamic> json) {
    final t = json['default_territory_code']?.toString().trim();
    return CustomerCreateChoices(
      defaultChannelIds: json['default_channel_ids'] is List
          ? (json['default_channel_ids'] as List).map((e) => int.tryParse(e.toString())).whereType<int>().toList()
          : const [],
      defaultTerritoryCode: t == null || t.isEmpty ? null : t,
    );
  }

  Map<String, dynamic> toJson() => {
        'default_channel_ids': defaultChannelIds,
        'default_territory_code': defaultTerritoryCode,
      };
}

class CustomerMetaData {
  final List<CustomerCategoryItem> customerTypes;
  final List<CustomerCategoryItem> channels;
  final List<CustomerCategoryItem> regions;
  final List<CustomerProvinceItem> provinces;
  final List<CustomerDynamicColumn> dynamicColumns;

  /// Danh mục Kênh Bravo (`sales_channel`: id, code = mã ngắn, name) — ô Kênh tự khai.
  final List<CustomerCategoryItem> salesChannels;

  /// Danh mục Tuyến Bravo (`sales_territory`: code, name) — ô Tuyến tự khai.
  final List<CustomerCategoryItem> territories;

  /// NULL khi server chưa trả (bản cũ / bản lưu cũ) ⇒ màn tạo không vẽ hai ô Kênh/Tuyến.
  final CustomerCreateChoices? createChoices;

  const CustomerMetaData({
    this.customerTypes = const [],
    this.channels = const [],
    this.regions = const [],
    this.provinces = const [],
    this.dynamicColumns = const [],
    this.salesChannels = const [],
    this.territories = const [],
    this.createChoices,
  });

  factory CustomerMetaData.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;

    List<CustomerCategoryItem> parseCategoryList(dynamic list) {
      if (list is List) {
        return list
            .whereType<Map<String, dynamic>>()
            .map((e) => CustomerCategoryItem.fromJson(e))
            .toList();
      }
      return [];
    }

    List<CustomerProvinceItem> parseProvinces(dynamic list) {
      if (list is List) {
        return list
            .whereType<Map<String, dynamic>>()
            .map((e) => CustomerProvinceItem.fromJson(e))
            .where((p) => p.provinceName.isNotEmpty)
            .toList();
      }
      return [];
    }

    List<CustomerDynamicColumn> parseDynamicColumns(dynamic list) {
      if (list is List) {
        return list
            .whereType<Map<String, dynamic>>()
            .map((e) => CustomerDynamicColumn.fromJson(e))
            .toList();
      }
      return [];
    }

    return CustomerMetaData(
      customerTypes: parseCategoryList(data['customerTypes']),
      channels: parseCategoryList(data['channels']),
      regions: parseCategoryList(data['regions']),
      provinces: parseProvinces(data['provinces']),
      dynamicColumns: parseDynamicColumns(data['dynamicColumns']),
      salesChannels: parseCategoryList(data['salesChannels']),
      territories: parseCategoryList(data['territories']),
      createChoices: data['createChoices'] is Map<String, dynamic>
          ? CustomerCreateChoices.fromJson(data['createChoices'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'data': {
        'customerTypes': customerTypes.map((e) => e.toJson()).toList(),
        'channels': channels.map((e) => e.toJson()).toList(),
        'regions': regions.map((e) => e.toJson()).toList(),
        'provinces': provinces.map((e) => e.toJson()).toList(),
        'dynamicColumns': dynamicColumns.map((e) => e.toJson()).toList(),
        'salesChannels': salesChannels.map((e) => e.toJson()).toList(),
        'territories': territories.map((e) => e.toJson()).toList(),
        if (createChoices != null) 'createChoices': createChoices!.toJson(),
      }
    };
  }
}

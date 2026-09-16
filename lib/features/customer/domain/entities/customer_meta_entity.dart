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
}

class CustomerMetaData {
  final List<CustomerCategoryItem> customerTypes;
  final List<CustomerCategoryItem> channels;
  final List<CustomerCategoryItem> regions;
  final List<CustomerProvinceItem> provinces;
  final List<CustomerDynamicColumn> dynamicColumns;

  const CustomerMetaData({
    this.customerTypes = const [],
    this.channels = const [],
    this.regions = const [],
    this.provinces = const [],
    this.dynamicColumns = const [],
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
    );
  }
}

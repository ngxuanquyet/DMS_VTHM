import 'package:flutter/material.dart';
import '../../features/customer/domain/entities/customer_entity.dart';
import '../utils/string_utils.dart';

/// Các tiêu chí tìm kiếm điểm bán / khách hàng trên thanh tìm kiếm
enum SearchTarget {
  all,
  name,
  code,
  route,
  address,
  phone;

  /// Nhãn hiển thị trên Chip hoặc Menu
  String get label {
    switch (this) {
      case SearchTarget.all:
        return 'Tất cả';
      case SearchTarget.name:
        return 'Tên';
      case SearchTarget.code:
        return 'Mã';
      case SearchTarget.route:
        return 'Tuyến';
      case SearchTarget.address:
        return 'Địa chỉ';
      case SearchTarget.phone:
        return 'SĐT';
    }
  }

  /// Gợi ý placeholder trên thanh tìm kiếm
  String get hintText {
    switch (this) {
      case SearchTarget.all:
        return 'Tìm theo tên, mã, tuyến, địa chỉ, SĐT...';
      case SearchTarget.name:
        return 'Tìm theo tên điểm bán...';
      case SearchTarget.code:
        return 'Tìm theo mã điểm bán (VD: KH01)...';
      case SearchTarget.route:
        return 'Tìm theo tên tuyến bán hàng...';
      case SearchTarget.address:
        return 'Tìm theo địa chỉ, quận, huyện, tỉnh...';
      case SearchTarget.phone:
        return 'Tìm theo số điện thoại liên hệ...';
    }
  }

  /// Biểu tượng minh họa cho từng tiêu chí
  IconData get icon {
    switch (this) {
      case SearchTarget.all:
        return Icons.all_inclusive_rounded;
      case SearchTarget.name:
        return Icons.storefront_rounded;
      case SearchTarget.code:
        return Icons.badge_outlined;
      case SearchTarget.route:
        return Icons.alt_route_rounded;
      case SearchTarget.address:
        return Icons.location_on_outlined;
      case SearchTarget.phone:
        return Icons.phone_outlined;
    }
  }

  /// Kiểm tra khách hàng có thỏa mãn từ khóa tìm kiếm (đã chuẩn hóa không dấu) theo tiêu chí này hay không
  bool matchesCustomer(CustomerEntity c, String query) {
    if (query.isEmpty) return true;

    switch (this) {
      case SearchTarget.name:
        return StringUtils.toUnaccentedLower(c.name).contains(query) ||
            (c.contactPerson.isNotEmpty &&
                StringUtils.toUnaccentedLower(c.contactPerson).contains(query)) ||
            (c.contactTitle != null &&
                StringUtils.toUnaccentedLower(c.contactTitle!).contains(query));

      case SearchTarget.code:
        return c.code.toLowerCase().contains(query);

      case SearchTarget.route:
        return StringUtils.toUnaccentedLower(c.route).contains(query) ||
            c.routes.any((r) => StringUtils.toUnaccentedLower(r).contains(query));

      case SearchTarget.address:
        return StringUtils.toUnaccentedLower(c.address).contains(query) ||
            (c.provinceName != null &&
                StringUtils.toUnaccentedLower(c.provinceName!).contains(query)) ||
            (c.wardName != null &&
                StringUtils.toUnaccentedLower(c.wardName!).contains(query));

      case SearchTarget.phone:
        return c.phone.replaceAll(' ', '').contains(query);

      case SearchTarget.all:
        return StringUtils.toUnaccentedLower(c.name).contains(query) ||
            c.code.toLowerCase().contains(query) ||
            c.phone.replaceAll(' ', '').contains(query) ||
            StringUtils.toUnaccentedLower(c.address).contains(query) ||
            StringUtils.toUnaccentedLower(c.route).contains(query) ||
            c.routes.any((r) => StringUtils.toUnaccentedLower(r).contains(query)) ||
            (c.contactPerson.isNotEmpty &&
                StringUtils.toUnaccentedLower(c.contactPerson).contains(query)) ||
            (c.contactTitle != null &&
                StringUtils.toUnaccentedLower(c.contactTitle!).contains(query)) ||
            (c.provinceName != null &&
                StringUtils.toUnaccentedLower(c.provinceName!).contains(query)) ||
            (c.wardName != null &&
                StringUtils.toUnaccentedLower(c.wardName!).contains(query));
    }
  }
}

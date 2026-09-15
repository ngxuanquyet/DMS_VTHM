import 'package:flutter/material.dart';
import '../../../../core/map/goong_models.dart';

enum CustomerVisitStatus {
  visited,
  pending,
  notScheduled,
}

class CustomerEntity {
  final String id;
  final String code;
  final String name;
  final String type;
  final String route;
  final String address;
  final String contactPerson;
  final String phone;
  final double lat;
  final double lng;
  final bool isToday;
  final CustomerVisitStatus visitStatus;
  final Color accentColor;

  const CustomerEntity({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    required this.route,
    required this.address,
    required this.contactPerson,
    required this.phone,
    required this.lat,
    required this.lng,
    this.isToday = true,
    this.visitStatus = CustomerVisitStatus.pending,
    this.accentColor = const Color(0xFF10B981),
  });

  GoongLatLng get toGoongLatLng => GoongLatLng(lat, lng);
}

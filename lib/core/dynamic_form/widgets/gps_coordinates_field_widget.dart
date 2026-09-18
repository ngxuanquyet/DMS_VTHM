import 'package:flutter/material.dart';
import '../../../core/map/app_map_location_card.dart';
import '../models/dynamic_form_field.dart';

class DynamicGpsCoordinatesWidget extends StatelessWidget {
  final DynamicFormField? latField;
  final DynamicFormField? lngField;
  final num? lat;
  final num? lng;
  final void Function(double? lat, double? lng) onCoordinatesChanged;
  final String? errorText;

  const DynamicGpsCoordinatesWidget({
    super.key,
    this.latField,
    this.lngField,
    required this.lat,
    required this.lng,
    required this.onCoordinatesChanged,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final isReadOnly = (latField?.isReadOnly ?? false) || (lngField?.isReadOnly ?? false);
    final isRequired = (latField?.isRequired ?? false) || (lngField?.isRequired ?? false);

    return AppMapLocationCard(
      title: 'Vị trí điểm bán trên bản đồ',
      lat: lat,
      lng: lng,
      isReadOnly: isReadOnly,
      isRequired: isRequired,
      errorText: errorText,
      onLocationChanged: (newLat, newLng, _) {
        onCoordinatesChanged(newLat, newLng);
      },
      onCleared: () {
        onCoordinatesChanged(null, null);
      },
    );
  }
}

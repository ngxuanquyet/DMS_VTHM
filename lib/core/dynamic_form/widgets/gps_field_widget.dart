import 'package:flutter/material.dart';
import '../../../core/map/app_map_location_card.dart';
import '../models/dynamic_form_field.dart';

class DynamicGpsFieldWidget extends StatelessWidget {
  final DynamicFormField field;
  final Map<String, dynamic>? value;
  final ValueChanged<Map<String, dynamic>?> onChanged;
  final String? errorText;

  const DynamicGpsFieldWidget({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final lat = value?['lat'] is num ? value!['lat'] as num : num.tryParse(value?['lat']?.toString() ?? '');
    final lng = value?['lng'] is num ? value!['lng'] as num : num.tryParse(value?['lng']?.toString() ?? '');

    return AppMapLocationCard(
      title: field.label.isNotEmpty ? field.label : 'Vị trí điểm bán trên bản đồ',
      lat: lat,
      lng: lng,
      isReadOnly: field.isReadOnly,
      isRequired: field.isRequired,
      errorText: errorText,
      onLocationChanged: (newLat, newLng, _) {
        onChanged({'lat': newLat, 'lng': newLng});
      },
      onCleared: () {
        onChanged(null);
      },
    );
  }
}

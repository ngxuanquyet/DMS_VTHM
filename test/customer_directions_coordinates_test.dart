import 'package:flutter_test/flutter_test.dart';
import 'package:vthm_dms/features/customer/presentation/widgets/customer_card.dart';

void main() {
  group('CustomerCard.extractCoordinates tests', () {
    test('extracts direct lat and lng when available', () {
      final coords = CustomerCard.extractCoordinates(
        lat: 21.028511,
        lng: 105.854444,
      );

      expect(coords, isNotNull);
      expect(coords!.$1, closeTo(21.028511, 0.0001));
      expect(coords.$2, closeTo(105.854444, 0.0001));
    });

    test('extracts coords from dynamicFields["coords"] map', () {
      final coords = CustomerCard.extractCoordinates(
        dynamicFields: {
          'coords': {
            'lat': 10.776889,
            'lng': 106.700806,
          },
        },
      );

      expect(coords, isNotNull);
      expect(coords!.$1, closeTo(10.776889, 0.0001));
      expect(coords.$2, closeTo(106.700806, 0.0001));
    });

    test('extracts string coordinates in dynamicFields["coords"]', () {
      final coords = CustomerCard.extractCoordinates(
        dynamicFields: {
          'coords': {
            'lat': '16.054407',
            'lng': '108.202167',
          },
        },
      );

      expect(coords, isNotNull);
      expect(coords!.$1, closeTo(16.054407, 0.0001));
      expect(coords.$2, closeTo(108.202167, 0.0001));
    });

    test('extracts lat/lng directly from dynamicFields keys', () {
      final coords = CustomerCard.extractCoordinates(
        dynamicFields: {
          'lat': 20.9712,
          'lng': 105.7891,
        },
      );

      expect(coords, isNotNull);
      expect(coords!.$1, closeTo(20.9712, 0.0001));
      expect(coords.$2, closeTo(105.7891, 0.0001));
    });

    test('extracts coordinates from dynamicFields["toa_do"] comma-separated string', () {
      final coords = CustomerCard.extractCoordinates(
        dynamicFields: {
          'toa_do': '21.0285, 105.8544',
        },
      );

      expect(coords, isNotNull);
      expect(coords!.$1, closeTo(21.0285, 0.0001));
      expect(coords.$2, closeTo(105.8544, 0.0001));
    });

    test('returns null when no coordinates or dynamicFields provided', () {
      final coords = CustomerCard.extractCoordinates(
        lat: null,
        lng: null,
        dynamicFields: {},
      );

      expect(coords, isNull);
    });

    test('prioritizes direct lat/lng over dynamicFields', () {
      final coords = CustomerCard.extractCoordinates(
        lat: 21.0,
        lng: 105.0,
        dynamicFields: {
          'coords': {
            'lat': 10.0,
            'lng': 106.0,
          },
        },
      );

      expect(coords, isNotNull);
      expect(coords!.$1, closeTo(21.0, 0.0001));
      expect(coords.$2, closeTo(105.0, 0.0001));
    });
  });
}

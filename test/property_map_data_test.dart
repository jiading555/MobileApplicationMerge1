import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smart_property_advisor/features/map/property_map_data.dart';
import 'package:smart_property_advisor/models/property.dart';

void main() {
  group('map property data', () {
    test('valid-coordinate properties are mappable', () {
      final properties = [
        _property(id: 'valid', latitude: 3.03, longitude: 101.44),
      ];

      final mappable = mappableMapProperties(properties);

      expect(mappable.map((property) => property.id), ['valid']);
    });

    test('null-coordinate properties are excluded', () {
      final properties = [
        _property(id: 'missing-latitude', longitude: 101.44),
        _property(id: 'missing-longitude', latitude: 3.03),
      ];

      final mappable = mappableMapProperties(properties);

      expect(mappable, isEmpty);
    });

    test('out-of-range coordinates are excluded', () {
      final properties = [
        _property(id: 'bad-latitude', latitude: 120, longitude: 101.44),
        _property(id: 'bad-longitude', latitude: 3.03, longitude: 200),
      ];

      final mappable = mappableMapProperties(properties);

      expect(mappable, isEmpty);
    });

    test('area filter determines marker data', () {
      final properties = [
        _property(
          id: 'klang',
          areaId: 'selangor_klang',
          latitude: 3.03,
          longitude: 101.44,
        ),
        _property(
          id: 'petaling',
          areaId: 'selangor_petaling',
          latitude: 3.10,
          longitude: 101.60,
        ),
        _property(id: 'unmapped', areaId: 'selangor_klang'),
      ];

      expect(
        mappableMapProperties(
          visibleMapProperties(properties, selectedAreaId: allMapAreasId),
        ).map((property) => property.id),
        ['klang', 'petaling'],
      );
      expect(
        mappableMapProperties(
          visibleMapProperties(properties, selectedAreaId: 'Selangor Klang'),
        ).map((property) => property.id),
        ['klang'],
      );
    });

    test('selecting property resolves expected preview property', () {
      final properties = [_property(id: 'first'), _property(id: 'selected')];

      expect(
        selectedMapProperty(properties, selectedPropertyId: 'selected')?.id,
        'selected',
      );
      expect(
        selectedMapProperty(properties, selectedPropertyId: 'missing')?.id,
        'first',
      );
    });

    test('zero-marker fallback uses Malaysia camera target', () {
      final target = cameraTargetForProperties([
        _property(id: 'without-coordinates'),
      ]);

      expect(target.isBounds, isFalse);
      expect(target.center, malaysiaMapCenter);
      expect(target.zoom, malaysiaMapZoom);
    });

    test('single marker camera target centers the property', () {
      final target = cameraTargetForProperties([
        _property(id: 'single', latitude: 3.03, longitude: 101.44),
      ]);

      expect(target.isBounds, isFalse);
      expect(target.center, const LatLng(3.03, 101.44));
      expect(target.zoom, singlePropertyMapZoom);
    });

    test('many marker camera target keeps all marker coordinates', () {
      final target = cameraTargetForProperties([
        _property(id: 'a', latitude: 3.03, longitude: 101.44),
        _property(id: 'b', latitude: 5.41, longitude: 100.33),
      ]);

      expect(target.isBounds, isTrue);
      expect(target.points, const [LatLng(3.03, 101.44), LatLng(5.41, 100.33)]);
      expect(target.maxZoom, manyPropertiesMaxZoom);
    });
  });
}

Property _property({
  required String id,
  String areaId = 'selangor_klang',
  double? latitude,
  double? longitude,
}) {
  return Property(
    id: id,
    name: 'Property $id',
    areaId: areaId,
    address: 'Demo address',
    type: 'Apartment',
    tenure: 'Freehold',
    latitude: latitude,
    longitude: longitude,
    summary: 'Summary',
    facilities: const [],
    palette: 0,
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smart_property_advisor/features/map/property_map_data.dart';
import 'package:smart_property_advisor/models/area_data.dart';
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

    test('placeholder and non-Malaysia coordinates are excluded', () {
      final properties = [
        _property(id: 'zero', latitude: 0, longitude: 0),
        _property(id: 'central-asia', latitude: 88, longitude: 4.6),
        _property(id: 'malaysia', latitude: 5.12456, longitude: 103.03314),
      ];

      final mappable = mappableMapProperties(properties);

      expect(mappable.map((property) => property.id), ['malaysia']);
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

    test('area with zero mappable properties is absent from map options', () {
      final options = mapAreaOptions(
        [
          _property(
            id: 'batu-pahat-without-coordinates',
            areaId: 'johor_batu_pahat',
            state: 'Johor',
            district: 'Batu Pahat',
          ),
          _property(
            id: 'kluang',
            areaId: 'johor_kluang',
            state: 'Johor',
            district: 'Kluang',
            latitude: 2.03,
            longitude: 103.32,
          ),
        ],
        areas: const [_batuPahat, _kluang],
      );

      expect(options.map((option) => option.label), [
        'All areas',
        'Kluang, Johor',
      ]);
      expect(options.map((option) => option.value), [
        allMapAreasId,
        'johor_kluang',
      ]);
    });

    test(
      'AreaProfile without mappable properties does not create map option',
      () {
        final options = mapAreaOptions(
          [
            _property(
              id: 'kluang',
              areaId: 'johor_kluang',
              state: 'Johor',
              district: 'Kluang',
              latitude: 2.03,
              longitude: 103.32,
            ),
          ],
          areas: const [_batuPahat, _kluang],
        );

        expect(
          options.map((option) => option.label),
          isNot(contains('Batu Pahat, Johor')),
        );
        expect(
          options.map((option) => option.label),
          contains('Kluang, Johor'),
        );
      },
    );

    test('invalid coordinates do not make an area selectable', () {
      final options = mapAreaOptions([
        _property(
          id: 'zero',
          areaId: 'johor_batu_pahat',
          state: 'Johor',
          district: 'Batu Pahat',
          latitude: 0,
          longitude: 0,
        ),
        _property(
          id: 'outside-malaysia',
          areaId: 'johor_muar',
          state: 'Johor',
          district: 'Muar',
          latitude: 13.75,
          longitude: 100.5,
        ),
      ]);

      expect(options.map((option) => option.value), [allMapAreasId]);
      expect(options.map((option) => option.label), ['All areas']);
    });

    test('Kluang filter only shows Kluang mappable properties', () {
      final properties = [
        _property(
          id: 'kluang',
          areaId: 'johor_kluang',
          state: 'Johor',
          district: 'Kluang',
          latitude: 2.03,
          longitude: 103.32,
        ),
        _property(
          id: 'muar',
          areaId: 'johor_muar',
          state: 'Johor',
          district: 'Muar',
          latitude: 2.05,
          longitude: 102.57,
        ),
        _property(
          id: 'kluang-unmapped',
          areaId: 'johor_kluang',
          state: 'Johor',
          district: 'Kluang',
        ),
      ];

      final visible = mappableMapProperties(
        visibleMapProperties(
          properties,
          selectedAreaId: 'johor_kluang',
          areas: const [_kluang],
        ),
      );

      expect(visible.map((property) => property.id), ['kluang']);
    });

    test('All areas restores all valid property markers', () {
      final properties = [
        _property(
          id: 'kluang',
          areaId: 'johor_kluang',
          state: 'Johor',
          district: 'Kluang',
          latitude: 2.03,
          longitude: 103.32,
        ),
        _property(
          id: 'muar',
          areaId: 'johor_muar',
          state: 'Johor',
          district: 'Muar',
          latitude: 2.05,
          longitude: 102.57,
        ),
        _property(
          id: 'batu-pahat',
          areaId: 'johor_batu_pahat',
          state: 'Johor',
          district: 'Batu Pahat',
        ),
      ];

      final visible = mappableMapProperties(
        visibleMapProperties(properties, selectedAreaId: allMapAreasId),
      );

      expect(visible.map((property) => property.id), ['kluang', 'muar']);
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
        _property(id: 'central-asia', latitude: 88, longitude: 4.6),
      ]);

      expect(target.isBounds, isFalse);
      expect(target.center, malaysiaMapCenter);
      expect(target.zoom, malaysiaMapZoom);
    });

    test('Taman Rawai Perdana camera target centers Marang coordinates', () {
      final target = cameraTargetForProperties([
        _property(
          id: 'taman-rawai-perdana',
          latitude: 5.12456,
          longitude: 103.03314,
        ),
      ]);

      expect(target.isBounds, isFalse);
      expect(target.center, const LatLng(5.12456, 103.03314));
      expect(target.zoom, singlePropertyMapZoom);
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
        _property(id: 'invalid', latitude: 88, longitude: 4.6),
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
  String? state,
  String? district,
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
    state: state,
    district: district,
    latitude: latitude,
    longitude: longitude,
    summary: 'Summary',
    facilities: const [],
    palette: 0,
  );
}

const _batuPahat = AreaData(
  id: 'johor_batu_pahat',
  name: 'Batu Pahat',
  state: 'Johor',
  isGovernmentProfile: true,
);

const _kluang = AreaData(
  id: 'johor_kluang',
  name: 'Kluang',
  state: 'Johor',
  isGovernmentProfile: true,
);

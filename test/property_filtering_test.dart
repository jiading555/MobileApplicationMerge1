import 'package:flutter_test/flutter_test.dart';
import 'package:smart_property_advisor/core/utils/property_filtering.dart';
import 'package:smart_property_advisor/models/property.dart';

void main() {
  group('PropertyFilterNormalizer', () {
    test('normalizeAreaId uses underscores', () {
      expect(
        PropertyFilterNormalizer.normalizeAreaId('Selangor Petaling'),
        'selangor_petaling',
      );
      expect(
        PropertyFilterNormalizer.normalizeAreaId('Johor-Bahru'),
        'johor_bahru',
      );
      expect(
        PropertyFilterNormalizer.normalizeAreaId('  Kuala Lumpur  '),
        'kuala_lumpur',
      );
    });

    test('areaMatches works with consistent normalization', () {
      expect(
        PropertyFilterNormalizer.areaMatches(
          'selangor_petaling',
          'Selangor Petaling',
        ),
        true,
      );
      expect(
        PropertyFilterNormalizer.areaMatches('johor_bahru', 'johor-bahru'),
        true,
      );
      expect(PropertyFilterNormalizer.areaMatches('any', 'Any'), true);
    });

    test('stateMatches uses canonical Malaysian state aliases', () {
      expect(
        PropertyFilterNormalizer.stateMatches('Penang', 'Pulau Pinang'),
        true,
      );
      expect(
        PropertyFilterNormalizer.stateMatches(
          'W.P. Kuala Lumpur',
          'Kuala Lumpur',
        ),
        true,
      );
    });

    test('availableTypes shows normalized categories only', () {
      final options = PropertyFilterNormalizer.availableTypes([
        'APARTMEN',
        'RUMAH TERES 2 TINGKAT',
        'Kedai Pejabat 1 Setengah Tingkat',
      ]);

      expect(options, [
        'Any Type',
        'Apartment / Flat',
        'Terrace House',
        'Shop Apartment',
      ]);
      expect(options, isNot(contains('APARTMEN')));
      expect(options, isNot(contains('RUMAH TERES 2 TINGKAT')));
    });

    test('multiple raw property types match each normalized category', () {
      const raw = 'RUMAH TERES 2 TINGKAT; RUMAH KLUSTER 2 TINGKAT';

      expect(PropertyFilterNormalizer.typeMatches(raw, 'Terrace House'), true);
      expect(PropertyFilterNormalizer.typeMatches(raw, 'Cluster House'), true);
      expect(
        PropertyFilterNormalizer.typeMatches(raw, 'Apartment / Flat'),
        false,
      );
    });

    test('UI category derivation handles multiple unit types', () {
      const property = Property(
        id: 'teduh_1',
        name: 'Mixed Homes',
        areaId: 'selangor_klang',
        address: 'Klang, Selangor',
        type: 'Public housing',
        tenure: 'Tenure not available',
        summary: '',
        facilities: [],
        palette: 0,
        unitTypes: ['RUMAH TERES', 'RUMAH BERKEMBAR'],
      );

      expect(PropertyFilterNormalizer.availablePropertyTypes([property]), [
        'Any Type',
        'Terrace House',
        'Semi-Detached',
      ]);
      expect(
        PropertyFilterNormalizer.propertyTypeMatches(property, 'Terrace House'),
        true,
      );
      expect(
        PropertyFilterNormalizer.propertyTypeMatches(property, 'Semi-Detached'),
        true,
      );
      expect(
        PropertyFilterNormalizer.propertyTypeMatches(
          property,
          'Apartment / Flat',
        ),
        false,
      );
    });

    test('null verified property_type is safe when unit types exist', () {
      final property = Property.fromTeduhJson(
        {
          'source_id': 'SPNB_7',
          'project_name': 'Taman Kelubi Idaman',
          'state': 'Melaka',
          'district': null,
          'unit_types': ['Rumah Bandar'],
        },
        areaId: 'unknown',
        palette: 0,
      );

      expect(property.verifiedPropertyType, isNull);
      expect(property.type, isEmpty);
      expect(
        PropertyFilterNormalizer.propertyTypeMatches(property, 'Townhouse'),
        true,
      );
      expect(property.toSupabaseJson()['property_type'], isNull);
    });

    test(
      'null property_type falls back to normalized unit_types for UI only',
      () {
        final properties = [
          _teduhProperty('apartment', ['APARTMEN']),
          _teduhProperty('terrace', ['RUMAH TERES']),
          _teduhProperty('semi_d', ['RUMAH BERKEMBAR']),
          _teduhProperty('townhouse', ['RUMAH BANDAR']),
          _teduhProperty('cluster', ['RUMAH KLUSTER 2 TINGKAT']),
        ];

        expect(PropertyFilterNormalizer.availablePropertyTypes(properties), [
          'Any Type',
          'Apartment / Flat',
          'Terrace House',
          'Semi-Detached',
          'Townhouse',
          'Cluster House',
        ]);
        expect(
          PropertyFilterNormalizer.propertyTypeMatches(
            properties[0],
            'Apartment / Flat',
          ),
          true,
        );
        expect(
          PropertyFilterNormalizer.propertyTypeMatches(
            properties[1],
            'Terrace House',
          ),
          true,
        );
        expect(
          PropertyFilterNormalizer.propertyTypeMatches(
            properties[2],
            'Semi-Detached',
          ),
          true,
        );
        expect(
          properties.map(
            (property) => property.toSupabaseJson()['property_type'],
          ),
          everyElement(isNull),
        );
      },
    );

    test('verified property_type takes precedence over unit_types', () {
      const property = Property(
        id: 'teduh_3',
        name: 'Verified Apartment Homes',
        areaId: 'selangor_klang',
        address: 'Klang, Selangor',
        type: 'Apartment',
        tenure: 'Tenure not available',
        verifiedPropertyType: 'APARTMEN',
        summary: '',
        facilities: [],
        palette: 0,
        unitTypes: ['RUMAH TERES'],
      );

      expect(PropertyFilterNormalizer.availablePropertyTypes([property]), [
        'Any Type',
        'Apartment / Flat',
      ]);
      expect(
        PropertyFilterNormalizer.propertyTypeMatches(
          property,
          'Apartment / Flat',
        ),
        true,
      );
      expect(
        PropertyFilterNormalizer.propertyTypeMatches(property, 'Terrace House'),
        false,
      );
      expect(property.toSupabaseJson()['property_type'], 'APARTMEN');
    });

    test('available property types falls back to verified property_type', () {
      const property = Property(
        id: 'teduh_2',
        name: 'Verified Type Homes',
        areaId: 'selangor_klang',
        address: 'Klang, Selangor',
        type: 'Apartment',
        tenure: 'Tenure not available',
        verifiedPropertyType: 'Apartment',
        summary: '',
        facilities: [],
        palette: 0,
      );

      expect(PropertyFilterNormalizer.availablePropertyTypes([property]), [
        'Any Type',
        'Apartment / Flat',
      ]);
    });

    test('property type normalization handles common TEDUH values', () {
      expect(
        PropertyFilterNormalizer.normalizeType('APARTMEN'),
        'Apartment / Flat',
      );
      expect(
        PropertyFilterNormalizer.normalizeType('Pangsapuri Jenis A'),
        'Apartment / Flat',
      );
      expect(
        PropertyFilterNormalizer.normalizeType('RUMAH TERES SATU TINGKAT'),
        'Terrace House',
      );
      expect(
        PropertyFilterNormalizer.normalizeType('RUMAH BERKEMBAR'),
        'Semi-Detached',
      );
      expect(
        PropertyFilterNormalizer.normalizeType('Kedai Pejabat'),
        'Shop Apartment',
      );
      expect(
        PropertyFilterNormalizer.normalizeType('Tenure unknown'),
        'Others',
      );
    });

    test('scheme normalization merges safe equivalents', () {
      expect(PropertyFilterNormalizer.normalizeScheme('PPAM'), 'PPAM');
      expect(
        PropertyFilterNormalizer.normalizeScheme(
          'Perumahan Penjawat Awam Malaysia',
        ),
        'PPAM',
      );
      expect(
        PropertyFilterNormalizer.normalizeScheme(
          'Perumahan Penjawat Awam Malaysia (PPAM)',
        ),
        'PPAM',
      );
      expect(PropertyFilterNormalizer.normalizeScheme('PR1MA'), 'PR1MA Homes');
      expect(
        PropertyFilterNormalizer.normalizeScheme(
          'Syarikat Perumahan Negara Berhad (SPNB)',
        ),
        'SPNB',
      );
    });

    test('normalizeTenure handles Malay terms', () {
      expect(PropertyFilterNormalizer.normalizeTenure('Freehold'), 'Freehold');
      expect(PropertyFilterNormalizer.normalizeTenure('Bebas'), 'Freehold');
      expect(PropertyFilterNormalizer.normalizeTenure('Pajakan'), 'Leasehold');
      expect(
        PropertyFilterNormalizer.normalizeTenure('Leasehold'),
        'Leasehold',
      );
    });

    test('matchPrice handles null maximumPrice (Any Budget)', () {
      final property = Property(
        id: '1',
        name: 'Test',
        areaId: 'area',
        address: 'addr',
        type: 'Type',
        tenure: 'Tenure',
        price: 500000,
        summary: 'sum',
        facilities: [],
        palette: 0,
      );
      expect(PropertyFilterNormalizer.matchPrice(property, null), true);
      expect(PropertyFilterNormalizer.matchPrice(property, 600000), true);
      expect(PropertyFilterNormalizer.matchPrice(property, 400000), false);
    });
  });

  group('Property Model Parsing', () {
    test('_intFromJson handles decimal strings', () {
      final json = {
        'id': '1',
        'name': 'Test',
        'areaId': 'area',
        'address': 'addr',
        'type': 'Type',
        'tenure': 'Tenure',
        'price': '350000.00',
        'summary': 'sum',
        'facilities': [],
        'palette': 0,
      };
      final property = Property.fromJson(json);
      expect(property.price, 350000);
    });

    test('_intFromJson returns null for invalid strings', () {
      final json = {
        'id': '1',
        'name': 'Test',
        'areaId': 'area',
        'address': 'addr',
        'type': 'Type',
        'tenure': 'Tenure',
        'price': 'invalid',
        'summary': 'sum',
        'facilities': [],
        'palette': 0,
      };
      final property = Property.fromJson(json);
      expect(property.price, null);
    });
  });
}

Property _teduhProperty(String id, List<String> unitTypes) {
  return Property.fromTeduhJson(
    {
      'source_id': id,
      'project_name': 'Project $id',
      'state': 'Selangor',
      'district': 'Klang',
      'property_type': null,
      'unit_types': unitTypes,
    },
    areaId: 'selangor_klang',
    palette: 0,
  );
}

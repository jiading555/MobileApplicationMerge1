import 'package:flutter_test/flutter_test.dart';
import 'package:smart_property_advisor/core/utils/property_area_resolver.dart';
import 'package:smart_property_advisor/data/repositories/property_repository.dart';
import 'package:smart_property_advisor/models/area_data.dart';
import 'package:smart_property_advisor/models/property.dart';

void main() {
  group('PropertyAreaResolver', () {
    test('RESIDENSI ALAM DAMAI never resolves to Batu Pahat Johor', () {
      final resolved = PropertyAreaResolver.resolve(
        property: _alamDamai(areaId: 'kuala_lumpur_cheras'),
        areas: const [_batuPahat],
      );

      expect(resolved, isNull);
    });

    test('RESIDENSI ALAM DAMAI resolves to Kuala Lumpur federal profile', () {
      final resolved = PropertyAreaResolver.resolve(
        property: _alamDamai(areaId: 'kuala_lumpur_cheras'),
        areas: const [_batuPahat, _kualaLumpur],
      );

      expect(resolved?.id, 'kuala_lumpur_w_p_kuala_lumpur');
      expect(resolved?.state, 'Kuala Lumpur');
      expect(resolved?.name, 'W P Kuala Lumpur');
    });

    test('RESIDENSI ALAM DAMAI returns null without a trusted KL profile', () {
      final resolved = PropertyAreaResolver.resolve(
        property: _alamDamai(areaId: 'kuala_lumpur_cheras'),
        areas: const [_petaling, _batuPahat],
      );

      expect(resolved, isNull);
    });

    test('Kuala Lumpur property never follows a Johor area id', () {
      final resolved = PropertyAreaResolver.resolve(
        property: _alamDamai(areaId: 'johor_batu_pahat'),
        areas: const [_batuPahat],
      );

      expect(resolved, isNull);
    });

    test('same district names in different states do not collide', () {
      final resolved = PropertyAreaResolver.resolve(
        property: const Property(
          id: 'teduh_setapak',
          name: 'Residensi Setapak',
          areaId: 'kuala_lumpur_setapak',
          address: 'Setapak, Kuala Lumpur',
          type: '',
          tenure: '',
          state: 'Kuala Lumpur',
          district: 'Setapak',
          summary: 'Official housing project information sourced from TEDUH.',
          facilities: [],
          palette: 0,
          source: 'TEDUH - Jabatan Perumahan Negara, KPKT',
        ),
        areas: const [
          AreaData(id: 'johor_setapak', name: 'Setapak', state: 'Johor'),
          _kualaLumpur,
        ],
      );

      expect(resolved?.state, 'Kuala Lumpur');
      expect(resolved?.id, 'kuala_lumpur_w_p_kuala_lumpur');
    });

    test('Batu Pahat Johor properties still resolve exactly', () {
      final resolved = PropertyAreaResolver.resolve(
        property: const Property(
          id: 'teduh_batu_pahat',
          name: 'Residensi Batu Pahat',
          areaId: 'johor_batu_pahat',
          address: 'Batu Pahat, Johor',
          type: '',
          tenure: '',
          state: 'Johor',
          district: 'Batu Pahat',
          summary: 'Official housing project information sourced from TEDUH.',
          facilities: [],
          palette: 0,
          source: 'TEDUH - Jabatan Perumahan Negara, KPKT',
        ),
        areas: const [_batuPahat, _kualaLumpur],
      );

      expect(resolved?.id, 'johor_batu_pahat');
    });

    test('existing valid profiles elsewhere in Malaysia continue working', () {
      final resolved = PropertyAreaResolver.resolve(
        property: const Property(
          id: 'teduh_timur_laut',
          name: 'Residensi Timur Laut',
          areaId: 'pulau_pinang_timur_laut',
          address: 'Timur Laut, Pulau Pinang',
          type: '',
          tenure: '',
          state: 'Penang',
          district: 'Timur Laut',
          summary: 'Official housing project information sourced from TEDUH.',
          facilities: [],
          palette: 0,
          source: 'TEDUH - Jabatan Perumahan Negara, KPKT',
        ),
        areas: const [_timurLaut],
      );

      expect(resolved?.id, 'pulau_pinang_timur_laut');
    });

    test(
      'property repository uses the same resolver for generated area ids',
      () {
        final areaId = PropertyRepository.resolveAreaIdForRow(
          const {
            'state': 'Kuala Lumpur',
            'district': 'Cheras',
            'address': 'Cheras, Kuala Lumpur',
            'raw_location': 'CHERAS, WILAYAH PERSEKUTUAN KUALA LUMPUR',
          },
          const [_kualaLumpur],
        );

        expect(areaId, 'kuala_lumpur_w_p_kuala_lumpur');
      },
    );

    test('Setiawangsa resolves internally to Kuala Lumpur federal profile', () {
      final resolved = PropertyAreaResolver.resolve(
        property: _property(
          id: 'setiawangsa',
          name: 'Residensi Setiawangsa',
          state: 'Kuala Lumpur',
          district: 'Setiawangsa',
          areaId: 'kuala_lumpur_setiawangsa',
        ),
        areas: const [_kualaLumpur],
      );

      expect(resolved?.id, 'kuala_lumpur_w_p_kuala_lumpur');
    });

    test('Semenyih resolves internally to Ulu Langat profile', () {
      final resolved = PropertyAreaResolver.resolve(
        property: _property(
          id: 'semenyih',
          name: 'Residensi Semenyih',
          state: 'Selangor',
          district: 'Semenyih',
          areaId: 'selangor_semenyih',
        ),
        areas: const [_uluLangat],
      );

      expect(resolved?.id, 'selangor_ulu_langat');
    });

    test('Sungai Petani resolves internally to Kuala Muda profile', () {
      final resolved = PropertyAreaResolver.resolve(
        property: _property(
          id: 'sungai_petani',
          name: 'Residensi Sungai Petani',
          state: 'Kedah',
          district: 'Sungai Petani',
          areaId: 'kedah_sungai_petani',
        ),
        areas: const [_kualaMuda],
      );

      expect(resolved?.id, 'kedah_kuala_muda');
    });

    test('conflicting state tokens stay unresolved', () {
      final property = Property.fromTeduhJson(
        const {
          'source_id': 'RESIDENSIWILAYAH_999',
          'project_name': 'Residensi Wilayah Sentral',
          'state': 'Putrajaya',
          'district': 'W.P. Labuan',
          'raw_location': 'Putrajaya, W.P. Labuan',
          'source': 'TEDUH - Jabatan Perumahan Negara, KPKT',
        },
        areaId: 'labuan_w_p_labuan',
        palette: 0,
      );

      final resolved = PropertyAreaResolver.resolve(
        property: property,
        areas: const [_labuan, _putrajaya],
      );

      expect(resolved, isNull);
      expect(
        PropertyAreaResolver.matchesSelectedArea(
          property: property,
          selectedAreaId: 'labuan_w_p_labuan',
          areas: const [_labuan, _putrajaya],
        ),
        isFalse,
      );
    });

    test('repository does not synthesize area ids from conflicting data', () {
      final areaId = PropertyRepository.resolveAreaIdForRow(
        const {
          'state': 'Putrajaya',
          'district': 'Wilayah Persekutuan Labuan',
          'raw_location': 'Putrajaya, WILAYAH PERSEKUTUAN LABUAN',
        },
        const [_labuan, _putrajaya],
      );

      expect(areaId, 'unknown');
    });
  });
}

Property _property({
  required String id,
  required String name,
  required String state,
  required String district,
  required String areaId,
}) {
  return Property(
    id: 'teduh_$id',
    name: name,
    areaId: areaId,
    address: '$district, $state',
    type: '',
    tenure: '',
    state: state,
    district: district,
    summary: 'Official housing project information sourced from TEDUH.',
    facilities: const [],
    palette: 0,
    source: 'TEDUH - Jabatan Perumahan Negara, KPKT',
  );
}

Property _alamDamai({required String areaId}) {
  return Property.fromTeduhJson(
    const {
      'source_id': 'PR1MA_114',
      'project_name': 'RESIDENSI ALAM DAMAI',
      'state': 'Kuala Lumpur',
      'district': 'Cheras',
      'address': 'Cheras, Kuala Lumpur',
      'raw_location': 'CHERAS, WILAYAH PERSEKUTUAN KUALA LUMPUR',
      'source': 'TEDUH - Jabatan Perumahan Negara, KPKT',
    },
    areaId: areaId,
    palette: 0,
  );
}

const _kualaLumpur = AreaData(
  id: 'kuala_lumpur_w_p_kuala_lumpur',
  name: 'W P Kuala Lumpur',
  state: 'Kuala Lumpur',
  population: 2074100,
  medianIncome: 10234,
  schools: 290,
  isGovernmentProfile: true,
);

const _batuPahat = AreaData(
  id: 'johor_batu_pahat',
  name: 'Batu Pahat',
  state: 'Johor',
  population: 512000,
  medianIncome: 7555,
  schools: 175,
  isGovernmentProfile: true,
);

const _petaling = AreaData(
  id: 'selangor_petaling',
  name: 'Petaling',
  state: 'Selangor',
  isGovernmentProfile: true,
);

const _timurLaut = AreaData(
  id: 'pulau_pinang_timur_laut',
  name: 'Timur Laut',
  state: 'Pulau Pinang',
  isGovernmentProfile: true,
);

const _labuan = AreaData(
  id: 'labuan_w_p_labuan',
  name: 'W P Labuan',
  state: 'Labuan',
  isGovernmentProfile: true,
);

const _putrajaya = AreaData(
  id: 'putrajaya_w_p_putrajaya',
  name: 'W P Putrajaya',
  state: 'Putrajaya',
  isGovernmentProfile: true,
);

const _uluLangat = AreaData(
  id: 'selangor_ulu_langat',
  name: 'Ulu Langat',
  state: 'Selangor',
  isGovernmentProfile: true,
);

const _kualaMuda = AreaData(
  id: 'kedah_kuala_muda',
  name: 'Kuala Muda',
  state: 'Kedah',
  isGovernmentProfile: true,
);

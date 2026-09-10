import '../../models/area_data.dart';
import '../../models/property.dart';
import 'location_normalizer.dart';

class PropertyAreaResolver {
  const PropertyAreaResolver._();

  static AreaData? resolve({
    required Property property,
    required Iterable<AreaData> areas,
  }) {
    return resolveLocation(
      sourceAreaId: property.areaId,
      state: property.state,
      district: property.district,
      address: property.address,
      rawLocation: property.rawLocation,
      areas: areas,
    );
  }

  static String resolveAreaIdForLocation({
    Object? sourceAreaId,
    Object? state,
    Object? district,
    Object? address,
    Object? rawLocation,
    required Iterable<AreaData> areas,
  }) {
    if (_hasConflictingLocationData(
      state: state,
      district: district,
      rawLocation: rawLocation,
    )) {
      return 'unknown';
    }

    final resolved = resolveLocation(
      sourceAreaId: sourceAreaId,
      state: state,
      district: district,
      address: address,
      rawLocation: rawLocation,
      areas: areas,
    );
    if (resolved != null) {
      return resolved.id;
    }

    final canonicalState = LocationNormalizer.canonicalStateId(state);
    final canonicalDistrict = LocationNormalizer.canonicalDistrictIdForState(
      state,
      district,
    );
    if (canonicalState.isNotEmpty && canonicalDistrict.isNotEmpty) {
      return LocationNormalizer.canonicalAreaId(state, district);
    }
    return _validAreaId(sourceAreaId)
        ? LocationNormalizer.canonicalAreaIdFromExisting(sourceAreaId)
        : 'unknown';
  }

  static bool matchesSelectedArea({
    required Property property,
    required String? selectedAreaId,
    required Iterable<AreaData> areas,
  }) {
    if (selectedAreaId == null ||
        selectedAreaId.trim().isEmpty ||
        selectedAreaId == 'Any' ||
        selectedAreaId == 'any') {
      return true;
    }

    if (_hasConflictingLocationData(
      state: property.state,
      district: property.district,
      rawLocation: property.rawLocation,
    )) {
      return false;
    }

    final resolved = resolve(property: property, areas: areas);
    final comparableAreaId = resolved?.id ?? property.areaId;
    return LocationNormalizer.areaIdMatches(comparableAreaId, selectedAreaId);
  }

  static AreaData? resolveLocation({
    Object? sourceAreaId,
    Object? state,
    Object? district,
    Object? address,
    Object? rawLocation,
    required Iterable<AreaData> areas,
  }) {
    final areaList = areas.toList(growable: false);
    if (areaList.isEmpty) {
      return null;
    }
    if (_hasConflictingLocationData(
      state: state,
      district: district,
      rawLocation: rawLocation,
    )) {
      return null;
    }

    final propertyState = _propertyState(
      state: state,
      address: address,
      rawLocation: rawLocation,
    );
    final propertyDistrict = LocationNormalizer.canonicalDistrictIdForState(
      propertyState,
      district,
    );

    if (_validAreaId(sourceAreaId)) {
      final sourceId = LocationNormalizer.canonicalAreaIdFromExisting(
        sourceAreaId,
      );
      final exact = _firstWhere(
        areaList,
        (area) =>
            _stateCompatible(propertyState, area) &&
            LocationNormalizer.areaIdMatches(area.id, sourceId),
      );
      if (exact != null) {
        return exact;
      }
    }

    if (propertyState.isNotEmpty && propertyDistrict.isNotEmpty) {
      final exactStateDistrict = _firstWhere(
        areaList,
        (area) =>
            _sameState(propertyState, area) &&
            LocationNormalizer.districtMatches(
              area.name,
              district,
              state: area.state,
            ),
      );
      if (exactStateDistrict != null) {
        return exactStateDistrict;
      }
    }

    if (propertyState.isEmpty) {
      return null;
    }

    for (final locality in _localityCandidates(
      district,
      address,
      rawLocation,
    )) {
      final aliases = _districtAliasesForLocality(propertyState, locality);
      for (final alias in aliases) {
        final match = _firstWhere(
          areaList,
          (area) =>
              _sameState(propertyState, area) &&
              LocationNormalizer.canonicalDistrictIdForState(
                    area.state,
                    area.name,
                  ) ==
                  alias,
        );
        if (match != null) {
          return match;
        }
      }
    }

    return null;
  }

  static final Map<String, Map<String, List<String>>> _stateLocalityAliases = {
    'kuala_lumpur': {
      'kuala_lumpur': ['w_p_kuala_lumpur'],
      'w_p_kuala_lumpur': ['w_p_kuala_lumpur'],
      'wp_kuala_lumpur': ['w_p_kuala_lumpur'],
      'wilayah_persekutuan_kuala_lumpur': ['w_p_kuala_lumpur'],
      'bandar_tun_razak': ['w_p_kuala_lumpur'],
      'bangsar': ['w_p_kuala_lumpur'],
      'batu': ['w_p_kuala_lumpur'],
      'bukit_bintang': ['w_p_kuala_lumpur'],
      'cheras': ['w_p_kuala_lumpur'],
      'kepong': ['w_p_kuala_lumpur'],
      'lembah_pantai': ['w_p_kuala_lumpur'],
      'seputeh': ['w_p_kuala_lumpur'],
      'segambut': ['w_p_kuala_lumpur'],
      'sentul': ['w_p_kuala_lumpur'],
      'setapak': ['w_p_kuala_lumpur'],
      'titiwangsa': ['w_p_kuala_lumpur'],
      'wangsa_maju': ['w_p_kuala_lumpur'],
      'setiawangsa': ['w_p_kuala_lumpur'],
    },
    'johor': {
      'pasir_gudang': ['johor_bahru'],
    },
    'kedah': {
      'sungai_petani': ['kuala_muda'],
    },
    'labuan': {
      'labuan': ['w_p_labuan'],
      'w_p_labuan': ['w_p_labuan'],
      'wp_labuan': ['w_p_labuan'],
      'wilayah_persekutuan_labuan': ['w_p_labuan'],
    },
    'melaka': {
      'klebang': ['melaka_tengah'],
    },
    'perak': {
      'batu_gajah': ['kinta'],
      'larut_matang': ['larut_dan_matang'],
    },
    'perlis': {
      'arau': ['perlis'],
      'chuping': ['perlis'],
    },
    'putrajaya': {
      'putrajaya': ['w_p_putrajaya'],
      'w_p_putrajaya': ['w_p_putrajaya'],
      'wp_putrajaya': ['w_p_putrajaya'],
      'wilayah_persekutuan_putrajaya': ['w_p_putrajaya'],
    },
    'sabah': {
      'menggatal': ['kota_kinabalu'],
    },
    'selangor': {
      'semenyih': ['ulu_langat'],
    },
  };

  static String _propertyState({
    Object? state,
    Object? address,
    Object? rawLocation,
  }) {
    final explicit = LocationNormalizer.canonicalStateId(state);
    if (explicit.isNotEmpty) {
      return explicit;
    }
    for (final value in [rawLocation, address]) {
      final suffix = LocationNormalizer.matchStateSuffix(value);
      if (suffix != null) {
        return LocationNormalizer.canonicalStateId(suffix.state);
      }
    }
    return '';
  }

  static Iterable<String> _localityCandidates(
    Object? district,
    Object? address,
    Object? rawLocation,
  ) sync* {
    final seen = <String>{};
    final districtId = LocationNormalizer.canonicalDistrictId(district);
    if (districtId.isNotEmpty && seen.add(districtId)) {
      yield districtId;
    }

    for (final candidate in [
      ..._locationParts(rawLocation),
      ..._locationParts(address),
    ]) {
      if (LocationNormalizer.isKnownState(candidate)) {
        continue;
      }
      final id = LocationNormalizer.canonicalDistrictId(candidate);
      if (id.isNotEmpty && seen.add(id)) {
        yield id;
      }
    }
  }

  static Iterable<String> _locationParts(Object? value) sync* {
    final text = value?.toString();
    if (text == null || text.trim().isEmpty) {
      return;
    }
    for (final part in text.split(',')) {
      final trimmed = part.trim();
      if (trimmed.isNotEmpty) {
        yield trimmed;
      }
    }
  }

  static Iterable<String> _districtAliasesForLocality(
    String state,
    String locality,
  ) {
    return _stateLocalityAliases[state]?[locality] ?? const [];
  }

  static bool _hasConflictingLocationData({
    Object? state,
    Object? district,
    Object? rawLocation,
  }) {
    if (LocationNormalizer.hasConflictingKnownStates(rawLocation)) {
      return true;
    }

    final stateId = LocationNormalizer.canonicalStateId(state);
    if (stateId.isEmpty) {
      return false;
    }

    return LocationNormalizer.recognizedStateIds(
      district,
    ).any((districtStateId) => districtStateId != stateId);
  }

  static bool _validAreaId(Object? value) {
    final areaId = LocationNormalizer.canonicalAreaIdFromExisting(value);
    return areaId.isNotEmpty && areaId != 'unknown';
  }

  static bool _stateCompatible(String propertyState, AreaData area) {
    return propertyState.isEmpty || _sameState(propertyState, area);
  }

  static bool _sameState(String propertyState, AreaData area) {
    return LocationNormalizer.canonicalStateId(area.state) == propertyState;
  }

  static AreaData? _firstWhere(
    Iterable<AreaData> areas,
    bool Function(AreaData area) test,
  ) {
    for (final area in areas) {
      if (test(area)) {
        return area;
      }
    }
    return null;
  }
}

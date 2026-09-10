import 'package:latlong2/latlong.dart';

import '../../core/utils/location_normalizer.dart';
import '../../core/utils/property_area_resolver.dart';
import '../../core/utils/property_filtering.dart';
import '../../models/area_data.dart';
import '../../models/property.dart';

const String allMapAreasId = 'all';
const MapAreaOption allMapAreaOption = MapAreaOption(
  value: allMapAreasId,
  label: 'All areas',
);
const LatLng malaysiaMapCenter = LatLng(4.2105, 101.9758);
const double malaysiaMapZoom = 5.6;
const double singlePropertyMapZoom = 14;
const double selectedPropertyMapZoom = 15;
const double manyPropertiesMaxZoom = 12;
const double _malaysiaMinLatitude = 0.5;
const double _malaysiaMaxLatitude = 7.8;
const double _malaysiaMinLongitude = 99;
const double _malaysiaMaxLongitude = 119.5;

List<Property> visibleMapProperties(
  Iterable<Property> properties, {
  required String selectedAreaId,
  Iterable<AreaData> areas = const [],
}) {
  if (selectedAreaId == allMapAreasId) {
    return List<Property>.unmodifiable(properties);
  }
  return List<Property>.unmodifiable(
    properties.where((property) {
      final mapAreaId = mapAreaOptionForProperty(property, areas: areas)?.value;
      if (mapAreaId != null) {
        return LocationNormalizer.areaIdMatches(mapAreaId, selectedAreaId);
      }
      if (areas.isNotEmpty) {
        return PropertyAreaResolver.matchesSelectedArea(
          property: property,
          selectedAreaId: selectedAreaId,
          areas: areas,
        );
      }
      return PropertyFilterNormalizer.areaMatches(
        property.areaId,
        selectedAreaId,
      );
    }),
  );
}

List<MapAreaOption> mapAreaOptions(
  Iterable<Property> properties, {
  Iterable<AreaData> areas = const [],
}) {
  final labelsById = <String, String>{};
  for (final property in mappableMapProperties(properties)) {
    final option = mapAreaOptionForProperty(property, areas: areas);
    if (option == null) {
      continue;
    }
    labelsById.putIfAbsent(option.value, () => option.label);
  }

  final options =
      labelsById.entries
          .map((entry) => MapAreaOption(value: entry.key, label: entry.value))
          .toList()
        ..sort((left, right) {
          final labelOrder = left.label.compareTo(right.label);
          return labelOrder == 0
              ? left.value.compareTo(right.value)
              : labelOrder;
        });
  return List<MapAreaOption>.unmodifiable([allMapAreaOption, ...options]);
}

MapAreaOption? mapAreaOptionForProperty(
  Property property, {
  Iterable<AreaData> areas = const [],
}) {
  if (_hasConflictingMapLocationData(property)) {
    return null;
  }
  final propertyLocation = _propertyLocationOption(property);
  if (propertyLocation != null) {
    return propertyLocation;
  }

  final resolved = PropertyAreaResolver.resolve(
    property: property,
    areas: areas,
  );
  if (resolved != null) {
    return MapAreaOption(
      value: resolved.id,
      label: '${resolved.name}, ${resolved.state}',
    );
  }

  final normalizedAreaId = PropertyFilterNormalizer.normalizeAreaId(
    property.areaId,
  );
  if (normalizedAreaId.isEmpty || normalizedAreaId == 'unknown') {
    return null;
  }
  final matchedArea = _areaForId(normalizedAreaId, areas);
  if (matchedArea != null) {
    return MapAreaOption(
      value: matchedArea.id,
      label: '${matchedArea.name}, ${matchedArea.state}',
    );
  }
  return MapAreaOption(
    value: normalizedAreaId,
    label: LocationNormalizer.displayDistrictName(normalizedAreaId),
  );
}

List<Property> mappableMapProperties(Iterable<Property> properties) {
  return List<Property>.unmodifiable(properties.where(hasValidMapCoordinates));
}

bool hasValidMapCoordinates(Property property) {
  if (!property.hasCoordinates) {
    return false;
  }
  final latitude = property.latitude!;
  final longitude = property.longitude!;
  return latitude.isFinite &&
      longitude.isFinite &&
      (latitude != 0 || longitude != 0) &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180 &&
      latitude >= _malaysiaMinLatitude &&
      latitude <= _malaysiaMaxLatitude &&
      longitude >= _malaysiaMinLongitude &&
      longitude <= _malaysiaMaxLongitude;
}

LatLng propertyLatLng(Property property) {
  if (!hasValidMapCoordinates(property)) {
    throw ArgumentError('Property ${property.id} has invalid coordinates.');
  }
  return LatLng(property.latitude!, property.longitude!);
}

Property? selectedMapProperty(
  List<Property> properties, {
  required String? selectedPropertyId,
}) {
  if (properties.isEmpty) {
    return null;
  }
  if (selectedPropertyId == null) {
    return properties.first;
  }
  for (final property in properties) {
    if (property.id == selectedPropertyId) {
      return property;
    }
  }
  return properties.first;
}

MapCameraTarget cameraTargetForProperties(Iterable<Property> properties) {
  final mappable = mappableMapProperties(properties);
  if (mappable.isEmpty) {
    return const MapCameraTarget.center(
      center: malaysiaMapCenter,
      zoom: malaysiaMapZoom,
    );
  }
  if (mappable.length == 1) {
    return MapCameraTarget.center(
      center: propertyLatLng(mappable.single),
      zoom: singlePropertyMapZoom,
    );
  }
  return MapCameraTarget.bounds(
    points: mappable.map(propertyLatLng).toList(growable: false),
    maxZoom: manyPropertiesMaxZoom,
  );
}

PropertyCoordinateBounds propertyCoordinateBounds(List<Property> properties) {
  final mappable = mappableMapProperties(properties);
  if (mappable.isEmpty) {
    throw ArgumentError(
      'At least one property with valid coordinates is required.',
    );
  }

  var minLatitude = mappable.first.latitude!;
  var maxLatitude = minLatitude;
  var minLongitude = mappable.first.longitude!;
  var maxLongitude = minLongitude;

  for (final property in mappable.skip(1)) {
    final latitude = property.latitude!;
    final longitude = property.longitude!;
    if (latitude < minLatitude) {
      minLatitude = latitude;
    }
    if (latitude > maxLatitude) {
      maxLatitude = latitude;
    }
    if (longitude < minLongitude) {
      minLongitude = longitude;
    }
    if (longitude > maxLongitude) {
      maxLongitude = longitude;
    }
  }

  return PropertyCoordinateBounds(
    minLatitude: minLatitude,
    maxLatitude: maxLatitude,
    minLongitude: minLongitude,
    maxLongitude: maxLongitude,
  );
}

class MapCameraTarget {
  const MapCameraTarget.center({required this.center, required this.zoom})
    : points = const [],
      maxZoom = null;

  const MapCameraTarget.bounds({required this.points, required this.maxZoom})
    : center = null,
      zoom = null;

  final LatLng? center;
  final double? zoom;
  final List<LatLng> points;
  final double? maxZoom;

  bool get isBounds => points.length > 1;

  String get signature {
    if (!isBounds) {
      final targetCenter = center!;
      return [
        'center',
        targetCenter.latitude.toStringAsFixed(6),
        targetCenter.longitude.toStringAsFixed(6),
        zoom!.toStringAsFixed(2),
      ].join('|');
    }
    return [
      'bounds',
      maxZoom?.toStringAsFixed(2) ?? '',
      for (final point in points)
        '${point.latitude.toStringAsFixed(6)},${point.longitude.toStringAsFixed(6)}',
    ].join('|');
  }
}

class PropertyCoordinateBounds {
  const PropertyCoordinateBounds({
    required this.minLatitude,
    required this.maxLatitude,
    required this.minLongitude,
    required this.maxLongitude,
  });

  final double minLatitude;
  final double maxLatitude;
  final double minLongitude;
  final double maxLongitude;
}

class MapAreaOption {
  const MapAreaOption({required this.value, required this.label});

  final String value;
  final String label;
}

MapAreaOption? _propertyLocationOption(Property property) {
  final explicit = _optionFromStateDistrict(property.state, property.district);
  if (explicit != null) {
    return explicit;
  }

  for (final value in [property.rawLocation, property.address]) {
    final suffix = LocationNormalizer.matchStateSuffix(value);
    if (suffix == null || suffix.beforeState.isEmpty) {
      continue;
    }
    final inferred = _optionFromStateDistrict(suffix.state, suffix.beforeState);
    if (inferred != null) {
      return inferred;
    }
  }
  return null;
}

bool _hasConflictingMapLocationData(Property property) {
  if (LocationNormalizer.hasConflictingKnownStates(property.rawLocation)) {
    return true;
  }

  final stateId = LocationNormalizer.canonicalStateId(property.state);
  if (stateId.isEmpty) {
    return false;
  }
  return LocationNormalizer.recognizedStateIds(
    property.district,
  ).any((districtStateId) => districtStateId != stateId);
}

MapAreaOption? _optionFromStateDistrict(Object? state, Object? district) {
  final displayState = LocationNormalizer.nullableDisplayStateName(state);
  final displayDistrict = LocationNormalizer.nullableDisplayDistrictName(
    district,
  );
  if (displayState == null || displayDistrict == null) {
    return null;
  }
  return MapAreaOption(
    value: LocationNormalizer.canonicalAreaId(displayState, displayDistrict),
    label: '$displayDistrict, $displayState',
  );
}

AreaData? _areaForId(String areaId, Iterable<AreaData> areas) {
  for (final area in areas) {
    if (LocationNormalizer.areaIdMatches(area.id, areaId)) {
      return area;
    }
  }
  return null;
}

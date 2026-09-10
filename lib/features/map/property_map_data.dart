import 'package:latlong2/latlong.dart';

import '../../core/utils/property_filtering.dart';
import '../../models/property.dart';

const String allMapAreasId = 'all';
const LatLng malaysiaMapCenter = LatLng(4.2105, 101.9758);
const double malaysiaMapZoom = 5.6;
const double singlePropertyMapZoom = 14;
const double selectedPropertyMapZoom = 15;
const double manyPropertiesMaxZoom = 12;

List<Property> visibleMapProperties(
  Iterable<Property> properties, {
  required String selectedAreaId,
}) {
  if (selectedAreaId == allMapAreasId) {
    return List<Property>.unmodifiable(properties);
  }
  return List<Property>.unmodifiable(
    properties.where(
      (property) =>
          PropertyFilterNormalizer.areaMatches(property.areaId, selectedAreaId),
    ),
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
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
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

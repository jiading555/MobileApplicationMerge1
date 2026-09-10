import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive_layout.dart';
import '../../core/widgets/property_art.dart';
import '../../models/area_data.dart';
import '../../models/property.dart';
import '../search/property_detail_screen.dart';
import 'property_map_data.dart';

class PropertyMapScreen extends StatefulWidget {
  const PropertyMapScreen({
    this.useLiveMap = true,
    this.locationClient = const _GeolocatorPropertyMapLocationClient(),
    this.tileLayerBuilder,
    this.onCameraTargetApplied,
    this.onMarkerDataRecomputed,
    super.key,
  });

  @visibleForTesting
  final bool useLiveMap;

  @visibleForTesting
  final PropertyMapLocationClient locationClient;

  @visibleForTesting
  final WidgetBuilder? tileLayerBuilder;

  @visibleForTesting
  final ValueChanged<MapCameraTarget>? onCameraTargetApplied;

  @visibleForTesting
  final VoidCallback? onMarkerDataRecomputed;

  @override
  State<PropertyMapScreen> createState() => _PropertyMapScreenState();
}

@visibleForTesting
abstract interface class PropertyMapLocationClient {
  Future<bool> isLocationServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<LatLng> getCurrentLocation();
}

class _GeolocatorPropertyMapLocationClient
    implements PropertyMapLocationClient {
  const _GeolocatorPropertyMapLocationClient();

  @override
  Future<bool> isLocationServiceEnabled() {
    return Geolocator.isLocationServiceEnabled();
  }

  @override
  Future<LocationPermission> checkPermission() {
    return Geolocator.checkPermission();
  }

  @override
  Future<LocationPermission> requestPermission() {
    return Geolocator.requestPermission();
  }

  @override
  Future<LatLng> getCurrentLocation() async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
    );
    return LatLng(position.latitude, position.longitude);
  }
}

class _PropertyMapScreenState extends State<PropertyMapScreen> {
  final MapController _mapController = MapController();
  String? selectedPropertyId;
  String selectedAreaId = allMapAreasId;
  LatLng? _currentLocation;
  bool _mapReady = false;
  bool _isLocating = false;
  bool _disposed = false;
  int _pendingCameraRequest = 0;
  String? _lastCameraTargetSignature;
  String? _cachedAreaId;
  List<Property>? _cachedPropertySource;
  List<AreaData>? _cachedAreaSource;
  int _cachedPropertyLength = -1;
  int _cachedAreaLength = -1;
  List<Property> _visibleProperties = const [];
  List<Property> _mappableProperties = const [];
  List<MapAreaOption> _areaOptions = const [allMapAreaOption];
  List<Property>? _markerPropertySource;
  String? _markerSelectedPropertyId;
  List<Marker> _propertyMarkers = const [];

  @override
  void dispose() {
    _disposed = true;
    _pendingCameraRequest += 1;
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    _updatePropertyCache(state);
    final selected = selectedMapProperty(
      _mappableProperties,
      selectedPropertyId: selectedPropertyId,
    );
    _updateMarkerCache(
      properties: _mappableProperties,
      selectedPropertyId: selected?.id,
    );
    final compactHeight = ResponsiveLayout.isCompactLandscapePhone(context);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: compactHeight ? 48 : null,
        title: const Text('Map & nearby facilities'),
        actions: [
          IconButton(
            onPressed: () => _showMapInfo(context),
            icon: const Icon(Icons.info_outline_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = ResponsiveLayout.isTablet(context);
          final sidePanelWidth = ResponsiveLayout.isDesktop(context)
              ? 360.0
              : 340.0;
          final compactLandscapePhone =
              ResponsiveLayout.isCompactLandscapePhone(context);
          final map = _OpenStreetMapPropertyMap(
            controller: _mapController,
            properties: _mappableProperties,
            propertyMarkers: _propertyMarkers,
            currentLocation: _currentLocation,
            useLiveMap: widget.useLiveMap,
            isLocating: _isLocating,
            tileLayerBuilder: widget.tileLayerBuilder,
            onMapReady: _handleMapReady,
            onZoomIn: () => _zoomBy(1),
            onZoomOut: () => _zoomBy(-1),
            onMyLocation: _locateUser,
          );
          final panel = _LocationPanel(
            property: selected,
            compact: compactLandscapePhone,
          );
          return Column(
            children: [
              Padding(
                padding: compactLandscapePhone
                    ? const EdgeInsets.fromLTRB(10, 2, 10, 6)
                    : const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: DropdownButtonFormField<String>(
                  initialValue: selectedAreaId,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    prefixIconConstraints: BoxConstraints(
                      minWidth: compactLandscapePhone ? 40 : 44,
                      minHeight: compactLandscapePhone ? 40 : 44,
                    ),
                    labelText: 'Explore area',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: compactLandscapePhone ? 10 : 12,
                    ),
                  ),
                  isExpanded: true,
                  items: [
                    ..._areaOptions.map(
                      (option) => DropdownMenuItem(
                        value: option.value,
                        child: Text(option.label),
                      ),
                    ),
                  ],
                  onChanged: (value) => _selectArea(value ?? allMapAreasId),
                ),
              ),
              Expanded(
                child: wide
                    ? Row(
                        children: [
                          Expanded(flex: 7, child: map),
                          SizedBox(width: sidePanelWidth, child: panel),
                        ],
                      )
                    : _PhoneMapLayout(
                        map: map,
                        panel: panel,
                        hasSelection: selected != null,
                        overlaySelection: compactLandscapePhone,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _handleMapReady() {
    if (!mounted || _mapReady) {
      return;
    }
    _mapReady = true;
  }

  void _selectProperty(Property property) {
    if (selectedPropertyId == property.id) {
      return;
    }
    setState(() => selectedPropertyId = property.id);
    _moveCameraToProperty(property);
  }

  void _selectArea(String areaId) {
    if (areaId == selectedAreaId) {
      return;
    }
    setState(() {
      selectedAreaId = areaId;
      selectedPropertyId = null;
    });
    _scheduleCameraToCurrentProperties();
  }

  void _scheduleCameraToCurrentProperties() {
    final request = ++_pendingCameraRequest;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_disposed && request == _pendingCameraRequest) {
        _moveCameraToCurrentProperties(force: true);
      }
    });
  }

  void _moveCameraToCurrentProperties({bool force = false}) {
    if (!_mapReady || !widget.useLiveMap) {
      return;
    }
    final state = AppScope.read(context);
    _updatePropertyCache(state);
    _applyCameraTarget(
      cameraTargetForProperties(_mappableProperties),
      force: force,
    );
  }

  void _moveCameraToProperty(Property property) {
    if (!_mapReady || !widget.useLiveMap || !hasValidMapCoordinates(property)) {
      return;
    }
    _applyCameraTarget(
      MapCameraTarget.center(
        center: propertyLatLng(property),
        zoom: selectedPropertyMapZoom,
      ),
      force: true,
    );
  }

  void _applyCameraTarget(MapCameraTarget target, {bool force = false}) {
    final signature = target.signature;
    if (!force && _lastCameraTargetSignature == signature) {
      return;
    }
    _lastCameraTargetSignature = signature;
    widget.onCameraTargetApplied?.call(target);
    if (target.isBounds) {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(target.points),
          padding: const EdgeInsets.all(64),
          maxZoom: target.maxZoom,
        ),
      );
      return;
    }
    _mapController.move(target.center!, target.zoom!);
  }

  void _zoomBy(double delta) {
    if (!_mapReady || !widget.useLiveMap) {
      return;
    }
    final camera = _mapController.camera;
    final zoom = (camera.zoom + delta).clamp(4, 18).toDouble();
    _mapController.move(camera.center, zoom);
  }

  Future<void> _locateUser() async {
    if (_isLocating) {
      return;
    }
    setState(() => _isLocating = true);
    try {
      final serviceEnabled = await widget.locationClient
          .isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationMessage('Turn on location services to use My Location.');
        return;
      }

      var permission = await widget.locationClient.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await widget.locationClient.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _showLocationMessage('Location permission was denied.');
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        _showLocationMessage(
          'Location permission is permanently denied. Enable it in settings.',
        );
        return;
      }

      final point = await widget.locationClient.getCurrentLocation();
      if (!mounted) {
        return;
      }
      setState(() => _currentLocation = point);
      if (_mapReady && widget.useLiveMap) {
        _applyCameraTarget(
          MapCameraTarget.center(center: point, zoom: selectedPropertyMapZoom),
          force: true,
        );
      }
    } catch (error) {
      if (mounted) {
        _showLocationMessage('Could not get current location.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  void _showLocationMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showMapInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('OpenStreetMap'),
        content: const Text(
          'Property pins are generated from Supabase records that include valid latitude and longitude values. Records without coordinates remain available in Search and Details, but are not shown as map pins.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _updatePropertyCache(AppState state) {
    final sourcesUnchanged =
        identical(_cachedPropertySource, state.properties) &&
        identical(_cachedAreaSource, state.areas) &&
        _cachedPropertyLength == state.properties.length &&
        _cachedAreaLength == state.areas.length;
    if (sourcesUnchanged && _cachedAreaId == selectedAreaId) {
      return;
    }
    if (!sourcesUnchanged) {
      _areaOptions = mapAreaOptions(state.properties, areas: state.areas);
      final availableAreaIds = _areaOptions
          .map((option) => option.value)
          .toSet();
      if (!availableAreaIds.contains(selectedAreaId)) {
        selectedAreaId = allMapAreasId;
        selectedPropertyId = null;
      }
    }
    _visibleProperties = visibleMapProperties(
      state.properties,
      selectedAreaId: selectedAreaId,
      areas: state.areas,
    );
    _mappableProperties = mappableMapProperties(_visibleProperties);
    _cachedPropertySource = state.properties;
    _cachedAreaSource = state.areas;
    _cachedPropertyLength = state.properties.length;
    _cachedAreaLength = state.areas.length;
    _cachedAreaId = selectedAreaId;
  }

  void _updateMarkerCache({
    required List<Property> properties,
    required String? selectedPropertyId,
  }) {
    if (identical(_markerPropertySource, properties) &&
        _markerSelectedPropertyId == selectedPropertyId) {
      return;
    }
    _propertyMarkers = [
      for (final property in properties)
        Marker(
          key: ValueKey('property-marker-${property.id}'),
          point: propertyLatLng(property),
          width: 116,
          height: 58,
          alignment: Alignment.topCenter,
          child: _PropertyMarker(
            property: property,
            selected: property.id == selectedPropertyId,
            onTap: () => _selectProperty(property),
          ),
        ),
    ];
    _markerPropertySource = properties;
    _markerSelectedPropertyId = selectedPropertyId;
    widget.onMarkerDataRecomputed?.call();
  }
}

class _OpenStreetMapPropertyMap extends StatelessWidget {
  const _OpenStreetMapPropertyMap({
    required this.controller,
    required this.properties,
    required this.propertyMarkers,
    required this.currentLocation,
    required this.useLiveMap,
    required this.isLocating,
    required this.tileLayerBuilder,
    required this.onMapReady,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onMyLocation,
  });

  final MapController controller;
  final List<Property> properties;
  final List<Marker> propertyMarkers;
  final LatLng? currentLocation;
  final bool useLiveMap;
  final bool isLocating;
  final WidgetBuilder? tileLayerBuilder;
  final VoidCallback onMapReady;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onMyLocation;

  @override
  Widget build(BuildContext context) {
    final initialTarget = cameraTargetForProperties(properties);
    if (!useLiveMap) {
      return _TestMapPlaceholder(
        markerCount: properties.length,
        cameraTarget: initialTarget,
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: controller,
            options: MapOptions(
              initialCenter: initialTarget.center ?? malaysiaMapCenter,
              initialZoom: initialTarget.zoom ?? malaysiaMapZoom,
              initialCameraFit: initialTarget.isBounds
                  ? CameraFit.bounds(
                      bounds: LatLngBounds.fromPoints(initialTarget.points),
                      padding: const EdgeInsets.all(64),
                      maxZoom: initialTarget.maxZoom,
                    )
                  : null,
              minZoom: 4,
              maxZoom: 18,
              keepAlive: true,
              onMapReady: onMapReady,
            ),
            children: [
              tileLayerBuilder?.call(context) ??
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.smart_property_advisor',
                    maxZoom: 19,
                  ),
              MarkerLayer(markers: propertyMarkers),
              if (currentLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      key: const ValueKey('current-location-marker'),
                      point: currentLocation!,
                      width: 34,
                      height: 34,
                      child: const _CurrentLocationMarker(),
                    ),
                  ],
                ),
              RichAttributionWidget(
                alignment: AttributionAlignment.bottomRight,
                popupBackgroundColor: Colors.white,
                popupBorderRadius: BorderRadius.circular(8),
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    onTap: _openOpenStreetMapCopyright,
                  ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: Column(
            children: [
              _MapControl(
                tooltip: 'Zoom in',
                icon: Icons.add_rounded,
                onTap: onZoomIn,
              ),
              const SizedBox(height: 6),
              _MapControl(
                tooltip: 'Zoom out',
                icon: Icons.remove_rounded,
                onTap: onZoomOut,
              ),
              const SizedBox(height: 12),
              _MapControl(
                tooltip: 'My location',
                icon: Icons.my_location_rounded,
                onTap: onMyLocation,
                isLoading: isLocating,
              ),
            ],
          ),
        ),
        if (properties.isEmpty)
          const Center(
            child: _MapEmptyState(
              message: 'No records with coordinates in this area.',
            ),
          ),
      ],
    );
  }
}

class _PropertyMarker extends StatelessWidget {
  const _PropertyMarker({
    required this.property,
    required this.selected,
    required this.onTap,
  });

  final Property property;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = selected ? AppTheme.navy : Colors.white;
    final foreground = selected ? Colors.white : AppTheme.blue;
    return Semantics(
      button: true,
      label: 'Select ${property.name}',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 160),
          scale: selected ? 1.08 : 1,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 108,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  _priceText(property, compact: true),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(Icons.location_pin, color: foreground, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentLocationMarker extends StatelessWidget {
  const _CurrentLocationMarker();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.blue.withValues(alpha: 0.18),
      ),
      child: Center(
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.blue,
            border: Border.all(color: Colors.white, width: 3),
          ),
        ),
      ),
    );
  }
}

class _PhoneMapLayout extends StatelessWidget {
  const _PhoneMapLayout({
    required this.map,
    required this.panel,
    required this.hasSelection,
    required this.overlaySelection,
  });

  final Widget map;
  final Widget panel;
  final bool hasSelection;
  final bool overlaySelection;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!hasSelection) {
          return map;
        }
        if (overlaySelection) {
          return Stack(
            children: [
              Positioned.fill(child: map),
              Positioned.fill(
                child: SafeArea(
                  top: false,
                  left: false,
                  right: false,
                  minimum: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Align(alignment: Alignment.bottomCenter, child: panel),
                ),
              ),
            ],
          );
        }
        final compactHeight = constraints.maxHeight < 520;
        final panelHeight = compactHeight
            ? (constraints.maxHeight * 0.45).clamp(140.0, 200.0)
            : (constraints.maxHeight * 0.42).clamp(220.0, 340.0);
        return Column(
          children: [
            Expanded(child: map),
            SizedBox(height: panelHeight, child: panel),
          ],
        );
      },
    );
  }
}

class _LocationPanel extends StatelessWidget {
  const _LocationPanel({required this.property, this.compact = false});

  final Property? property;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (property == null) {
      return const ColoredBox(
        color: Colors.white,
        child: Center(child: Text('No properties in this area.')),
      );
    }
    final state = AppScope.of(context);
    final area = state.matchedAreaFor(property!);
    if (compact) {
      return Material(
        key: const ValueKey('property-map-compact-preview'),
        color: Colors.white,
        elevation: 10,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const actionMinWidth = 124.0;
            final useHorizontalLayout =
                constraints.maxWidth >= actionMinWidth + 180;
            final details = _CompactPropertyDetails(property: property!);
            final action = ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: actionMinWidth,
                minHeight: 44,
              ),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(actionMinWidth, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        PropertyDetailScreen(propertyId: property!.id),
                  ),
                ),
                child: const Text(
                  'View Details',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );

            if (!useHorizontalLayout) {
              return Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [details, const SizedBox(height: 7), action],
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: details),
                  const SizedBox(width: 10),
                  action,
                ],
              ),
            );
          },
        ),
      );
    }
    return Material(
      color: Colors.white,
      elevation: 10,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD5DDE8),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 12),
            PropertyArt(palette: property!.palette, height: 120),
            const SizedBox(height: 12),
            Text(property!.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              property!.address,
              style: const TextStyle(color: AppTheme.muted),
            ),
            const SizedBox(height: 7),
            Text(
              _priceText(property!),
              style: const TextStyle(
                color: AppTheme.green,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Area insights',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _MiniInsight(
                    label: 'Safety',
                    value: _scoreText(area?.safetyScore),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniInsight(
                    label: 'Transit',
                    value: _scoreText(area?.transportScore),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: _MiniInsight(
                    label: 'Schools',
                    value: area?.schools?.toString() ?? 'N/A',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniInsight(
                    label: 'Hospitals',
                    value: area?.hospitals?.toString() ?? 'N/A',
                  ),
                ),
              ],
            ),
            if (property!.facilities.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: property!.facilities
                    .map(
                      (item) => Chip(
                        label: Text(item, style: const TextStyle(fontSize: 10)),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        PropertyDetailScreen(propertyId: property!.id),
                  ),
                ),
                child: const Text('View property details'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactPropertyDetails extends StatelessWidget {
  const _CompactPropertyDetails({required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          property.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 2),
        Text(
          property.address,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppTheme.muted, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          _priceText(property),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppTheme.green,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _MapControl extends StatelessWidget {
  const _MapControl({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.isLoading = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(8),
      child: IconButton(
        tooltip: tooltip,
        onPressed: isLoading ? null : onTap,
        icon: isLoading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon),
        iconSize: 20,
      ),
    );
  }
}

class _MapEmptyState extends StatelessWidget {
  const _MapEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(message, style: const TextStyle(color: AppTheme.muted)),
      ),
    );
  }
}

class _TestMapPlaceholder extends StatelessWidget {
  const _TestMapPlaceholder({
    required this.markerCount,
    required this.cameraTarget,
  });

  final int markerCount;
  final MapCameraTarget cameraTarget;

  @override
  Widget build(BuildContext context) {
    final center = cameraTarget.center ?? malaysiaMapCenter;
    return ColoredBox(
      key: const ValueKey('property-map-content'),
      color: const Color(0xFFEAF2E8),
      child: Center(
        child: _MapEmptyState(
          message:
              'OpenStreetMap test placeholder - $markerCount markers near ${center.latitude.toStringAsFixed(2)}, ${center.longitude.toStringAsFixed(2)}.',
        ),
      ),
    );
  }
}

String _priceText(Property property, {bool compact = false}) {
  final min = property.priceMin;
  final max = property.priceMax;
  if (min != null && max != null && min != max) {
    return compact
        ? '${formatRinggit(min, compact: true)}+'
        : '${formatRinggit(min)} - ${formatRinggit(max)}';
  }
  final price = property.price ?? min ?? max;
  return price == null
      ? 'Price unavailable'
      : formatRinggit(price, compact: compact);
}

String _scoreText(double? score) {
  return score == null ? 'N/A' : '${score.round()}/100';
}

class _MiniInsight extends StatelessWidget {
  const _MiniInsight({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: AppTheme.canvas,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppTheme.muted, fontSize: 10),
          ),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

void _openOpenStreetMapCopyright() {
  launchUrl(
    Uri.parse('https://www.openstreetmap.org/copyright'),
    mode: LaunchMode.externalApplication,
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive_layout.dart';
import '../../core/widgets/property_art.dart';
import '../../models/property.dart';
import '../search/property_detail_screen.dart';
import 'property_map_data.dart';

class PropertyMapScreen extends StatefulWidget {
  const PropertyMapScreen({this.useLiveMap = true, super.key});

  @visibleForTesting
  final bool useLiveMap;

  @override
  State<PropertyMapScreen> createState() => _PropertyMapScreenState();
}

class _PropertyMapScreenState extends State<PropertyMapScreen> {
  final MapController _mapController = MapController();
  String? selectedPropertyId;
  String selectedAreaId = allMapAreasId;
  LatLng? _currentLocation;
  bool _mapReady = false;
  bool _isLocating = false;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final properties = visibleMapProperties(
      state.properties,
      selectedAreaId: selectedAreaId,
    );
    final mappableProperties = mappableMapProperties(properties);
    final selected = selectedMapProperty(
      properties,
      selectedPropertyId: selectedPropertyId,
    );
    return Scaffold(
      appBar: AppBar(
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
          final map = _OpenStreetMapPropertyMap(
            controller: _mapController,
            properties: mappableProperties,
            selectedPropertyId: selected?.id,
            currentLocation: _currentLocation,
            useLiveMap: widget.useLiveMap,
            isLocating: _isLocating,
            onMapReady: _handleMapReady,
            onSelect: _selectProperty,
            onZoomIn: () => _zoomBy(1),
            onZoomOut: () => _zoomBy(-1),
            onMyLocation: _locateUser,
          );
          final panel = _LocationPanel(property: selected);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                child: DropdownButtonFormField<String>(
                  initialValue: selectedAreaId,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.location_on_outlined),
                    labelText: 'Explore area',
                    isDense: true,
                  ),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(
                      value: allMapAreasId,
                      child: Text('All areas'),
                    ),
                    ...state.areas.map(
                      (area) => DropdownMenuItem(
                        value: area.id,
                        child: Text('${area.name}, ${area.state}'),
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
                          SizedBox(width: 360, child: panel),
                        ],
                      )
                    : _PhoneMapLayout(
                        map: map,
                        panel: panel,
                        hasSelection: selected != null,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _handleMapReady() {
    _mapReady = true;
    _moveCameraToCurrentProperties();
  }

  void _selectProperty(Property property) {
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _moveCameraToCurrentProperties();
      }
    });
  }

  void _moveCameraToCurrentProperties() {
    if (!_mapReady || !widget.useLiveMap) {
      return;
    }
    final state = AppScope.read(context);
    final properties = mappableMapProperties(
      visibleMapProperties(state.properties, selectedAreaId: selectedAreaId),
    );
    _applyCameraTarget(cameraTargetForProperties(properties));
  }

  void _moveCameraToProperty(Property property) {
    if (!_mapReady || !widget.useLiveMap || !hasValidMapCoordinates(property)) {
      return;
    }
    _mapController.move(propertyLatLng(property), selectedPropertyMapZoom);
  }

  void _applyCameraTarget(MapCameraTarget target) {
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
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationMessage('Turn on location services to use My Location.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
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

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      final point = LatLng(position.latitude, position.longitude);
      if (!mounted) {
        return;
      }
      setState(() => _currentLocation = point);
      if (_mapReady && widget.useLiveMap) {
        _mapController.move(point, selectedPropertyMapZoom);
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
}

class _OpenStreetMapPropertyMap extends StatelessWidget {
  const _OpenStreetMapPropertyMap({
    required this.controller,
    required this.properties,
    required this.selectedPropertyId,
    required this.currentLocation,
    required this.useLiveMap,
    required this.isLocating,
    required this.onMapReady,
    required this.onSelect,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onMyLocation,
  });

  final MapController controller;
  final List<Property> properties;
  final String? selectedPropertyId;
  final LatLng? currentLocation;
  final bool useLiveMap;
  final bool isLocating;
  final VoidCallback onMapReady;
  final ValueChanged<Property> onSelect;
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
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.smart_property_advisor',
                maxZoom: 19,
              ),
              MarkerLayer(markers: _propertyMarkers()),
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

  List<Marker> _propertyMarkers() {
    return [
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
            onTap: () => onSelect(property),
          ),
        ),
    ];
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
  });

  final Widget map;
  final Widget panel;
  final bool hasSelection;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!hasSelection) {
          return map;
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
  const _LocationPanel({required this.property});

  final Property? property;

  @override
  Widget build(BuildContext context) {
    if (property == null) {
      return const ColoredBox(
        color: Colors.white,
        child: Center(child: Text('No properties in this area.')),
      );
    }
    final state = AppScope.of(context);
    final area = state.areaFor(property!.areaId);
    return Material(
      color: Colors.white,
      elevation: 10,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
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
            const SizedBox(height: 14),
            PropertyArt(palette: property!.palette, height: 132),
            const SizedBox(height: 14),
            Text(property!.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              property!.address,
              style: const TextStyle(color: AppTheme.muted),
            ),
            const SizedBox(height: 8),
            Text(
              _priceText(property!),
              style: const TextStyle(
                color: AppTheme.green,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Area insights',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MiniInsight(
                    label: 'Safety',
                    value: _scoreText(area.safetyScore),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniInsight(
                    label: 'Transit',
                    value: _scoreText(area.transportScore),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _MiniInsight(
                    label: 'Schools',
                    value: area.schools?.toString() ?? 'N/A',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniInsight(
                    label: 'Hospitals',
                    value: area.hospitals?.toString() ?? 'N/A',
                  ),
                ),
              ],
            ),
            if (property!.facilities.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: property!.facilities
                    .map(
                      (item) => Chip(
                        label: Text(item, style: const TextStyle(fontSize: 10)),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
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
      padding: const EdgeInsets.all(11),
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
          const SizedBox(height: 3),
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

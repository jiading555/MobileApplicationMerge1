import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:smart_property_advisor/app/app_scope.dart';
import 'package:smart_property_advisor/app/app_state.dart';
import 'package:smart_property_advisor/core/theme/app_theme.dart';
import 'package:smart_property_advisor/features/map/property_map_data.dart';
import 'package:smart_property_advisor/features/map/property_map_screen.dart';
import 'package:smart_property_advisor/features/search/property_detail_screen.dart';
import 'package:smart_property_advisor/models/area_data.dart';
import 'package:smart_property_advisor/models/property.dart';

void main() {
  testWidgets('opening live map does not repeatedly request app camera moves', (
    tester,
  ) async {
    var cameraTargets = 0;
    var markerRecomputes = 0;
    await _pumpMap(
      tester,
      locationClient: _FakeLocationClient.throwing(),
      onCameraTargetApplied: (_) => cameraTargets += 1,
      onMarkerDataRecomputed: () => markerRecomputes += 1,
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(cameraTargets, 0);
    expect(markerRecomputes, 1);
  });

  testWidgets('area filter change requests one camera fit', (tester) async {
    final appliedTargets = <MapCameraTarget>[];
    await _pumpMap(
      tester,
      locationClient: _FakeLocationClient.throwing(),
      onCameraTargetApplied: appliedTargets.add,
    );

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Petaling, Selangor').last);
    await tester.pump();
    await tester.pump();

    expect(appliedTargets, hasLength(1));
    expect(appliedTargets.single.isBounds, isFalse);
    expect(appliedTargets.single.center, const LatLng(3.1, 101.6));
  });

  testWidgets('selecting a new marker requests one property recenter', (
    tester,
  ) async {
    final appliedTargets = <MapCameraTarget>[];
    await _pumpMap(
      tester,
      locationClient: _FakeLocationClient.throwing(),
      onCameraTargetApplied: appliedTargets.add,
    );

    await tester.tap(find.text('RM 320K+'));
    await tester.pump();

    expect(appliedTargets, hasLength(1));
    expect(appliedTargets.single.center, const LatLng(3.1, 101.6));
    expect(appliedTargets.single.zoom, selectedPropertyMapZoom);
  });

  testWidgets('zoom camera movement does not regenerate property markers', (
    tester,
  ) async {
    var markerRecomputes = 0;
    await _pumpMap(
      tester,
      locationClient: _FakeLocationClient.throwing(),
      onMarkerDataRecomputed: () => markerRecomputes += 1,
    );

    expect(markerRecomputes, 1);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.add_rounded));
    await tester.pump();
    await tester.pump();

    expect(markerRecomputes, 1);
  });

  testWidgets('renders live map without checking location permission', (
    tester,
  ) async {
    await _pumpMap(tester, locationClient: _FakeLocationClient.throwing());

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byKey(const ValueKey('test-tile-layer')), findsOneWidget);
    expect(find.text('RM 280K+'), findsOneWidget);
    expect(find.text('RM 320K+'), findsOneWidget);
    expect(find.text('Residensi Klang One'), findsOneWidget);
  });

  testWidgets('area filtering and detail navigation do not use location', (
    tester,
  ) async {
    final locationClient = _FakeLocationClient.throwing();
    await _pumpMap(tester, locationClient: locationClient);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Petaling, Selangor').last);
    await tester.pump();

    expect(find.text('Residensi Petaling Two'), findsOneWidget);
    expect(find.text('RM 320K+'), findsOneWidget);
    expect(locationClient.totalCalls, 0);

    await tester.tap(find.text('View property details'));
    await tester.pumpAndSettle();

    expect(find.byType(PropertyDetailScreen), findsOneWidget);
    expect(find.text('Residensi Petaling Two'), findsOneWidget);
    expect(locationClient.totalCalls, 0);
  });

  testWidgets('Explore area dropdown only lists mappable property areas', (
    tester,
  ) async {
    await _pumpMap(
      tester,
      state: _johorMapState(),
      locationClient: _FakeLocationClient.throwing(),
    );

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    expect(find.text('Kluang, Johor'), findsWidgets);
    expect(find.text('Muar, Johor'), findsWidgets);
    expect(find.text('Batu Pahat, Johor'), findsNothing);
  });

  testWidgets('Kluang filter hides other markers and All areas restores them', (
    tester,
  ) async {
    await _pumpMap(
      tester,
      state: _johorMapState(),
      useLiveMap: false,
      locationClient: _FakeLocationClient.throwing(),
    );

    expect(
      find.textContaining('OpenStreetMap test placeholder - 2 markers'),
      findsOneWidget,
    );

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kluang, Johor').last);
    await tester.pump();

    expect(find.text('Residensi Kluang Marker'), findsOneWidget);
    expect(
      find.textContaining('OpenStreetMap test placeholder - 1 markers'),
      findsOneWidget,
    );
    expect(find.text('Residensi Muar Marker'), findsNothing);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All areas').last);
    await tester.pump();

    expect(
      find.textContaining('OpenStreetMap test placeholder - 2 markers'),
      findsOneWidget,
    );
  });

  testWidgets('landscape phone overlays area selector on primary map area', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      AppScope(
        notifier: _mapState(),
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: const MediaQueryData(size: Size(844, 390)),
            child: child!,
          ),
          home: PropertyMapScreen(
            locationClient: _FakeLocationClient.throwing(),
            tileLayerBuilder: (_) =>
                const SizedBox.expand(key: ValueKey('test-tile-layer')),
          ),
        ),
      ),
    );
    await tester.pump();

    final selector = find.byKey(const ValueKey('property-map-area-selector'));
    final map = find.byType(FlutterMap);
    final preview = find.byKey(const ValueKey('property-map-compact-preview'));
    final viewDetails = find.widgetWithText(FilledButton, 'View Details');
    final zoomIn = find.widgetWithIcon(IconButton, Icons.add_rounded);
    final zoomOut = find.widgetWithIcon(IconButton, Icons.remove_rounded);
    final myLocation = find.widgetWithIcon(
      IconButton,
      Icons.my_location_rounded,
    );

    expect(tester.takeException(), isNull);
    expect(selector, findsOneWidget);
    expect(map, findsOneWidget);
    expect(preview, findsOneWidget);
    expect(viewDetails, findsOneWidget);
    expect(zoomIn, findsOneWidget);
    expect(zoomOut, findsOneWidget);
    expect(myLocation, findsOneWidget);

    final appBarRect = tester.getRect(find.byType(AppBar));
    final mapRect = tester.getRect(map);
    final selectorRect = tester.getRect(selector);
    final previewRect = tester.getRect(preview);
    final viewDetailsRect = tester.getRect(viewDetails);
    final zoomInRect = tester.getRect(zoomIn);
    final zoomOutRect = tester.getRect(zoomOut);
    final myLocationRect = tester.getRect(myLocation);

    expect(mapRect.top, appBarRect.bottom);
    expect(selectorRect.top, greaterThan(mapRect.top));
    expect(selectorRect.left, greaterThan(mapRect.left));
    expect(selectorRect.right, lessThan(zoomInRect.left));
    expect(selectorRect.width, lessThanOrEqualTo(300));
    expect(previewRect.bottom, lessThanOrEqualTo(390));
    expect(previewRect.top, greaterThan(selectorRect.bottom));
    expect(viewDetailsRect.bottom, lessThanOrEqualTo(previewRect.bottom));
    expect(zoomInRect.right, lessThanOrEqualTo(mapRect.right));
    expect(zoomOutRect.right, lessThanOrEqualTo(mapRect.right));
    expect(myLocationRect.right, lessThanOrEqualTo(mapRect.right));

    await tester.tap(viewDetails);
    await tester.pumpAndSettle();

    expect(find.byType(PropertyDetailScreen), findsOneWidget);
  });

  testWidgets('portrait phone keeps Explore area above map', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      AppScope(
        notifier: _mapState(),
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: const MediaQueryData(size: Size(390, 844)),
            child: child!,
          ),
          home: PropertyMapScreen(
            useLiveMap: false,
            locationClient: _FakeLocationClient.throwing(),
          ),
        ),
      ),
    );
    await tester.pump();

    final selectorRect = tester.getRect(
      find.byKey(const ValueKey('property-map-area-selector')),
    );
    final mapRect = tester.getRect(
      find.byKey(const ValueKey('property-map-content')),
    );

    expect(tester.takeException(), isNull);
    expect(selectorRect.bottom, lessThanOrEqualTo(mapRect.top));
    expect(selectorRect.width, greaterThan(350));
  });

  for (final size in [const Size(780, 360), const Size(844, 390)]) {
    testWidgets(
      'landscape phone selected preview keeps View Details tappable at $size',
      (tester) async {
        const safePadding = EdgeInsets.only(bottom: 32);
        await _pumpMapWithSideNavigationWidth(
          tester,
          size: size,
          safePadding: safePadding,
          state: _longLandscapeMapState(),
        );

        await tester.tap(find.text('RM 320K+'));
        await tester.pump();

        final preview = find.byKey(
          const ValueKey('property-map-compact-preview'),
        );
        final viewDetails = find.widgetWithText(FilledButton, 'View Details');

        expect(tester.takeException(), isNull);
        expect(preview, findsOneWidget);
        expect(find.textContaining('Residensi Petaling Two'), findsOneWidget);
        expect(viewDetails, findsOneWidget);

        final safeBottom = size.height - safePadding.bottom;
        final previewRect = tester.getRect(preview);
        final buttonRect = tester.getRect(viewDetails);

        expect(previewRect.bottom, lessThanOrEqualTo(safeBottom));
        expect(buttonRect.left, greaterThanOrEqualTo(0));
        expect(buttonRect.right, lessThanOrEqualTo(size.width));
        expect(buttonRect.bottom, lessThanOrEqualTo(safeBottom));

        await tester.tap(viewDetails);
        await tester.pumpAndSettle();

        expect(find.byType(PropertyDetailScreen), findsOneWidget);
        expect(
          find.text('Residensi Petaling Two With A Long Official Project Name'),
          findsOneWidget,
        );
      },
    );
  }

  for (final scenario in [
    _LocationScenario(
      name: 'location services disabled',
      client: _FakeLocationClient(serviceEnabled: false),
      message: 'Turn on location services to use My Location.',
    ),
    _LocationScenario(
      name: 'location permission denied',
      client: _FakeLocationClient(
        checkPermissionResult: LocationPermission.denied,
        requestPermissionResult: LocationPermission.denied,
      ),
      message: 'Location permission was denied.',
    ),
    _LocationScenario(
      name: 'location permission permanently denied',
      client: _FakeLocationClient(
        checkPermissionResult: LocationPermission.deniedForever,
      ),
      message:
          'Location permission is permanently denied. Enable it in settings.',
    ),
  ]) {
    testWidgets('${scenario.name} keeps the map usable', (tester) async {
      await _pumpMap(tester, locationClient: scenario.client);

      await tester.tap(
        find.widgetWithIcon(IconButton, Icons.my_location_rounded),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byKey(const ValueKey('test-tile-layer')), findsOneWidget);
      expect(find.text('Residensi Klang One'), findsOneWidget);
      expect(find.text(scenario.message), findsOneWidget);
      expect(scenario.client.currentLocationCalls, 0);
    });
  }

  testWidgets('granted location recenters without changing property flow', (
    tester,
  ) async {
    final locationClient = _FakeLocationClient(
      checkPermissionResult: LocationPermission.whileInUse,
      currentLocation: const LatLng(3.139, 101.6869),
    );
    await _pumpMap(tester, locationClient: locationClient);

    await tester.tap(
      find.widgetWithIcon(IconButton, Icons.my_location_rounded),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(locationClient.currentLocationCalls, 1);

    await tester.tap(find.text('View property details'));
    await tester.pumpAndSettle();

    expect(find.byType(PropertyDetailScreen), findsOneWidget);
    expect(find.text('Residensi Klang One'), findsOneWidget);
  });
}

Future<void> _pumpMap(
  WidgetTester tester, {
  AppState? state,
  bool useLiveMap = true,
  required PropertyMapLocationClient locationClient,
  ValueChanged<MapCameraTarget>? onCameraTargetApplied,
  VoidCallback? onMarkerDataRecomputed,
}) async {
  await tester.binding.setSurfaceSize(const Size(1024, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    AppScope(
      notifier: state ?? _mapState(),
      child: MaterialApp(
        theme: AppTheme.light.copyWith(splashFactory: NoSplash.splashFactory),
        home: PropertyMapScreen(
          useLiveMap: useLiveMap,
          locationClient: locationClient,
          onCameraTargetApplied: onCameraTargetApplied,
          onMarkerDataRecomputed: onMarkerDataRecomputed,
          tileLayerBuilder: (_) =>
              const SizedBox.expand(key: ValueKey('test-tile-layer')),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpMapWithSideNavigationWidth(
  WidgetTester tester, {
  required Size size,
  required EdgeInsets safePadding,
  required AppState state,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    AppScope(
      notifier: state,
      child: MaterialApp(
        theme: AppTheme.light.copyWith(splashFactory: NoSplash.splashFactory),
        builder: (context, child) => MediaQuery(
          data: MediaQueryData(size: size, padding: safePadding),
          child: child!,
        ),
        home: Row(
          children: [
            const SizedBox(width: 72),
            const VerticalDivider(width: 1),
            Expanded(
              child: PropertyMapScreen(
                locationClient: _FakeLocationClient.throwing(),
                tileLayerBuilder: (_) =>
                    const SizedBox.expand(key: ValueKey('test-tile-layer')),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
}

AppState _mapState() {
  final state = AppState();
  state.isLoading = false;
  state.isUsingCloudAreaProfiles = true;
  state.isUsingCloudProperties = true;
  state.areas = const [
    AreaData(
      id: 'selangor_klang',
      name: 'Klang',
      state: 'Selangor',
      population: 1088000,
      medianIncome: 9120,
      safetyScore: 84,
      transportScore: 72,
      schools: 112,
      snapshotDate: '2025',
      source: 'OpenDOSM; data.gov.my',
      isGovernmentProfile: true,
    ),
    AreaData(
      id: 'selangor_petaling',
      name: 'Petaling',
      state: 'Selangor',
      population: 2360000,
      medianIncome: 10400,
      safetyScore: 78,
      transportScore: 88,
      schools: 220,
      snapshotDate: '2025',
      source: 'OpenDOSM; data.gov.my',
      isGovernmentProfile: true,
    ),
  ];
  state.properties = [
    Property(
      id: 'teduh_klang_1',
      name: 'Residensi Klang One',
      areaId: 'selangor_klang',
      address: 'Klang, Selangor',
      type: 'Apartment',
      tenure: 'Leasehold',
      state: 'Selangor',
      district: 'Klang',
      priceMin: 280000,
      priceMax: 350000,
      latitude: 3.03,
      longitude: 101.44,
      summary: 'Official housing project information sourced from TEDUH.',
      facilities: const ['PR1MA Homes', 'Klang'],
      palette: 1,
      source: 'TEDUH - Jabatan Perumahan Negara, KPKT',
      sourceId: 'KLANG_1',
      scheme: 'PR1MA Homes',
    ),
    Property(
      id: 'teduh_petaling_2',
      name: 'Residensi Petaling Two',
      areaId: 'selangor_petaling',
      address: 'Petaling, Selangor',
      type: 'Apartment',
      tenure: 'Leasehold',
      state: 'Selangor',
      district: 'Petaling',
      priceMin: 320000,
      priceMax: 410000,
      latitude: 3.1,
      longitude: 101.6,
      summary: 'Official housing project information sourced from TEDUH.',
      facilities: const ['Transit', 'Petaling'],
      palette: 2,
      source: 'TEDUH - Jabatan Perumahan Negara, KPKT',
      sourceId: 'PETALING_2',
      scheme: 'Rumah Selangorku',
    ),
  ];
  return state;
}

AppState _longLandscapeMapState() {
  final state = _mapState();
  state.properties = [
    state.properties.first,
    const Property(
      id: 'teduh_petaling_2',
      name: 'Residensi Petaling Two With A Long Official Project Name',
      areaId: 'selangor_petaling',
      address:
          'Persiaran Petaling Utama Near Transit And Community Facilities, Selangor',
      type: 'Apartment',
      tenure: 'Leasehold',
      state: 'Selangor',
      district: 'Petaling',
      priceMin: 320000,
      priceMax: 410000,
      latitude: 3.1,
      longitude: 101.6,
      summary: 'Official housing project information sourced from TEDUH.',
      facilities: ['Transit', 'Petaling'],
      palette: 2,
      source: 'TEDUH - Jabatan Perumahan Negara, KPKT',
      sourceId: 'PETALING_2',
      scheme: 'Rumah Selangorku',
    ),
  ];
  return state;
}

AppState _johorMapState() {
  final state = AppState();
  state.isLoading = false;
  state.isUsingCloudAreaProfiles = true;
  state.isUsingCloudProperties = true;
  state.areas = const [
    AreaData(
      id: 'johor_batu_pahat',
      name: 'Batu Pahat',
      state: 'Johor',
      isGovernmentProfile: true,
    ),
    AreaData(
      id: 'johor_kluang',
      name: 'Kluang',
      state: 'Johor',
      isGovernmentProfile: true,
    ),
    AreaData(
      id: 'johor_muar',
      name: 'Muar',
      state: 'Johor',
      isGovernmentProfile: true,
    ),
  ];
  state.properties = [
    Property(
      id: 'teduh_kluang_marker',
      name: 'Residensi Kluang Marker',
      areaId: 'johor_kluang',
      address: 'Kluang, Johor',
      type: 'Apartment',
      tenure: 'Leasehold',
      state: 'Johor',
      district: 'Kluang',
      priceMin: 310000,
      priceMax: 390000,
      latitude: 2.03,
      longitude: 103.32,
      summary: 'Official housing project information sourced from TEDUH.',
      facilities: const ['Kluang'],
      palette: 1,
      source: 'TEDUH - Jabatan Perumahan Negara, KPKT',
      sourceId: 'KLUANG_MARKER',
    ),
    Property(
      id: 'teduh_muar_marker',
      name: 'Residensi Muar Marker',
      areaId: 'johor_muar',
      address: 'Muar, Johor',
      type: 'Apartment',
      tenure: 'Leasehold',
      state: 'Johor',
      district: 'Muar',
      priceMin: 270000,
      priceMax: 340000,
      latitude: 2.05,
      longitude: 102.57,
      summary: 'Official housing project information sourced from TEDUH.',
      facilities: const ['Muar'],
      palette: 2,
      source: 'TEDUH - Jabatan Perumahan Negara, KPKT',
      sourceId: 'MUAR_MARKER',
    ),
    Property(
      id: 'teduh_batu_pahat_unmapped',
      name: 'Residensi Batu Pahat Without Coordinates',
      areaId: 'johor_batu_pahat',
      address: 'Batu Pahat, Johor',
      type: 'Apartment',
      tenure: 'Leasehold',
      state: 'Johor',
      district: 'Batu Pahat',
      priceMin: 300000,
      priceMax: 360000,
      summary: 'Official housing project information sourced from TEDUH.',
      facilities: const ['Batu Pahat'],
      palette: 3,
      source: 'TEDUH - Jabatan Perumahan Negara, KPKT',
      sourceId: 'BATU_PAHAT_UNMAPPED',
    ),
    Property(
      id: 'teduh_batu_pahat_invalid',
      name: 'Residensi Batu Pahat Invalid Coordinates',
      areaId: 'johor_batu_pahat',
      address: 'Batu Pahat, Johor',
      type: 'Apartment',
      tenure: 'Leasehold',
      state: 'Johor',
      district: 'Batu Pahat',
      priceMin: 300000,
      priceMax: 360000,
      latitude: 0,
      longitude: 0,
      summary: 'Official housing project information sourced from TEDUH.',
      facilities: const ['Batu Pahat'],
      palette: 4,
      source: 'TEDUH - Jabatan Perumahan Negara, KPKT',
      sourceId: 'BATU_PAHAT_INVALID',
    ),
  ];
  return state;
}

class _LocationScenario {
  const _LocationScenario({
    required this.name,
    required this.client,
    required this.message,
  });

  final String name;
  final _FakeLocationClient client;
  final String message;
}

class _FakeLocationClient implements PropertyMapLocationClient {
  _FakeLocationClient({
    this.serviceEnabled = true,
    this.checkPermissionResult = LocationPermission.denied,
    this.requestPermissionResult = LocationPermission.whileInUse,
    this.currentLocation = const LatLng(4.2105, 101.9758),
  }) : throwOnUse = false;

  _FakeLocationClient.throwing()
    : serviceEnabled = true,
      checkPermissionResult = LocationPermission.denied,
      requestPermissionResult = LocationPermission.denied,
      currentLocation = const LatLng(4.2105, 101.9758),
      throwOnUse = true;

  final bool serviceEnabled;
  final LocationPermission checkPermissionResult;
  final LocationPermission requestPermissionResult;
  final LatLng currentLocation;
  final bool throwOnUse;

  int serviceEnabledCalls = 0;
  int checkPermissionCalls = 0;
  int requestPermissionCalls = 0;
  int currentLocationCalls = 0;

  int get totalCalls =>
      serviceEnabledCalls +
      checkPermissionCalls +
      requestPermissionCalls +
      currentLocationCalls;

  @override
  Future<bool> isLocationServiceEnabled() async {
    _throwIfUnexpected();
    serviceEnabledCalls += 1;
    return serviceEnabled;
  }

  @override
  Future<LocationPermission> checkPermission() async {
    _throwIfUnexpected();
    checkPermissionCalls += 1;
    return checkPermissionResult;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    _throwIfUnexpected();
    requestPermissionCalls += 1;
    return requestPermissionResult;
  }

  @override
  Future<LatLng> getCurrentLocation() async {
    _throwIfUnexpected();
    currentLocationCalls += 1;
    return currentLocation;
  }

  void _throwIfUnexpected() {
    if (throwOnUse) {
      throw StateError('Location client should not be used.');
    }
  }
}

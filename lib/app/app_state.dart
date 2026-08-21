import 'package:flutter/foundation.dart';

import '../data/asset_repository.dart';
import '../data/repositories/area_profile_repository.dart';
import '../data/repositories/property_repository.dart';
import '../core/config/supabase_config.dart';
import '../models/app_user.dart';
import '../models/area_data.dart';
import '../models/area_profile.dart';
import '../models/property.dart';
import '../models/recommendation.dart';
import '../models/user_preferences.dart';
import '../services/recommendation_service.dart';

class AppState extends ChangeNotifier {
  AppState({
    this._repository = const AssetRepository(),
    this._areaProfileRepository = const AreaProfileRepository(),
    this._propertyRepository = const PropertyRepository(),
    this._recommendationService = const RecommendationService(),
  });

  final AssetRepository _repository;
  final AreaProfileRepository _areaProfileRepository;
  final PropertyRepository _propertyRepository;
  final RecommendationService _recommendationService;
  final Set<String> _favouriteIds = {'p01', 'p03'};

  bool isLoading = true;
  String? loadError;
  bool isAuthenticated = false;
  int selectedIndex = 0;
  AppUser user = const AppUser(
    name: 'Alex Tan',
    email: 'alex@smartadvisor.demo',
    phone: '+60 12-345 6789',
  );
  UserPreferences preferences = const UserPreferences();
  List<AreaData> areas = const [];
  List<Property> properties = const [];
  bool isUsingCloudAreaProfiles = false;
  bool isUsingProcessedAreaProfiles = false;
  bool isUsingCloudProperties = false;
  bool isUsingProcessedTeduhProperties = false;
  String? openDataLoadMessage;

  Set<String> get favouriteIds => Set.unmodifiable(_favouriteIds);

  List<Property> get favouriteProperties => properties
      .where((property) => _favouriteIds.contains(property.id))
      .toList();

  List<PropertyRecommendation> get recommendations => _recommendationService
      .rank(properties: properties, areas: areas, preferences: preferences);

  Future<void> initialise() async {
    try {
      final results = await Future.wait([
        _repository.loadAreas(),
        _repository.loadProperties(),
      ]);
      final localAreas = results[0] as List<AreaData>;
      final localProperties = results[1] as List<Property>;
      areas = localAreas;
      properties = localProperties;

      final cloudProfiles = await _loadCloudAreaProfiles();
      if (cloudProfiles.isNotEmpty) {
        areas = _areasFromProfiles(cloudProfiles, localAreas);
        isUsingCloudAreaProfiles = true;
      } else {
        final processedProfiles = await _repository.loadProcessedAreaProfiles();
        if (processedProfiles.isNotEmpty) {
          areas = _areasFromProfiles(processedProfiles, localAreas);
          isUsingProcessedAreaProfiles = true;
        }
      }

      final cloudProperties = await _loadCloudProperties(areas);
      if (cloudProperties.isNotEmpty) {
        properties = _mergeProperties(localProperties, cloudProperties);
        isUsingCloudProperties = true;
      } else {
        final teduhFallback = await _repository.loadProcessedTeduhProjects(
          areas,
        );
        if (teduhFallback.isNotEmpty) {
          properties = _mergeProperties(localProperties, teduhFallback);
          isUsingProcessedTeduhProperties = true;
        }
      }
    } catch (error) {
      loadError = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  String? login(String email, String password) {
    final normalizedEmail = email.trim();
    if (!normalizedEmail.contains('@')) {
      return 'Enter a valid email address.';
    }
    if (password.length < 6) {
      return 'Password must contain at least 6 characters.';
    }
    user = user.copyWith(email: normalizedEmail);
    isAuthenticated = true;
    notifyListeners();
    return null;
  }

  String? register(String name, String email, String password) {
    if (name.trim().length < 2) {
      return 'Enter your full name.';
    }
    if (!email.trim().contains('@')) {
      return 'Enter a valid email address.';
    }
    if (password.length < 8) {
      return 'Use at least 8 characters for your password.';
    }
    user = AppUser(name: name.trim(), email: email.trim());
    isAuthenticated = true;
    notifyListeners();
    return null;
  }

  void continueAsDemo() {
    isAuthenticated = true;
    notifyListeners();
  }

  void logout() {
    isAuthenticated = false;
    selectedIndex = 0;
    notifyListeners();
  }

  void selectDestination(int index) {
    selectedIndex = index;
    notifyListeners();
  }

  void updatePreferences(UserPreferences value) {
    preferences = value;
    notifyListeners();
  }

  void toggleFavourite(String propertyId) {
    if (_favouriteIds.contains(propertyId)) {
      _favouriteIds.remove(propertyId);
    } else {
      _favouriteIds.add(propertyId);
    }
    notifyListeners();
  }

  bool isFavourite(String propertyId) => _favouriteIds.contains(propertyId);

  AreaData areaFor(String areaId) {
    return areas.firstWhere(
      (area) => area.id == areaId,
      orElse: () => areas.first,
    );
  }

  void updateUser(AppUser value) {
    user = value;
    notifyListeners();
  }

  Future<List<AreaProfile>> _loadCloudAreaProfiles() async {
    if (!SupabaseConfig.isConfigured) {
      return const [];
    }
    try {
      return await _areaProfileRepository.getAreaProfiles();
    } on AreaProfileRepositoryException catch (error) {
      openDataLoadMessage = error.toString();
      return const [];
    }
  }

  Future<List<Property>> _loadCloudProperties(List<AreaData> areas) async {
    if (!SupabaseConfig.isConfigured) {
      return const [];
    }
    try {
      return await _propertyRepository.getProperties(areas);
    } on PropertyRepositoryException catch (error) {
      openDataLoadMessage = error.toString();
      return const [];
    }
  }

  List<AreaData> _areasFromProfiles(
    List<AreaProfile> profiles,
    List<AreaData> localAreas,
  ) {
    final localById = {for (final area in localAreas) area.id: area};
    final converted = profiles.map((profile) {
      final id = _normaliseId(profile.district);
      return AreaData.fromProfile(profile, fallback: localById[id]);
    }).toList();
    final convertedIds = converted.map((area) => area.id).toSet();
    return [
      ...converted,
      ...localAreas.where((area) => !convertedIds.contains(area.id)),
    ];
  }

  List<Property> _mergeProperties(
    List<Property> localProperties,
    List<Property> openDataProperties,
  ) {
    final seen = <String>{};
    final merged = <Property>[];
    for (final property in [...openDataProperties, ...localProperties]) {
      if (seen.add(property.id)) {
        merged.add(property);
      }
    }
    return merged;
  }

  String _normaliseId(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }
}

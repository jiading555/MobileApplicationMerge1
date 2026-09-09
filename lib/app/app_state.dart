import 'package:flutter/foundation.dart';

import '../data/asset_repository.dart';
import '../data/repositories/area_profile_repository.dart';
import '../data/repositories/property_repository.dart';
import '../core/config/supabase_config.dart';
import '../core/utils/location_normalizer.dart';
import '../models/app_user.dart';
import '../models/area_data.dart';
import '../models/area_profile.dart';
import '../models/property.dart';
import '../models/recommendation.dart';
import '../models/user_preferences.dart';
import '../services/recommendation_service.dart';

class AppState extends ChangeNotifier {
  AppState({
    AssetRepository repository = const AssetRepository(),
    AreaProfileRepository areaProfileRepository = const AreaProfileRepository(),
    PropertyRepository propertyRepository = const PropertyRepository(),
    RecommendationService recommendationService = const RecommendationService(),
  }) : this._(
         repository,
         areaProfileRepository,
         propertyRepository,
         recommendationService,
       );

  AppState._(
    this._repository,
    this._areaProfileRepository,
    this._propertyRepository,
    this._recommendationService,
  );

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
  bool isRefreshingLatestData = false;
  bool isRefreshingGovernmentData = false;
  String? openDataLoadMessage;
  String? latestDataRefreshMessage;
  String? governmentDataRefreshMessage;

  Set<String> get favouriteIds => Set.unmodifiable(_favouriteIds);

  List<Property> _cachedFavouriteProperties = const [];
  String _favouriteCacheKey = '';
  List<PropertyRecommendation> _cachedRecommendations = const [];
  String _recommendationCacheKey = '';

  List<Property> get favouriteProperties {
    final cacheKey = '${properties.length}|${_favouriteIds.toList().join(',')}';
    if (_favouriteCacheKey != cacheKey) {
      _cachedFavouriteProperties = properties
          .where((property) => _favouriteIds.contains(property.id))
          .toList();
      _favouriteCacheKey = cacheKey;
    }
    return _cachedFavouriteProperties;
  }

  List<PropertyRecommendation> get recommendations {
    final cacheKey =
        '${properties.length}|${areas.length}|${preferences.budget}|${preferences.propertyType}|${preferences.preferredAreaId}|${preferences.goal}';
    if (_recommendationCacheKey != cacheKey) {
      _cachedRecommendations = _recommendationService.rank(
        properties: properties,
        areas: areas,
        preferences: preferences,
      );
      _recommendationCacheKey = cacheKey;
    }
    return _cachedRecommendations;
  }

  Future<void> initialise() async {
    try {
      final localAreas = await _loadStaticAreaMetadata();
      areas = const [];
      properties = const [];
      isUsingCloudAreaProfiles = false;
      isUsingProcessedAreaProfiles = false;
      isUsingCloudProperties = false;
      isUsingProcessedTeduhProperties = false;

      if (!SupabaseConfig.isConfigured) {
        openDataLoadMessage =
            'Supabase is not configured. Add the project URL and publishable key to load official property and area data.';
        return;
      }

      final cloudProfiles = await _loadCloudAreaProfiles();
      if (cloudProfiles.isNotEmpty) {
        areas = _areasFromProfiles(cloudProfiles, localAreas);
        isUsingCloudAreaProfiles = true;
      }

      final cloudProperties = await _loadCloudProperties(areas);
      if (cloudProperties.isNotEmpty) {
        properties = cloudProperties;
        isUsingCloudProperties = true;
      }
    } catch (error) {
      loadError = 'Failed to load official app data: $error';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshLatestData() async {
    if (!SupabaseConfig.isConfigured) {
      latestDataRefreshMessage =
          'Supabase is not configured. Add the project URL and client-safe publishable key to load latest data.';
      notifyListeners();
      return;
    }

    if (isRefreshingLatestData) {
      return;
    }

    isRefreshingLatestData = true;
    latestDataRefreshMessage = null;
    notifyListeners();

    try {
      await _reloadVisibleData();
      latestDataRefreshMessage =
          'Latest data refreshed: ${properties.length} properties and ${areas.length} areas loaded.';
    } catch (error) {
      latestDataRefreshMessage = 'Latest data refresh failed: $error';
    } finally {
      isRefreshingLatestData = false;
      notifyListeners();
    }
  }

  Future<void> refreshGovernmentData() async {
    if (!SupabaseConfig.isConfigured) {
      governmentDataRefreshMessage =
          'Supabase is not configured. Add the project URL and client-safe publishable key before reloading latest data.';
      notifyListeners();
      return;
    }

    if (isRefreshingGovernmentData) {
      return;
    }

    final previousAreas = areas;
    final previousProperties = properties;
    final previousCloudAreaProfiles = isUsingCloudAreaProfiles;
    final previousProcessedAreaProfiles = isUsingProcessedAreaProfiles;
    final previousCloudProperties = isUsingCloudProperties;
    final previousProcessedTeduhProperties = isUsingProcessedTeduhProperties;

    isRefreshingGovernmentData = true;
    governmentDataRefreshMessage = null;
    notifyListeners();

    try {
      await _reloadVisibleData();
      governmentDataRefreshMessage =
          'Latest data reloaded: ${properties.length} properties and ${areas.length} areas loaded from Supabase.';
    } catch (error) {
      areas = previousAreas;
      properties = previousProperties;
      isUsingCloudAreaProfiles = previousCloudAreaProfiles;
      isUsingProcessedAreaProfiles = previousProcessedAreaProfiles;
      isUsingCloudProperties = previousCloudProperties;
      isUsingProcessedTeduhProperties = previousProcessedTeduhProperties;
      governmentDataRefreshMessage = 'Latest data reload failed: $error';
    } finally {
      isRefreshingGovernmentData = false;
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
      (area) => LocationNormalizer.areaIdMatches(area.id, areaId),
      orElse: () => AreaData.unavailable(areaId),
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

  Future<void> _reloadVisibleData() async {
    final localAreas = await _loadStaticAreaMetadata();

    isUsingCloudAreaProfiles = false;
    isUsingProcessedAreaProfiles = false;
    isUsingCloudProperties = false;
    isUsingProcessedTeduhProperties = false;
    areas = const [];
    properties = const [];

    if (!SupabaseConfig.isConfigured) {
      openDataLoadMessage =
          'Supabase is not configured. Add the project URL and publishable key to load official property and area data.';
      return;
    }

    final cloudProfiles = await _loadCloudAreaProfiles();
    if (cloudProfiles.isNotEmpty) {
      areas = _areasFromProfiles(cloudProfiles, localAreas);
      isUsingCloudAreaProfiles = true;
    }

    final cloudProperties = await _loadCloudProperties(areas);
    if (cloudProperties.isNotEmpty) {
      properties = cloudProperties;
      isUsingCloudProperties = true;
    }
  }

  List<AreaData> _areasFromProfiles(
    List<AreaProfile> profiles,
    List<AreaData> localAreas,
  ) {
    final localById = {
      for (final area in localAreas)
        LocationNormalizer.canonicalAreaIdFromExisting(area.id): area,
    };
    final localByLocation = {
      for (final area in localAreas)
        LocationNormalizer.stateDistrictKey(area.state, area.name): area,
    };
    final canonicalProfiles = AreaProfileRepository.mergeProfileData(
      profiles,
    ).values;
    final converted =
        canonicalProfiles.map((profile) {
          final canonical = profile.canonicalized();
          final fallback =
              localById[canonical.areaId] ??
              localByLocation[LocationNormalizer.stateDistrictKey(
                canonical.state,
                canonical.district,
              )];
          return AreaData.fromProfile(canonical, fallback: fallback);
        }).toList()..sort((left, right) {
          final byState = left.state.compareTo(right.state);
          return byState == 0 ? left.name.compareTo(right.name) : byState;
        });
    return converted;
  }

  Future<List<AreaData>> _loadStaticAreaMetadata() async {
    try {
      return await _repository.loadAreas();
    } catch (_) {
      return const [];
    }
  }
}

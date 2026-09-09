import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/asset_repository.dart';
import '../data/repositories/area_profile_repository.dart';
import '../data/repositories/property_repository.dart';
import '../data/repositories/user_account_repository.dart';
import '../core/config/supabase_config.dart';
import '../core/utils/auth_validators.dart';
import '../models/app_user.dart';
import '../models/area_data.dart';
import '../models/area_profile.dart';
import '../models/property.dart';
import '../models/recommendation.dart';
import '../models/user_preferences.dart';
import '../services/market_trend_cache.dart';
import '../services/open_data_service.dart';
import '../services/recommendation_service.dart';

class AppState extends ChangeNotifier {
  AppState({
    this._repository = const AssetRepository(),
    this._areaProfileRepository = const AreaProfileRepository(),
    this._propertyRepository = const PropertyRepository(),
    this._recommendationService = const RecommendationService(),
    this._userAccountRepository = const UserAccountRepository(),
    OpenDataService? openDataService,
    MarketTrendCache? marketTrendCache,
  }) : _openDataService = openDataService ?? OpenDataService(),
       _marketTrendCache = marketTrendCache ?? MarketTrendCache();

  final AssetRepository _repository;
  final AreaProfileRepository _areaProfileRepository;
  final PropertyRepository _propertyRepository;
  final RecommendationService _recommendationService;
  final UserAccountRepository _userAccountRepository;
  final OpenDataService _openDataService;
  final MarketTrendCache _marketTrendCache;
  final Set<String> _favouriteIds = {'p01', 'p03'};

  bool isLoading = true;
  String? loadError;
  bool isAuthenticated = false;
  int selectedIndex = 0;
  AppUser user = const AppUser(
    id: '',
    name: '',
    email: '',
  );
  UserPreferences preferences = const UserPreferences();
  List<AreaData> areas = const [];
  List<Property> properties = const [];
  bool isUsingCloudAreaProfiles = false;
  bool isUsingProcessedAreaProfiles = false;
  bool isUsingMarketTrendCache = false;
  bool isUsingLiveAreaProfiles = false;
  bool isUsingCloudProperties = false;
  bool isUsingProcessedTeduhProperties = false;
  bool isSyncingGovernmentData = false;
  bool hasAttemptedInitialMarketRefresh = false;
  DateTime? marketTrendCacheUpdatedAt;
  String? openDataLoadMessage;
  String? governmentDataSyncMessage;
  bool isAccountBusy = false;
  bool registrationNeedsConfirmation = false;
  String? accountError;

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

      final cachedMarketTrend = await _loadMarketTrendCache();
      if (cachedMarketTrend != null && cachedMarketTrend.areas.isNotEmpty) {
        areas = cachedMarketTrend.areas;
        marketTrendCacheUpdatedAt = cachedMarketTrend.updatedAt;
        isUsingMarketTrendCache = true;
      } else {
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
      }

      final cloudProperties = await _loadCloudProperties(areas);
      if (cloudProperties.isNotEmpty) {
        properties = cloudProperties;
        isUsingCloudProperties = true;
      } else {
        final teduhFallback = await _repository.loadProcessedTeduhProjects(
          areas,
        );
        if (teduhFallback.isNotEmpty) {
          properties = teduhFallback;
          isUsingProcessedTeduhProperties = true;
        }
      }

      if (SupabaseConfig.isConfigured) {
        final authUser = Supabase.instance.client.auth.currentUser;
        if (authUser != null) {
          await _loadAccount(authUser);
          isAuthenticated = true;
        }
      }
    } catch (error) {
      loadError = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> ensureInitialMarketData() async {
    if (hasAttemptedInitialMarketRefresh) return;
    hasAttemptedInitialMarketRefresh = true;
    final updatedAt = marketTrendCacheUpdatedAt;
    if (updatedAt != null &&
        DateTime.now().toUtc().difference(updatedAt.toUtc()) <
            const Duration(days: 1)) {
      return;
    }
    await refreshGovernmentData();
  }

  Future<void> refreshGovernmentData() async {
    if (isSyncingGovernmentData) return;

    isSyncingGovernmentData = true;
    governmentDataSyncMessage = null;
    notifyListeners();

    try {
      if (!SupabaseConfig.isConfigured) {
        throw Exception('Supabase is not configured.');
      }
      final latestCloudProfiles =
          await _areaProfileRepository.getAreaProfiles();
      if (latestCloudProfiles.isEmpty) {
        throw Exception('No NAPIC market data was returned by Supabase.');
      }

      final areasWithLatestMarketData = _areasFromProfiles(
        latestCloudProfiles,
        areas,
      );
      final targets = areasWithLatestMarketData
          .map((area) => (area.state, area.name))
          .toSet()
          .toList();
      final governmentProfiles = await _openDataService.fetchAreaProfiles(
        targets: targets,
      );
      final refreshedAreas = _areasFromProfiles(
        governmentProfiles,
        areasWithLatestMarketData,
      );
      final cachedAt = DateTime.now().toUtc();
      await _saveMarketTrendCache(refreshedAreas, cachedAt);
      areas = refreshedAreas;
      marketTrendCacheUpdatedAt = cachedAt;
      isUsingLiveAreaProfiles = true;
      isUsingCloudAreaProfiles = false;
      isUsingProcessedAreaProfiles = false;
      isUsingMarketTrendCache = false;
      final years = _dataYears(refreshedAreas);
      governmentDataSyncMessage = years.isEmpty
          ? 'Data refreshed successfully.'
          : 'Data refreshed successfully · ${years.join(', ')}';
    } catch (error) {
      final detail = error.toString().replaceFirst('Exception: ', '');
      governmentDataSyncMessage = 'Refresh failed. $detail';
    } finally {
      isSyncingGovernmentData = false;
      notifyListeners();
    }
  }

  List<int> _dataYears(List<AreaData> values) {
    final years = <int>{};
    for (final area in values) {
      years.addAll([
        ?area.populationYear,
        ?area.incomeYear,
        ?area.crimeYear,
        ?area.educationYear,
        ?area.hospitalYear,
        ?area.transportYear,
        ?area.marketPriceYear,
      ]);
    }
    final sorted = years.toList()..sort();
    return sorted;
  }

  Future<String?> login(String email, String password) async {
    final emailError = AuthValidators.email(email);
    if (emailError != null) return emailError;
    final passwordError = AuthValidators.loginPassword(password);
    if (passwordError != null) return passwordError;
    if (!SupabaseConfig.isConfigured) {
      return 'Supabase is not configured.';
    }
    isAccountBusy = true;
    accountError = null;
    notifyListeners();
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final authUser = response.user;
      if (authUser == null) return 'Unable to sign in.';
      await _loadAccount(authUser);
      isAuthenticated = true;
      return null;
    } on AuthException catch (error) {
      final message = error.message.toLowerCase();
      if (message.contains('invalid login credentials')) {
        return 'Incorrect email address or password.';
      }
      if (message.contains('email not confirmed')) {
        return 'Confirm your email address before signing in.';
      }
      return error.message;
    } catch (_) {
      return 'Unable to sign in. Please try again.';
    } finally {
      isAccountBusy = false;
      notifyListeners();
    }
  }

  Future<String?> register(String name, String email, String password) async {
    if (name.trim().length < 2) return 'Enter your full name.';
    final emailError = AuthValidators.email(email);
    if (emailError != null) return emailError;
    final passwordError = AuthValidators.registrationPassword(password);
    if (passwordError != null) return passwordError;
    if (!SupabaseConfig.isConfigured) {
      return 'Supabase is not configured.';
    }
    isAccountBusy = true;
    registrationNeedsConfirmation = false;
    accountError = null;
    notifyListeners();
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'full_name': name.trim()},
      );
      final authUser = response.user;
      if (authUser == null) return 'Unable to create account.';
      user = AppUser(
        id: authUser.id,
        name: name.trim(),
        email: authUser.email ?? email.trim(),
      );
      preferences = const UserPreferences();
      registrationNeedsConfirmation = response.session == null;
      isAuthenticated = response.session != null;
      if (response.session != null) {
        await _userAccountRepository.saveProfile(user);
        await _userAccountRepository.savePreferences(authUser.id, preferences);
      }
      return null;
    } on AuthException catch (error) {
      return error.message;
    } catch (_) {
      return 'Unable to create account. Please try again.';
    } finally {
      isAccountBusy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    if (!user.isDemo && SupabaseConfig.isConfigured) {
      await Supabase.instance.client.auth.signOut();
    }
    isAuthenticated = false;
    selectedIndex = 0;
    notifyListeners();
  }

  Future<String?> resendSignupConfirmation(String email) async {
    if (!SupabaseConfig.isConfigured) return 'Supabase is not configured.';
    isAccountBusy = true;
    notifyListeners();
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: email.trim(),
      );
      return null;
    } on AuthException catch (error) {
      return error.message;
    } catch (_) {
      return 'Unable to resend confirmation email. Please try again.';
    } finally {
      isAccountBusy = false;
      notifyListeners();
    }
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

  Future<String?> saveUser(AppUser value) async {
    if (value.isDemo) {
      user = value;
      notifyListeners();
      return null;
    }
    isAccountBusy = true;
    notifyListeners();
    try {
      await _userAccountRepository.saveProfile(value);
      user = value;
      return null;
    } catch (_) {
      return 'Unable to save profile. Please try again.';
    } finally {
      isAccountBusy = false;
      notifyListeners();
    }
  }

  Future<String?> saveAccountPreferences(UserPreferences value) async {
    if (user.isDemo) {
      preferences = value;
      notifyListeners();
      return null;
    }
    if (!value.minimumBudget.isFinite ||
        !value.maximumBudget.isFinite ||
        value.minimumBudget < 0 ||
        value.maximumBudget <= 0) {
      return 'Enter a valid budget range.';
    }
    if (value.minimumBudget > value.maximumBudget) {
      return 'Minimum budget cannot exceed maximum budget.';
    }
    if (value.maximumBudget > 1000000000) {
      return 'Maximum budget cannot exceed RM 1,000,000,000.';
    }
    isAccountBusy = true;
    notifyListeners();
    try {
      await _userAccountRepository.savePreferences(user.id, value);
      preferences = value;
      return null;
    } catch (_) {
      return 'Unable to save preferences. Please try again.';
    } finally {
      isAccountBusy = false;
      notifyListeners();
    }
  }

  Future<String?> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (user.isDemo) {
      return 'Password changes are unavailable in sample mode.';
    }
    if (currentPassword.isEmpty) return 'Enter your current password.';
    final passwordError = AuthValidators.registrationPassword(newPassword);
    if (passwordError != null) return passwordError;
    if (currentPassword == newPassword) {
      return 'New password must be different from the current password.';
    }

    final email = Supabase.instance.client.auth.currentUser?.email;
    if (email == null) return 'Your sign-in session has expired.';

    isAccountBusy = true;
    notifyListeners();
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      return null;
    } on AuthException catch (error) {
      if (error.message.toLowerCase().contains('invalid login')) {
        return 'Current password is incorrect.';
      }
      return error.message;
    } catch (_) {
      return 'Unable to update password. Please try again.';
    } finally {
      isAccountBusy = false;
      notifyListeners();
    }
  }

  Future<String?> resetPassword(String email) async {
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email.trim());
      return null;
    } on AuthException catch (error) {
      return error.message;
    } catch (_) {
      return 'Unable to send reset email. Please try again.';
    }
  }

  Future<String?> uploadAvatar(
    Uint8List bytes,
    String extension,
  ) async {
    if (user.isDemo) return 'Avatar upload is unavailable in sample mode.';
    isAccountBusy = true;
    notifyListeners();
    try {
      final url = await _userAccountRepository.uploadAvatar(
        userId: user.id,
        bytes: bytes,
        extension: extension,
      );
      final updated = user.copyWith(avatarUrl: url);
      await _userAccountRepository.saveProfile(updated);
      user = updated;
      return null;
    } catch (_) {
      return 'Unable to upload avatar. Please try again.';
    } finally {
      isAccountBusy = false;
      notifyListeners();
    }
  }

  Future<void> _loadAccount(User authUser) async {
    user = await _userAccountRepository.loadProfile(authUser);
    preferences = await _userAccountRepository.loadPreferences(authUser.id);
  }

  Future<MarketTrendCacheEntry?> _loadMarketTrendCache() async {
    try {
      return await _marketTrendCache.load();
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveMarketTrendCache(
    List<AreaData> value,
    DateTime updatedAt,
  ) async {
    try {
      await _marketTrendCache.save(value, updatedAt: updatedAt);
    } catch (_) {
      // A cache write must never discard successfully downloaded data.
    }
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

  String _normaliseId(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }
}


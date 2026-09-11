import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../core/utils/auth_error_mapper.dart';
import '../core/utils/auth_validators.dart';
import '../core/utils/location_normalizer.dart';
import '../core/utils/network_error_mapper.dart';
import '../core/utils/property_area_resolver.dart';
import '../data/asset_repository.dart';
import '../data/repositories/area_profile_repository.dart';
import '../data/repositories/property_repository.dart';
import '../data/repositories/user_account_repository.dart';
import '../models/app_user.dart';
import '../models/area_data.dart';
import '../models/area_profile.dart';
import '../models/property.dart';
import '../models/recommendation.dart';
import '../models/user_preferences.dart';
import '../services/market_trend_cache.dart';
import '../services/recommendation_service.dart';

enum DataRefreshStatus { idle, success, failure }

class DataRefreshResult {
  const DataRefreshResult._({
    required this.succeeded,
    required this.message,
    required this.status,
  });

  const DataRefreshResult.success(String message)
    : this._(
        succeeded: true,
        message: message,
        status: DataRefreshStatus.success,
      );

  const DataRefreshResult.failure(String message)
    : this._(
        succeeded: false,
        message: message,
        status: DataRefreshStatus.failure,
      );

  final bool succeeded;
  final String message;
  final DataRefreshStatus status;
}

class _VisibleDataLoadResult {
  bool cloudAreaProfilesSucceeded = false;
  bool cloudPropertiesSucceeded = false;
  bool loadedFromMarketTrendCache = false;
  Object? areaProfilesError;
  Object? propertiesError;
  int displayedAreaCount = 0;
}

class _CloudAreaProfilesLoadAttempt {
  const _CloudAreaProfilesLoadAttempt.success(this.profiles) : error = null;

  const _CloudAreaProfilesLoadAttempt.failure(this.error) : profiles = const [];

  final List<AreaProfile> profiles;
  final Object? error;

  bool get succeeded => error == null;
}

class _CloudPropertiesLoadAttempt {
  const _CloudPropertiesLoadAttempt.success(this.properties) : error = null;

  const _CloudPropertiesLoadAttempt.failure(this.error) : properties = const [];

  final List<Property> properties;
  final Object? error;

  bool get succeeded => error == null;
}

class AppState extends ChangeNotifier {
  AppState({
    AssetRepository repository = const AssetRepository(),
    AreaProfileRepository areaProfileRepository = const AreaProfileRepository(),
    PropertyRepository propertyRepository = const PropertyRepository(),
    RecommendationService recommendationService = const RecommendationService(),
    UserAccountRepository userAccountRepository = const UserAccountRepository(),
    MarketTrendCache? marketTrendCache,
    String? Function()? currentAuthUserIdProvider,
  }) : this._(
         repository,
         areaProfileRepository,
         propertyRepository,
         recommendationService,
         userAccountRepository,
         marketTrendCache,
         currentAuthUserIdProvider,
       );

  AppState._(
    this._repository,
    this._areaProfileRepository,
    this._propertyRepository,
    this._recommendationService,
    this._userAccountRepository,
    MarketTrendCache? marketTrendCache,
    this._currentAuthUserIdProvider,
  ) : _marketTrendCache = marketTrendCache ?? MarketTrendCache();

  final AssetRepository _repository;
  final AreaProfileRepository _areaProfileRepository;
  final PropertyRepository _propertyRepository;
  final RecommendationService _recommendationService;
  final UserAccountRepository _userAccountRepository;
  final MarketTrendCache _marketTrendCache;
  final String? Function()? _currentAuthUserIdProvider;
  final Set<String> _favouriteIds = <String>{};
  final ValueNotifier<Set<String>> _favouriteIdsNotifier =
      ValueNotifier<Set<String>>(const {});
  final Set<String> _favouriteOperationsInProgress = <String>{};
  final ValueNotifier<Set<String>> _favouriteOperationIdsNotifier =
      ValueNotifier<Set<String>>(const {});

  bool isLoading = true;
  String? loadError;
  bool isAuthenticated = false;
  AppUser user = const AppUser(id: '', name: '', email: '');
  UserPreferences preferences = const UserPreferences();
  List<AreaData> areas = const [];
  List<Property> properties = const [];
  bool isUsingCloudAreaProfiles = false;
  bool isUsingProcessedAreaProfiles = false;
  bool isUsingMarketTrendCache = false;
  bool isUsingLiveAreaProfiles = false;
  bool isUsingCloudProperties = false;
  bool isUsingProcessedTeduhProperties = false;
  bool isRefreshingLatestData = false;
  bool isRefreshingGovernmentData = false;
  bool hasAttemptedInitialMarketRefresh = false;
  bool hasAttemptedExpiredMarketCacheRefresh = false;
  DateTime? marketTrendCacheUpdatedAt;
  String? openDataLoadMessage;
  String? latestDataRefreshMessage;
  String? governmentDataRefreshMessage;
  DataRefreshStatus latestDataRefreshStatus = DataRefreshStatus.idle;
  DataRefreshStatus governmentDataRefreshStatus = DataRefreshStatus.idle;
  bool isAccountBusy = false;
  bool registrationNeedsConfirmation = false;
  String? accountError;
  bool isPasswordRecovery = false;
  String? accountNotice;
  String? requestedAnalysisState;
  String? requestedAnalysisDistrict;
  int _requestedAnalysisLocationVersion = 0;

  bool get isSyncingGovernmentData => isRefreshingGovernmentData;
  String? get governmentDataSyncMessage => governmentDataRefreshMessage;
  int get requestedAnalysisLocationVersion => _requestedAnalysisLocationVersion;

  static const _noInternetMessage =
      'No internet connection. Check your network and try again.';

  Set<String> get favouriteIds => Set.unmodifiable(_favouriteIds);
  ValueListenable<Set<String>> get favouriteIdsListenable =>
      _favouriteIdsNotifier;
  Set<String> get favouriteOperationIds =>
      Set.unmodifiable(_favouriteOperationsInProgress);
  ValueListenable<Set<String>> get favouriteOperationIdsListenable =>
      _favouriteOperationIdsNotifier;

  List<Property> _cachedFavouriteProperties = const [];
  String _favouriteCacheKey = '';
  List<PropertyRecommendation> _cachedRecommendations = const [];
  String _recommendationCacheKey = '';
  Map<String, AreaData> _cachedAreaById = const {};
  List<AreaData>? _cachedAreaSource;
  int _cachedAreaLength = -1;

  List<Property> get favouriteProperties {
    final sortedFavouriteIds = _favouriteIds.toList()..sort();
    final cacheKey =
        '${identityHashCode(properties)}|${properties.length}|'
        '${sortedFavouriteIds.join(',')}';
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
        '${identityHashCode(properties)}|${properties.length}|'
        '${identityHashCode(areas)}|${areas.length}|'
        '${preferences.goal}|${preferences.budget}|'
        '${preferences.preferredAreaId}|${preferences.propertyType}|'
        '${preferences.preferredState}|${preferences.preferredDistrict}|'
        '${preferences.minimumBudget}|${preferences.maximumBudget}|'
        '${preferences.ownStaySafetyPriority}|'
        '${preferences.ownStayEducationPriority}|'
        '${preferences.ownStayTransportPriority}|'
        '${preferences.investmentIncomePriority}|'
        '${preferences.investmentTransportPriority}|'
        '${preferences.investmentAffordabilityPriority}|'
        '${preferences.safetyPriority}|${preferences.transportPriority}|'
        '${preferences.facilitiesPriority}';
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
      final restoredCache = await _restoreMarketTrendCache();
      if (restoredCache) {
        isLoading = false;
        notifyListeners();
      }
      await _loadCurrentAuthSession();
      await _reloadVisibleData(
        allowMarketCacheFallback: !restoredCache,
        preserveCurrentData: restoredCache,
        skipCloudAreaProfiles: restoredCache,
      );
    } catch (error) {
      loadError = NetworkErrorMapper.messageFor(
        error,
        action: NetworkErrorAction.load,
      );
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> ensureInitialMarketData() async {
    if (!SupabaseConfig.isConfigured || isRefreshingGovernmentData) {
      return;
    }

    final cachedAt = marketTrendCacheUpdatedAt;
    if (cachedAt != null) {
      final cacheEntry = MarketTrendCacheEntry(
        areas: areas,
        updatedAt: cachedAt,
      );
      if (cacheEntry.isFreshAt(DateTime.now())) return;
      if (hasAttemptedExpiredMarketCacheRefresh) return;
      hasAttemptedExpiredMarketCacheRefresh = true;
      await refreshGovernmentData();
      return;
    }

    if (hasAttemptedInitialMarketRefresh ||
        areas.any((area) => area.hasMarketHistory)) {
      return;
    }
    hasAttemptedInitialMarketRefresh = true;
    await refreshGovernmentData();
  }

  Future<DataRefreshResult> refreshLatestData() async {
    if (!SupabaseConfig.isConfigured) {
      final message =
          'Supabase is not configured. Add the project URL and client-safe '
          'publishable key to load latest data.';
      latestDataRefreshStatus = DataRefreshStatus.failure;
      latestDataRefreshMessage = message;
      notifyListeners();
      return DataRefreshResult.failure(message);
    }

    if (isRefreshingLatestData) {
      return DataRefreshResult.failure(
        latestDataRefreshMessage ?? NetworkErrorMapper.refreshFailureMessage,
      );
    }

    final previousAreas = areas;
    final previousProperties = properties;
    final previousCloudAreaProfiles = isUsingCloudAreaProfiles;
    final previousProcessedAreaProfiles = isUsingProcessedAreaProfiles;
    final previousMarketTrendCache = isUsingMarketTrendCache;
    final previousLiveAreaProfiles = isUsingLiveAreaProfiles;
    final previousCloudProperties = isUsingCloudProperties;
    final previousProcessedTeduhProperties = isUsingProcessedTeduhProperties;
    final previousCacheUpdatedAt = marketTrendCacheUpdatedAt;

    isRefreshingLatestData = true;
    latestDataRefreshMessage = null;
    latestDataRefreshStatus = DataRefreshStatus.idle;
    notifyListeners();

    try {
      final loadResult = await _reloadVisibleData(
        allowMarketCacheFallback: true,
        preserveCurrentData: true,
        requireCloudData: true,
      );
      if (!loadResult.cloudAreaProfilesSucceeded ||
          !loadResult.cloudPropertiesSucceeded) {
        throw StateError(
          'Latest data was not confirmed from Supabase; keeping current data.',
        );
      }
      final message =
          'Latest data refreshed: ${properties.length} properties and '
          '${areas.length} areas loaded.';
      latestDataRefreshStatus = DataRefreshStatus.success;
      latestDataRefreshMessage = message;
      return DataRefreshResult.success(message);
    } catch (error) {
      areas = previousAreas;
      properties = previousProperties;
      isUsingCloudAreaProfiles = previousCloudAreaProfiles;
      isUsingProcessedAreaProfiles = previousProcessedAreaProfiles;
      isUsingMarketTrendCache = previousMarketTrendCache;
      isUsingLiveAreaProfiles = previousLiveAreaProfiles;
      isUsingCloudProperties = previousCloudProperties;
      isUsingProcessedTeduhProperties = previousProcessedTeduhProperties;
      marketTrendCacheUpdatedAt = previousCacheUpdatedAt;
      _invalidateDataCaches();
      final message = NetworkErrorMapper.messageFor(
        error,
        action: NetworkErrorAction.refresh,
      );
      latestDataRefreshStatus = DataRefreshStatus.failure;
      latestDataRefreshMessage = message;
      return DataRefreshResult.failure(message);
    } finally {
      isRefreshingLatestData = false;
      notifyListeners();
    }
  }

  Future<DataRefreshResult> refreshGovernmentData() async {
    if (!SupabaseConfig.isConfigured) {
      final message =
          'Supabase is not configured. Add the project URL and client-safe '
          'publishable key before reloading latest data.';
      governmentDataRefreshStatus = DataRefreshStatus.failure;
      governmentDataRefreshMessage = message;
      notifyListeners();
      return DataRefreshResult.failure(message);
    }

    if (isRefreshingGovernmentData) {
      return DataRefreshResult.failure(
        governmentDataRefreshMessage ??
            NetworkErrorMapper.refreshFailureMessage,
      );
    }

    final previousAreas = areas;
    final previousProperties = properties;
    final previousCloudAreaProfiles = isUsingCloudAreaProfiles;
    final previousProcessedAreaProfiles = isUsingProcessedAreaProfiles;
    final previousMarketTrendCache = isUsingMarketTrendCache;
    final previousLiveAreaProfiles = isUsingLiveAreaProfiles;
    final previousCloudProperties = isUsingCloudProperties;
    final previousProcessedTeduhProperties = isUsingProcessedTeduhProperties;
    final previousCacheUpdatedAt = marketTrendCacheUpdatedAt;

    isRefreshingGovernmentData = true;
    governmentDataRefreshMessage = null;
    governmentDataRefreshStatus = DataRefreshStatus.idle;
    notifyListeners();

    try {
      final loadResult = await _reloadVisibleData(
        allowMarketCacheFallback: true,
        preserveCurrentData: true,
        requireCloudData: true,
      );
      if (!loadResult.cloudAreaProfilesSucceeded || areas.isEmpty) {
        throw StateError(
          'No area profiles were returned; keeping the previous data.',
        );
      }
      if (!loadResult.cloudPropertiesSucceeded) {
        throw StateError(
          'Properties were not confirmed from Supabase; keeping previous data.',
        );
      }
      final years = _dataYears(areas);
      final message =
          'Latest market data reloaded from Supabase. Data years: '
          '${years.isEmpty ? 'unavailable' : years.join(', ')}.';
      governmentDataRefreshStatus = DataRefreshStatus.success;
      governmentDataRefreshMessage = message;
      return DataRefreshResult.success(message);
    } catch (error) {
      areas = previousAreas;
      properties = previousProperties;
      isUsingCloudAreaProfiles = previousCloudAreaProfiles;
      isUsingProcessedAreaProfiles = previousProcessedAreaProfiles;
      isUsingMarketTrendCache = previousMarketTrendCache;
      isUsingLiveAreaProfiles = previousLiveAreaProfiles;
      isUsingCloudProperties = previousCloudProperties;
      isUsingProcessedTeduhProperties = previousProcessedTeduhProperties;
      marketTrendCacheUpdatedAt = previousCacheUpdatedAt;
      _invalidateDataCaches();
      final message = _marketRefreshFailureMessage(
        error,
        hasRetainedMarketData: previousAreas.isNotEmpty,
      );
      governmentDataRefreshStatus = DataRefreshStatus.failure;
      governmentDataRefreshMessage = message;
      return DataRefreshResult.failure(message);
    } finally {
      isRefreshingGovernmentData = false;
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

  bool _isOfflineError(Object? error) {
    if (error == null) return false;

    return NetworkErrorMapper.isNetworkError(error);
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
      accountNotice = null;
      return null;
    } catch (error, stackTrace) {
      _debugAuthError('sign in', error, stackTrace);
      return AuthErrorMapper.messageFor(
        error,
        context: AuthErrorContext.signIn,
      );
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
        emailRedirectTo: SupabaseConfig.emailConfirmationRedirectUrl,
        data: {'full_name': name.trim()},
      );
      final authUser = response.user;
      if (authUser == null) return 'Unable to create account.';
      if (authUser.identities?.isEmpty ?? false) {
        return AuthErrorMapper.duplicateAccountMessage;
      }
      user = AppUser(
        id: authUser.id,
        name: name.trim(),
        email: authUser.email ?? email.trim(),
      );
      preferences = const UserPreferences();
      _recommendationCacheKey = '';
      registrationNeedsConfirmation = response.session == null;
      isAuthenticated = response.session != null;
      if (response.session != null) {
        await _userAccountRepository.saveProfile(user);
        await _userAccountRepository.savePreferences(authUser.id, preferences);
      }
      return null;
    } catch (error, stackTrace) {
      _debugAuthError('create account', error, stackTrace);
      return AuthErrorMapper.messageFor(
        error,
        context: AuthErrorContext.signUp,
      );
    } finally {
      isAccountBusy = false;
      notifyListeners();
    }
  }

  void continueAsDemo() {
    user = const AppUser(
      id: 'demo',
      name: 'Alex Tan',
      email: 'alex@smartadvisor.demo',
      phone: '+60 12-345 6789',
      isDemo: true,
    );
    isAuthenticated = true;
    accountNotice = null;
    notifyListeners();
  }

  Future<void> handleAuthDeepLink(Uri uri) async {
    if (uri.scheme != 'smartpropertyadvisor') return;

    if (uri.host == 'email-confirmed') {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await _signOutLocalSession();
      isPasswordRecovery = false;
      isAuthenticated = false;
      accountNotice = 'Email confirmed successfully. Please sign in.';
      notifyListeners();
      return;
    }

    if (uri.host == 'reset-password') {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      isPasswordRecovery = true;
      isAuthenticated = false;
      accountNotice = null;
      notifyListeners();
    }
  }

  Future<String?> updateRecoveredPassword({
    required String password,
    required String confirmation,
  }) async {
    final passwordError = AuthValidators.registrationPassword(password);
    if (passwordError != null) return passwordError;
    final confirmationError = AuthValidators.confirmPassword(
      confirmation,
      password,
    );
    if (confirmationError != null) return confirmationError;

    isAccountBusy = true;
    notifyListeners();
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password),
      );
      await _signOutLocalSession();
      isPasswordRecovery = false;
      isAuthenticated = false;
      accountNotice = 'Password updated successfully. Please sign in.';
      return null;
    } catch (error, stackTrace) {
      _debugAuthError('update recovered password', error, stackTrace);
      return AuthErrorMapper.messageFor(
        error,
        context: AuthErrorContext.passwordUpdate,
      );
    } finally {
      isAccountBusy = false;
      notifyListeners();
    }
  }

  Future<void> cancelPasswordRecovery() async {
    await _signOutLocalSession();
    isPasswordRecovery = false;
    isAuthenticated = false;
    notifyListeners();
  }

  Future<void> logout() async {
    if (!user.isDemo) {
      await _signOutLocalSession();
    }
    isAuthenticated = false;
    _favouriteIds.clear();
    _favouriteOperationsInProgress.clear();
    _publishFavouriteIds();
    _publishFavouriteOperationIds();
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
        emailRedirectTo: SupabaseConfig.emailConfirmationRedirectUrl,
      );
      return null;
    } catch (error, stackTrace) {
      _debugAuthError('resend confirmation email', error, stackTrace);
      return AuthErrorMapper.messageFor(
        error,
        context: AuthErrorContext.resendConfirmation,
      );
    } finally {
      isAccountBusy = false;
      notifyListeners();
    }
  }

  void updatePreferences(UserPreferences value) {
    preferences = value;
    _recommendationCacheKey = '';
    notifyListeners();
  }

  void requestAnalysisLocation({
    required String state,
    required String district,
  }) {
    final displayState = LocationNormalizer.nullableDisplayStateName(state);
    final displayDistrict = LocationNormalizer.nullableDisplayDistrictName(
      district,
    );

    if (displayState == null || displayDistrict == null) {
      return;
    }

    requestedAnalysisState = displayState;
    requestedAnalysisDistrict = displayDistrict;
    _requestedAnalysisLocationVersion += 1;
    notifyListeners();
  }

  Future<String?> toggleFavourite(String propertyId) async {
    final trimmedPropertyId = propertyId.trim();
    if (trimmedPropertyId.isEmpty) {
      debugPrint('[FAVOURITE] Invalid property id');
      return 'Could not add this property to favourites.';
    }
    if (_favouriteOperationsInProgress.contains(trimmedPropertyId)) {
      return null;
    }

    final wasFavourite = _favouriteIds.contains(trimmedPropertyId);
    final authUserId = _currentFavouriteAuthUserId();
    if (authUserId == null || authUserId.isEmpty) {
      debugPrint(
        '[FAVOURITE] ${wasFavourite ? 'Remove' : 'Add'} blocked '
        'propertyId=$trimmedPropertyId: no authenticated Supabase user',
      );
      return 'Sign in to save favourite properties.';
    }
    if (user.id.isNotEmpty && user.id != authUserId) {
      debugPrint(
        '[FAVOURITE] Auth user mismatch '
        'appUserId=${user.id} authUserId=$authUserId',
      );
    }

    _favouriteOperationsInProgress.add(trimmedPropertyId);
    _publishFavouriteOperationIds();

    if (wasFavourite) {
      _favouriteIds.remove(trimmedPropertyId);
    } else {
      _favouriteIds.add(trimmedPropertyId);
    }
    _publishFavouriteIds();
    notifyListeners();

    try {
      await _userAccountRepository.setFavourite(
        userId: authUserId,
        propertyId: trimmedPropertyId,
        isFavourite: !wasFavourite,
      );
      accountError = null;
      return null;
    } catch (error, stackTrace) {
      debugPrint(
        '[FAVOURITE] ${wasFavourite ? 'Remove' : 'Add'} failed '
        'propertyId=$trimmedPropertyId userId=$authUserId: $error',
      );
      debugPrintStack(
        label: '[FAVOURITE] ${wasFavourite ? 'Remove' : 'Add'} stack',
        stackTrace: stackTrace,
      );
      final message = _favouriteFailureMessage(
        wasFavourite: wasFavourite,
        error: error,
      );
      if (wasFavourite) {
        _favouriteIds.add(trimmedPropertyId);
      } else {
        _favouriteIds.remove(trimmedPropertyId);
      }
      accountError = message;
      _publishFavouriteIds();
      notifyListeners();
      return message;
    } finally {
      _favouriteOperationsInProgress.remove(trimmedPropertyId);
      _publishFavouriteOperationIds();
    }
  }

  String? _currentFavouriteAuthUserId() {
    if (!isAuthenticated || user.isDemo) {
      return null;
    }
    final injected = _currentAuthUserIdProvider;
    if (injected != null) {
      return injected()?.trim();
    }
    if (!SupabaseConfig.isConfigured) {
      return null;
    }
    try {
      return Supabase.instance.client.auth.currentUser?.id.trim();
    } catch (error) {
      debugPrint('[FAVOURITE] Unable to read current auth user: $error');
      return null;
    }
  }

  bool isFavourite(String propertyId) => _favouriteIds.contains(propertyId);

  String _favouriteFailureMessage({
    required bool wasFavourite,
    required Object error,
  }) {
    if (_isOfflineError(error)) {
      return 'No internet connection. Favourite changes could not be saved.';
    }
    return wasFavourite
        ? 'Could not remove this property from favourites.'
        : 'Could not add this property to favourites.';
  }

  AreaData areaFor(String areaId) {
    final lookup = areaLookup;
    return lookup[LocationNormalizer.canonicalAreaIdFromExisting(areaId)] ??
        AreaData.unavailable(areaId);
  }

  AreaData? matchedAreaFor(Property property) {
    return PropertyAreaResolver.resolve(property: property, areas: areas);
  }

  PropertyRecommendation? suitabilityFor(Property property) {
    return _recommendationService.scoreProperty(
      property: property,
      areas: areas,
      preferences: preferences,
    );
  }

  bool matchesAdvisorPreferences(Property property) {
    return _recommendationService.matchesPreferences(
      property: property,
      areas: areas,
      preferences: preferences,
    );
  }

  Map<String, AreaData> get areaLookup {
    if (identical(_cachedAreaSource, areas) &&
        _cachedAreaLength == areas.length) {
      return _cachedAreaById;
    }
    final lookup = <String, AreaData>{};
    for (final area in areas) {
      lookup[LocationNormalizer.canonicalAreaIdFromExisting(area.id)] = area;
      lookup[LocationNormalizer.canonicalAreaId(area.state, area.name)] = area;
    }
    _cachedAreaSource = areas;
    _cachedAreaLength = areas.length;
    _cachedAreaById = lookup;
    return _cachedAreaById;
  }

  void updateUser(AppUser value) {
    user = value;
    notifyListeners();
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
    } catch (error, stackTrace) {
      _debugAuthError('save profile', error, stackTrace);
      return AuthErrorMapper.messageFor(
        error,
        context: AuthErrorContext.accountUpdate,
        fallback: 'Unable to save profile. Please try again.',
      );
    } finally {
      isAccountBusy = false;
      notifyListeners();
    }
  }

  Future<String?> saveAccountPreferences(UserPreferences value) async {
    if (user.isDemo) {
      preferences = value;
      _recommendationCacheKey = '';
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
      _recommendationCacheKey = '';
      return null;
    } catch (error, stackTrace) {
      _debugAuthError('save preferences', error, stackTrace);
      return AuthErrorMapper.messageFor(
        error,
        context: AuthErrorContext.accountUpdate,
        fallback: 'Unable to save preferences. Please try again.',
      );
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

    final email = _currentAuthEmail();
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
    } catch (error, stackTrace) {
      _debugAuthError('change password', error, stackTrace);
      return AuthErrorMapper.messageFor(
        error,
        context: AuthErrorContext.passwordUpdate,
        fallback: 'Unable to update password. Please try again.',
      );
    } finally {
      isAccountBusy = false;
      notifyListeners();
    }
  }

  Future<String?> resetPassword(String email) async {
    final emailError = AuthValidators.email(email);
    if (emailError != null) return emailError;
    if (!SupabaseConfig.isConfigured) {
      return 'Supabase is not configured.';
    }
    isAccountBusy = true;
    notifyListeners();
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: SupabaseConfig.passwordRecoveryRedirectUrl,
      );
      return null;
    } catch (error, stackTrace) {
      _debugAuthError('send password reset email', error, stackTrace);
      return AuthErrorMapper.messageFor(
        error,
        context: AuthErrorContext.passwordReset,
      );
    } finally {
      isAccountBusy = false;
      notifyListeners();
    }
  }

  Future<String?> uploadAvatar(Uint8List bytes, String extension) async {
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
    } catch (error, stackTrace) {
      _debugAuthError('upload avatar', error, stackTrace);
      return AuthErrorMapper.messageFor(
        error,
        context: AuthErrorContext.accountUpdate,
        fallback: 'Unable to upload avatar. Please try again.',
      );
    } finally {
      isAccountBusy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _favouriteIdsNotifier.dispose();
    _favouriteOperationIdsNotifier.dispose();
    super.dispose();
  }

  Future<_VisibleDataLoadResult> _reloadVisibleData({
    bool allowMarketCacheFallback = false,
    bool preserveCurrentData = false,
    bool requireCloudData = false,
    bool skipCloudAreaProfiles = false,
    bool preferMarketCache = false,
  }) async {
    final result = _VisibleDataLoadResult();
    final localAreas = await _loadStaticAreaMetadata();

    if (!preserveCurrentData) {
      isUsingCloudAreaProfiles = false;
      isUsingProcessedAreaProfiles = false;
      isUsingMarketTrendCache = false;
      isUsingLiveAreaProfiles = false;
      isUsingCloudProperties = false;
      isUsingProcessedTeduhProperties = false;
      marketTrendCacheUpdatedAt = null;
      areas = const [];
      properties = const [];
      _invalidateDataCaches();
    }
    openDataLoadMessage = null;

    var loadedAreas = preserveCurrentData && areas.isNotEmpty;
    var cacheApplied = false;

    if (allowMarketCacheFallback && preferMarketCache) {
      final cachedMarketTrend = await _loadMarketTrendCache();
      if (cachedMarketTrend != null && cachedMarketTrend.areas.isNotEmpty) {
        if (!preserveCurrentData || areas.isEmpty || isUsingMarketTrendCache) {
          _applyMarketTrendCache(cachedMarketTrend);
          cacheApplied = true;
          loadedAreas = true;
          result.loadedFromMarketTrendCache = true;
        }
      }
    }

    final shouldLoadCloudAreaProfiles =
        !skipCloudAreaProfiles &&
        SupabaseConfig.isConfigured &&
        !(preferMarketCache && cacheApplied);

    if (!SupabaseConfig.isConfigured) {
      openDataLoadMessage =
          'Supabase is not configured. Add the project URL and publishable key '
          'to load official property and area data.';
      if (requireCloudData) {
        throw StateError(
          openDataLoadMessage ??
              'Supabase is not configured to load official data.',
        );
      }
      return result;
    }

    if (shouldLoadCloudAreaProfiles) {
      final cloudProfiles = await _loadCloudAreaProfiles();
      final cloudProfilesError = cloudProfiles.error;
      result.areaProfilesError = cloudProfilesError;
      if (cloudProfilesError != null) {
        openDataLoadMessage = NetworkErrorMapper.messageFor(
          cloudProfilesError,
          action: NetworkErrorAction.load,
        );
        if (requireCloudData) {
          throw cloudProfilesError;
        }
      } else if (cloudProfiles.profiles.isNotEmpty) {
        final refreshedAreas = _areasFromProfiles(
          cloudProfiles.profiles,
          localAreas,
        );
        if (refreshedAreas.isNotEmpty) {
          areas = refreshedAreas;
          isUsingCloudAreaProfiles = true;
          isUsingProcessedAreaProfiles = false;
          isUsingMarketTrendCache = false;
          isUsingLiveAreaProfiles = false;
          result.cloudAreaProfilesSucceeded = true;
          loadedAreas = true;
        }
      } else if (cloudProfiles.succeeded) {
        openDataLoadMessage =
            'Supabase returned no area profiles; keeping available data.';
      }
    }

    if (!loadedAreas && allowMarketCacheFallback) {
      final cachedMarketTrend = await _loadMarketTrendCache();
      if (cachedMarketTrend != null && cachedMarketTrend.areas.isNotEmpty) {
        _applyMarketTrendCache(cachedMarketTrend);
        result.loadedFromMarketTrendCache = true;
        loadedAreas = true;
      }
    }

    if (!loadedAreas && preserveCurrentData) {
      throw StateError(
        openDataLoadMessage ??
            'No area profiles were returned; keeping the current data.',
      );
    }

    final cloudProperties = await _loadCloudProperties(areas);
    result.cloudPropertiesSucceeded = cloudProperties.succeeded;
    final cloudPropertiesError = cloudProperties.error;
    if (cloudPropertiesError != null) {
      openDataLoadMessage = NetworkErrorMapper.messageFor(
        cloudPropertiesError,
        action: NetworkErrorAction.load,
      );
      if (requireCloudData) {
        throw cloudPropertiesError;
      }
    } else {
      properties = cloudProperties.properties;
      isUsingCloudProperties = true;
      isUsingProcessedTeduhProperties = false;
    }

    if (areas.isNotEmpty && isUsingCloudAreaProfiles) {
      final cachedAt = DateTime.now().toUtc();
      await _saveMarketTrendCache(areas, cachedAt);
      marketTrendCacheUpdatedAt = cachedAt;
    }
    _invalidateDataCaches();
    result.displayedAreaCount = areas.length;
    return result;
  }

  Future<_CloudAreaProfilesLoadAttempt> _loadCloudAreaProfiles() async {
    try {
      return _CloudAreaProfilesLoadAttempt.success(
        await _areaProfileRepository.getAreaProfiles(),
      );
    } catch (error) {
      return _CloudAreaProfilesLoadAttempt.failure(error);
    }
  }

  Future<_CloudPropertiesLoadAttempt> _loadCloudProperties(
    List<AreaData> areas,
  ) async {
    try {
      return _CloudPropertiesLoadAttempt.success(
        await _propertyRepository.getProperties(areas),
      );
    } catch (error) {
      return _CloudPropertiesLoadAttempt.failure(error);
    }
  }

  void _applyMarketTrendCache(MarketTrendCacheEntry cachedMarketTrend) {
    areas = _canonicalAreas(cachedMarketTrend.areas);
    marketTrendCacheUpdatedAt = cachedMarketTrend.updatedAt;
    isUsingCloudAreaProfiles = false;
    isUsingProcessedAreaProfiles = false;
    isUsingMarketTrendCache = true;
    isUsingLiveAreaProfiles = false;
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

  List<AreaData> _canonicalAreas(List<AreaData> source) {
    final byKey = <String, AreaData>{};
    for (final area in source) {
      final key = LocationNormalizer.stateDistrictKey(area.state, area.name);
      final existing = byKey[key];
      if (existing == null || _areaScore(area) > _areaScore(existing)) {
        byKey[key] = area;
      }
    }
    final areas = byKey.values.toList()
      ..sort((left, right) {
        final byState = left.state.compareTo(right.state);
        return byState == 0 ? left.name.compareTo(right.name) : byState;
      });
    return areas;
  }

  int _areaScore(AreaData area) {
    return [
          area.population,
          area.medianIncome,
          area.safetyScore,
          area.schools,
          area.hospitalBeds,
          area.transportStopCount,
          area.medianResidentialPrice,
          area.transactionCount,
        ].where((value) => value != null).length +
        area.priceHistory.length +
        area.marketPriceHistoryByType.length +
        area.marketAreaPriceHistoryByType.length;
  }

  Future<List<AreaData>> _loadStaticAreaMetadata() async {
    try {
      return await _repository.loadAreas();
    } catch (_) {
      return const [];
    }
  }

  Future<MarketTrendCacheEntry?> _loadMarketTrendCache() async {
    try {
      return await _marketTrendCache.load();
    } catch (_) {
      return null;
    }
  }

  Future<bool> _restoreMarketTrendCache() async {
    final cachedMarketTrend = await _loadMarketTrendCache();
    if (cachedMarketTrend == null || cachedMarketTrend.areas.isEmpty) {
      return false;
    }

    areas = _canonicalAreas(cachedMarketTrend.areas);
    marketTrendCacheUpdatedAt = cachedMarketTrend.updatedAt;
    isUsingCloudAreaProfiles = false;
    isUsingProcessedAreaProfiles = false;
    isUsingMarketTrendCache = true;
    isUsingLiveAreaProfiles = false;
    _invalidateDataCaches();
    return true;
  }

  String _marketRefreshFailureMessage(
    Object error, {
    required bool hasRetainedMarketData,
  }) {
    if (NetworkErrorMapper.isNetworkError(error)) {
      return hasRetainedMarketData
          ? 'Refresh failed: no internet connection. Cached market data is still displayed.'
          : 'Refresh failed: no internet connection. Market data is unavailable.';
    }

    return hasRetainedMarketData
        ? 'Latest market data could not be reloaded. Cached data is still displayed.'
        : 'Latest market data could not be reloaded.';
  }

  Future<void> _saveMarketTrendCache(
    List<AreaData> value,
    DateTime updatedAt,
  ) async {
    try {
      await _marketTrendCache.save(value, updatedAt: updatedAt);
    } catch (_) {}
  }

  Future<void> _loadCurrentAuthSession() async {
    if (!SupabaseConfig.isConfigured) {
      return;
    }
    try {
      final authUser = Supabase.instance.client.auth.currentUser;
      if (authUser != null) {
        await _loadAccount(authUser);
        isAuthenticated = true;
      }
    } catch (_) {}
  }

  Future<void> _loadAccount(User authUser) async {
    user = await _userAccountRepository.loadProfile(authUser);
    preferences = await _userAccountRepository.loadPreferences(authUser.id);
    final favouriteIds = await _userAccountRepository.loadFavouritePropertyIds(
      authUser.id,
    );
    _favouriteIds
      ..clear()
      ..addAll(favouriteIds);
    _publishFavouriteIds();
    _recommendationCacheKey = '';
  }

  Future<void> _signOutLocalSession() async {
    if (!SupabaseConfig.isConfigured) {
      return;
    }
    try {
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    } catch (_) {}
  }

  String? _currentAuthEmail() {
    try {
      return Supabase.instance.client.auth.currentUser?.email;
    } catch (_) {
      return null;
    }
  }

  void _debugAuthError(String action, Object error, StackTrace stackTrace) {
    if (!kDebugMode) return;
    debugPrint('[Auth] Failed to $action: $error');
    debugPrintStack(label: '[Auth] $action stack', stackTrace: stackTrace);
  }

  void _publishFavouriteIds() {
    _favouriteCacheKey = '';
    _favouriteIdsNotifier.value = Set.unmodifiable(_favouriteIds);
  }

  void _publishFavouriteOperationIds() {
    _favouriteOperationIdsNotifier.value = Set.unmodifiable(
      _favouriteOperationsInProgress,
    );
  }

  void _invalidateDataCaches() {
    _cachedAreaSource = null;
    _cachedAreaLength = -1;
    _cachedAreaById = const {};
    _favouriteCacheKey = '';
    _recommendationCacheKey = '';
  }
}

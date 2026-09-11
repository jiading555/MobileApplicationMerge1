import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../core/utils/auth_validators.dart';
import '../core/utils/location_normalizer.dart';
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
  DateTime? marketTrendCacheUpdatedAt;
  String? openDataLoadMessage;
  String? latestDataRefreshMessage;
  String? governmentDataRefreshMessage;
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
      await _reloadVisibleData(
        allowMarketCacheFallback: true,
        preferMarketCache: true,
      );
      await _loadCurrentAuthSession();
    } catch (error) {
      loadError = 'Failed to load official app data: $error';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> ensureInitialMarketData() async {
    if (hasAttemptedInitialMarketRefresh || isRefreshingGovernmentData) {
      return;
    }

    final cacheUpdatedAt = marketTrendCacheUpdatedAt;
    final hasExpiredCache =
        isUsingMarketTrendCache &&
        cacheUpdatedAt != null &&
        !MarketTrendCacheEntry(
          areas: areas,
          updatedAt: cacheUpdatedAt,
        ).isFreshAt(DateTime.now());
    final needsMarketData = !areas.any((area) => area.hasMarketHistory);

    if (!hasExpiredCache && !needsMarketData) return;
    if (!SupabaseConfig.isConfigured) return;

    hasAttemptedInitialMarketRefresh = true;
    await refreshGovernmentData();
  }

  Future<void> refreshLatestData() async {
    if (!SupabaseConfig.isConfigured) {
      latestDataRefreshMessage =
          'Supabase is not configured. Add the project URL and client-safe '
          'publishable key to load latest data.';
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
      final result = await _reloadVisibleData(
        allowMarketCacheFallback: true,
        preserveCurrentData: true,
      );
      latestDataRefreshMessage = result.loadedAreaProfilesFromSupabase
          ? 'Latest data refreshed: ${properties.length} properties and '
                '${areas.length} areas loaded from Supabase.'
          : _marketRefreshFailureMessage(result);
    } catch (error) {
      latestDataRefreshMessage = _isOfflineError(error)
          ? 'Refresh failed: no internet connection. Current data is still displayed.'
          : 'Latest market data could not be reloaded. Current data is still displayed.';
    } finally {
      isRefreshingLatestData = false;
      notifyListeners();
    }
  }

  Future<void> refreshGovernmentData() async {
    if (!SupabaseConfig.isConfigured) {
      governmentDataRefreshMessage =
          'Supabase is not configured. Add the project URL and client-safe '
          'publishable key before reloading latest data.';
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
    final previousMarketTrendCache = isUsingMarketTrendCache;
    final previousLiveAreaProfiles = isUsingLiveAreaProfiles;
    final previousCloudProperties = isUsingCloudProperties;
    final previousProcessedTeduhProperties = isUsingProcessedTeduhProperties;
    final previousCacheUpdatedAt = marketTrendCacheUpdatedAt;

    isRefreshingGovernmentData = true;
    governmentDataRefreshMessage = null;
    notifyListeners();

    try {
      final result = await _reloadVisibleData(
        allowMarketCacheFallback: true,
        preserveCurrentData: true,
      );
      if (!result.loadedAreaProfilesFromSupabase) {
        governmentDataRefreshMessage = _marketRefreshFailureMessage(result);
        return;
      }
      if (areas.isEmpty) {
        throw StateError(
          'Supabase returned no area profiles; keeping the previous data.',
        );
      }
      final years = _dataYears(areas);
      final yearSuffix = years.isEmpty
          ? ''
          : ' Data years: ${years.join(', ')}.';
      governmentDataRefreshMessage =
          'Latest market data reloaded from Supabase.$yearSuffix';
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
      governmentDataRefreshMessage = _isOfflineError(error)
          ? 'Refresh failed: no internet connection. Current data is still displayed.'
          : 'Latest market data could not be reloaded. Current data is still displayed.';
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

  String _marketRefreshFailureMessage(_VisibleDataReloadResult result) {
    if (!SupabaseConfig.isConfigured) {
      return 'Supabase is not configured. Add the project URL and client-safe '
          'publishable key before reloading latest data.';
    }

    final hasDisplayedData = result.displayedAreaCount > 0;
    final hasCachedData = result.loadedFromMarketTrendCache;

    if (_isOfflineError(result.areaProfilesError) ||
        _isOfflineError(result.propertiesError)) {
      if (hasCachedData) {
        return 'Refresh failed: no internet connection. Cached market data is still displayed.';
      }
      if (hasDisplayedData) {
        return 'Refresh failed: no internet connection. Current data is still displayed.';
      }
      return 'Refresh failed: no internet connection. No market data is available.';
    }

    if (hasCachedData) {
      return 'Latest market data could not be reloaded. Cached data is still displayed.';
    }
    if (hasDisplayedData) {
      return 'Latest market data could not be reloaded. Current data is still displayed.';
    }
    return 'Latest market data could not be reloaded. No market data is available.';
  }

  bool _isOfflineError(Object? error) {
    if (error == null) return false;

    final message = error.toString().toLowerCase();
    return message.contains('socketexception') ||
        message.contains('clientexception') ||
        message.contains('failed host lookup') ||
        message.contains('network is unreachable') ||
        message.contains('connection refused') ||
        message.contains('connection reset') ||
        message.contains('connection timed out') ||
        message.contains('timed out') ||
        message.contains('timeout');
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
    } on AuthException catch (error) {
      final message = error.message.toLowerCase();
      if (message.contains('invalid login credentials')) {
        return 'Incorrect email address or password.';
      }
      if (message.contains('email not confirmed')) {
        return 'Confirm your email address before signing in.';
      }
      if (_isOfflineError(error)) {
        return _noInternetMessage;
      }
      return error.message;
    } catch (error) {
      if (_isOfflineError(error)) {
        return _noInternetMessage;
      }
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
        emailRedirectTo: SupabaseConfig.emailConfirmationRedirectUrl,
        data: {'full_name': name.trim()},
      );
      final authUser = response.user;
      if (authUser == null) return 'Unable to create account.';
      if (authUser.identities?.isEmpty ?? false) {
        return 'An account with this email address already exists. Please sign in.';
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
    } on AuthException catch (error) {
      if (error.message.toLowerCase().contains('already registered')) {
        return 'An account with this email address already exists. Please sign in.';
      }
      return error.message;
    } catch (_) {
      return 'Unable to create account. Please try again.';
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
    } on AuthException catch (error) {
      return error.message;
    } catch (_) {
      return 'Unable to update password. Please request a new reset link.';
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
    } on AuthException catch (error) {
      return error.message;
    } catch (_) {
      return 'Unable to resend confirmation email. Please try again.';
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
    } on AuthException catch (error) {
      return error.message;
    } catch (_) {
      return 'Unable to send reset email. Please try again.';
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
    } catch (_) {
      return 'Unable to upload avatar. Please try again.';
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

  Future<_VisibleDataReloadResult> _reloadVisibleData({
    bool allowMarketCacheFallback = false,
    bool preserveCurrentData = false,
    bool preferMarketCache = false,
  }) async {
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

    MarketTrendCacheEntry? cachedMarketTrend;
    var cacheApplied = false;

    if (allowMarketCacheFallback) {
      cachedMarketTrend = await _loadMarketTrendCache();
      if (cachedMarketTrend != null && cachedMarketTrend.areas.isNotEmpty) {
        if (!preserveCurrentData || areas.isEmpty || isUsingMarketTrendCache) {
          _applyMarketTrendCache(cachedMarketTrend);
          cacheApplied = true;
        }
      }
    }

    var loadedAreaProfilesFromSupabase = false;
    Object? areaProfilesError;
    final shouldLoadCloudAreaProfiles =
        SupabaseConfig.isConfigured && !(preferMarketCache && cacheApplied);

    if (!SupabaseConfig.isConfigured) {
      openDataLoadMessage =
          'Supabase is not configured. Add the project URL and publishable key '
          'to load official property and area data.';
    } else if (shouldLoadCloudAreaProfiles) {
      final cloudProfiles = await _loadCloudAreaProfiles();
      areaProfilesError = cloudProfiles.error;

      if (cloudProfiles.values.isNotEmpty) {
        final refreshedAreas = _areasFromProfiles(
          cloudProfiles.values,
          localAreas,
        );
        if (refreshedAreas.isNotEmpty) {
          areas = refreshedAreas;
          isUsingCloudAreaProfiles = true;
          isUsingProcessedAreaProfiles = false;
          isUsingMarketTrendCache = false;
          isUsingLiveAreaProfiles = false;
          loadedAreaProfilesFromSupabase = true;
        }
      } else if (cloudProfiles.succeeded) {
        openDataLoadMessage =
            'Supabase returned no area profiles; keeping available data.';
      }
    }

    Object? propertiesError;
    if (SupabaseConfig.isConfigured && areas.isNotEmpty) {
      final cloudProperties = await _loadCloudProperties(areas);
      propertiesError = cloudProperties.error;
      if (cloudProperties.values.isNotEmpty) {
        properties = cloudProperties.values;
        isUsingCloudProperties = true;
        isUsingProcessedTeduhProperties = false;
      }
    }

    if (areas.isNotEmpty && loadedAreaProfilesFromSupabase) {
      final cachedAt = DateTime.now().toUtc();
      await _saveMarketTrendCache(areas, cachedAt);
      marketTrendCacheUpdatedAt = cachedAt;
    }
    _invalidateDataCaches();

    return _VisibleDataReloadResult(
      loadedAreaProfilesFromSupabase: loadedAreaProfilesFromSupabase,
      loadedFromMarketTrendCache:
          isUsingMarketTrendCache && !loadedAreaProfilesFromSupabase,
      areaProfilesError: areaProfilesError,
      propertiesError: propertiesError,
      displayedAreaCount: areas.length,
    );
  }

  void _applyMarketTrendCache(MarketTrendCacheEntry cachedMarketTrend) {
    areas = _canonicalAreas(cachedMarketTrend.areas);
    marketTrendCacheUpdatedAt = cachedMarketTrend.updatedAt;
    isUsingCloudAreaProfiles = false;
    isUsingProcessedAreaProfiles = false;
    isUsingMarketTrendCache = true;
    isUsingLiveAreaProfiles = false;
  }

  Future<_RepositoryLoadResult<AreaProfile>> _loadCloudAreaProfiles() async {
    try {
      return _RepositoryLoadResult.success(
        await _areaProfileRepository.getAreaProfiles(),
      );
    } on AreaProfileRepositoryException catch (error) {
      openDataLoadMessage = error.toString();
      return _RepositoryLoadResult.failure(error);
    }
  }

  Future<_RepositoryLoadResult<Property>> _loadCloudProperties(
    List<AreaData> areas,
  ) async {
    try {
      return _RepositoryLoadResult.success(
        await _propertyRepository.getProperties(areas),
      );
    } on PropertyRepositoryException catch (error) {
      openDataLoadMessage = error.toString();
      return _RepositoryLoadResult.failure(error);
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

class _RepositoryLoadResult<T> {
  const _RepositoryLoadResult.success(this.values) : error = null;
  const _RepositoryLoadResult.failure(this.error) : values = const [];

  final List<T> values;
  final Object? error;

  bool get succeeded => error == null;
}

class _VisibleDataReloadResult {
  const _VisibleDataReloadResult({
    required this.loadedAreaProfilesFromSupabase,
    required this.loadedFromMarketTrendCache,
    required this.displayedAreaCount,
    this.areaProfilesError,
    this.propertiesError,
  });

  final bool loadedAreaProfilesFromSupabase;
  final bool loadedFromMarketTrendCache;
  final int displayedAreaCount;
  final Object? areaProfilesError;
  final Object? propertiesError;
}

import 'package:flutter/foundation.dart';

import '../data/asset_repository.dart';
import '../models/app_user.dart';
import '../models/area_data.dart';
import '../models/property.dart';
import '../models/recommendation.dart';
import '../models/user_preferences.dart';
import '../services/recommendation_service.dart';

class AppState extends ChangeNotifier {
  AppState({
    this._repository = const AssetRepository(),
    this._recommendationService = const RecommendationService(),
  });

  final AssetRepository _repository;
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
      areas = results[0] as List<AreaData>;
      properties = results[1] as List<Property>;
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
    return areas.firstWhere((area) => area.id == areaId);
  }

  void updateUser(AppUser value) {
    user = value;
    notifyListeners();
  }
}

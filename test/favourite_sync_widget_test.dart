import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_property_advisor/app/app_navigation_scope.dart';
import 'package:smart_property_advisor/app/app_scope.dart';
import 'package:smart_property_advisor/app/app_state.dart';
import 'package:smart_property_advisor/core/theme/app_theme.dart';
import 'package:smart_property_advisor/data/repositories/user_account_repository.dart';
import 'package:smart_property_advisor/features/home/home_screen.dart';
import 'package:smart_property_advisor/features/profile/profile_screen.dart';
import 'package:smart_property_advisor/features/search/property_detail_screen.dart';
import 'package:smart_property_advisor/features/search/property_search_screen.dart';
import 'package:smart_property_advisor/models/app_user.dart';
import 'package:smart_property_advisor/models/property.dart';

void main() {
  testWidgets('favourite state syncs across Home, Search, and Profile', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 932);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    final state = _favouriteState();

    await _pumpHome(tester, state);
    final homeHeart = find.byIcon(Icons.favorite_border_rounded).first;
    await tester.ensureVisible(homeHeart);
    await tester.pumpAndSettle();
    await tester.tap(homeHeart);
    await tester.pumpAndSettle();

    expect(state.isFavourite('property_sync'), isTrue);

    await _pumpProfile(tester, state);
    expect(find.text('1 saved'), findsOneWidget);
    expect(find.text('Residensi Sync'), findsOneWidget);

    await _pumpSearch(tester, state);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite_rounded).first);
    await tester.pumpAndSettle();

    expect(state.isFavourite('property_sync'), isFalse);

    await _pumpHome(tester, state);
    final homeHeartAfterSearchRemove = find
        .byIcon(Icons.favorite_border_rounded)
        .first;
    await tester.ensureVisible(homeHeartAfterSearchRemove);
    await tester.pumpAndSettle();
    expect(homeHeartAfterSearchRemove, findsOneWidget);

    await _pumpDetail(tester, state);
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded).first);
    await tester.pumpAndSettle();

    expect(state.isFavourite('property_sync'), isTrue);

    await _pumpProfile(tester, state);
    expect(find.text('1 saved'), findsOneWidget);
    expect(find.text('Residensi Sync'), findsOneWidget);

    await _pumpDetail(tester, state);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite_rounded).first);
    await tester.pumpAndSettle();

    expect(state.isFavourite('property_sync'), isFalse);

    await _pumpProfile(tester, state);
    expect(find.text('0 saved'), findsOneWidget);
    expect(find.text('No favourite properties yet.'), findsOneWidget);
  });
}

AppState _favouriteState() {
  final state = AppState(
    userAccountRepository: const _NoopUserAccountRepository(),
    currentAuthUserIdProvider: () => 'user_a',
  );
  state.isLoading = false;
  state.isAuthenticated = true;
  state.user = const AppUser(
    id: 'user_a',
    name: 'Alex Tan',
    email: 'alex@example.com',
  );
  state.properties = const [
    Property(
      id: 'property_sync',
      name: 'Residensi Sync',
      areaId: 'perak_kinta',
      address: 'Kinta, Perak',
      type: 'Apartment',
      tenure: 'Freehold',
      state: 'Perak',
      district: 'Kinta',
      price: 300000,
      summary: 'Official listing information.',
      facilities: [],
      palette: 0,
    ),
  ];
  return state;
}

Future<void> _pumpHome(WidgetTester tester, AppState state) {
  return tester.pumpWidget(
    AppScope(
      notifier: state,
      child: AppNavigationScope(
        selectDestination: (_) {},
        child: MaterialApp(
          theme: AppTheme.light.copyWith(splashFactory: NoSplash.splashFactory),
          home: const HomeScreen(),
        ),
      ),
    ),
  );
}

Future<void> _pumpSearch(WidgetTester tester, AppState state) {
  return tester.pumpWidget(
    AppScope(
      notifier: state,
      child: MaterialApp(
        theme: AppTheme.light.copyWith(splashFactory: NoSplash.splashFactory),
        home: const PropertySearchScreen(),
      ),
    ),
  );
}

Future<void> _pumpDetail(WidgetTester tester, AppState state) {
  return tester.pumpWidget(
    AppScope(
      notifier: state,
      child: MaterialApp(
        theme: AppTheme.light.copyWith(splashFactory: NoSplash.splashFactory),
        home: const PropertyDetailScreen(propertyId: 'property_sync'),
      ),
    ),
  );
}

Future<void> _pumpProfile(WidgetTester tester, AppState state) {
  return tester.pumpWidget(
    AppScope(
      notifier: state,
      child: MaterialApp(
        theme: AppTheme.light.copyWith(splashFactory: NoSplash.splashFactory),
        home: const ProfileScreen(),
      ),
    ),
  );
}

class _NoopUserAccountRepository extends UserAccountRepository {
  const _NoopUserAccountRepository();

  @override
  Future<void> setFavourite({
    required String userId,
    required String propertyId,
    required bool isFavourite,
  }) async {}
}

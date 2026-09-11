import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_property_advisor/app/app_state.dart';
import 'package:smart_property_advisor/data/repositories/user_account_repository.dart';
import 'package:smart_property_advisor/models/app_user.dart';

void main() {
  test('toggleFavourite adds and removes by property id', () async {
    final repository = _FakeUserAccountRepository();
    final state = _authenticatedState(repository);

    expect(await state.toggleFavourite('property_a'), isNull);

    expect(state.isFavourite('property_a'), isTrue);
    expect(state.favouriteIdsListenable.value, contains('property_a'));
    expect(repository.writes, [
      const _FavouriteWrite('user_a', 'property_a', true),
    ]);

    expect(await state.toggleFavourite('property_a'), isNull);

    expect(state.isFavourite('property_a'), isFalse);
    expect(state.favouriteIdsListenable.value, isNot(contains('property_a')));
    expect(repository.writes, [
      const _FavouriteWrite('user_a', 'property_a', true),
      const _FavouriteWrite('user_a', 'property_a', false),
    ]);
  });

  test(
    'toggleFavourite ignores rapid duplicate taps for same property',
    () async {
      final repository = _FakeUserAccountRepository(
        blockedPropertyIds: {'property_a'},
      );
      final state = _authenticatedState(repository);

      final firstToggle = state.toggleFavourite('property_a');

      expect(state.isFavourite('property_a'), isTrue);
      expect(state.favouriteOperationIds, contains('property_a'));
      expect(repository.writes, [
        const _FavouriteWrite('user_a', 'property_a', true),
      ]);

      expect(await state.toggleFavourite('property_a'), isNull);
      expect(repository.writes, [
        const _FavouriteWrite('user_a', 'property_a', true),
      ]);

      repository.release('property_a');
      expect(await firstToggle, isNull);

      expect(state.isFavourite('property_a'), isTrue);
      expect(state.favouriteOperationIds, isNot(contains('property_a')));
    },
  );

  test('toggleFavourite does not false-succeed without auth user', () async {
    final repository = _FakeUserAccountRepository();
    final state = _authenticatedState(repository, authUserId: null);

    final error = await state.toggleFavourite('property_a');

    expect(error, 'Sign in to save favourite properties.');
    expect(state.isFavourite('property_a'), isFalse);
    expect(repository.writes, isEmpty);
  });

  test(
    'toggleFavourite rejects empty property id before persistence',
    () async {
      final repository = _FakeUserAccountRepository();
      final state = _authenticatedState(repository);

      final error = await state.toggleFavourite('  ');

      expect(error, 'Could not add this property to favourites.');
      expect(state.favouriteIds, isEmpty);
      expect(repository.writes, isEmpty);
    },
  );

  test(
    'toggleFavourite only blocks the property currently in flight',
    () async {
      final repository = _FakeUserAccountRepository(
        blockedPropertyIds: {'property_a'},
      );
      final state = _authenticatedState(repository);

      final firstToggle = state.toggleFavourite('property_a');
      expect(state.favouriteOperationIds, contains('property_a'));

      expect(await state.toggleFavourite('property_b'), isNull);

      expect(state.isFavourite('property_a'), isTrue);
      expect(state.isFavourite('property_b'), isTrue);
      expect(repository.writes, [
        const _FavouriteWrite('user_a', 'property_a', true),
        const _FavouriteWrite('user_a', 'property_b', true),
      ]);

      repository.release('property_a');
      expect(await firstToggle, isNull);
    },
  );

  test('toggleFavourite restores previous state when add fails', () async {
    final repository = _FakeUserAccountRepository()
      ..failure = Exception('PostgrestException: duplicate key');
    final state = _authenticatedState(repository);

    final error = await state.toggleFavourite('property_a');

    expect(error, 'Could not add this property to favourites.');
    expect(state.accountError, error);
    expect(state.isFavourite('property_a'), isFalse);
  });

  test(
    'toggleFavourite restores previous state on offline remove failure',
    () async {
      final repository = _FakeUserAccountRepository();
      final state = _authenticatedState(repository);

      expect(await state.toggleFavourite('property_a'), isNull);

      repository.failure = Exception('SocketException: failed host lookup');
      final error = await state.toggleFavourite('property_a');

      expect(
        error,
        'No internet connection. Favourite changes could not be saved.',
      );
      expect(state.accountError, error);
      expect(state.isFavourite('property_a'), isTrue);
    },
  );

  test('toggleFavourite restores previous state on remove failure', () async {
    final repository = _FakeUserAccountRepository();
    final state = _authenticatedState(repository);

    expect(await state.toggleFavourite('property_a'), isNull);

    repository.failure = Exception('PostgrestException: permission denied');
    final error = await state.toggleFavourite('property_a');

    expect(error, 'Could not remove this property from favourites.');
    expect(state.accountError, error);
    expect(state.isFavourite('property_a'), isTrue);
  });
}

AppState _authenticatedState(
  UserAccountRepository repository, {
  String? authUserId = 'user_a',
}) {
  final state = AppState(
    userAccountRepository: repository,
    currentAuthUserIdProvider: () => authUserId,
  );
  state.isAuthenticated = true;
  state.user = const AppUser(
    id: 'user_a',
    name: 'Alex Tan',
    email: 'alex@example.com',
  );
  return state;
}

class _FakeUserAccountRepository extends UserAccountRepository {
  _FakeUserAccountRepository({this.blockedPropertyIds = const {}});

  final Set<String> blockedPropertyIds;
  final List<_FavouriteWrite> writes = [];
  final Map<String, Completer<void>> _gates = {};
  Object? failure;

  @override
  Future<void> setFavourite({
    required String userId,
    required String propertyId,
    required bool isFavourite,
  }) async {
    writes.add(_FavouriteWrite(userId, propertyId, isFavourite));

    if (blockedPropertyIds.contains(propertyId)) {
      await _gates.putIfAbsent(propertyId, Completer<void>.new).future;
    }

    if (failure != null) {
      throw failure!;
    }
  }

  void release(String propertyId) {
    final gate = _gates[propertyId];
    if (gate != null && !gate.isCompleted) {
      gate.complete();
    }
  }
}

class _FavouriteWrite {
  const _FavouriteWrite(this.userId, this.propertyId, this.isFavourite);

  final String userId;
  final String propertyId;
  final bool isFavourite;

  @override
  bool operator ==(Object other) {
    return other is _FavouriteWrite &&
        other.userId == userId &&
        other.propertyId == propertyId &&
        other.isFavourite == isFavourite;
  }

  @override
  int get hashCode => Object.hash(userId, propertyId, isFavourite);

  @override
  String toString() {
    return 'FavouriteWrite($userId, $propertyId, $isFavourite)';
  }
}

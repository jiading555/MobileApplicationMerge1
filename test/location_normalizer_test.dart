import 'package:flutter_test/flutter_test.dart';
import 'package:smart_property_advisor/core/utils/location_normalizer.dart';
import 'package:smart_property_advisor/data/repositories/area_profile_repository.dart';
import 'package:smart_property_advisor/models/area_profile.dart';

void main() {
  test('canonical area id resolves Penang aliases to Pulau Pinang', () {
    expect(
      LocationNormalizer.canonicalAreaId('Penang', 'Timur Laut'),
      'pulau_pinang_timur_laut',
    );
    expect(
      LocationNormalizer.canonicalAreaId('Pulau Pinang', 'Timur Laut'),
      'pulau_pinang_timur_laut',
    );
    expect(
      LocationNormalizer.canonicalAreaId('pulau pinang', 'Timur Laut'),
      'pulau_pinang_timur_laut',
    );
  });

  test('canonical area id normalizes Malaysian state aliases', () {
    expect(LocationNormalizer.displayStateName('KL'), 'Kuala Lumpur');
    expect(
      LocationNormalizer.displayStateName('W.P. Kuala Lumpur'),
      'Kuala Lumpur',
    );
    expect(LocationNormalizer.displayStateName('WP Labuan'), 'Labuan');
    expect(LocationNormalizer.displayStateName('WP Putrajaya'), 'Putrajaya');
    expect(LocationNormalizer.displayStateName('Malacca'), 'Melaka');
    expect(
      LocationNormalizer.displayStateName('Negri Sembilan'),
      'Negeri Sembilan',
    );
  });

  test('legacy and canonical Penang area ids match', () {
    expect(
      LocationNormalizer.areaIdMatches(
        'penang_timur_laut',
        'pulau_pinang_timur_laut',
      ),
      isTrue,
    );
  });

  test(
    'area profile merge enriches one canonical row without null overwrite',
    () {
      final merged = AreaProfileRepository.mergeProfileData([
        const AreaProfile(
          areaId: 'pulau_pinang_timur_laut',
          state: 'Pulau Pinang',
          district: 'Timur Laut',
          population: 565900,
          populationYear: 2025,
          medianHouseholdIncome: 7745,
          source: 'OpenDOSM',
        ),
        const AreaProfile(
          areaId: 'penang_timur_laut',
          state: 'Penang',
          district: 'Timur Laut',
          transportStopCount: 88,
          transportYear: 2024,
          dataYear: 2024,
          source: 'Transit feed',
        ),
        const AreaProfile(
          areaId: 'pulau_pinang_timur_laut',
          state: 'Pulau Pinang',
          district: 'Timur Laut',
          dataYear: 2025,
          source: 'data.gov.my',
        ),
      ]);

      expect(merged, hasLength(1));
      final profile = merged['pulau_pinang_timur_laut']!;
      expect(profile.state, 'Pulau Pinang');
      expect(profile.district, 'Timur Laut');
      expect(profile.population, 565900);
      expect(profile.populationYear, 2025);
      expect(profile.medianHouseholdIncome, 7745);
      expect(profile.transportStopCount, 88);
      expect(profile.transportYear, 2024);
      expect(profile.dataYear, 2025);
      expect(profile.source, 'OpenDOSM; Transit feed; data.gov.my');
    },
  );
}

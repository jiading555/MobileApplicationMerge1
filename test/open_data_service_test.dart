import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_property_advisor/models/area_data.dart';
import 'package:smart_property_advisor/models/area_profile.dart';
import 'package:smart_property_advisor/services/open_data_service.dart';

void main() {
  test('discovers dynamic districts from population master dataset', () async {
    final requested = <Uri>[];
    final client = MockClient((request) {
      requested.add(request.url);
      final uri = request.url;
      if (uri.toString().contains('population_district.csv')) {
        return Future.value(http.Response(_populationCsv, 200));
      }
      if (uri.queryParameters['id'] == 'hh_income_district') {
        return Future.value(
          http.Response(jsonEncode({'data': _incomeRows}), 200),
        );
      }
      if (uri.queryParameters['id'] == 'schools_district') {
        return Future.value(
          http.Response(jsonEncode({'data': _schoolRows}), 200),
        );
      }
      if (uri.toString().contains('crime_district.csv')) {
        return Future.value(http.Response(_crimeCsv, 200));
      }
      return Future.value(http.Response('not found', 404));
    });

    final profiles = await OpenDataService(client: client).fetchAreaProfiles();
    final byId = {for (final profile in profiles) profile.areaId: profile};

    expect(requested, hasLength(4));
    expect(profiles, hasLength(7));
    expect(byId, contains('selangor_petaling'));
    expect(byId, contains('selangor_klang'));
    expect(byId, contains('pulau_pinang_timur_laut'));
    expect(byId, contains('johor_johor_bahru'));
    expect(byId['selangor_petaling']!.population, 2298000);
    expect(byId['selangor_petaling']!.crimeCount, 300);
    expect(byId['pulau_pinang_timur_laut']!.medianHouseholdIncome, 8123);
    expect(byId['selangor_klang']!.crimeCount, isNull);
    expect(byId['johor_johor_bahru']!.educationInstitutionCount, isNull);
  });

  test('AreaData from profile does not inherit sample analytics fallback', () {
    const fallback = AreaData(
      id: 'petaling',
      name: 'Petaling',
      state: 'Selangor',
      population: 1,
      populationGrowth: 9,
      medianIncome: 1,
      safetyScore: 90,
      connectivityScore: 90,
      transportScore: 90,
      schools: 99,
      hospitals: 9,
      averagePricePsf: 999,
      rentalYield: 9,
      priceGrowth: 9,
      priceHistory: [1, 2, 3],
      snapshotDate: 'sample',
    );

    final area = AreaData.fromProfile(
      const AreaProfile(
        areaId: 'selangor_petaling',
        state: 'Selangor',
        district: 'Petaling',
        population: 2298000,
        medianHouseholdIncome: 9880,
        populationYear: 2025,
      ),
      fallback: fallback,
    );

    expect(area.id, 'selangor_petaling');
    expect(area.population, 2298000);
    expect(area.medianIncome, 9880);
    expect(area.safetyScore, isNull);
    expect(area.schools, isNull);
    expect(area.hospitals, isNull);
    expect(area.averagePricePsf, isNull);
    expect(area.rentalYield, isNull);
    expect(area.priceGrowth, isNull);
    expect(area.priceHistory, isEmpty);
  });
}

const _populationCsv = '''
date,state,district,sex,age,ethnicity,population
2024-01-01,Selangor,Petaling,both,overall,overall,2200
2025-01-01,Selangor,Petaling,both,overall,overall,2298
2025-01-01,Selangor,Gombak,both,overall,overall,942
2025-01-01,Selangor,Ulu Langat,both,overall,overall,1400
2025-01-01,Selangor,Klang,both,overall,overall,1088
2025-01-01,Johor,Johor Bahru,both,overall,overall,1711
2025-01-01,Penang,Timur Laut,both,overall,overall,556
2025-01-01,Pulau Pinang,Seberang Perai Tengah,both,overall,overall,420
2025-01-01,Selangor,Petaling,male,overall,overall,1100
''';

const _incomeRows = [
  {
    'date': '2024-01-01',
    'state': 'Pulau Pinang',
    'district': 'Timur Laut',
    'income_median': 8123,
  },
  {
    'date': '2024-01-01',
    'state': 'Selangor',
    'district': 'Petaling',
    'income_median': 9880,
  },
];

const _schoolRows = [
  {
    'date': '2022-01-01',
    'state': 'Selangor',
    'district': 'Petaling',
    'schools': 128,
  },
  {
    'date': '2022-01-01',
    'state': 'Selangor',
    'district': 'Klang',
    'schools': 112,
  },
];

const _crimeCsv = '''
date,state,district,type,crimes
2023-01-01,Selangor,Petaling Jaya,all,200
2023-01-01,Selangor,Shah Alam,all,100
2023-01-01,Selangor,Gombak,all,80
2023-01-01,Pulau Pinang,Timur Laut,all,60
2023-01-01,Johor,Johor Bahru Selatan,all,70
2023-01-01,Johor,Johor Bahru Utara,all,40
2023-01-01,Selangor,Petaling Jaya,violent,9
''';

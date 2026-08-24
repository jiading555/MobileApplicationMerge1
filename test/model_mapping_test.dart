import 'package:flutter_test/flutter_test.dart';
import 'package:smart_property_advisor/models/area_profile.dart';
import 'package:smart_property_advisor/models/property.dart';

void main() {
  test('TEDUH property mapping keeps stable Supabase keys', () {
    final property = Property.fromTeduhJson(
      {
        'source_id': 'teduh-001',
        'project_name': 'Residensi Test',
        'state': 'Selangor',
        'district': 'Gombak',
        'source': 'TEDUH - Jabatan Perumahan Negara, KPKT',
      },
      areaId: 'selangor_gombak',
      palette: 1,
    );

    final supabaseJson = property.toSupabaseJson();

    expect(property.id, 'teduh_teduh-001');
    expect(property.name, 'Residensi Test');
    expect(supabaseJson['source_id'], 'teduh-001');
    expect(supabaseJson['project_name'], 'Residensi Test');
    expect(supabaseJson.containsKey('price_min'), isTrue);
    expect(supabaseJson.containsKey('available_units'), isTrue);
    expect(supabaseJson.containsKey('raw_location'), isTrue);
  });

  test('area profile mapping keeps stable Supabase keys', () {
    final profile = AreaProfile.fromJson({
      'area_id': 'selangor_gombak',
      'state': 'Selangor',
      'district': 'Gombak',
      'population': 942600,
      'median_household_income': 9134,
      'source': 'OpenDOSM; data.gov.my',
    });

    final supabaseJson = profile.toSupabaseJson();

    expect(profile.areaId, 'selangor_gombak');
    expect(profile.medianHouseholdIncome, 9134);
    expect(supabaseJson['area_id'], 'selangor_gombak');
    expect(supabaseJson.containsKey('crime_count'), isTrue);
    expect(supabaseJson.containsKey('education_institution_count'), isTrue);
    expect(supabaseJson.containsKey('transport_stop_count'), isTrue);
  });
}

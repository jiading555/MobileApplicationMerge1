class AreaProfile {
  const AreaProfile({
    required this.areaId,
    required this.state,
    required this.district,
    this.population,
    this.populationYear,
    this.medianHouseholdIncome,
    this.incomeYear,
    this.crimeCount,
    this.crimeYear,
    this.educationInstitutionCount,
    this.educationYear,
    this.transportStopCount,
    this.transportYear,
    this.dataYear,
    this.source,
    this.sourceUrl,
    this.retrievedAt,
  });

  final String areaId;
  final String state;
  final String district;
  final int? population;
  final int? populationYear;
  final double? medianHouseholdIncome;
  final int? incomeYear;
  final int? crimeCount;
  final int? crimeYear;
  final int? educationInstitutionCount;
  final int? educationYear;
  final int? transportStopCount;
  final int? transportYear;
  final int? dataYear;
  final String? source;
  final String? sourceUrl;
  final DateTime? retrievedAt;

  factory AreaProfile.fromJson(Map<String, dynamic> json) {
    return AreaProfile(
      areaId: _stringFromJson(json['area_id'] ?? json['areaId']),
      state: _stringFromJson(json['state']),
      district: _stringFromJson(json['district']),
      population: _intFromJson(json['population']),
      populationYear: _intFromJson(
        json['population_year'] ?? json['populationYear'],
      ),
      medianHouseholdIncome: _doubleFromJson(
        json['median_household_income'] ?? json['medianHouseholdIncome'],
      ),
      incomeYear: _intFromJson(json['income_year'] ?? json['incomeYear']),
      crimeCount: _intFromJson(json['crime_count'] ?? json['crimeCount']),
      crimeYear: _intFromJson(json['crime_year'] ?? json['crimeYear']),
      educationInstitutionCount: _intFromJson(
        json['education_institution_count'] ??
            json['educationInstitutionCount'],
      ),
      educationYear: _intFromJson(
        json['education_year'] ?? json['educationYear'],
      ),
      transportStopCount: _intFromJson(
        json['transport_stop_count'] ?? json['transportStopCount'],
      ),
      transportYear: _intFromJson(
        json['transport_year'] ?? json['transportYear'],
      ),
      dataYear: _intFromJson(json['data_year'] ?? json['dataYear']),
      source: _nullableStringFromJson(json['source']),
      sourceUrl: _nullableStringFromJson(
        json['source_url'] ?? json['sourceUrl'],
      ),
      retrievedAt: _dateTimeFromJson(
        json['retrieved_at'] ?? json['retrievedAt'],
      ),
    );
  }

  Map<String, dynamic> toSupabaseJson() {
    return {
      'area_id': areaId,
      'state': state,
      'district': district,
      'population': population,
      'population_year': populationYear,
      'median_household_income': medianHouseholdIncome,
      'income_year': incomeYear,
      'crime_count': crimeCount,
      'crime_year': crimeYear,
      'education_institution_count': educationInstitutionCount,
      'education_year': educationYear,
      'transport_stop_count': transportStopCount,
      'transport_year': transportYear,
      'data_year': dataYear,
      'source': source,
      'source_url': sourceUrl,
      'retrieved_at': retrievedAt?.toUtc().toIso8601String(),
    }..removeWhere((_, value) => value == null);
  }

  static String _stringFromJson(Object? value) {
    return value?.toString() ?? '';
  }

  static String? _nullableStringFromJson(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static int? _intFromJson(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString());
  }

  static double? _doubleFromJson(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }

  static DateTime? _dateTimeFromJson(Object? value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }
}

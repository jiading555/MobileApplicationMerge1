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
    this.hospitalBedCount,
    this.hospitalYear,
    this.transportStopCount,
    this.transportYear,
    this.marketPriceHistory = const [],
    this.marketPricePeriods = const [],
    this.medianResidentialPrice,
    this.marketPriceYear,
    this.transactionCount,
    this.previousTransactionCount,
    this.transactionValueMillion,
    this.previousTransactionValueMillion,
    this.marketPeriod,
    this.marketSourceUrl,
    this.marketRetrievedAt,
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
  final int? hospitalBedCount;
  final int? hospitalYear;
  final int? transportStopCount;
  final int? transportYear;
  final List<double> marketPriceHistory;
  final List<String> marketPricePeriods;
  final double? medianResidentialPrice;
  final int? marketPriceYear;
  final int? transactionCount;
  final int? previousTransactionCount;
  final double? transactionValueMillion;
  final double? previousTransactionValueMillion;
  final String? marketPeriod;
  final String? marketSourceUrl;
  final DateTime? marketRetrievedAt;
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
      hospitalBedCount: _intFromJson(
        json['hospital_bed_count'] ?? json['hospitalBedCount'],
      ),
      hospitalYear: _intFromJson(
        json['hospital_year'] ?? json['hospitalYear'],
      ),
      transportStopCount: _intFromJson(
        json['transport_stop_count'] ?? json['transportStopCount'],
      ),
      transportYear: _intFromJson(
        json['transport_year'] ?? json['transportYear'],
      ),
      marketPriceHistory: _doubleListFromJson(
        json['market_price_history'] ?? json['marketPriceHistory'],
      ),
      marketPricePeriods: _stringListFromJson(
        json['market_price_periods'] ?? json['marketPricePeriods'],
      ),
      medianResidentialPrice: _doubleFromJson(
        json['median_residential_price'] ?? json['medianResidentialPrice'],
      ),
      marketPriceYear: _intFromJson(
        json['market_price_year'] ?? json['marketPriceYear'],
      ),
      transactionCount: _intFromJson(
        json['transaction_count'] ?? json['transactionCount'],
      ),
      previousTransactionCount: _intFromJson(
        json['previous_transaction_count'] ?? json['previousTransactionCount'],
      ),
      transactionValueMillion: _doubleFromJson(
        json['transaction_value_million'] ?? json['transactionValueMillion'],
      ),
      previousTransactionValueMillion: _doubleFromJson(
        json['previous_transaction_value_million'] ??
            json['previousTransactionValueMillion'],
      ),
      marketPeriod: _nullableStringFromJson(
        json['market_period'] ?? json['marketPeriod'],
      ),
      marketSourceUrl: _nullableStringFromJson(
        json['market_source_url'] ?? json['marketSourceUrl'],
      ),
      marketRetrievedAt: _dateTimeFromJson(
        json['market_retrieved_at'] ?? json['marketRetrievedAt'],
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
      'market_price_history': marketPriceHistory,
      'market_price_periods': marketPricePeriods,
      'median_residential_price': medianResidentialPrice,
      'market_price_year': marketPriceYear,
      'transaction_count': transactionCount,
      'previous_transaction_count': previousTransactionCount,
      'transaction_value_million': transactionValueMillion,
      'previous_transaction_value_million': previousTransactionValueMillion,
      'market_period': marketPeriod,
      'market_source_url': marketSourceUrl,
      'market_retrieved_at': marketRetrievedAt?.toUtc().toIso8601String(),
      'data_year': dataYear,
      'source': source,
      'source_url': sourceUrl,
      'retrieved_at': retrievedAt?.toUtc().toIso8601String(),
    };
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

  static List<double> _doubleListFromJson(Object? value) {
    if (value is! List) return const [];
    return value.map(_doubleFromJson).whereType<double>().toList();
  }

  static List<String> _stringListFromJson(Object? value) {
    if (value is! List) return const [];
    return value.map((item) => item.toString()).toList();
  }

  static DateTime? _dateTimeFromJson(Object? value) {
    if (value == null) {
      return null;
    }
    return DateTime.tryParse(value.toString());
  }
}

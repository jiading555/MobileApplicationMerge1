class LocationNormalizer {
  const LocationNormalizer._();

  static const Map<String, String> _stateAliases = {
    'johor': 'Johor',
    'kedah': 'Kedah',
    'kelantan': 'Kelantan',
    'melaka': 'Melaka',
    'malacca': 'Melaka',
    'negeri sembilan': 'Negeri Sembilan',
    'negri sembilan': 'Negeri Sembilan',
    'n sembilan': 'Negeri Sembilan',
    'pahang': 'Pahang',
    'perak': 'Perak',
    'perlis': 'Perlis',
    'pulau pinang': 'Pulau Pinang',
    'penang': 'Pulau Pinang',
    'p pinang': 'Pulau Pinang',
    'sabah': 'Sabah',
    'sarawak': 'Sarawak',
    'selangor': 'Selangor',
    'terengganu': 'Terengganu',
    'trengganu': 'Terengganu',
    'kuala lumpur': 'Kuala Lumpur',
    'kl': 'Kuala Lumpur',
    'wp kuala lumpur': 'Kuala Lumpur',
    'w p kuala lumpur': 'Kuala Lumpur',
    'wilayah kuala lumpur': 'Kuala Lumpur',
    'wilayah persekutuan kuala lumpur': 'Kuala Lumpur',
    'labuan': 'Labuan',
    'wp labuan': 'Labuan',
    'w p labuan': 'Labuan',
    'wilayah persekutuan labuan': 'Labuan',
    'putrajaya': 'Putrajaya',
    'wp putrajaya': 'Putrajaya',
    'w p putrajaya': 'Putrajaya',
    'wilayah persekutuan putrajaya': 'Putrajaya',
  };

  static final List<String> _stateAliasKeysByLength =
      _stateAliases.keys.toList()
        ..sort((left, right) => right.length.compareTo(left.length));

  static String canonicalAreaId(Object? state, Object? district) {
    final stateId = canonicalStateId(state);
    final districtId = canonicalDistrictId(district);
    if (stateId.isEmpty && districtId.isEmpty) {
      return 'unknown';
    }
    if (stateId.isEmpty) {
      return districtId;
    }
    if (districtId.isEmpty) {
      return stateId;
    }
    return '${stateId}_$districtId';
  }

  static String canonicalStateId(Object? value) {
    final display = displayStateName(value);
    return _slug(display);
  }

  static String canonicalDistrictId(Object? value) {
    return _slug(_cleanLocationText(value));
  }

  static String canonicalAreaIdFromExisting(Object? value) {
    final text = _normaliseWords(value);
    if (text.isEmpty) {
      return '';
    }

    for (final alias in _stateAliasKeysByLength) {
      if (text == alias) {
        return canonicalStateId(_stateAliases[alias]);
      }
      if (text.startsWith('$alias ')) {
        final district = text.substring(alias.length).trim();
        return canonicalAreaId(_stateAliases[alias], district);
      }
    }

    return _slug(text);
  }

  static String displayStateName(Object? value) {
    final words = _normaliseWords(value);
    if (words.isEmpty) {
      return '';
    }
    return _stateAliases[words] ?? _titleCase(words);
  }

  static String? nullableDisplayStateName(Object? value) {
    final display = displayStateName(value);
    return display.isEmpty ? null : display;
  }

  static String displayDistrictName(Object? value) {
    final words = _normaliseWords(value);
    return words.isEmpty ? '' : _titleCase(words);
  }

  static String? nullableDisplayDistrictName(Object? value) {
    final display = displayDistrictName(value);
    return display.isEmpty ? null : display;
  }

  static bool isKnownState(Object? value) {
    return _stateAliases.containsKey(_normaliseWords(value));
  }

  static Set<String> recognizedStateIds(Object? value) {
    final words = _normaliseWords(value);
    if (words.isEmpty) {
      return const {};
    }

    final padded = ' $words ';
    final stateIds = <String>{};
    for (final alias in _stateAliasKeysByLength) {
      if (padded.contains(' $alias ')) {
        stateIds.add(canonicalStateId(_stateAliases[alias]));
      }
    }
    return stateIds;
  }

  static bool hasConflictingKnownStates(Object? value) {
    return recognizedStateIds(value).length > 1;
  }

  static bool stateMatches(Object? left, Object? right) {
    return canonicalStateId(left) == canonicalStateId(right);
  }

  static bool districtMatches(Object? left, Object? right) {
    return canonicalDistrictId(left) == canonicalDistrictId(right);
  }

  static bool areaIdMatches(Object? left, Object? right) {
    return canonicalAreaIdFromExisting(left) ==
        canonicalAreaIdFromExisting(right);
  }

  static String stateDistrictKey(Object? state, Object? district) {
    return '${canonicalStateId(state)}|${canonicalDistrictId(district)}';
  }

  static StateSuffixMatch? matchStateSuffix(Object? value) {
    final words = _normaliseWords(value);
    if (words.isEmpty) {
      return null;
    }
    for (final alias in _stateAliasKeysByLength) {
      if (words == alias) {
        return StateSuffixMatch(state: _stateAliases[alias]!, beforeState: '');
      }
      if (words.endsWith(' $alias')) {
        final before = words.substring(0, words.length - alias.length).trim();
        return StateSuffixMatch(
          state: _stateAliases[alias]!,
          beforeState: before,
        );
      }
    }
    return null;
  }

  static String _cleanLocationText(Object? value) {
    return value?.toString().replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
  }

  static String _normaliseWords(Object? value) {
    return _cleanLocationText(value)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _slug(String value) {
    return _normaliseWords(value).replaceAll(' ', '_');
  }

  static String _titleCase(String value) {
    return value
        .split(RegExp(r'\s+'))
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }
}

class StateSuffixMatch {
  const StateSuffixMatch({required this.state, required this.beforeState});

  final String state;
  final String beforeState;
}

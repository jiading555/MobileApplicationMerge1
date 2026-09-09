class PropertyPreferenceOptions {
  const PropertyPreferenceOptions._();

  static const propertyTypes = [
    'Any',
    'Apartment',
    'Terrace House',
    'Semi-detached House',
    'Detached House',
    'Townhouse',
    'Shop House',
    'Public Housing',
    'Other',
  ];

  static const districtsByState = <String, List<String>>{
    'Johor': ['Batu Pahat', 'Johor Bahru', 'Kluang', 'Kota Tinggi', 'Kulai', 'Mersing', 'Muar', 'Pontian', 'Segamat', 'Tangkak'],
    'Kedah': ['Baling', 'Bandar Baharu', 'Kota Setar', 'Kuala Muda', 'Kubang Pasu', 'Kulim', 'Langkawi', 'Padang Terap', 'Pendang', 'Pokok Sena', 'Sik', 'Yan'],
    'Kelantan': ['Bachok', 'Gua Musang', 'Jeli', 'Kecil Lojing', 'Kota Bharu', 'Kuala Krai', 'Machang', 'Pasir Mas', 'Pasir Puteh', 'Tanah Merah', 'Tumpat'],
    'Melaka': ['Alor Gajah', 'Jasin', 'Melaka Tengah'],
    'Negeri Sembilan': ['Jelebu', 'Jempol', 'Kuala Pilah', 'Port Dickson', 'Rembau', 'Seremban', 'Tampin'],
    'Pahang': ['Bentong', 'Bera', 'Cameron Highlands', 'Jerantut', 'Kuantan', 'Lipis', 'Maran', 'Pekan', 'Raub', 'Rompin', 'Temerloh'],
    'Perak': ['Bagan Datuk', 'Batang Padang', 'Hilir Perak', 'Hulu Perak', 'Kampar', 'Kerian', 'Kinta', 'Kuala Kangsar', 'Larut Dan Matang', 'Manjung', 'Muallim', 'Perak Tengah', 'Selama'],
    'Perlis': ['Perlis'],
    'Pulau Pinang': ['Barat Daya', 'Seberang Perai Selatan', 'Seberang Perai Tengah', 'Seberang Perai Utara', 'Timur Laut'],
    'Sabah': ['Beaufort', 'Beluran', 'Kalabakan', 'Keningau', 'Kinabatangan', 'Kota Belud', 'Kota Kinabalu', 'Kota Marudu', 'Kuala Penyu', 'Kudat', 'Kunak', 'Lahad Datu', 'Nabawan', 'Papar', 'Penampang', 'Pitas', 'Putatan', 'Ranau', 'Sandakan', 'Semporna', 'Sipitang', 'Tambunan', 'Tawau', 'Telupid', 'Tenom', 'Tongod', 'Tuaran'],
    'Sarawak': ['Asajaya', 'Bau', 'Belaga', 'Beluru', 'Betong', 'Bintulu', 'Bukit Mabong', 'Dalat', 'Daro', 'Julau', 'Kabong', 'Kanowit', 'Kapit', 'Kuching', 'Lawas', 'Limbang', 'Lubok Antu', 'Lundu', 'Maradong', 'Marudi', 'Matu', 'Miri', 'Mukah', 'Pakan', 'Pusa', 'Samarahan', 'Saratok', 'Sarikei', 'Sebauh', 'Selangau', 'Serian', 'Sibu', 'Simunjan', 'Song', 'Sri Aman', 'Subis', 'Tanjung Manis', 'Tatau', 'Tebedu', 'Telang Usan'],
    'Selangor': ['Gombak', 'Klang', 'Kuala Langat', 'Kuala Selangor', 'Petaling', 'Sabak Bernam', 'Sepang', 'Ulu Langat', 'Ulu Selangor'],
    'Terengganu': ['Besut', 'Dungun', 'Hulu Terengganu', 'Kemaman', 'Kuala Nerus', 'Kuala Terengganu', 'Marang', 'Setiu'],
    'W.P. Kuala Lumpur': ['W.P. Kuala Lumpur'],
    'W.P. Labuan': ['W.P. Labuan'],
    'W.P. Putrajaya': ['W.P. Putrajaya'],
  };

  static List<String> get states => districtsByState.keys.toList();

  static List<String> districtsFor(String state) =>
      districtsByState[state] ?? const [];

  static bool matchesPropertyType(String preference, String rawType) {
    if (preference == 'Any') return true;
    final value = rawType.toLowerCase();
    final apartment = value.contains('apartment') ||
        value.contains('apartmen') ||
        value.contains('pangsapuri') ||
        value.contains('flat');
    final terrace = value.contains('terrace') || value.contains('teres');
    final semiDetached = value.contains('semi') || value.contains('berkembar');
    final detached = value.contains('detached') ||
        value.contains('banglo') ||
        value.contains('sesebuah');
    final townhouse = value.contains('townhouse') || value.contains('rumah bandar');
    final shopHouse = value.contains('shop house') ||
        value.contains('shoplot') ||
        value.contains('rumah kedai') ||
        value.contains('kedai pejabat');
    final publicHousing = value.contains('pr1ma') ||
        value.contains('ppam') ||
        value.contains('spnb') ||
        value.contains('ppr') ||
        value.contains('public housing');

    return switch (preference) {
      'Apartment' => apartment,
      'Terrace House' => terrace,
      'Semi-detached House' => semiDetached,
      'Detached House' => detached,
      'Townhouse' => townhouse,
      'Shop House' => shopHouse,
      'Public Housing' => publicHousing,
      'Other' => !apartment &&
          !terrace &&
          !semiDetached &&
          !detached &&
          !townhouse &&
          !shopHouse &&
          !publicHousing,
      _ => false,
    };
  }
}

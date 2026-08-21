# Smart Property Advisor

A Flutter application for exploring Malaysian property information, comparing
area indicators, and supporting property recommendations.

## Data Flow

The Area Data Analytics + Location & Property Information module now uses a
Flutter/Dart data pipeline:

```text
Malaysian Government Data
        |
Flutter/Dart Data Services
        |
package:http
        |
JSON decoding / package:html parsing
        |
Dart Models
        |
Supabase
        |
Flutter UI
```

TEDUH project data is fetched through `TeduhService`, cleaned into the
`Property` model, and synchronized to the Supabase `properties` table. District
area indicators are fetched through `OpenDataService`, cleaned into
`AreaProfile`, and synchronized to `area_profiles`.

## Running

```bash
flutter pub get
flutter run
```

Supabase is initialized from `lib/core/config/supabase_config.dart`, where the
project URL and client-safe publishable/anon key are defined as Dart constants.
Use only a key intended for client-side Flutter apps. Never embed a Supabase
service-role key, database password, or other server-side secret in the mobile
application.

The app keeps local JSON fallback data for a stable assignment demo when
Supabase or an external data source is unavailable.

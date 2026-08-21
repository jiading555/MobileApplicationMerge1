# Area Data Analytics + Location & Property Information Module

**Module Owner:** Mok Chun Bing  
**Application:** Smart Property Advisor (PandaGuru)  
**Course:** BMIT2073 Mobile Application Development  
**Platform:** Flutter  
**Primary Backend / Cloud Database:** Supabase  
**Primary Data Sources:** TEDUH, data.gov.my, OpenDOSM

## 1. Module Scope

This module provides the property, location, and area analytics data used by the Smart Property Advisor app. It owns these visible flows:

- Property Search
- Property Detail
- Map / Location support
- Area Analytics

It does not own authentication, final recommendation scoring, AI explanation, loan calculation, or market forecasting logic.

## 2. Practical Alignment

### Practical 10 - Weather Web API

The module follows the same basic Web API pattern:

```dart
final response = await http.get(uri);

if (response.statusCode == 200) {
  final data = jsonDecode(response.body);
}
```

The Dart services use `package:http` to retrieve TEDUH, data.gov.my, and OpenDOSM records. HTTP failures are caught and reported so the app can keep displaying Supabase or local fallback data.

### Practical 11 - Supabase Backend as a Service

The app keeps the existing secure Supabase initialization:

```dart
await Supabase.initialize(
  url: SupabaseConfig.url,
  publishableKey: SupabaseConfig.publishableKey,
);

final supabase = Supabase.instance.client;
```

The repositories use simple Supabase table operations:

```dart
supabase.from('area_profiles').select();
supabase.from('properties').select();
supabase.from('area_profiles').upsert(..., onConflict: 'area_id');
supabase.from('properties').upsert(..., onConflict: 'source_id');
```

The Supabase project URL and client-safe publishable/anon key are defined in
`lib/core/config/supabase_config.dart` for a simpler Practical 11 style demo.

### Practical 12 - OpenStreetMap

The current map screen remains a stable offline normalized map preview. If it is later replaced with a live map, use the Practical 12 approach with OpenStreetMap tiles, `flutter_map`, and `latlong2`.

## 3. Current Data Architecture

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

The app no longer requires a separate data-preparation utility before running the mobile application.

## 4. TEDUH Property Flow

TEDUH is used as the government housing information source for property records.

```text
TEDUH
  -> http.get
  -> HTML shell check with html_parser.parse
  -> public TEDUH project JSON endpoint used by the TEDUH page
  -> clean fields in Dart
  -> Property model
  -> Supabase properties table
  -> Property Search / Property Detail
```

The live `/projek` page currently serves a Vue shell with `#app`, then the browser JavaScript fetches `/api/portal/projects`. The service therefore checks the HTML shell using `package:html`, supports the project-card selectors used by the rendered page, and uses the same public JSON endpoint for actual project records and pagination.

Verified TEDUH page selectors / client-rendered classes:

- `#app`
- `article.ppam-card`
- `.price-pill`
- `.footer-title`
- `.footer-loc`
- `.page-num`

Actual TEDUH JSON fields handled by the Dart service:

- `id` -> `source_id`
- `name` -> `project_name`
- `location` -> `state`, `district`, `raw_location`
- `scheme_name`, `scheme_logo_url`, or ID prefix -> `scheme`
- `price_text`, `units.price_start`, `units.price_from_text` -> `price_min`, `price_max`
- `units.house_type`, `units.unit_type` -> `property_type`, `unit_types`
- `status` -> `project_status`
- `developer.name` -> `developer_name`
- `developer.full_address` -> `developer_address`
- `address`
- `latitude`
- `longitude`
- `total_unit` -> `total_units`
- `baki_unit` -> `available_units`
- `web_url` -> `external_project_url`
- source metadata and `retrieved_at`

Missing TEDUH values are stored as `null` rather than fabricated.

## 5. Government Area Data Flow

The Dart `OpenDataService` migrates the existing district datasets into Flutter/Dart:

- `population_district`
- `hh_income_district`
- `schools_district`
- `crime_district`

```text
data.gov.my / OpenDOSM
  -> package:http
  -> JSON or CSV response
  -> Dart cleaning and district matching
  -> AreaProfile model
  -> Supabase area_profiles table
  -> Area Analytics
```

The service normalizes state/district names, handles numeric conversion, keeps data years, and preserves source URLs.

## 6. Supabase Tables

### `area_profiles`

Used by Area Analytics. Important columns:

- `area_id`
- `state`
- `district`
- `population`
- `population_year`
- `median_household_income`
- `income_year`
- `crime_count`
- `crime_year`
- `education_institution_count`
- `education_year`
- `transport_stop_count`
- `transport_year`
- `data_year`
- `source`
- `source_url`
- `retrieved_at`

Duplicate handling uses `area_id`.

### `properties`

Used by Property Search and Property Detail. Important columns:

- `source_id`
- `project_name`
- `state`
- `district`
- `scheme`
- `price_min`
- `price_max`
- `property_type`
- `project_status`
- `developer_name`
- `address`
- `latitude`
- `longitude`
- `total_units`
- `available_units`
- `unit_types`
- `source`
- `source_url`
- `external_project_url`
- `developer_address`
- `raw_location`
- `retrieved_at`

Duplicate handling uses `source_id`.

### `data_sources`

Reserved for source metadata. It is kept simple and readable by the app.

## 7. Visible App Integration

- Property Search reads the central app state, which prefers Supabase `properties` and falls back to processed/local JSON.
- Property Detail displays TEDUH source metadata, scheme, developer, price range, unit counts, coordinates, source URL, and retrieved date when available.
- Area Analytics reads the central app state, which prefers Supabase `area_profiles` and falls back to processed/local JSON.
- Refresh buttons in Search and Analytics trigger explicit government-data synchronization. Crawling is not run inside widget `build()`.

## 8. Fallback Behavior

- If TEDUH is unavailable, the app continues to show previously stored Supabase properties or retained local fallback data.
- If data.gov.my or OpenDOSM is unavailable, the app continues to show previously stored Supabase area profiles or retained local fallback data.
- If Supabase is unavailable or not configured, the app starts with local JSON fallback data and shows a clear sync message.

## 9. Structured Code Walkthrough

Recommended final walkthrough order:

1. Show TEDUH website.
2. Show `TeduhService`.
3. Explain `package:http`.
4. Explain `package:html`.
5. Show `Property.fromTeduhJson` and `Property.toSupabaseJson`.
6. Show Supabase `properties` table.
7. Show `PropertyRepository`.
8. Show Property Search.
9. Open Property Detail.
10. Show `OpenDataService`.
11. Show `AreaProfileRepository`.
12. Show Supabase `area_profiles` table.
13. Show Area Analytics.

## 10. Key Explanation: Why Use package:html?

The Web API practical taught `package:http` for retrieving data. TEDUH returns an HTML app shell for the `/projek` page, so `package:html` is used to parse the returned HTML DOM and verify/select public project-card structures when they are present. The current live page then loads project data through a public JSON endpoint, so the Dart service also uses that endpoint for reliable project records and pagination.

## 11. Verification Checklist

Before final presentation:

- Run `flutter pub get`.
- Run `flutter analyze`.
- Run `flutter test`.
- Run the app normally with `flutter run`.
- Confirm Supabase initializes.
- Confirm `area_profiles` can be read.
- Press refresh and confirm TEDUH projects are fetched.
- Confirm TEDUH records sync to `properties` without duplicates.
- Confirm Property Search shows TEDUH/Supabase records.
- Confirm Property Detail opens and shows source metadata.
- Confirm Area Analytics shows Supabase area data.
- Confirm local fallback still works when Supabase is not configured.

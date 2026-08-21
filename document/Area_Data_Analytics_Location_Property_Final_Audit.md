# Smart Property Advisor / PandaGuru - Final Audit

Audit date: 2026-08-21

Scope: Area Data Analytics + Location & Property Information

This audit is reporting-only. The current codebase is treated as the source of truth. The available documentation reviewed was `README.md` and `document/Area_Data_Analytics_Location_Property_Information_Module.md`. No standalone BMIT2073 assignment/practical files were found in this repository.

## 1. Executive Summary

The module is MOSTLY READY for a fallback-data demo and partially ready for a live Supabase/government-data demo.

Implemented in code:

- Dart services now fetch TEDUH and Malaysian government datasets from Flutter code.
- The old Python crawler/import workflow files are deleted from the working tree.
- Processed JSON fallback data is bundled and automatically used when Supabase is unavailable or not configured.
- Property Search, Property Detail, Area Analytics, and the Map screen consume central `AppState` data.
- Supabase table access exists for `area_profiles` and `properties`, using `select()` and `upsert()`.
- `flutter analyze` and `flutter test` both pass.

Main gaps:

- Supabase URL and publishable key are placeholders, so live Supabase sync is currently disabled.
- OpenStreetMap is not implemented; the map is an offline normalized custom-painted preview.
- `data_sources` exists in migration SQL but is not used by app repositories.
- Nearby schools, hospitals, public transport, and facility radius search are not real location queries.
- Area analytics still mixes official indicators with fallback/demo market, transport, hospital, and price-series values.
- There are no module-specific service/repository tests.

## 2. Full Important File Inventory

| File | Purpose | Module | Status / Notes |
|---|---|---|---|
| `README.md` | Describes app purpose, Dart data flow, Supabase config, and fallback behavior. | Documentation | Updated for Dart migration. |
| `pubspec.yaml` | Defines dependencies and bundled JSON assets. | Shared / App Foundation | Uses `http`, `html`, `supabase_flutter`; no map package. |
| `analysis_options.yaml` | Flutter lint configuration. | Shared / App Foundation | Standard lint setup. |
| `lib/main.dart` | Initializes Flutter and Supabase when config is set. | Shared / App Foundation; Database / Infrastructure | Uses constants, not `String.fromEnvironment`. |
| `lib/core/config/supabase_config.dart` | Stores Supabase URL/key constants and configured check. | Database / Infrastructure | Placeholder values; live Supabase disabled. |
| `lib/services/supabase_connection_verifier.dart` | Debug helper to verify first `area_profiles` row. | Database / Infrastructure | Runs only in debug when Supabase configured. |
| `lib/app/app_state.dart` | Central app state, fallback loading, cloud loading, and government-data refresh. | Shared / App Foundation; MY MODULE; Smart Recommendation / Comparison | Important integration layer. |
| `lib/app/app_scope.dart` | Inherited notifier exposing `AppState`. | Shared / App Foundation | Implemented. |
| `lib/app/app_shell.dart` | Main navigation shell for Home/Search/Map/Advisor/Analysis/Profile. | Shared / App Foundation | Implemented. |
| `lib/app/smart_property_advisor_app.dart` | Root widget and app initialization flow. | Shared / App Foundation | Implemented. |
| `lib/services/teduh_service.dart` | Fetches, parses, cleans, and dedupes TEDUH project records. | Area Data Analytics + Location & Property Information - MY MODULE | Implemented Dart replacement for TEDUH crawler. |
| `lib/services/open_data_service.dart` | Fetches population, income, schools, and crime district datasets. | Area Data Analytics + Location & Property Information - MY MODULE | Implemented Dart replacement for open-data crawler. |
| `lib/services/recommendation_service.dart` | Deterministic weighted recommendation scoring. | Smart Recommendation / Comparison | Other member/module. |
| `lib/models/property.dart` | Property model for local JSON, TEDUH, and Supabase serialization. | MY MODULE; Smart Recommendation / Comparison | Implemented; many TEDUH fields nullable. |
| `lib/models/area_profile.dart` | Supabase/open-data area profile model. | Area Data Analytics + Location & Property Information - MY MODULE | Implemented. |
| `lib/models/area_data.dart` | UI-facing area model with computed scores and fallback merging. | MY MODULE; Market Trend / Analytics; Smart Recommendation / Comparison | Mixes government values with demo fallback values. |
| `lib/models/recommendation.dart` | Recommendation result/factor model. | Smart Recommendation / Comparison | Other module. |
| `lib/models/user_preferences.dart` | User preference model for advisor scoring. | Smart Recommendation / Comparison; User Management | Other/shared. |
| `lib/models/app_user.dart` | Demo user profile model. | User Management | Other module. |
| `lib/data/asset_repository.dart` | Loads local sample and processed fallback JSON assets. | MY MODULE; Shared / App Foundation | Automatic fallback loader. |
| `lib/data/repositories/property_repository.dart` | Reads/upserts Supabase `properties`. | Area Data Analytics + Location & Property Information - MY MODULE | Uses `select()` and `upsert(... onConflict: source_id)`. |
| `lib/data/repositories/area_profile_repository.dart` | Reads/upserts Supabase `area_profiles`. | Area Data Analytics + Location & Property Information - MY MODULE | Uses `select()` and `upsert(... onConflict: area_id)`. |
| `lib/features/search/property_search_screen.dart` | Search/filter UI for properties and refresh button. | Area Data Analytics + Location & Property Information - MY MODULE | Implemented; can show local, processed, or Supabase properties. |
| `lib/features/search/property_detail_screen.dart` | Detail UI for listing/TEDUH facts, area signals, and source metadata. | Area Data Analytics + Location & Property Information - MY MODULE; Smart Recommendation / Comparison | Implemented; nearby facilities are not live facility queries. |
| `lib/features/map/property_map_screen.dart` | Offline custom map preview with coordinate-normalized pins. | Area Data Analytics + Location & Property Information - MY MODULE | Placeholder/partial map, not OSM. |
| `lib/features/analysis/analysis_screen.dart` | Area analytics UI, source modal, refresh button, comparison view. | Area Data Analytics + Location & Property Information - MY MODULE; Market Trend / Analytics | Implemented; some metrics remain demo fallback. |
| `lib/features/home/home_screen.dart` | Home hub, market snapshot, featured properties, area cards. | Shared / App Foundation; MY MODULE | Uses state lists but contains hard-coded market snapshot text/values. |
| `lib/features/advisor/advisor_screen.dart` | Preference UI and ranked recommendation list. | Smart Recommendation / Comparison | Other module; consumes property/area data. |
| `lib/features/advisor/comparison_screen.dart` | Compares recommended properties. | Smart Recommendation / Comparison | Other module; consumes area signals. |
| `lib/features/auth/login_screen.dart` | Demo login/sample mode. | User Management | Other module; no real auth backend. |
| `lib/features/auth/register_screen.dart` | Demo registration UI. | User Management | Other module. |
| `lib/features/auth/reset_password_screen.dart` | Demo reset password UI. | User Management | Other module. |
| `lib/features/profile/profile_screen.dart` | Demo profile/settings/favourites. | User Management | Other module; uses property cards. |
| `lib/core/widgets/*.dart` | Shared UI widgets, charts, cards, branding, formatters. | Shared / App Foundation | Implemented. |
| `assets/data/areas.json` | Local sample area dataset. | MY MODULE; Local/Fallback Data | Bundled asset; 6 records. |
| `assets/data/properties.json` | Local sample property dataset. | MY MODULE; Local/Fallback Data | Bundled asset; 10 records. |
| `data/processed/area_profiles.json` | Processed government area fallback data. | MY MODULE; Local/Fallback Data | Bundled asset; 5 records. |
| `data/processed/teduh_projects.json` | Processed TEDUH fallback data. | MY MODULE; Local/Fallback Data | Bundled asset; 103 records. |
| `supabase/migrations/202608190001_create_area_profiles.sql` | Creates initial `area_profiles` table and test seed. | Database / Infrastructure; MY MODULE | Relevant migration. |
| `supabase/migrations/202608200001_extend_area_profiles_and_create_properties.sql` | Extends area profiles and creates `properties`. | Database / Infrastructure; MY MODULE | Relevant migration. |
| `supabase/migrations/202608210001_flutter_dart_data_sync.sql` | Adds sync columns, `data_sources`, and client insert/update RLS. | Database / Infrastructure; MY MODULE | New untracked migration. |
| `android/app/src/main/AndroidManifest.xml` | Android app manifest and permissions. | Shared / App Foundation | Internet permission is present. |
| `test/widget_test.dart` | Smoke test for sign-in screen. | Testing | Passes; not module-specific. |
| `web/`, `ios/`, `macos/`, `linux/`, `windows/` | Flutter platform shells. | Shared / App Foundation | Mostly generated/boilerplate; not audited as module logic. |

## 3. My Module File Inventory

| Group | File | What it does | What to say in walkthrough |
|---|---|---|---|
| Models | `lib/models/property.dart` | Represents sample and TEDUH properties; converts TEDUH/Supabase fields into UI fields. | "This model lets TEDUH records become normal app property records without inventing missing values." |
| Models | `lib/models/area_profile.dart` | Represents official district indicators from government datasets and Supabase. | "This is the clean storage model for population, income, crime, education, source URL, and retrieved timestamp." |
| Models | `lib/models/area_data.dart` | Converts `AreaProfile` into UI metrics and fills missing UI-only fields from fallback data. | "This adapts official data into dashboard cards while keeping demo-only values available." |
| Services | `lib/services/teduh_service.dart` | Uses Dart `http` and light `html` parsing to fetch TEDUH project records. | "The old external TEDUH crawler is now inside Flutter/Dart as `TeduhService`." |
| Services | `lib/services/open_data_service.dart` | Fetches OpenDOSM/data.gov.my district population, income, school, and crime data. | "This service collects Malaysian government district indicators directly from Dart." |
| Repositories | `lib/data/repositories/property_repository.dart` | Reads and upserts Supabase `properties`. | "This is where TEDUH records are synchronized to Supabase using `source_id` to prevent duplicates." |
| Repositories | `lib/data/repositories/area_profile_repository.dart` | Reads and upserts Supabase `area_profiles`. | "This syncs official area profiles by stable `area_id`." |
| Local/Fallback Data | `lib/data/asset_repository.dart` | Loads bundled local and processed JSON fallback files. | "The app remains demo-stable even if Supabase or government APIs are unavailable." |
| State Management | `lib/app/app_state.dart` | Orchestrates loading local data, cloud data, processed fallback data, and refresh/sync. | "AppState decides which data source is visible and triggers the government data refresh." |
| Screens/UI | `lib/features/search/property_search_screen.dart` | Displays property search/filter results and government refresh action. | "Search shows Supabase TEDUH data when available, otherwise processed/local fallback." |
| Screens/UI | `lib/features/search/property_detail_screen.dart` | Shows property facts, TEDUH source metadata, area profile, and coordinates. | "Detail proves source transparency with source URL and retrieved timestamp." |
| Screens/UI | `lib/features/map/property_map_screen.dart` | Shows a normalized offline map canvas with pins for records that have coordinates. | "This is a reliable demo map, not yet OpenStreetMap." |
| Screens/UI | `lib/features/analysis/analysis_screen.dart` | Shows area metrics, source modal, charts, and district comparison. | "Area Analytics displays government-derived indicators plus fallback market snapshot data." |
| Supabase | `supabase/migrations/*.sql` | Defines `area_profiles`, `properties`, `data_sources`, and RLS policies. | "These migrations create the module tables and allow client-safe demo sync." |
| Configuration | `lib/core/config/supabase_config.dart` | Stores Supabase URL and key constants. | "This must be configured before live Supabase sync works." |
| Configuration | `pubspec.yaml` | Declares `http`, `html`, `supabase_flutter`, and JSON assets. | "The module uses Flutter dependencies instead of Python runtime tools." |
| Tests | `test/widget_test.dart` | Smoke test only. | "The app has a basic UI test, but the data services still need targeted tests." |
| Documentation | `document/Area_Data_Analytics_Location_Property_Information_Module.md` | Current module documentation. | "This explains scope, data flow, Supabase tables, and presentation order." |

## 4. Current Architecture

```text
TEDUH `/projek`, `/api/portal/projects`, `/api/portal/projects/filters`
data.gov.my / OpenDOSM datasets
        |
        v
`TeduhService` / `OpenDataService`
        |
        v
`Property.fromTeduhJson` / `AreaProfile.fromJson`
        |
        v
`PropertyRepository` / `AreaProfileRepository`
        |
        v
Supabase tables: `properties`, `area_profiles`
        |
        v
`AppState`
        |
        v
Search, Detail, Map, Analysis, Home, Advisor

Fallback path:
`AssetRepository` -> `assets/data/*.json` and `data/processed/*.json` -> `AppState` -> UI
```

## 5. TEDUH Audit

- Access method: Dart `http.Client.get()`.
- HTML usage: `package:html/parser.dart` is imported and used to parse `/projek`. The service checks for `#app` and looks for `article.ppam-card` cards. In the current flow, this is a light fallback/shell check, not the main data path.
- JSON/API endpoint: `https://teduh.kpkt.gov.my/api/portal/projects`.
- Filters endpoint: `https://teduh.kpkt.gov.my/api/portal/projects/filters`.
- Page endpoint: `https://teduh.kpkt.gov.my/projek?source=Perumahan+Awam`.
- Pagination: `_fetchProjectPages()` sends `page`, reads `last_page`, stops at `maxRecords`, empty data, `last_page`, or page 50.
- Sampling: by default, `fetchProjects()` loops target states and requests up to `maxPerState`.
- Cleaning: trims empty/`-`/`n/a`/`null`, title-cases state/district, parses numbers, validates coordinates, maps scheme prefixes/logo names, collects unit types, and creates source metadata.
- Duplicate handling: `_dedupe()` uses `sourceId` when present, otherwise property name.
- Fields populated: `source_id`, `project_name`, `state`, `district`, `scheme`, prices, property type, status, developer, address, source/source URL, retrieved time, latitude/longitude, units, unit types, external URL, developer address, raw location.
- Nullable fields: district, scheme, prices, status, developer, address, coordinates, unit counts, external URL, developer address, raw location.
- Supabase path: `AppState.refreshGovernmentData()` fetches TEDUH, then `PropertyRepository.upsertProperties()` writes to `properties` with `onConflict: source_id`.
- UI path: `PropertyRepository.getProperties()` and `AssetRepository.loadProcessedTeduhProjects()` map TEDUH rows to `Property`; `PropertySearchScreen`, `PropertyDetailScreen`, and `PropertyMapScreen` consume `AppState.properties`.
- TEDUH unavailable: during refresh, the error is caught and shown in `governmentDataSyncMessage`; existing visible data remains. At startup, TEDUH is not fetched live; Supabase or processed/local fallback is used.
- `html` dependency status: genuinely used, but narrowly. It is not a full HTML scraping pipeline in the normal path.

## 6. Government Open Data Audit

| Dataset | Implemented? | Source | Data Retrieved | Used in UI? | Stored in Supabase? |
|---|---|---|---|---|---|
| `population_district` | Yes | `https://storage.dosm.gov.my/population/population_district.csv` | Latest overall/both population, multiplied by 1000 | Yes, population cards/table/detail area profile | Yes, `area_profiles.population`, `population_year` |
| `hh_income_district` | Yes | `https://api.data.gov.my/data-catalogue?id=hh_income_district` | `income_median` for target state/district | Yes, median household income | Yes, `median_household_income`, `income_year` |
| `schools_district` | Yes | `https://api.data.gov.my/data-catalogue?id=schools_district` | School count summed from latest matched rows | Yes, education count and infrastructure score | Yes, `education_institution_count`, `education_year` |
| `crime_district` | Yes | `https://storage.data.gov.my/publicsafety/crime_district.csv` | Latest `type=all` crime count with selected police-district aliases | Yes, transformed into normalized safety score; raw count not prominently shown | Yes, `crime_count`, `crime_year` |

Planned or mentioned but not currently implemented:

- OpenStreetMap live tiles: mentioned as future Practical 12 direction; not implemented.
- GTFS/public transport stop dataset: present in previous documentation/history, but current code sets transport stop count to null.
- Hospital/health facilities: visible as fallback/sample `hospitals` value only; no government hospital dataset is implemented.
- Nearby schools/facilities around a selected property: screen labels exist, but no radius-based API or facility lookup exists.
- Flood, internet/digital connectivity, and administrative boundary data: not implemented in code and not clearly required by the current module document.

## 7. Supabase Audit

- Initialization: `main.dart` calls `Supabase.initialize(url: SupabaseConfig.url, publishableKey: SupabaseConfig.publishableKey)` only when `SupabaseConfig.isConfigured` is true.
- URL/key definition: `lib/core/config/supabase_config.dart`.
- Current values: placeholders, not real configured values.
- `String.fromEnvironment`: removed from current source; `rg` found no active use.
- `--dart-define`: no longer required by current code. Configuration now requires editing constants.
- Tables used by app code: `area_profiles`, `properties`.
- Table present in migration but unused by app code: `data_sources`.
- `select()` calls: `AreaProfileRepository.getAreaProfiles()`, `PropertyRepository.getProperties()`.
- `insert()` calls: none directly in Dart.
- `update()` calls: none directly in Dart.
- `upsert()` calls: area profiles and properties.
- `onConflict`: `area_id` for `area_profiles`, `source_id` for `properties`.

Migration summary:

- `202608190001_create_area_profiles.sql`: creates `area_profiles`, enables RLS, adds public read policy, inserts one test row.
- `202608200001_extend_area_profiles_and_create_properties.sql`: adds source/year columns, removes the test seed, creates `properties`, enables public read policy.
- `202608210001_flutter_dart_data_sync.sql`: adds update/status/detail columns, creates `data_sources`, and adds anon/authenticated insert/update policies for TEDUH properties and government area profiles.

## 8. API Key / Configuration Audit

| Integration | Implemented in Code? | Requires Key? | Key Configured? | Current Status |
|---|---:|---:|---:|---|
| Supabase URL | Yes | Yes | No | Placeholder `MY_SUPABASE_URL`; live cloud disabled. |
| Supabase publishable/anon key | Yes | Yes | No | Placeholder `MY_SUPABASE_PUBLISHABLE_KEY`; no secret exposed. |
| TEDUH | Yes | No key in code | Not applicable | Implemented keyless public access. |
| data.gov.my | Yes | No key in code | Not applicable | Implemented keyless catalogue access. |
| OpenDOSM | Yes | No key in code | Not applicable | Implemented keyless CSV/source access. |
| OpenStreetMap | No | Usually no key for public tiles, depending provider | Not applicable | Mentioned as future; not implemented. |
| Google Maps | No | Yes | No | Mentioned only as possible future replacement in map info text. |
| Google Places | No | Yes | No | Not implemented. |
| Google Geocoding | No | Yes | No | Not implemented. |
| Google Distance Matrix | No | Yes | No | Not implemented. |
| OpenRouteService | No | Yes | No | Not implemented. |
| Gemini/OpenAI/Claude/other AI API | No | Yes | No | Not implemented; advisor states no generative AI service is used. |

## 9. Map / Location Audit

Status: PARTIALLY IMPLEMENTED / PLACEHOLDER.

- Real OpenStreetMap widget: not implemented.
- `flutter_map`: not installed.
- OpenStreetMap tiles: not used.
- Google Maps: not used.
- Static/offline map: yes, a `CustomPainter` offline map canvas.
- Mock map: yes, normalized preview.
- Property latitude/longitude connected: partially. Records with coordinates are selected and normalized into canvas pin positions. Coordinates do not drive real geographic map tiles.
- Records without coordinates: omitted from pins, with visible message.

## 10. UI Integration Audit

| Screen | Data Source | Real Data / Fallback / Mock | Status |
|---|---|---|---|
| Home | `AppState.properties`, `AppState.areas`, plus hard-coded snapshot cards | Mixed: state data plus hard-coded sample market metrics | Partially real; copy still says local sample data. |
| Property Search | `AppState.properties`; refresh calls `AppState.refreshGovernmentData()` | Supabase TEDUH, processed TEDUH JSON, and local sample fallback | Implemented. |
| Property Detail | Selected `Property` plus `AreaData` | TEDUH metadata when government record; fallback area signals when missing | Implemented with mixed data. |
| Area Analytics | `AppState.areas`; refresh calls government sync | Supabase/processed area profiles plus fallback market values | Implemented, but not fully official-data-only. |
| Map | `AppState.properties` and `AreaData` | Offline normalized pins and sample/fallback facility numbers | Placeholder/partial. |
| Advisor/Comparison | `AppState.recommendations`, `Property`, `AreaData` | Deterministic scoring from available data | Other module consuming this module data. |

## 11. Fallback / Local Data Audit

Bundled Flutter assets:

- `assets/data/areas.json`: 6 local sample area records.
- `assets/data/properties.json`: 10 local sample property records.
- `data/processed/area_profiles.json`: 5 processed government area records.
- `data/processed/teduh_projects.json`: 103 processed TEDUH project records.

Development/old processed files deleted from current working tree:

- `data/processed/area_profiles.csv`
- `data/processed/data_sources.json`
- `data/processed/teduh_data_source.json`
- `data/processed/teduh_projects.csv`

Fallback behavior:

- Startup loads local areas/properties first.
- If Supabase is configured and returns area profiles, those override/enrich areas.
- If Supabase area profiles are empty/unavailable, processed area profiles are used.
- If Supabase properties are available, they are merged before local properties.
- If Supabase properties are empty/unavailable, processed TEDUH properties are merged before local properties.
- If Supabase is not configured, refresh is blocked with a clear message.
- If government APIs fail during refresh, an error message is stored and visible data remains whatever was already loaded.

## 12. Implemented Features

| Feature | Relevant files | Data source | Supabase involvement | Visible screen | Status |
|---|---|---|---|---|---|
| TEDUH Dart data collection | `teduh_service.dart`, `property.dart` | TEDUH JSON endpoint | Upsert to `properties` | Search/Detail/Map | Implemented, config-dependent for sync. |
| Government area data collection | `open_data_service.dart`, `area_profile.dart` | data.gov.my/OpenDOSM | Upsert to `area_profiles` | Analysis/Detail/Home | Implemented for 4 datasets. |
| Processed fallback data | `asset_repository.dart`, `pubspec.yaml`, JSON files | Local bundled JSON | None | Search/Analysis/Detail/Map/Home | Implemented. |
| Property search/filtering | `property_search_screen.dart` | AppState merged properties | Reads cloud if configured | Search | Implemented. |
| Property detail with source metadata | `property_detail_screen.dart` | Property/AreaData | Reads cloud/fallback | Detail | Implemented. |
| Area analytics | `analysis_screen.dart` | AreaData from cloud/processed/local | Reads/upserts area profiles | Analysis | Implemented with mixed fallback metrics. |
| Manual refresh/sync | `app_state.dart`, Search/Analysis screens | TEDUH + government APIs | Upserts both tables | Search/Analysis snackbars | Implemented but disabled until Supabase configured. |
| Coordinate pin preview | `property_map_screen.dart` | Property lat/long | Reads cloud/fallback | Map | Partially implemented; offline map only. |
| Supabase migrations | `supabase/migrations/*.sql` | Database schema | Creates policies/tables | Backend | Implemented locally; not applied by audit. |

## 13. Missing / Incomplete Features

| Priority | Missing / incomplete item | Why it matters | Related requirement/source | Partial implementation | Suggested next action |
|---|---|---|---|---|---|
| CRITICAL | Supabase constants are placeholders | Live sync and cloud read/write will not work | Practical 11 / current README | Fallback mode works | Configure client-safe Supabase URL/key and apply migrations. |
| CRITICAL if required by lecturer | Real OpenStreetMap integration | Practical 12 alignment expects OSM-style implementation | Module doc says current map is offline and OSM would be later | Offline map with pins | Add `flutter_map`/`latlong2` and OSM tile layer if Practical 12 must be demonstrated. |
| RECOMMENDED | `data_sources` app usage | Source metadata table exists but app never reads/writes it | Supabase migration and module transparency | Source/source URL stored on records | Add repository/upsert for data source metadata if needed. |
| RECOMMENDED | Real nearby facilities | Map/detail labels suggest nearby facilities | Location & Property Information scope | Uses sample `facilities`, area school/hospital counts | Implement facility dataset or OSM/Overpass-style lookup later. |
| RECOMMENDED | Public transport data | Transport score/count remains fallback/null | Older docs/history mention GTFS; current model has transport fields | `transport_stop_count` exists but null | Add GTFS/public transport ingestion if required. |
| RECOMMENDED | Hospital/health facility dataset | UI displays hospital count but it is fallback-only | Location/facility expectations | `hospitals` from local JSON fallback | Add official health facility source or label as sample. |
| RECOMMENDED | Module-specific tests | Data parsing/sync risks are untested | Data management quality | Only sign-in smoke test exists | Add tests for TEDUH parsing, open-data parsing, fallback loading, repository mapping. |
| RECOMMENDED | Raw crime display | Crime is stored but only converted into safety score | Area analytics transparency | Safety score shown | Add source-backed crime count display if desired. |
| RECOMMENDED | Home consistency | Home has hard-coded market snapshot and local-sample copy | UI accuracy | Uses state for lists | Update copy/metrics after data mode is finalized. |
| OPTIONAL | Flood/internet/boundary datasets | Could enrich SDG/location analysis | Not active in current code/doc | None | Only add if assignment scope expands. |

## 14. Specific Missing-Area Checklist

| Area | Actual Status |
|---|---|
| Real OpenStreetMap integration | Not implemented. |
| Property markers using latitude/longitude | Partially implemented on offline normalized map. |
| Nearby facilities | Mock/sample chips and area counts only. |
| Schools around selected property | Not implemented; district school count only. |
| Hospitals around selected property | Not implemented; local fallback hospital count only. |
| Public transport information | Fallback transport score; `transport_stop_count` null in open-data flow. |
| District comparison | Implemented in Area Analytics using available `AreaData`. |
| Area charts | Implemented using sample/fallback `priceHistory`, not official open data. |
| Population display | Implemented. |
| Household income display | Implemented. |
| Crime display | Stored/used as safety score; raw count not prominent. |
| Education institution display | Implemented. |
| TEDUH source attribution | Implemented. |
| Source URL in Property Detail | Implemented when available. |
| Last updated/retrieved timestamp | Implemented when available. |
| Data source metadata | Record-level metadata implemented; `data_sources` table unused. |
| Manual data refresh | Implemented in Search and Analysis. |
| Supabase synchronization | Implemented in code but disabled until config is set. |
| Supabase fallback | Implemented. |
| Error/loading states | Implemented at app loading and sync-message level; could be more granular. |

## 15. Data Management Assessment

Rating: ADEQUATE.

Evidence:

- Good: clear models, data cleaning, null handling, coordinate validation, dedupe by source ID, Supabase upserts, processed fallback, source URLs, retrieved timestamps.
- Good: external data fetch is not done inside widget `build()`.
- Weak: live Supabase is currently unconfigured.
- Weak: no targeted tests for parsing or repository behavior.
- Weak: `data_sources` table is not integrated.
- Weak: area analytics mixes official and sample-derived metrics, which must be explained during presentation.

## 16. BMIT2073 Practical Alignment

| BMIT2073 Practical | Current Project Usage | Files | Status |
|---|---|---|---|
| Practical 8 - Data File | Bundled JSON assets and processed fallback data | `pubspec.yaml`, `AssetRepository`, `assets/data/*.json`, `data/processed/*.json` | Implemented. |
| Practical 10 - Web API | Dart `http.get()` calls to TEDUH, data.gov.my, OpenDOSM/CSV URLs | `TeduhService`, `OpenDataService` | Implemented. |
| Practical 11 - Supabase | Initialize Supabase, select, upsert, migrations/RLS | `main.dart`, `SupabaseConfig`, repositories, migrations | Code implemented; runtime config missing. |
| Practical 12 - OpenStreetMap | Current map is offline preview; docs mention OSM as future replacement | `PropertyMapScreen`, module doc | Not implemented for real OSM. |

## 17. Recent Added / Modified / Removed Changes

Based on `git status`, `git diff --stat`, and `git show HEAD`.

ADDED:

- `lib/services/open_data_service.dart`
- `lib/services/teduh_service.dart`
- `supabase/migrations/202608210001_flutter_dart_data_sync.sql`
- `http` and `html` dependencies in `pubspec.yaml`

MODIFIED:

- `README.md`
- `document/Area_Data_Analytics_Location_Property_Information_Module.md`
- `android/app/src/main/AndroidManifest.xml` adds Internet permission.
- `lib/main.dart`
- `lib/core/config/supabase_config.dart`
- `lib/app/app_state.dart`
- `lib/models/property.dart`
- `lib/models/area_profile.dart`
- `lib/data/repositories/property_repository.dart`
- `lib/data/repositories/area_profile_repository.dart`
- `lib/features/search/property_search_screen.dart`
- `lib/features/search/property_detail_screen.dart`
- `lib/features/analysis/analysis_screen.dart`
- `pubspec.lock`

REMOVED from working tree:

- `tool/import_supabase_data.py`
- `tool/open_data_crawler.py`
- `tool/teduh_crawler.py`
- `data/processed/area_profiles.csv`
- `data/processed/data_sources.json`
- `data/processed/teduh_data_source.json`
- `data/processed/teduh_projects.csv`

Unable to confirm from current git history:

- Whether migrations have been applied to the remote Supabase project.
- Whether current processed JSON was generated by the deleted Python tools or another process before this audit.

## 18. Dead / Duplicate / Obsolete Code Findings

| Finding | Status |
|---|---|
| Deleted Python crawler/import files are still tracked as deletions in git status. | SAFE TO REVIEW LATER. |
| Deleted processed CSV/source JSON files are still tracked as deletions. | SAFE TO REVIEW LATER. |
| `data_sources` table exists in migration but no Dart repository reads/writes it. | POTENTIAL PROBLEM. |
| `html` dependency is used only for light TEDUH HTML parsing/fallback. | SAFE TO REVIEW LATER. |
| Home screen copy says property/location tools use local sample data even when processed/Supabase data can be active. | POTENTIAL PROBLEM. |
| Area `hospitals`, market price, rental yield, connectivity, and transport values can remain fallback/demo values after government profile conversion. | POTENTIAL PROBLEM. |
| `openDataLoadMessage` is set on repository failure but not prominently displayed in major screens. | SAFE TO REVIEW LATER. |
| No Firebase references found. | No issue. |
| No Google Maps/Places/geocoding packages or keys found. | No issue unless those were expected. |

## 19. Final Module Readiness

Module:
Area Data Analytics + Location & Property Information

Overall:
MOSTLY READY

Implemented:

- Dart-based TEDUH retrieval and cleaning.
- Dart-based government open-data retrieval for population, income, schools, and crime.
- Supabase repositories and migrations for `properties` and `area_profiles`.
- Local/processed JSON fallback.
- Property Search, Property Detail, Area Analytics, and offline Map screens.
- Source URL and retrieved timestamp display where available.

Still Required:

- Configure Supabase URL and publishable key.
- Apply/confirm Supabase migrations in the real Supabase project.
- Decide whether Practical 12 requires real OpenStreetMap implementation.

Recommended Improvements:

- Add app integration for `data_sources`.
- Add service/repository tests.
- Clarify sample versus official metrics in Home/Analysis/Map.
- Add real nearby facility/transport datasets if presentation scope requires them.

Optional Improvements:

- Flood, internet/connectivity, hospital, and boundary datasets.
- More granular sync/loading UI.

API / Configuration Still Needed:

- Supabase URL: missing/placeholder.
- Supabase publishable key: missing/placeholder.
- No TEDUH/data.gov.my/OpenDOSM keys needed.

Database Setup Still Needed:

- Confirm migrations have been applied remotely.
- Confirm `properties`, `area_profiles`, and RLS policies exist in Supabase.
- Decide whether to populate/use `data_sources`.

Runtime Testing Still Needed:

- Run app with real Supabase config.
- Press refresh and confirm upserts.
- Confirm Search/Detail/Analysis display Supabase rows.
- Confirm fallback still works when Supabase is not configured.

Presentation Points I Should Understand:

- The module changed from Python preprocessing to Flutter/Dart services.
- TEDUH data is fetched from a public JSON endpoint, not only HTML scraping.
- The app keeps fallback JSON for demo stability.
- Supabase sync is implemented but currently blocked by placeholder config.
- Map is an offline coordinate preview, not OpenStreetMap.

## 20. Priority Action Checklist

PRIORITY 1 - Must do before final demo

- [ ] Configure Supabase URL and client-safe publishable key.
- [ ] Apply/verify Supabase migrations in the remote project.
- [ ] Run the app and confirm government refresh upserts records.
- [ ] Decide whether live OpenStreetMap is mandatory for Practical 12.
- [ ] Prepare to explain that current map is offline normalized preview.

PRIORITY 2 - Should do

- [ ] Add/verify `data_sources` repository usage or explain it as reserved.
- [ ] Add module-specific tests for TEDUH/open-data parsing and fallback loading.
- [ ] Make UI labels clearer where values are sample/fallback.
- [ ] Show raw crime count or explain the normalized safety conversion.

PRIORITY 3 - Optional

- [ ] Add nearby facilities by radius.
- [ ] Add public transport/GTFS data.
- [ ] Add hospital/health facility data.
- [ ] Add flood/connectivity/boundary datasets.

## 21. What I Can Say My Module Does

- "My module collects TEDUH public housing project data directly inside Flutter/Dart."
- "It fetches Malaysian government open data for population, household income, schools, and crime."
- "It cleans names, numbers, years, coordinates, and missing values before converting data into app models."
- "It synchronizes property data to Supabase `properties` and area data to `area_profiles`."
- "It keeps processed JSON fallback data so the demo still works when Supabase or external APIs are unavailable."
- "It powers Property Search, Property Detail, Area Analytics, and the location/map preview."
- "It shows source URLs and retrieved timestamps so users can understand where the information came from."
- "The recommendation module uses my property and area data, but it owns the final scoring logic."

## 22. Verification Results

`flutter analyze`

```text
Analyzing MobileApplication...
No issues found! (ran in 1.7s)
```

`flutter test`

```text
00:00 +0: loading C:/Users/Acer/Documents/GitHub/MobileApplication/test/widget_test.dart
00:00 +0: shows the sign in screen
00:01 +1: All tests passed!
```

## 23. No Code Modification Confirmation

No application code was modified by this audit. The only file created by this audit is this documentation file.

The working tree already contained uncommitted application-code changes before the report was written.

## 24. Commit / Push Confirmation

Nothing was committed.

Nothing was pushed.

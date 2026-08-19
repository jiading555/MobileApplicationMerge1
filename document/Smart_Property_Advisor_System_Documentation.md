# Smart Property Advisor System Documentation

## System Overview

Smart Property Advisor is a Flutter mobile app for SDG 9: Industry, Innovation and Infrastructure. The app turns Malaysian open government data into a property research and decision-support experience. Users can browse sample property records, inspect area indicators, compare infrastructure access, view market signals, save preferred properties, and generate transparent property matches from selected user preferences.

The app does not perform buying, renting, financing, legal valuation, or official property approval. Its role is to help users understand property areas using structured public data and a clear mobile interface.

## Main Features

- Property search by name, area, address, type, tenure, and budget.
- Property detail pages with price, size, tenure, address, nearby facilities, and area indicators.
- Offline map-style view for stable assignment demonstration.
- Area analytics using population, household income, education, crime, transport, and infrastructure signals.
- Preference-based advisor using deterministic weighted scoring.
- Property comparison table and score breakdown.
- Demo user account, profile editing, preferences, and saved properties.
- Open-data crawler for data.gov.my, OpenDOSM, and GTFS Static feeds.

## Architecture

The migrated architecture is adapted from `pandaGuru_Flutter_project` and simplified for this assignment.

```text
lib/
  app/
    app_scope.dart
    app_shell.dart
    app_state.dart
    smart_property_advisor_app.dart
  core/
    theme/
    utils/
    widgets/
  data/
    asset_repository.dart
  features/
    auth/
    home/
    search/
    map/
    advisor/
    analysis/
    profile/
  models/
  services/
assets/
  data/
tool/
  open_data_crawler.py
data/
  processed/
document/
```

`AppState` is the single application state holder. It loads local JSON assets through `AssetRepository`, stores the current demo user, keeps selected navigation state, tracks favourites, and exposes recommendations from `RecommendationService`. `AppScope` provides that state to screens through `InheritedNotifier`.

## Reused And Adapted Components

The source project provided a useful app shell, responsive navigation, property cards, asset repository, local models, auth/profile screens, map-style presentation, analytics screen, and advisor scoring service. These were migrated into `smart_property_advisor` and rebranded around the SDG 9 open-data property use case.

The following changes were made during adaptation:

- Replaced the broken Flutter counter starter with a six-section app shell.
- Changed app name and package metadata to Smart Property Advisor.
- Added local JSON assets to `pubspec.yaml`.
- Removed PandaGuru-specific docs and branding.
- Replaced the old mascot brand mark with an infrastructure mark.
- Updated the test to validate the migrated sign-in flow.
- Added a standard-library Python crawler under `tool/open_data_crawler.py`.
- Added `data/processed` as the crawler output location.

## Module Breakdown

| Module | Responsibility | Current code locations | Team member |
|---|---|---|---|
| Area, Location and Property Information | Property search, property details, nearby facilities, current area profile, source metadata, crawler-ready area data | `features/search`, `features/map`, `models/property.dart`, `models/area_data.dart`, `data/asset_repository.dart`, `tool/open_data_crawler.py` | To confirm |
| Market Trend and Analytics | District-level analytics, price history display, population and income signals, comparison dashboard | `features/analysis`, `core/widgets/line_chart.dart`, `core/widgets/metric_card.dart` | To confirm |
| Smart Advisor and Comparison | User preference input, deterministic scoring, ranked matches, transparent comparison | `features/advisor`, `services/recommendation_service.dart`, `models/recommendation.dart`, `models/user_preferences.dart` | To confirm |
| User Management | Demo login, registration, reset password, profile editing, favourites, preference summary | `features/auth`, `features/profile`, `models/app_user.dart`, `app/app_state.dart` | To confirm |
| Shared UI and App Foundation | App theme, responsive app shell, shared cards, formatting helpers, state scope | `app`, `core` | To confirm |

The existing project documentation suggests the likely individual module is Area, Location and Property Information, but the final team-member names should be confirmed before submission.

## Open Data Crawler

The crawler is located at:

```text
tool/open_data_crawler.py
```

It can fetch and clean district-level records from:

- `population_district`
- `hh_income_district`
- `schools_district`
- `crime_district`
- optional GTFS Static transport stops

Example command:

```powershell
python tool\open_data_crawler.py --target "Selangor,Gombak" --target "Selangor,Petaling" --output data\processed
```

Optional GTFS command:

```powershell
python tool\open_data_crawler.py --include-gtfs --gtfs-agency prasarana --gtfs-category rapid-rail-kl --output data\processed
```

Expected outputs:

```text
data/processed/area_profiles.json
data/processed/area_profiles.csv
data/processed/data_sources.json
data/processed/transport_stops.json
data/processed/transport_stops.csv
```

The JSON output is suitable for Flutter assets, Firebase Firestore imports, Supabase import scripts, or SQLite seed data.

## Recommended Database

Firebase is the best fit for this assignment because the app already has user-management screens, favourites, preferences, and data snapshots that map naturally to Firebase Authentication and Firestore. It also reduces backend setup compared with running a custom server.

Supabase/Postgres is a strong alternative if the team wants SQL queries, joins, geospatial extensions, or a more traditional relational schema. SQLite is useful for offline caching, but it is not enough by itself if the app needs shared user accounts or cloud-synced favourites.

## Firebase Setup Steps

1. Create a Firebase project in the Firebase Console.
2. Add an Android app using the package name from `android/app/build.gradle.kts`.
3. Download `google-services.json` and place it in `android/app`.
4. Add Firebase Authentication and enable Email/Password sign-in.
5. Create a Firestore database in production or test mode depending on the assignment deadline.
6. Install FlutterFire CLI if needed:

```powershell
dart pub global activate flutterfire_cli
flutterfire configure
```

7. Add Flutter dependencies:

```powershell
flutter pub add firebase_core firebase_auth cloud_firestore
```

8. Initialise Firebase in `main.dart` before `runApp`.
9. Replace the demo login/register methods in `AppState` with Firebase Auth calls.
10. Replace in-memory favourites and preferences with Firestore reads and writes.

## Firestore Collections

```text
users/{userId}
  name
  email
  phone
  createdAt
  updatedAt

users/{userId}/preferences/current
  goal
  budget
  preferredAreaId
  propertyType
  safetyPriority
  transportPriority
  facilitiesPriority

users/{userId}/favourites/{propertyId}
  propertyId
  savedAt

properties/{propertyId}
  name
  areaId
  address
  type
  tenure
  price
  bedrooms
  bathrooms
  sizeSqft
  latitude
  longitude
  source
  lastUpdated

areas/{areaId}
  state
  district
  population
  medianHouseholdIncome
  educationInstitutionCount
  crimeCount
  transportStopCount
  dataYear
  retrievedAt

recommendationHistory/{recordId}
  userId
  propertyId
  score
  factors
  createdAt

dataSources/{sourceId}
  datasetId
  name
  url
  retrievedAt
  license
```

## Supabase Alternative

Use Supabase if the team wants SQL and easier bulk import from crawler CSV files.

Suggested tables:

```text
profiles
properties
area_profiles
facilities
transport_stops
user_preferences
favourites
recommendation_history
data_sources
```

Setup steps:

1. Create a Supabase project.
2. Create the tables above using SQL Editor.
3. Enable Row Level Security.
4. Add policies so users can read public property/open-data tables and only update their own profile, preferences, favourites, and history.
5. Install Flutter dependencies:

```powershell
flutter pub add supabase_flutter
```

6. Initialise Supabase with the project URL and anon key.
7. Import crawler CSV files through Supabase Table Editor or a scripted import.

## SQLite Alternative

SQLite is recommended only for local caching or fully offline demos. It should store `properties`, `area_profiles`, `transport_stops`, and `data_sources`, while Firebase or Supabase handles authentication and user data.

Suggested Flutter package:

```powershell
flutter pub add sqflite path
```

## Data Source References

- data.gov.my Data Catalogue API: `https://api.data.gov.my/data-catalogue`
- OpenDOSM API: `https://api.data.gov.my/opendosm`
- Crime by district: `https://data.gov.my/data-catalogue/crime_district`
- Public education institutions: `https://data.gov.my/data-catalogue/schools_district`
- Population by district: `https://open.dosm.gov.my/data-catalogue/population_district`
- Household income by district: `https://open.dosm.gov.my/data-catalogue/hh_income_district`
- GTFS Static: `https://api.data.gov.my/gtfs-static/<agency>`


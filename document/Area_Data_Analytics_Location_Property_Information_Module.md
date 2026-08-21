# Area Data Analytics + Location & Property Information Module

## Smart Property Advisor — PandaGuru

**Module Owner:** Mok Chun Bing  
**Application:** Smart Property Advisor (PandaGuru)  
**Course:** BMIT2073 Mobile Application Development  
**Platform:** Flutter  
**Primary Backend / Cloud Database:** Supabase  
**Primary Data Sources:** data.gov.my, OpenDOSM, GTFS Static, TEDUH  
**SDG Alignment:** SDG 9 — Industry, Innovation and Infrastructure

---

## 1. Module Overview

The **Area Data Analytics + Location & Property Information Module** is responsible for collecting, cleaning, storing, presenting, and analysing Malaysian property-area information and government open data.

The module combines two closely related responsibilities:

1. **Location & Property Information**  
   Provides property, housing, location, map, and nearby-facility information to the user.

2. **Area Data Analytics**  
   Converts government datasets into understandable indicators such as population, household income, crime statistics, education availability, and public transport accessibility.

This module acts as the **data foundation** for the Smart Property Advisor application. It prepares structured and consistent property-area data that can later be used by the Smart Recommendation and Comparison module.

The module does **not** decide the final property recommendation by itself. Its main responsibility is to provide reliable evidence and analytics for decision support.

---

## 2. Module Objectives

The module aims to:

- Centralise relevant Malaysian property and area information in one mobile application.
- Use Malaysian government open data as required by the assignment.
- Allow users to search and explore housing projects and locations.
- Present area-level indicators in a simple and understandable form.
- Reduce the need for users to manually research multiple government portals.
- Provide cleaned and structured data for the recommendation module.
- Demonstrate proper mobile data management through API access, web crawling, transformation, caching, and cloud storage.
- Support SDG 9 by improving access to infrastructure-related information and data-driven decision support.

---

## 3. Scope of the Module

### 3.1 In Scope

The module is responsible for:

- Property and housing information.
- TEDUH affordable housing project information.
- Property search by state, district, town, project name, or keyword.
- Property detail display.
- Property location and geographic coordinates.
- Map-based property and area display.
- Nearby facilities and infrastructure.
- Population statistics.
- Household income statistics.
- Crime statistics.
- Public education institution information.
- Public transport stop information.
- Area profiles.
- Area indicator cards.
- Area comparison data.
- Government data source metadata.
- Data retrieval timestamps.
- Data cleaning and district-name normalisation.
- Python-based open-data crawling / extraction.
- JSON / CSV processed datasets.
- Supabase storage for structured data used by the Flutter application.

### 3.2 Out of Scope

The module is not responsible for:

- Final AI-generated recommendation text.
- Final weighted property ranking.
- User authentication.
- User registration and password recovery.
- User profile management.
- Market investment forecasting.
- Detailed ROI prediction.
- Loan or mortgage calculations.
- Legal property valuation.
- Property purchase or rental transactions.

These responsibilities belong to other modules in the Smart Property Advisor system.

---

## 4. Relationship With Other Team Modules

### 4.1 This Module

**Area Data Analytics + Location & Property Information**

Main question answered:

> What information is available about this property and what is the condition of its surrounding area?

Example outputs:

- Property price
- Property type
- Property location
- TEDUH project details
- Population
- Household income
- Crime statistics
- Number of nearby schools
- Nearby transport facilities
- Area-level infrastructure indicators

### 4.2 Smart Recommendation & Comparison Module

This module consumes the structured data prepared by the Area Data Analytics + Location & Property Information module.

Example:

```text
Area data
    ↓
Crime statistic
Population
Income
Facilities
Transport
Property information
    ↓
Recommendation scoring
    ↓
Ranked properties / areas
    ↓
Recommendation explanation
```

The recommendation module decides how different indicators are weighted and how properties are ranked.

### 4.3 Market Trend & Analytics + User Management Module

The other team module is responsible for functions such as:

- Login / registration
- User profile
- Favourites
- User preference persistence
- Market trend information
- Historical price trend
- Other market-oriented analytics

The Area Data Analytics module may provide supporting population or income values, but ownership of the final market-trend presentation remains separate.

---

## 5. Main Functional Requirements

### 5.1 Search Location or Property

The user can search for a property, housing project, district, town, or state.

Possible search fields:

- Project name
- State
- District
- Town
- Address
- Property type
- Price range

### 5.2 View Property Information

The user can view basic information for a selected property or housing project.

Possible information:

- Project name
- Property / housing type
- State
- District
- Address
- Price or price range
- Latitude
- Longitude
- Data source
- Last updated time

### 5.3 View TEDUH Housing Information

The application can display public affordable-housing information obtained from TEDUH.

TEDUH should be treated as **one government property-information source**, not as the entire recommendation system.

The application may display:

- Project name
- Housing scheme
- Location
- State
- District
- Project information available publicly from TEDUH
- Source URL / source label
- Retrieved date

### 5.4 View Property on Map

The user can inspect the geographic position of a property or area.

Map-related information may include:

- Property marker
- Area location
- Nearby facilities
- Transport stops
- Location summary

For a stable assignment demonstration, the app may use an offline or simplified map-style view when a live map service is not required.

### 5.5 View Nearby Facilities

The user can inspect facilities surrounding a property or area.

Possible categories:

- Schools
- Hospitals
- Police stations
- Public transport
- Shopping / commercial facilities

Facility data can be obtained from government datasets, GTFS, or other approved mapping/location services used by the project.

### 5.6 View Area Profile

The user can open an area profile containing government-derived indicators.

Example:

```text
Area: Gombak, Selangor

Population: 900,000+
Median Household Income: RM x,xxx
Education Institutions: xx
Crime Indicator: xxx
Transport Stops: xx
Data Year: 20xx
Last Updated: yyyy-mm-dd
```

Actual values must come from the retrieved datasets and must not be hard-coded as factual government statistics unless they are part of demo/sample data.

### 5.7 View Area Analytics

The user can view simplified analytics for a district or area.

Possible indicators:

- Population
- Population growth
- Household income
- Crime count / crime indicator
- Education institution count
- Transport availability
- Infrastructure-related indicators

### 5.8 Compare Area Indicators

The module can provide structured values that allow two or more locations to be compared.

Example structure:

| Indicator | Area A | Area B |
|---|---:|---:|
| Population | Value | Value |
| Household Income | Value | Value |
| Crime Indicator | Value | Value |
| Schools | Value | Value |
| Transport Stops | Value | Value |

The final recommendation score remains the responsibility of the recommendation module.

### 5.9 Show Data Source Metadata

For transparency, the application should be able to identify where data came from.

Example:

```text
Dataset: crime_district
Source: data.gov.my
Data year: 2024
Retrieved at: 2026-08-19
```

This is important because the application combines information from multiple government sources.

---

## 6. Government Open Data Sources

The module prioritises Malaysian government open data because the assignment specifically requires the application to utilise real-time or static data from Malaysian Government open-data platforms.

### 6.1 data.gov.my Data Catalogue API

Base endpoint:

```text
https://api.data.gov.my/data-catalogue
```

Example pattern:

```text
https://api.data.gov.my/data-catalogue?id=<dataset_id>
```

Datasets relevant to this module include:

- `crime_district`
- `schools_district`
- other suitable government datasets available through the catalogue

### 6.2 OpenDOSM

OpenDOSM provides official statistical datasets.

Relevant datasets include:

- Population by district
- Household income by district
- Demographic indicators where required

Documented examples used by the project include:

- `population_district`
- `hh_income_district`

### 6.3 GTFS Static

GTFS Static provides public transport schedule and stop information.

Base pattern:

```text
https://api.data.gov.my/gtfs-static/<agency>
```

For Prasarana, categories may include services such as:

```text
rapid-rail-kl
rapid-bus-kl
rapid-bus-mrtfeeder
```

The crawler may extract stop information from GTFS files for area-level transport availability.

### 6.4 TEDUH

TEDUH is used as a government housing / property-information source.

Purpose in this project:

- Retrieve public housing project information.
- Add real Malaysian housing information to the property exploration feature.
- Provide a government-data alternative to commercial listing portals.
- Keep the assignment scope focused on relevant public-sector information.

The project intentionally does not need to crawl large commercial portals such as PropertyGuru or Mudah in order to satisfy the assignment.

---

## 7. Data Collection Strategy

The module uses a combination of:

1. **Government APIs**
2. **Static government datasets**
3. **TEDUH public-page crawling**
4. **Processed local files**
5. **Supabase cloud storage**

### 7.1 Why Python Is Used for Data Collection

The crawler is implemented as a Python utility rather than placing all crawling logic directly inside Flutter.

Reason:

- Crawling and data cleaning are backend/data-processing tasks.
- Python is suitable for HTTP requests, parsing, transformation, and CSV/JSON generation.
- The mobile app should focus on presenting already-structured data.
- Data can be prepared before the live demo.
- The application becomes more stable because it does not depend on a website layout every time a user opens a screen.

Architecture:

```text
Government API / TEDUH
        ↓
Python crawler / data processor
        ↓
Clean and normalise
        ↓
JSON / CSV
        ↓
Supabase
        ↓
Flutter repository/service
        ↓
Mobile UI
```

---

## 8. Existing Crawler Structure

The documented crawler location is:

```text
tool/open_data_crawler.py
```

Its documented responsibilities include retrieving district-level information from:

- `population_district`
- `hh_income_district`
- `schools_district`
- `crime_district`
- optional GTFS Static transport data

Example command:

```powershell
python tool\open_data_crawler.py --target "Selangor,Gombak" --target "Selangor,Petaling" --output data\processed
```

Optional GTFS example:

```powershell
python tool\open_data_crawler.py --include-gtfs --gtfs-agency prasarana --gtfs-category rapid-rail-kl --output data\processed
```

Expected processed outputs:

```text
data/processed/area_profiles.json
data/processed/area_profiles.csv
data/processed/data_sources.json
data/processed/transport_stops.json
data/processed/transport_stops.csv
```

TEDUH extraction can be integrated into the same data-processing workflow so that the crawler remains a single controlled data-ingestion layer.

---

## 9. Data Cleaning and Normalisation

Government datasets may use different naming conventions.

Example:

```text
Petaling
PETALING
Daerah Petaling
Petaling, Selangor
```

Before the data is used by Flutter, the module should normalise these values.

### 9.1 Normalisation Tasks

- Trim extra whitespace.
- Standardise uppercase / lowercase handling.
- Standardise state names.
- Standardise district names.
- Remove duplicate records.
- Convert numeric strings into numeric values.
- Handle missing values safely.
- Store data year.
- Store retrieval timestamp.
- Preserve original source information.

### 9.2 Common Area Key

A recommended internal area key is:

```text
<state>_<district>
```

Example:

```text
selangor_gombak
selangor_petaling
kuala_lumpur_kuala_lumpur
```

This makes cross-dataset matching easier.

---

## 10. Processed Data Structure

### 10.1 Area Profile Example

```json
{
  "area_id": "selangor_gombak",
  "state": "Selangor",
  "district": "Gombak",
  "population": 0,
  "median_household_income": 0,
  "education_institution_count": 0,
  "crime_count": 0,
  "transport_stop_count": 0,
  "data_year": null,
  "retrieved_at": null
}
```

The zero / null values above are placeholders describing structure only. Actual stored values must come from retrieved datasets.

### 10.2 Property / TEDUH Project Example

```json
{
  "property_id": "project_identifier",
  "name": "Project Name",
  "state": "Selangor",
  "district": "Gombak",
  "address": "Available public address",
  "property_type": "Housing",
  "price_min": null,
  "price_max": null,
  "latitude": null,
  "longitude": null,
  "source": "TEDUH",
  "source_url": "public source URL",
  "retrieved_at": null
}
```

---

## 11. Supabase Data Storage

Supabase is used as the project's cloud database layer.

The crawler prepares clean data, while Supabase provides a consistent data source for Flutter.

### 11.1 Suggested Tables

#### `area_profiles`

```text
id
area_id
state
district
population
median_household_income
education_institution_count
crime_count
transport_stop_count
data_year
retrieved_at
created_at
updated_at
```

#### `properties`

```text
id
name
area_id
address
state
district
property_type
tenure
price
price_min
price_max
latitude
longitude
source
source_url
retrieved_at
created_at
updated_at
```

#### `facilities`

```text
id
area_id
name
facility_type
address
latitude
longitude
source
retrieved_at
```

#### `transport_stops`

```text
id
area_id
agency
stop_id
stop_name
latitude
longitude
source
retrieved_at
```

#### `data_sources`

```text
id
dataset_id
source_name
source_url
data_year
retrieved_at
notes
```

### 11.2 Recommended Access Rules

Public government-derived data can be readable by application users.

Examples:

- `area_profiles`: public read
- `properties`: public read
- `facilities`: public read
- `transport_stops`: public read
- `data_sources`: public read

Write operations should be restricted to trusted import / maintenance processes instead of ordinary mobile users.

---

## 12. Flutter Integration

The existing project documentation places this module mainly in:

```text
lib/
  data/
    asset_repository.dart

  features/
    search/
    map/

  models/
    property.dart
    area_data.dart

tool/
  open_data_crawler.py
```

With Supabase integration, the project can gradually move from local asset-only reads to repository methods that retrieve cloud data.

Recommended flow:

```text
Flutter Screen
    ↓
Repository / Service
    ↓
Supabase query
    ↓
Model mapping
    ↓
UI state
    ↓
Property / Area screen
```

---

## 13. Suggested Flutter Responsibilities

### Search Feature

Responsibilities:

- Search property / area.
- Apply filters.
- Display matching result cards.
- Open property detail.

Possible filters:

- State
- District
- Property type
- Budget
- Source

### Property Detail Feature

Responsibilities:

- Display project / property information.
- Display source metadata.
- Link to area information.
- Show nearby-facility summary.
- Show location.

### Map Feature

Responsibilities:

- Display area / property location.
- Display nearby facilities or transport points.
- Display simplified location insight.
- Navigate to area detail.

### Area Analytics Feature

Responsibilities:

- Load area profile.
- Display indicator cards.
- Display charts where useful.
- Show data year / update timestamp.
- Allow comparison of structured area values.

---

## 14. UI Screens in This Module

Recommended screens owned or substantially supported by this module:

### 14.1 Property Search Screen

Contains:

- Search bar
- State filter
- District filter
- Property type filter
- Price filter
- Search result list

### 14.2 Property Detail Screen

Contains:

- Property / project name
- Location
- Price information
- Housing type
- Source
- Map preview
- Nearby facility summary
- Area analytics shortcut

### 14.3 Map / Location Screen

Contains:

- Property markers
- Area position
- Transport stops
- Facility markers or summary
- Location insight

### 14.4 Area Analytics Screen

Contains:

- Population
- Income
- Crime
- Education
- Transport
- Data source
- Data year
- Last updated

### 14.5 Area Comparison View

Contains structured side-by-side values.

This view provides analytics data only; the final suitability ranking belongs to the recommendation module.

---

## 15. Error Handling

The module should handle data errors safely.

### API Failure

If a government API is temporarily unavailable:

- Do not crash the application.
- Use cached / previously imported data where possible.
- Show an appropriate unavailable message.
- Preserve the last retrieval timestamp.

### Missing Value

If a field is missing:

```text
Not available
```

is preferable to inventing a value.

### Empty Search Result

Display a clear empty-state message and allow the user to change filters.

### Invalid Coordinates

Do not attempt to place invalid coordinates on the map.

---

## 16. Data Freshness and Transparency

Every imported dataset should ideally preserve:

- Source name
- Dataset ID
- Data year
- Retrieved date
- Source URL

Example UI:

```text
Source: data.gov.my
Dataset: crime_district
Data year: 2024
Updated in app: 19 Aug 2026
```

This helps users understand that government datasets may be released at different intervals.

---

## 17. SDG 9 Contribution

This module supports **SDG 9: Industry, Innovation and Infrastructure** by making infrastructure-related public information easier to access and understand.

Examples:

- Public transport availability helps users understand connectivity.
- Education facilities indicate supporting infrastructure.
- Population and income data help describe area development.
- Location information helps users assess accessibility.
- Government housing information improves access to public-sector property information.
- Integrating multiple public datasets demonstrates digital innovation using open government data.

The app does not claim that these indicators alone determine whether a property is a good investment. They are decision-support information.

---

## 18. Data Management Contribution

Data management is a major strength of this module.

The complete process is:

```text
1. Identify relevant government dataset
2. Fetch API / public data
3. Crawl TEDUH public project information
4. Validate response
5. Clean records
6. Normalise district and state names
7. Remove duplicates
8. Convert data types
9. Add source metadata
10. Export JSON / CSV
11. Import / upsert to Supabase
12. Query from Flutter
13. Convert response into Dart models
14. Present on mobile screens
```

This pipeline demonstrates that the app is not simply displaying hard-coded sample values.

---

## 19. Module Architecture

```text
                    ┌───────────────────────┐
                    │ Malaysian Open Data  │
                    │ data.gov.my / DOSM   │
                    │ GTFS / TEDUH         │
                    └───────────┬───────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │ Python Data Layer     │
                    │ crawler + cleaning   │
                    │ normalisation        │
                    └───────────┬───────────┘
                                │
                     JSON / CSV │
                                ▼
                    ┌───────────────────────┐
                    │ Supabase             │
                    │ structured storage   │
                    └───────────┬───────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │ Flutter Repository   │
                    │ / Data Service       │
                    └───────────┬───────────┘
                                │
             ┌──────────────────┼──────────────────┐
             ▼                  ▼                  ▼
      ┌─────────────┐    ┌─────────────┐   ┌──────────────┐
      │ Search      │    │ Map /       │   │ Area         │
      │ Property    │    │ Location    │   │ Analytics    │
      └─────────────┘    └─────────────┘   └──────────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │ Recommendation       │
                    │ Module consumes data │
                    └───────────────────────┘
```

---

## 20. Suggested Repository Structure

```text
lib/
  core/
    config/
      supabase_config.dart

  data/
    repositories/
      area_repository.dart
      property_repository.dart
      facility_repository.dart

  features/
    search/
    map/
    analysis/

  models/
    property.dart
    area_data.dart
    facility.dart
    transport_stop.dart
    data_source.dart

  services/
    area_data_service.dart
    property_data_service.dart

tool/
  open_data_crawler.py
  teduh_crawler.py          # optional if separated

data/
  processed/
    area_profiles.json
    area_profiles.csv
    data_sources.json
    transport_stops.json
    transport_stops.csv
    teduh_projects.json
```

The exact file names can be adjusted to match the repository. The important point is to keep crawling/data-processing code separate from Flutter UI code.

---

## 21. Example End-to-End Use Case

### Scenario

A user wants to explore housing in Gombak.

### Flow

```text
User opens Search
    ↓
Searches "Gombak"
    ↓
Flutter queries property / housing data
    ↓
TEDUH project records are shown
    ↓
User selects a project
    ↓
Property Detail displays project information
    ↓
User opens Area Analytics
    ↓
App retrieves Gombak area profile
    ↓
Population / income / crime / education /
transport indicators are displayed
    ↓
User may send/select this property for
Smart Recommendation / Comparison
```

This flow clearly separates **information and analytics** from **recommendation logic**.

---

## 22. Testing Plan

### 22.1 Data Layer Tests

Test:

- API response parsing.
- Missing fields.
- Invalid JSON.
- District normalisation.
- Duplicate removal.
- Numeric conversion.
- CSV / JSON output generation.

### 22.2 Supabase Tests

Test:

- Area data can be read.
- Property data can be read.
- Search filters return expected records.
- Empty result is handled.
- Data source metadata is preserved.

### 22.3 Flutter Tests

Test:

- Property list loads.
- Search works.
- Filters work.
- Property detail opens.
- Area analytics loads.
- Missing data does not crash the screen.
- Navigation between Search, Map and Analytics works.

### 22.4 Manual Demo Tests

Before presentation:

1. Run crawler / confirm processed data exists.
2. Confirm Supabase tables contain expected rows.
3. Start Flutter app using required Supabase `--dart-define` values.
4. Search a known area.
5. Open a known TEDUH property.
6. Open area analytics.
7. Check source / update metadata.
8. Test offline / API-failure fallback if implemented.

---

## 23. Final Presentation — Structured Code Walkthrough

The final presentation requires each member to present their own module.

For this module, the recommended walkthrough order is:

### Part 1 — Explain the Problem

Users normally need to check multiple sources to understand a property area.

### Part 2 — Explain the Data Sources

Show:

- data.gov.my
- OpenDOSM
- GTFS
- TEDUH

### Part 3 — Show the Python Data Pipeline

Show:

```text
tool/open_data_crawler.py
```

Explain:

- API request
- parsing
- cleaning
- normalisation
- processed output

### Part 4 — Show Supabase

Show relevant tables such as:

- `area_profiles`
- `properties`
- `transport_stops`
- `data_sources`

### Part 5 — Show Flutter Data Access

Explain how Flutter:

- queries the data,
- maps it into models,
- and updates the UI.

### Part 6 — Live Demo

Demonstrate:

```text
Search
→ Property Detail
→ Map / Location
→ Area Analytics
```

### Part 7 — Explain Module Boundary

State clearly:

> My module prepares and displays property, location, infrastructure and area data. The Smart Recommendation module uses these values to calculate its recommendation and comparison results.

---

## 24. Key Points to Explain if Asked by Lecturer

### Why use Python if the app is Flutter?

Python is used only as a data-collection and preprocessing utility. Flutter remains the mobile application. The crawler prepares government/open web data so the Flutter app can consume structured, reliable records.

### Why not crawl PropertyGuru or Mudah?

The assignment is specifically based on Malaysian Government open data. TEDUH, data.gov.my, OpenDOSM and GTFS already provide sufficient assignment-relevant sources. Avoiding unnecessary commercial scraping keeps the scope focused and reduces legal, technical, and reliability issues.

### Why use Supabase?

Supabase provides cloud storage that the Flutter application can query consistently. It also supports structured relational data and allows the cleaned crawler output to be imported into database tables.

### Is TEDUH the recommendation system?

No. TEDUH is only one property-information source. Recommendation is generated by another module using multiple factors.

### Does this module decide which property is best?

No. This module provides the evidence and analytics. The recommendation module applies its scoring / comparison logic.

---

## 25. Module Completion Checklist

### Data Sources

- [ ] Confirm final data.gov.my datasets.
- [ ] Confirm OpenDOSM datasets.
- [ ] Confirm GTFS scope.
- [ ] Confirm TEDUH public data fields.

### Data Pipeline

- [ ] Government API retrieval working.
- [ ] TEDUH extraction working.
- [ ] Data cleaning implemented.
- [ ] District/state normalisation implemented.
- [ ] Duplicate handling implemented.
- [ ] JSON / CSV output generated.
- [ ] Data-source metadata generated.

### Supabase

- [ ] Create required tables.
- [ ] Import / upsert processed area data.
- [ ] Import / upsert TEDUH property data.
- [ ] Configure read policies.
- [ ] Verify Flutter can read data.

### Flutter

- [ ] Search screen connected.
- [ ] Property detail connected.
- [ ] Map/location display connected.
- [ ] Area analytics connected.
- [ ] Filters connected.
- [ ] Empty/error states handled.
- [ ] Source/update metadata displayed.

### Presentation

- [ ] Prepare module architecture explanation.
- [ ] Prepare crawler code walkthrough.
- [ ] Prepare Supabase walkthrough.
- [ ] Prepare Flutter repository/model walkthrough.
- [ ] Prepare live demo flow.
- [ ] Be able to explain why Python is used.
- [ ] Be able to explain module boundary with recommendation module.

---

## 26. Final Module Summary

The **Area Data Analytics + Location & Property Information Module** is the data-centric foundation of Smart Property Advisor.

Its responsibility can be summarised as:

```text
Collect
    ↓
Clean
    ↓
Normalise
    ↓
Store
    ↓
Search / Explore
    ↓
Visualise
    ↓
Analyse
    ↓
Provide structured evidence to the recommendation module
```

The module combines Malaysian government open data with property and location information so that users can understand an area before making a property decision.

The final system should therefore clearly demonstrate that this module is more than a property-search page: it includes **government open-data integration, data processing, data management, location information, infrastructure information, area analytics, and transparent source tracking**.

---

## 27. References / Data Endpoints

- Malaysian Government Open Data Portal: `https://data.gov.my/`
- Data Catalogue API: `https://api.data.gov.my/data-catalogue`
- OpenDOSM: `https://open.dosm.gov.my/`
- OpenDOSM API: `https://api.data.gov.my/opendosm`
- GTFS Static API: `https://api.data.gov.my/gtfs-static/<agency>`
- Crime by District: `https://data.gov.my/data-catalogue/crime_district`
- Public Education Institutions: `https://data.gov.my/data-catalogue/schools_district`
- Population by District: `https://open.dosm.gov.my/data-catalogue/population_district`
- Household Income by District: `https://open.dosm.gov.my/data-catalogue/hh_income_district`
- TEDUH: Malaysian public housing/property information source used by this project

---

## 28. Source Basis for This Documentation

This module document is aligned with:

- The BMIT2073 Mobile Application Development assignment requirement to use Malaysian Government open data for an SDG 9 mobile solution.
- The PandaGuru / Smart Property Advisor prototype and navigation structure.
- The Smart Property Advisor system documentation.
- The project's finalised module distribution in which **Area Data Analytics** and **Location & Property Information** are combined as one member-owned module.

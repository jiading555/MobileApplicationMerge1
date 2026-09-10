import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/location_normalizer.dart';
import '../../core/utils/property_area_resolver.dart';
import '../../core/utils/property_filtering.dart';
import '../../core/utils/property_type_normalizer.dart';
import '../../core/utils/scheme_normalizer.dart';
import '../../core/utils/responsive_layout.dart';
import '../../core/widgets/page_container.dart';
import '../../core/widgets/property_card.dart';
import '../../models/area_data.dart';
import '../../models/property.dart';
import 'property_detail_screen.dart';

class PropertySearchScreen extends StatefulWidget {
  const PropertySearchScreen({super.key});

  @override
  State<PropertySearchScreen> createState() => _PropertySearchScreenState();
}

class _PropertySearchScreenState extends State<PropertySearchScreen> {
  static const _searchDebounceDuration = Duration(milliseconds: 250);

  final searchController = TextEditingController();
  Timer? _searchDebounce;
  String searchQuery = '';
  String selectedState = 'Any';
  String selectedAreaId = 'Any';
  String selectedType = PropertyTypeNormalizer.anyType;
  String selectedScheme = SchemeNormalizer.anyScheme;

  _SearchIndex? _searchIndex;
  List<Property>? _indexedPropertiesSource;
  List<AreaData>? _indexedAreasSource;
  int _indexedPropertiesLength = -1;
  int _indexedAreasLength = -1;
  _SearchIndex? _lastFilterIndex;
  String _lastFilterKey = '';
  List<Property> _lastFilteredResults = const [];
  _SearchIndex? _lastAreaOptionsIndex;
  String _lastAreaOptionsState = '';
  List<_FilterOption> _lastAreaOptions = const [];

  @override
  void dispose() {
    _searchDebounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final index = _ensureSearchIndex(state.properties, state.areas);
    final typeValues = index.typeValues;
    final schemeValues = index.schemeValues;
    final stateValues = index.stateValues;
    final areaValues = _areaFilterOptions(index, selectedState);
    final areaIds = areaValues.map((option) => option.value).toSet();
    if (!stateValues.contains(selectedState)) {
      selectedState = 'Any';
      selectedAreaId = 'Any';
    }
    if (!areaIds.contains(selectedAreaId)) {
      selectedAreaId = 'Any';
    }
    if (!typeValues.contains(selectedType)) {
      selectedType = PropertyTypeNormalizer.anyType;
    }
    if (!schemeValues.contains(selectedScheme)) {
      selectedScheme = SchemeNormalizer.anyScheme;
    }
    final results = _filtered(index);
    final selectedAreaLabel = selectedAreaId == 'Any'
        ? 'Any Area'
        : areaValues
              .firstWhere(
                (option) => option.value == selectedAreaId,
                orElse: () => _FilterOption(selectedAreaId, selectedAreaId),
              )
              .label;
    final sourceLabel = state.isUsingCloudProperties
        ? 'Source: Supabase / TEDUH'
        : 'Source: official data unavailable';
    final compactHeight = ResponsiveLayout.isCompactLandscapePhone(context);
    final tablet = ResponsiveLayout.isTablet(context);
    final pagePadding = compactHeight
        ? const EdgeInsets.fromLTRB(14, 6, 14, 10)
        : tablet
        ? const EdgeInsets.fromLTRB(18, 12, 18, 20)
        : const EdgeInsets.fromLTRB(18, 14, 18, 22);
    final controlGap = compactHeight ? 8.0 : 10.0;
    final sectionGap = compactHeight ? 8.0 : 12.0;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: compactHeight ? 48 : null,
        title: const Text('Property search'),
        actions: [
          IconButton(
            onPressed: _reset,
            tooltip: 'Reset filters',
            icon: const Icon(Icons.restart_alt_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: PageContainer(
        padding: pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search locations, projects, property type...',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: compactHeight ? 10 : 12,
                ),
                prefixIcon: const Icon(Icons.search_rounded),
                prefixIconConstraints: BoxConstraints(
                  minWidth: compactHeight ? 40 : 44,
                  minHeight: compactHeight ? 40 : 44,
                ),
                suffixIconConstraints: BoxConstraints(
                  minWidth: compactHeight ? 40 : 44,
                  minHeight: compactHeight ? 40 : 44,
                ),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: searchController,
                  builder: (context, value, _) {
                    if (value.text.isEmpty) {
                      return const Icon(Icons.tune_rounded);
                    }
                    return IconButton(
                      onPressed: _clearSearch,
                      icon: const Icon(Icons.close_rounded),
                    );
                  },
                ),
              ),
            ),
            SizedBox(height: controlGap),
            SingleChildScrollView(
              key: const ValueKey('property-filter-scroll-row'),
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterDropdown(
                    buttonKey: const ValueKey('property-filter-state-button'),
                    label: selectedState == 'Any' ? 'Any State' : selectedState,
                    options: stateValues
                        .map(
                          (value) => _FilterOption(
                            value,
                            value == 'Any' ? 'Any State' : value,
                          ),
                        )
                        .toList(),
                    value: selectedState,
                    width: 158,
                    selected: selectedState != 'Any',
                    onChanged: (value) => setState(() {
                      selectedState = value;
                      selectedAreaId = 'Any';
                    }),
                  ),
                  SizedBox(width: controlGap),
                  _FilterDropdown(
                    buttonKey: const ValueKey('property-filter-area-button'),
                    label: selectedAreaLabel,
                    options: areaValues,
                    value: selectedAreaId,
                    width: 158,
                    enabled: selectedState != 'Any',
                    selected: selectedAreaId != 'Any',
                    onChanged: (value) =>
                        setState(() => selectedAreaId = value),
                  ),
                  SizedBox(width: controlGap),
                  _FilterDropdown(
                    buttonKey: const ValueKey('property-filter-type-button'),
                    label: selectedType,
                    options: typeValues
                        .map((value) => _FilterOption(value, value))
                        .toList(),
                    value: selectedType,
                    width: 166,
                    selected: selectedType != PropertyTypeNormalizer.anyType,
                    onChanged: (value) => setState(() => selectedType = value),
                  ),
                  SizedBox(width: controlGap),
                  _FilterDropdown(
                    buttonKey: const ValueKey(
                      'property-filter-programme-button',
                    ),
                    label: selectedScheme,
                    options: schemeValues
                        .map((value) => _FilterOption(value, value))
                        .toList(),
                    value: selectedScheme,
                    width: 188,
                    selected: selectedScheme != SchemeNormalizer.anyScheme,
                    onChanged: (value) =>
                        setState(() => selectedScheme = value),
                  ),
                ],
              ),
            ),
            SizedBox(height: sectionGap),
            _ResultSummaryRow(
              resultCount: results.length,
              sourceLabel: sourceLabel,
            ),
            SizedBox(height: compactHeight ? 6 : 10),
            Expanded(
              child: results.isEmpty
                  ? const _NoResults()
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        if (!ResponsiveLayout.isTablet(context)) {
                          return ListView.separated(
                            itemCount: results.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) => PropertyCard(
                              property: results[index],
                              compact: true,
                              showPropertyInfo: true,
                              showDetailsAction: true,
                              onTap: () => _open(results[index]),
                            ),
                          );
                        }
                        final columns = ResponsiveLayout.isDesktop(context)
                            ? 3
                            : 2;
                        return CustomScrollView(
                          slivers: [
                            SliverGrid.builder(
                              itemCount: results.length,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    mainAxisExtent: 356,
                                  ),
                              itemBuilder: (context, index) {
                                final property = results[index];
                                return PropertyCard(
                                  property: property,
                                  showPropertyInfo: true,
                                  showDetailsAction: true,
                                  onTap: () => _open(property),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _open(Property property) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PropertyDetailScreen(propertyId: property.id),
      ),
    );
  }

  void _reset() {
    searchController.clear();
    _searchDebounce?.cancel();
    setState(() {
      searchQuery = '';
      selectedState = 'Any';
      selectedAreaId = 'Any';
      selectedType = PropertyTypeNormalizer.anyType;
      selectedScheme = SchemeNormalizer.anyScheme;
    });
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_searchDebounceDuration, () {
      final nextQuery = value.trim().toLowerCase();
      if (!mounted || nextQuery == searchQuery) {
        return;
      }
      setState(() => searchQuery = nextQuery);
    });
  }

  void _clearSearch() {
    searchController.clear();
    _searchDebounce?.cancel();
    if (searchQuery.isEmpty) {
      return;
    }
    setState(() => searchQuery = '');
  }

  _SearchIndex _ensureSearchIndex(
    List<Property> properties,
    List<AreaData> areas,
  ) {
    if (identical(_indexedPropertiesSource, properties) &&
        identical(_indexedAreasSource, areas) &&
        _indexedPropertiesLength == properties.length &&
        _indexedAreasLength == areas.length &&
        _searchIndex != null) {
      return _searchIndex!;
    }

    final rows = <_SearchProperty>[];
    final states = <String>{};
    for (final property in properties) {
      final area = PropertyAreaResolver.resolve(
        property: property,
        areas: areas,
      );
      final displayState = LocationNormalizer.nullableDisplayStateName(
        property.state,
      );
      final displayDistrict = LocationNormalizer.nullableDisplayDistrictName(
        property.district,
      );
      final normalizedLocalityAreaId =
          displayState == null || displayDistrict == null
          ? ''
          : LocationNormalizer.canonicalAreaId(displayState, displayDistrict);
      if (displayState != null && displayState.isNotEmpty) {
        states.add(displayState);
      }
      rows.add(
        _SearchProperty(
          property: property,
          normalizedLocalityAreaId: normalizedLocalityAreaId,
          displayState: displayState,
          displayDistrict: displayDistrict,
          searchableText: [
            property.name,
            property.address,
            property.type,
            ...property.unitTypes,
            property.tenure,
            property.state,
            property.district,
            property.scheme,
            property.developerName,
            property.source,
            property.rawLocation,
            area?.name,
            area?.state,
          ].whereType<String>().join(' ').toLowerCase(),
        ),
      );
    }

    final stateValues = ['Any', ...states.toList()..sort()];
    _searchIndex = _SearchIndex(
      rows: rows,
      typeValues: PropertyFilterNormalizer.availablePropertyTypes(properties),
      schemeValues: PropertyFilterNormalizer.availableSchemes(
        properties.map((property) => property.scheme),
      ),
      stateValues: stateValues,
    );
    _indexedPropertiesSource = properties;
    _indexedAreasSource = areas;
    _indexedPropertiesLength = properties.length;
    _indexedAreasLength = areas.length;
    _lastFilterIndex = null;
    _lastAreaOptionsIndex = null;
    return _searchIndex!;
  }

  List<Property> _filtered(_SearchIndex index) {
    final normalizedAreaId = PropertyFilterNormalizer.normalizeAreaId(
      selectedAreaId,
    );
    final key =
        '$searchQuery|$selectedState|$normalizedAreaId|$selectedType|$selectedScheme';
    if (identical(_lastFilterIndex, index) && _lastFilterKey == key) {
      return _lastFilteredResults;
    }

    final results = <Property>[];
    for (final row in index.rows) {
      final property = row.property;
      if (searchQuery.isNotEmpty && !row.searchableText.contains(searchQuery)) {
        continue;
      }
      if (!PropertyFilterNormalizer.stateMatches(
        property.state,
        selectedState,
      )) {
        continue;
      }
      if (selectedAreaId != 'Any' &&
          row.normalizedLocalityAreaId != normalizedAreaId) {
        continue;
      }
      if (!PropertyFilterNormalizer.propertyTypeMatches(
        property,
        selectedType,
      )) {
        continue;
      }
      if (!PropertyFilterNormalizer.schemeMatches(
        property.scheme,
        selectedScheme,
      )) {
        continue;
      }
      results.add(property);
    }

    _lastFilterIndex = index;
    _lastFilterKey = key;
    _lastFilteredResults = results;
    return results;
  }

  List<_FilterOption> _areaFilterOptions(
    _SearchIndex index,
    String selectedState,
  ) {
    if (selectedState == 'Any') {
      return const [_FilterOption('Any', 'Any Area')];
    }
    if (identical(_lastAreaOptionsIndex, index) &&
        _lastAreaOptionsState == selectedState) {
      return _lastAreaOptions;
    }

    final labelsById = <String, String>{};
    for (final row in index.rows) {
      final state = row.displayState;
      final district = row.displayDistrict;
      if (state == null ||
          district == null ||
          row.normalizedLocalityAreaId.isEmpty ||
          !LocationNormalizer.stateMatches(state, selectedState)) {
        continue;
      }
      labelsById.putIfAbsent(row.normalizedLocalityAreaId, () => district);
    }

    final options =
        labelsById.entries
            .map((entry) => _FilterOption(entry.key, entry.value))
            .toList()
          ..sort((left, right) => left.label.compareTo(right.label));
    _lastAreaOptionsIndex = index;
    _lastAreaOptionsState = selectedState;
    _lastAreaOptions = [const _FilterOption('Any', 'Any Area'), ...options];
    return _lastAreaOptions;
  }
}

class _SearchIndex {
  const _SearchIndex({
    required this.rows,
    required this.typeValues,
    required this.schemeValues,
    required this.stateValues,
  });

  final List<_SearchProperty> rows;
  final List<String> typeValues;
  final List<String> schemeValues;
  final List<String> stateValues;
}

class _SearchProperty {
  const _SearchProperty({
    required this.property,
    required this.normalizedLocalityAreaId,
    required this.searchableText,
    required this.displayState,
    required this.displayDistrict,
  });

  final Property property;
  final String normalizedLocalityAreaId;
  final String searchableText;
  final String? displayState;
  final String? displayDistrict;
}

class _FilterOption {
  const _FilterOption(this.value, this.label);

  final String value;
  final String label;
}

class _ResultSummaryRow extends StatelessWidget {
  const _ResultSummaryRow({
    required this.resultCount,
    required this.sourceLabel,
  });

  final int resultCount;
  final String sourceLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$resultCount properties found',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: Row(
                key: const ValueKey('property-search-source-summary'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 15,
                    color: AppTheme.muted,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      sourceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.buttonKey,
    required this.label,
    required this.options,
    required this.value,
    required this.width,
    required this.onChanged,
    this.enabled = true,
    this.selected = false,
  });

  final Key buttonKey;
  final String label;
  final List<_FilterOption> options;
  final String value;
  final double width;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      initialValue: value,
      enabled: enabled,
      constraints: BoxConstraints.tightFor(width: width),
      onSelected: enabled ? onChanged : null,
      itemBuilder: (_) => options
          .map(
            (item) => PopupMenuItem(
              value: item.value,
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      child: _FilterButton(
        key: buttonKey,
        label: label,
        enabled: enabled,
        selected: selected,
        width: width,
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.width,
    required this.enabled,
    required this.selected,
    super.key,
  });

  final String label;
  final double width;
  final bool enabled;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final textColor = enabled
        ? (selected ? AppTheme.blue : Colors.black87)
        : AppTheme.muted;
    final borderColor = selected && enabled
        ? AppTheme.blue
        : const Color(0xFFDCE3ED);
    return Container(
      width: width,
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: enabled ? Colors.white : const Color(0xFFF4F7FB),
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.arrow_drop_down_rounded,
            size: 19,
            color: enabled
                ? (selected ? AppTheme.blue : Colors.black87)
                : AppTheme.muted,
          ),
        ],
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.travel_explore_rounded, size: 58, color: AppTheme.muted),
          SizedBox(height: 14),
          Text('No properties match these filters.'),
          SizedBox(height: 4),
          Text(
            'Reset a filter to broaden the results.',
            style: TextStyle(color: AppTheme.muted),
          ),
        ],
      ),
    );
  }
}

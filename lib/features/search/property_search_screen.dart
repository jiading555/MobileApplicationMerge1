import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/location_normalizer.dart';
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
  final searchController = TextEditingController();
  int? maximumPrice;
  String selectedState = 'Any';
  String selectedAreaId = 'Any';
  String selectedType = PropertyTypeNormalizer.anyType;
  String selectedScheme = SchemeNormalizer.anyScheme;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<Property> filtered(List<Property> properties, List<AreaData> areas) {
    final query = searchController.text.trim().toLowerCase();
    final results = properties.where((property) {
      final area = _safeAreaFor(areas, property.areaId);
      final searchable = [
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
        area?.name,
        area?.state,
      ].whereType<String>().join(' ').toLowerCase();
      final matchesQuery = query.isEmpty || searchable.contains(query);

      final matchesState = PropertyFilterNormalizer.stateMatches(
        property.state,
        selectedState,
      );

      final matchesArea = PropertyFilterNormalizer.areaMatches(
        property.areaId,
        selectedAreaId,
      );
      final matchesType = PropertyFilterNormalizer.propertyTypeMatches(
        property,
        selectedType,
      );
      final matchesScheme = PropertyFilterNormalizer.schemeMatches(
        property.scheme,
        selectedScheme,
      );
      final matchesPrice = PropertyFilterNormalizer.matchPrice(
        property,
        maximumPrice,
      );
      return matchesQuery &&
          matchesState &&
          matchesArea &&
          matchesType &&
          matchesScheme &&
          matchesPrice;
    }).toList();

    return results;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final typeValues = PropertyFilterNormalizer.availablePropertyTypes(
      state.properties,
    );
    final schemeValues = PropertyFilterNormalizer.availableSchemes(
      state.properties.map((p) => p.scheme),
    );
    final stateValues = [
      'Any',
      ...state.properties
          .map((p) => p.state)
          .whereType<String>()
          .map(LocationNormalizer.displayStateName)
          .where((state) => state.isNotEmpty)
          .toSet()
          .toList()
        ..sort(),
    ];
    final areaValues = _areaFilterOptions(state.areas, state.properties);
    final areaIds = areaValues.map((option) => option.value).toSet();
    if (!stateValues.contains(selectedState)) {
      selectedState = 'Any';
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
    final results = filtered(state.properties, state.areas);
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
    return Scaffold(
      appBar: AppBar(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search locations, projects, property type...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: searchController.text.isEmpty
                    ? const Icon(Icons.tune_rounded)
                    : IconButton(
                        onPressed: () {
                          searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _DropdownFilter(
                    label: selectedState == 'Any' ? 'Any State' : selectedState,
                    values: stateValues,
                    value: selectedState,
                    onChanged: (value) => setState(() => selectedState = value),
                  ),
                  const SizedBox(width: 9),
                  _AreaDropdownFilter(
                    label: selectedAreaLabel,
                    values: areaValues,
                    value: selectedAreaId,
                    onChanged: (value) =>
                        setState(() => selectedAreaId = value),
                  ),
                  const SizedBox(width: 9),
                  _DropdownFilter(
                    title: 'Property Type',
                    label: selectedType,
                    values: typeValues,
                    value: selectedType,
                    onChanged: (value) => setState(() => selectedType = value),
                  ),
                  const SizedBox(width: 9),
                  _DropdownFilter(
                    title: 'Housing Programme',
                    label: selectedScheme,
                    values: schemeValues,
                    value: selectedScheme,
                    onChanged: (value) =>
                        setState(() => selectedScheme = value),
                  ),
                  const SizedBox(width: 9),
                  _FilterButton(
                    icon: Icons.payments_outlined,
                    label: maximumPrice == null
                        ? 'Any Budget'
                        : 'Up to ${formatRinggit(maximumPrice!, compact: true)}',
                    onTap: _showPriceSheet,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${results.length} properties found',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppTheme.muted,
                ),
                const SizedBox(width: 5),
                Text(
                  sourceLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: results.isEmpty
                  ? const _NoResults()
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        if (!ResponsiveLayout.isTablet(context)) {
                          return ListView.separated(
                            itemCount: results.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) => PropertyCard(
                              property: results[index],
                              compact: true,
                              onTap: () => _open(results[index]),
                            ),
                          );
                        }
                        final columns = ResponsiveLayout.isDesktop(context)
                            ? 3
                            : 2;
                        return GridView.builder(
                          itemCount: results.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                                childAspectRatio: columns == 3 ? 0.84 : 1.02,
                              ),
                          itemBuilder: (context, index) => PropertyCard(
                            property: results[index],
                            onTap: () => _open(results[index]),
                          ),
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
    setState(() {
      maximumPrice = null;
      selectedState = 'Any';
      selectedAreaId = 'Any';
      selectedType = PropertyTypeNormalizer.anyType;
      selectedScheme = SchemeNormalizer.anyScheme;
    });
  }

  Future<void> _showPriceSheet() async {
    var draft = (maximumPrice ?? 1500000).toDouble();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Maximum price',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      formatRinggit(draft),
                      style: const TextStyle(
                        color: AppTheme.blue,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => maximumPrice = null);
                      Navigator.of(context).pop();
                    },
                    child: const Text('Clear Filter'),
                  ),
                ],
              ),
              Slider(
                min: 350000,
                max: 1600000,
                divisions: 25,
                value: draft,
                onChanged: (value) => setSheetState(() => draft = value),
              ),
              FilledButton(
                onPressed: () {
                  setState(() => maximumPrice = draft.round());
                  Navigator.of(context).pop();
                },
                child: const Text('Apply price'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  AreaData? _safeAreaFor(List<AreaData> areas, String areaId) {
    try {
      return areas.firstWhere(
        (area) => LocationNormalizer.areaIdMatches(area.id, areaId),
      );
    } catch (_) {
      return null;
    }
  }

  List<_FilterOption> _areaFilterOptions(
    List<AreaData> areas,
    List<Property> properties,
  ) {
    final labelsById = <String, String>{};
    for (final area in areas) {
      labelsById[area.id] = '${area.name}, ${area.state}';
    }
    for (final property in properties) {
      final state = LocationNormalizer.nullableDisplayStateName(property.state);
      final district = LocationNormalizer.nullableDisplayDistrictName(
        property.district,
      );
      if (state == null || district == null) {
        continue;
      }
      final areaId = LocationNormalizer.canonicalAreaId(state, district);
      labelsById.putIfAbsent(areaId, () => '$district, $state');
    }

    final options =
        labelsById.entries
            .map((entry) => _FilterOption(entry.key, entry.value))
            .toList()
          ..sort((left, right) => left.label.compareTo(right.label));
    return [const _FilterOption('Any', 'Any Area'), ...options];
  }
}

class _FilterOption {
  const _FilterOption(this.value, this.label);

  final String value;
  final String label;
}

class _AreaDropdownFilter extends StatelessWidget {
  const _AreaDropdownFilter({
    required this.label,
    required this.values,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<_FilterOption> values;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (_) => values
          .map(
            (item) => PopupMenuItem(value: item.value, child: Text(item.label)),
          )
          .toList(),
      child: _FilterButton(label: label),
    );
  }
}

class _DropdownFilter extends StatelessWidget {
  const _DropdownFilter({
    required this.label,
    required this.values,
    required this.value,
    required this.onChanged,
    this.title,
  });

  final String? title;
  final String label;
  final List<String> values;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (_) => values
          .map((item) => PopupMenuItem(value: item, child: Text(item)))
          .toList(),
      child: _FilterButton(title: title, label: label),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.label, this.title, this.icon, this.onTap});

  final String? title;
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      constraints: const BoxConstraints(
        minWidth: 128,
        maxWidth: 220,
        minHeight: 48,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFDCE3ED)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: AppTheme.blue),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: title == null
                ? Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_drop_down_rounded, size: 20),
        ],
      ),
    );

    if (onTap == null) {
      return child;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: child,
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
            'Increase the budget or reset a filter.',
            style: TextStyle(color: AppTheme.muted),
          ),
        ],
      ),
    );
  }
}

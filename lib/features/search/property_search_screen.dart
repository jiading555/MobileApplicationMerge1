import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
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
  double maximumPrice = 1500000;
  String selectedAreaId = 'Any';
  String selectedType = 'Any';
  String selectedTenure = 'Any';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<Property> filtered(List<Property> properties, List<AreaData> areas) {
    final query = searchController.text.trim().toLowerCase();
    return properties.where((property) {
      final area = _areaFor(areas, property.areaId);
      final matchesQuery =
          query.isEmpty ||
          property.name.toLowerCase().contains(query) ||
          property.address.toLowerCase().contains(query) ||
          property.type.toLowerCase().contains(query) ||
          area.name.toLowerCase().contains(query) ||
          area.state.toLowerCase().contains(query);
      final matchesArea =
          selectedAreaId == 'Any' || property.areaId == selectedAreaId;
      final matchesType =
          selectedType == 'Any' || property.type == selectedType;
      final matchesTenure =
          selectedTenure == 'Any' || property.tenure == selectedTenure;
      return matchesQuery &&
          matchesArea &&
          matchesType &&
          matchesTenure &&
          property.price <= maximumPrice;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final results = filtered(state.properties, state.areas);
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
                    label: selectedAreaId == 'Any'
                        ? 'All areas'
                        : _areaFor(state.areas, selectedAreaId).name,
                    values: ['Any', ...state.areas.map((area) => area.id)],
                    value: selectedAreaId,
                    labelFor: (value) => value == 'Any'
                        ? 'Any'
                        : '${_areaFor(state.areas, value).name}, ${_areaFor(state.areas, value).state}',
                    onChanged: (value) =>
                        setState(() => selectedAreaId = value),
                  ),
                  const SizedBox(width: 9),
                  _DropdownFilter(
                    label: selectedType == 'Any' ? 'All types' : selectedType,
                    values: const [
                      'Any',
                      'Condominium',
                      'Apartment',
                      'Terrace',
                      'Semi-D',
                    ],
                    value: selectedType,
                    onChanged: (value) => setState(() => selectedType = value),
                  ),
                  const SizedBox(width: 9),
                  _DropdownFilter(
                    label: selectedTenure == 'Any'
                        ? 'All tenure'
                        : selectedTenure,
                    values: const ['Any', 'Freehold', 'Leasehold'],
                    value: selectedTenure,
                    onChanged: (value) =>
                        setState(() => selectedTenure = value),
                  ),
                  const SizedBox(width: 9),
                  ActionChip(
                    avatar: const Icon(Icons.payments_outlined, size: 18),
                    label: Text(
                      'Up to ${formatRinggit(maximumPrice, compact: true)}',
                    ),
                    onPressed: _showPriceSheet,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Text(
                  '${results.length} properties found',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppTheme.muted,
                ),
                const SizedBox(width: 5),
                const Text(
                  'Local sample listings',
                  style: TextStyle(color: AppTheme.muted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: results.isEmpty
                  ? const _NoResults()
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 700) {
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
                        final columns = constraints.maxWidth >= 1050 ? 3 : 2;
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
      maximumPrice = 1500000;
      selectedAreaId = 'Any';
      selectedType = 'Any';
      selectedTenure = 'Any';
    });
  }

  Future<void> _showPriceSheet() async {
    var draft = maximumPrice;
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
              Text(
                formatRinggit(draft),
                style: const TextStyle(
                  color: AppTheme.blue,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
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
                  setState(() => maximumPrice = draft);
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

  AreaData _areaFor(List<AreaData> areas, String areaId) {
    return areas.firstWhere((area) => area.id == areaId);
  }
}

class _DropdownFilter extends StatelessWidget {
  const _DropdownFilter({
    required this.label,
    required this.values,
    required this.value,
    this.labelFor,
    required this.onChanged,
  });

  final String label;
  final List<String> values;
  final String value;
  final String Function(String value)? labelFor;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (_) => values
          .map(
            (item) => PopupMenuItem(
              value: item,
              child: Text(labelFor?.call(item) ?? item),
            ),
          )
          .toList(),
      child: Chip(
        label: Text(label),
        avatar: const Icon(Icons.expand_more_rounded, size: 18),
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

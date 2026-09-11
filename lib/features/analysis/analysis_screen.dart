import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive_layout.dart';
import '../../core/widgets/app_feedback.dart';
import '../../core/widgets/line_chart.dart';
import '../../core/widgets/metric_card.dart';
import '../../core/widgets/page_container.dart';
import '../../models/area_data.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  String? selectedAreaId;
  String? selectedState;
  String selectedMarketArea = 'Overall';
  String selectedPropertyType = 'All residential';
  String comparisonPropertyType = 'All residential';
  String selectedView = 'Overview';
  bool _initialRefreshScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialRefreshScheduled) return;
    _initialRefreshScheduled = true;
    final state = AppScope.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      state.ensureInitialMarketData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (state.areas.isEmpty) {
      return const Scaffold(
        appBar: _AnalysisAppBar(),
        body: SafeArea(child: _NoAreasAvailable()),
      );
    }
    selectedAreaId ??= state.areas.first.id;
    var area = state.areaFor(selectedAreaId!);
    final states = state.areas.map((item) => item.state).toSet().toList()
      ..sort();
    selectedState ??= area.state;
    var stateDistricts =
        state.areas.where((item) => item.state == selectedState).toList()
          ..sort((left, right) => left.name.compareTo(right.name));
    if (!stateDistricts.any((item) => item.id == selectedAreaId)) {
      selectedAreaId = stateDistricts.first.id;
      area = state.areaFor(selectedAreaId!);
    }
    final sourceMode = state.isUsingLiveAreaProfiles
        ? 'data.gov.my API'
        : state.isUsingMarketTrendCache
        ? 'SQLite cache'
        : state.isUsingCloudAreaProfiles
        ? 'Supabase snapshot'
        : state.isUsingProcessedAreaProfiles
        ? 'processed JSON'
        : 'local sample';
    final refreshMessage = state.governmentDataSyncMessage;
    final refreshFailed =
        state.governmentDataRefreshStatus == DataRefreshStatus.failure;
    return Scaffold(
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'Market trend & analytics',
            maxLines: 1,
            style: TextStyle(fontSize: 18),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _showSources(context),
            tooltip: 'Data sources',
            icon: const Icon(Icons.dataset_outlined),
          ),
          IconButton(
            onPressed: state.isSyncingGovernmentData
                ? null
                : () => _refreshGovernmentData(state),
            tooltip: 'Reload latest government data',
            icon: state.isSyncingGovernmentData
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_sync_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: PageContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final stateSelect = DropdownButtonFormField<String>(
                    initialValue: selectedState,
                    isExpanded: true,
                    menuMaxHeight: 420,
                    decoration: const InputDecoration(
                      labelText: 'State',
                      prefixIcon: Icon(Icons.map_outlined),
                    ),
                    items: states
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(
                              value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null || value == selectedState) return;
                      final districts =
                          state.areas
                              .where((item) => item.state == value)
                              .toList()
                            ..sort(
                              (left, right) => left.name.compareTo(right.name),
                            );
                      setState(() {
                        selectedState = value;
                        selectedAreaId = districts.first.id;
                        selectedMarketArea = 'Overall';
                        selectedPropertyType = 'All residential';
                      });
                    },
                  );
                  final districtSelect = DropdownButtonFormField<String>(
                    key: ValueKey(selectedState),
                    initialValue: selectedAreaId,
                    isExpanded: true,
                    menuMaxHeight: 420,
                    decoration: const InputDecoration(
                      labelText: 'District',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    items: stateDistricts
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() {
                      selectedAreaId = value;
                      selectedMarketArea = 'Overall';
                      selectedPropertyType = 'All residential';
                    }),
                  );
                  final stamp = Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F6EF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.verified_outlined,
                          color: AppTheme.green,
                          size: 19,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            state.isSyncingGovernmentData
                                ? 'Loading latest government data...'
                                : refreshMessage?.startsWith('Data years:') ==
                                      true
                                ? refreshMessage!
                                : area.isGovernmentProfile
                                ? 'Government data via $sourceMode'
                                : 'Local sample snapshot ${area.snapshotDate}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.green,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                  return ResponsiveLayout.isTablet(context)
                      ? Row(
                          children: [
                            Expanded(flex: 2, child: stateSelect),
                            const SizedBox(width: 12),
                            Expanded(flex: 3, child: districtSelect),
                            const SizedBox(width: 12),
                            stamp,
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            stateSelect,
                            const SizedBox(height: 10),
                            districtSelect,
                            const SizedBox(height: 10),
                            stamp,
                          ],
                        );
                },
              ),
              if (refreshFailed) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFECEC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF2B8B5)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFB3261E)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          refreshMessage!,
                          style: const TextStyle(
                            color: Color(0xFFB3261E),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['Overview', 'Price trend', 'District comparison']
                      .map(
                        (label) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(label),
                            selected: selectedView == label,
                            showCheckmark: false,
                            backgroundColor: Colors.white,
                            selectedColor: const Color(0xFFDCEBFF),
                            side: const BorderSide(color: Color(0xFFB8C7DA)),
                            labelStyle: TextStyle(
                              color: selectedView == label
                                  ? AppTheme.blue
                                  : AppTheme.ink,
                              fontWeight: FontWeight.w700,
                            ),
                            onSelected: (_) =>
                                setState(() => selectedView = label),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 22),
              if (selectedView == 'Overview')
                _Overview(
                  area: area,
                  sourceMode: sourceMode,
                  marketArea: selectedMarketArea,
                  onMarketAreaChanged: (value) => setState(() {
                    selectedMarketArea = value;
                    selectedPropertyType = 'All residential';
                  }),
                  propertyType: selectedPropertyType,
                  onPropertyTypeChanged: (value) =>
                      setState(() => selectedPropertyType = value),
                ),
              if (selectedView == 'Price trend')
                _PriceTrend(
                  area: area,
                  marketArea: selectedMarketArea,
                  onMarketAreaChanged: (value) => setState(() {
                    selectedMarketArea = value;
                    selectedPropertyType = 'All residential';
                  }),
                  propertyType: selectedPropertyType,
                  onPropertyTypeChanged: (value) =>
                      setState(() => selectedPropertyType = value),
                ),
              if (selectedView == 'District comparison')
                _DistrictComparison(
                  areas: state.areas,
                  selectedState: area.state,
                  propertyType: comparisonPropertyType,
                  onPropertyTypeChanged: (value) =>
                      setState(() => comparisonPropertyType = value),
                ),
              const SizedBox(height: 22),
              const _DataCaveat(),
            ],
          ),
        ),
      ),
    );
  }

  void _showSources(BuildContext context) {
    const sources = [
      _DataSource(
        'Population by district',
        'data.gov.my - latest available release',
        'https://open.dosm.gov.my/data-catalogue/population_district',
      ),
      _DataSource(
        'Household income by district',
        'data.gov.my - latest available release',
        'https://open.dosm.gov.my/data-catalogue/hh_income_district',
      ),
      _DataSource(
        'Crimes by district and crime type',
        'data.gov.my - latest available release',
        'https://data.gov.my/data-catalogue/crime_district',
      ),
      _DataSource(
        'Public education institutions',
        'data.gov.my - latest available release',
        'https://data.gov.my/data-catalogue/schools_district',
      ),
      _DataSource(
        'Public hospital beds',
        'data.gov.my - latest available release',
        'https://data.gov.my/data-catalogue/hospital_beds',
      ),
      _DataSource(
        'Public transport stops and routes',
        'data.gov.my official GTFS - KTMB and Prasarana',
        'https://developer.data.gov.my/realtime-api/gtfs-static',
      ),
      _DataSource(
        'District residential prices and transactions',
        'NAPIC / JPPH quarterly XLSX publications',
        'https://napic.jpph.gov.my/en/latest-publication',
      ),
      _DataSource(
        'Administrative district boundaries',
        'DOSM official district GeoJSON',
        'https://github.com/dosm-malaysia/data-open/blob/main/datasets/geodata/administrative_2_district.geojson',
      ),
    ];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        minChildSize: 0.42,
        maxChildSize: 0.96,
        builder: (context, scrollController) => SafeArea(
          top: false,
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(
              20,
              2,
              20,
              24 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            children: [
              Text(
                'Official data sources',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Drag the sheet or scroll to view every source. '
                'Tap a source to copy its official URL.',
                style: TextStyle(color: AppTheme.muted),
              ),
              const SizedBox(height: 12),
              ...sources.map(
                (source) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    child: Icon(Icons.table_chart_outlined),
                  ),
                  title: Text(source.name),
                  subtitle: Text(source.detail),
                  trailing: const Icon(Icons.copy_rounded),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: source.url));
                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                      SnackBar(content: Text('${source.name} URL copied')),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refreshGovernmentData(AppState state) async {
    final result = await state.refreshGovernmentData();
    if (!mounted) {
      return;
    }
    showAppSnackBar(
      context,
      message: result.message,
      type: result.succeeded ? AppFeedbackType.success : AppFeedbackType.error,
    );
  }
}

class _DataSource {
  const _DataSource(this.name, this.detail, this.url);

  final String name;
  final String detail;
  final String url;
}

class _AnalysisAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AnalysisAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          'Market trend & analytics',
          maxLines: 1,
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}

class _NoAreasAvailable extends StatelessWidget {
  const _NoAreasAvailable();

  @override
  Widget build(BuildContext context) {
    return PageContainer(
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, color: AppTheme.muted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No area profiles are available yet. Refresh official data or check the Supabase configuration.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppTheme.muted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({
    required this.area,
    required this.sourceMode,
    required this.marketArea,
    required this.onMarketAreaChanged,
    required this.propertyType,
    required this.onPropertyTypeChanged,
  });

  final AreaData area;
  final String sourceMode;
  final String marketArea;
  final ValueChanged<String> onMarketAreaChanged;
  final String propertyType;
  final ValueChanged<String> onPropertyTypeChanged;

  @override
  Widget build(BuildContext context) {
    final marketAreas = <String>{'Overall', ...area.marketAreas}.toList();
    final activeMarketArea = marketAreas.contains(marketArea)
        ? marketArea
        : 'Overall';
    final priceTypes = <String>{
      'All residential',
      ...area.propertyTypesForMarketArea(activeMarketArea),
    }.toList();
    final activeType = priceTypes.contains(propertyType)
        ? propertyType
        : 'All residential';
    final latestPrice = area.latestPriceFor(
      activeType,
      marketArea: activeMarketArea,
    );
    final priceValues = area.priceHistoryFor(
      activeType,
      marketArea: activeMarketArea,
    );
    final pricePeriods = area.pricePeriodsFor(
      activeType,
      marketArea: activeMarketArea,
    );
    final priceGrowth = area.priceGrowthFor(
      activeType,
      marketArea: activeMarketArea,
    );
    final infrastructureScore = area.infrastructureScore;
    final cards = [
      MetricCard(
        label: 'Population',
        value: area.population == null
            ? 'Unavailable'
            : formatCount(area.population!),
        trend: _yearLabel('Year', area.populationYear),
        icon: Icons.groups_2_outlined,
      ),
      MetricCard(
        label: 'Median household income',
        value: area.medianIncome == null
            ? 'Unavailable'
            : formatRinggit(area.medianIncome!),
        trend: _yearLabel('Year', area.incomeYear),
        icon: Icons.account_balance_wallet_outlined,
        color: AppTheme.teal,
      ),
      MetricCard(
        label: 'Normalized safety',
        value: area.safetyScore == null
            ? 'Unavailable'
            : '${area.safetyScore!.round()}/100',
        trend: area.crimeYear == null
            ? 'No crime data reference'
            : 'Crime data ${area.crimeYear}',
        icon: Icons.shield_outlined,
        color: const Color(0xFF7758C8),
      ),
      MetricCard(
        label: 'Infrastructure',
        value: infrastructureScore == null
            ? 'Unavailable'
            : '${infrastructureScore.round()}/100',
        trend: [
          area.schools == null || area.educationYear == null
              ? 'schools unavailable'
              : '${area.schools} schools (${area.educationYear})',
          area.hospitalBeds == null || area.hospitalYear == null
              ? 'hospital beds unavailable'
              : '${area.hospitalBeds} beds (${area.hospitalYear})',
          area.transportStopCount == null || area.transportYear == null
              ? 'transport unavailable'
              : '${area.transportStopCount} transport stops '
                    '(${area.transportYear})',
        ].join(', '),
        icon: Icons.hub_outlined,
        color: AppTheme.green,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${area.name} at a glance',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        const Text(
          'Normalized indicators make different public datasets easier to compare.',
          style: TextStyle(color: AppTheme.muted),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = ResponsiveLayout.isTablet(context) ? 4 : 1;
            final width =
                (constraints.maxWidth - (columns - 1) * 12)
                    .clamp(0.0, double.infinity)
                    .toDouble() /
                columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: cards
                  .map((card) => SizedBox(width: width, child: card))
                  .toList(),
            );
          },
        ),
        const SizedBox(height: 14),
        _SourceSummary(area: area, sourceMode: sourceMode),
        const SizedBox(height: 22),
        _PriceFilters(
          marketArea: activeMarketArea,
          marketAreas: marketAreas,
          onMarketAreaChanged: onMarketAreaChanged,
          propertyType: activeType,
          propertyTypes: priceTypes,
          onPropertyTypeChanged: onPropertyTypeChanged,
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final price = latestPrice != null
                ? _ChartCard(
                    title: 'Historical price indicator',
                    subtitle:
                        'NAPIC $activeMarketArea - $activeType median (RM/unit)',
                    value: formatRinggit(latestPrice.round()),
                    trend: priceGrowth == null
                        ? 'More quarters required'
                        : '${priceGrowth >= 0 ? '+' : ''}'
                              '${priceGrowth.toStringAsFixed(1)}%',
                    values: priceValues,
                    labels: pricePeriods,
                  )
                : const _UnavailableCard(
                    title: 'Historical price indicator',
                    message:
                        'No NAPIC property-type data reference is available '
                        'for this district.',
                  );
            final demand = _DemandCard(area: area);
            return ResponsiveLayout.isTablet(context)
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: price),
                      const SizedBox(width: 14),
                      Expanded(flex: 2, child: demand),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [price, const SizedBox(height: 14), demand],
                  );
          },
        ),
      ],
    );
  }

  String _yearLabel(String label, int? year) {
    return year == null ? 'Year unavailable' : '$label $year';
  }
}

class _PriceFilters extends StatelessWidget {
  const _PriceFilters({
    required this.marketArea,
    required this.marketAreas,
    required this.onMarketAreaChanged,
    required this.propertyType,
    required this.propertyTypes,
    required this.onPropertyTypeChanged,
  });

  final String marketArea;
  final List<String> marketAreas;
  final ValueChanged<String> onMarketAreaChanged;
  final String propertyType;
  final List<String> propertyTypes;
  final ValueChanged<String> onPropertyTypeChanged;

  @override
  Widget build(BuildContext context) {
    final marketFilter = DropdownButtonFormField<String>(
      key: ValueKey('market-area-$marketArea'),
      initialValue: marketArea,
      isExpanded: true,
      menuMaxHeight: 420,
      decoration: const InputDecoration(
        labelText: 'NAPIC market area',
        prefixIcon: Icon(Icons.location_city_outlined),
      ),
      disabledHint: Text(
        marketArea,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppTheme.ink),
      ),
      items: marketAreas
          .map(
            (option) => DropdownMenuItem(
              value: option,
              child: Text(option, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: marketAreas.length <= 1
          ? null
          : (selected) {
              if (selected != null) onMarketAreaChanged(selected);
            },
    );
    final typeFilter = _PropertyTypeFilter(
      value: propertyType,
      options: propertyTypes,
      onChanged: onPropertyTypeChanged,
    );
    return LayoutBuilder(
      builder: (context, constraints) => ResponsiveLayout.isTablet(context)
          ? Row(
              children: [
                Expanded(child: marketFilter),
                const SizedBox(width: 12),
                Expanded(child: typeFilter),
              ],
            )
          : Column(
              children: [marketFilter, const SizedBox(height: 12), typeFilter],
            ),
    );
  }
}

class _PropertyTypeFilter extends StatelessWidget {
  const _PropertyTypeFilter({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: ValueKey('property-type-$value'),
      initialValue: value,
      isExpanded: true,
      menuMaxHeight: 420,
      decoration: const InputDecoration(
        labelText: 'Property type',
        prefixIcon: Icon(Icons.home_work_outlined),
      ),
      disabledHint: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppTheme.ink),
      ),
      items: options
          .map(
            (option) => DropdownMenuItem(
              value: option,
              child: Text(option, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: options.length <= 1
          ? null
          : (selected) {
              if (selected != null) onChanged(selected);
            },
    );
  }
}

class _SourceSummary extends StatelessWidget {
  const _SourceSummary({required this.area, required this.sourceMode});

  final AreaData area;
  final String sourceMode;

  @override
  Widget build(BuildContext context) {
    final retrieved = area.retrievedAt;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE3E9F2)),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 8,
        children: [
          _SourceItem(label: 'Data mode', value: sourceMode),
          _SourceItem(label: 'Source', value: area.source),
          _SourceItem(
            label: 'Latest year',
            value: area.snapshotDate ?? 'Unavailable',
          ),
          _SourceItem(
            label: 'Retrieved',
            value: retrieved == null
                ? 'Unavailable'
                : retrieved.toLocal().toString().split('.').first,
          ),
        ],
      ),
    );
  }
}

class _SourceItem extends StatelessWidget {
  const _SourceItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppTheme.muted, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _PriceTrend extends StatelessWidget {
  const _PriceTrend({
    required this.area,
    required this.marketArea,
    required this.onMarketAreaChanged,
    required this.propertyType,
    required this.onPropertyTypeChanged,
  });

  final AreaData area;
  final String marketArea;
  final ValueChanged<String> onMarketAreaChanged;
  final String propertyType;
  final ValueChanged<String> onPropertyTypeChanged;

  @override
  Widget build(BuildContext context) {
    final marketAreas = <String>{'Overall', ...area.marketAreas}.toList();
    final activeMarketArea = marketAreas.contains(marketArea)
        ? marketArea
        : 'Overall';
    final options = <String>{
      'All residential',
      ...area.propertyTypesForMarketArea(activeMarketArea),
    }.toList();
    final activeType = options.contains(propertyType)
        ? propertyType
        : 'All residential';
    final values = area.priceHistoryFor(
      activeType,
      marketArea: activeMarketArea,
    );
    final periods = area.pricePeriodsFor(
      activeType,
      marketArea: activeMarketArea,
    );
    final latestPrice = area.latestPriceFor(
      activeType,
      marketArea: activeMarketArea,
    );
    final changePercent = values.length >= 2 && values.first != 0
        ? (values.last - values.first) / values.first * 100
        : null;
    final latestGrowth = area.priceGrowthFor(
      activeType,
      marketArea: activeMarketArea,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${area.name} price trend',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        const Text(
          'Official NAPIC quarterly district price snapshots.',
          style: TextStyle(color: AppTheme.muted),
        ),
        const SizedBox(height: 16),
        _PriceFilters(
          marketArea: activeMarketArea,
          marketAreas: marketAreas,
          onMarketAreaChanged: onMarketAreaChanged,
          propertyType: activeType,
          propertyTypes: options,
          onPropertyTypeChanged: onPropertyTypeChanged,
        ),
        const SizedBox(height: 14),
        if (latestPrice == null)
          const _UnavailableCard(
            title: 'Historical price indicator',
            message:
                'No NAPIC property-type data reference is available for '
                'this district.',
          )
        else ...[
          _ChartCard(
            title: 'Historical price indicator',
            subtitle: 'NAPIC $activeMarketArea - $activeType median (RM/unit)',
            value: formatRinggit(latestPrice.round()),
            trend: changePercent == null
                ? 'More quarters required'
                : '${changePercent >= 0 ? '+' : ''}'
                      '${changePercent.toStringAsFixed(1)}% over the period',
            values: values,
            labels: periods,
            large: true,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SmallStat(
                  label: 'Latest quarterly price signal',
                  value: latestGrowth == null
                      ? 'Unavailable'
                      : '${latestGrowth >= 0 ? '+' : ''}'
                            '${latestGrowth.toStringAsFixed(1)}%',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SmallStat(
                  label: 'Latest NAPIC price period',
                  value: periods.isEmpty ? 'Unavailable' : periods.last,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _DistrictComparison extends StatelessWidget {
  const _DistrictComparison({
    required this.areas,
    required this.selectedState,
    required this.propertyType,
    required this.onPropertyTypeChanged,
  });

  final List<AreaData> areas;
  final String selectedState;
  final String propertyType;
  final ValueChanged<String> onPropertyTypeChanged;

  @override
  Widget build(BuildContext context) {
    final stateAreas = areas
        .where((area) => area.state == selectedState)
        .toList();
    final typeOptions =
        <String>{
          'All residential',
          for (final area in stateAreas) ...area.marketPropertyTypes,
        }.toList()..sort((left, right) {
          if (left == 'All residential') return -1;
          if (right == 'All residential') return 1;
          return left.compareTo(right);
        });
    final activeType = typeOptions.contains(propertyType)
        ? propertyType
        : 'All residential';
    final ranked = [...stateAreas]
      ..sort(
        (left, right) => (right.priceGrowthFor(activeType) ?? -999).compareTo(
          left.priceGrowthFor(activeType) ?? -999,
        ),
      );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'District comparison',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        const Text(
          'Compare districts in the selected state by residential property type.',
          style: TextStyle(color: AppTheme.muted),
        ),
        const SizedBox(height: 16),
        _PropertyTypeFilter(
          value: activeType,
          options: typeOptions,
          onChanged: onPropertyTypeChanged,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                const _ComparisonLegend(),
                const SizedBox(height: 18),
                ...ranked.map(
                  (area) => _AreaBars(area: area, propertyType: activeType),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (ResponsiveLayout.isPhone(context) &&
            !ResponsiveLayout.isLandscape(context))
          ...ranked.map(
            (area) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DistrictComparisonCard(
                area: area,
                propertyType: activeType,
              ),
            ),
          )
        else
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('District')),
                  DataColumn(label: Text('Price indicator')),
                  DataColumn(label: Text('Price period')),
                  DataColumn(label: Text('Population')),
                  DataColumn(label: Text('Median income')),
                ],
                rows: ranked.map((area) {
                  final price = area.latestPriceFor(activeType);
                  final periods = area.pricePeriodsFor(activeType);
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          area.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      DataCell(
                        Text(
                          price == null
                              ? 'Unavailable'
                              : formatRinggit(price.round()),
                        ),
                      ),
                      DataCell(
                        Text(periods.isEmpty ? 'Unavailable' : periods.last),
                      ),
                      DataCell(
                        Text(
                          area.population == null
                              ? 'Unavailable'
                              : formatCount(area.population!),
                        ),
                      ),
                      DataCell(
                        Text(
                          area.medianIncome == null
                              ? 'Unavailable'
                              : formatRinggit(area.medianIncome!),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }
}

class _DistrictComparisonCard extends StatelessWidget {
  const _DistrictComparisonCard({
    required this.area,
    required this.propertyType,
  });

  final AreaData area;
  final String propertyType;

  @override
  Widget build(BuildContext context) {
    final price = area.latestPriceFor(propertyType);
    final periods = area.pricePeriodsFor(propertyType);
    final values = [
      (
        label: 'Price indicator',
        value: price == null ? 'Unavailable' : formatRinggit(price.round()),
      ),
      (
        label: 'Price period',
        value: periods.isEmpty ? 'Unavailable' : periods.last,
      ),
      (
        label: 'Population',
        value: area.population == null
            ? 'Unavailable'
            : formatCount(area.population!),
      ),
      (
        label: 'Median income',
        value: area.medianIncome == null
            ? 'Unavailable'
            : formatRinggit(area.medianIncome!),
      ),
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              area.name,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 14,
                  children: [
                    for (final item in values)
                      SizedBox(
                        width: itemWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.label,
                              style: const TextStyle(
                                color: AppTheme.muted,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.value,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.trend,
    required this.values,
    this.large = false,
    this.labels = const [],
  });

  final String title;
  final String subtitle;
  final String value;
  final String trend;
  final List<double> values;
  final bool large;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            Text(
              subtitle,
              style: const TextStyle(color: AppTheme.muted, fontSize: 11),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(value, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F6EF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    trend,
                    style: const TextStyle(
                      color: AppTheme.green,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (values.length >= 2)
              SimpleLineChart(
                values: values,
                labels: labels,
                height: large ? 300 : 205,
              )
            else
              Container(
                height: large ? 150 : 110,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F8FB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'At least two quarterly snapshots are required '
                    'to draw a price trend.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.muted),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DemandCard extends StatelessWidget {
  const _DemandCard({required this.area});

  final AreaData area;

  @override
  Widget build(BuildContext context) {
    final demand = area.marketDemandScore;
    if (demand == null) {
      return const _UnavailableCard(
        title: 'Market demand signal',
        message:
            'No complete NAPIC district transaction reference is available.',
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Market demand signal',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 18),
            Center(
              child: SizedBox(
                width: 150,
                height: 150,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: demand / 100,
                      strokeWidth: 14,
                      backgroundColor: const Color(0xFFE6ECF3),
                      color: AppTheme.teal,
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${demand.round()}',
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Text(
                            'out of 100',
                            style: TextStyle(
                              color: AppTheme.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _DemandInterpretation(score: demand),
            const SizedBox(height: 20),
            _SignalRow(
              label:
                  'Transaction volume '
                  '(${_signed(area.transactionVolumeGrowth)} YoY)',
              value: _growthSignal(area.transactionVolumeGrowth),
            ),
            _SignalRow(
              label:
                  'Transaction value '
                  '(${_signed(area.transactionValueGrowth)} YoY)',
              value: _growthSignal(area.transactionValueGrowth),
            ),
            const Text(
              'Momentum score: 60% transaction-volume growth + 40% '
              'transaction-value growth. Each rate is capped from -20% '
              'to +20%; it does not measure market size.',
              style: TextStyle(color: AppTheme.muted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  String _signed(double? value) {
    if (value == null) return 'Unavailable';
    return '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}%';
  }

  double _growthSignal(double? value) {
    if (value == null) return 0;
    return ((value.clamp(-20, 20) + 20) / 40).toDouble();
  }
}

class _DemandInterpretation extends StatelessWidget {
  const _DemandInterpretation({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    final current = _meaningFor(score);
    const ranges = [
      ('0-24', 'Significant demand decline'),
      ('25-44', 'Weak demand'),
      ('45-55', 'Broadly stable'),
      ('56-74', 'Growing demand'),
      ('75-100', 'Strong demand growth'),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE3E9F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How to read this score',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            'Current signal: $current',
            style: const TextStyle(
              color: AppTheme.teal,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'It measures year-over-year residential transaction momentum, '
            'not total market demand or market size. A score near 50 means '
            'activity is broadly unchanged.',
            style: TextStyle(color: AppTheme.muted, fontSize: 11),
          ),
          const SizedBox(height: 10),
          ...ranges.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 58,
                    child: Text(
                      item.$1,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.$2,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'This is a market activity indicator, not an investment guarantee.',
            style: TextStyle(color: AppTheme.muted, fontSize: 10),
          ),
        ],
      ),
    );
  }

  String _meaningFor(double value) {
    if (value <= 24) return 'Significant demand decline';
    if (value <= 44) return 'Weak demand';
    if (value <= 55) return 'Broadly stable';
    if (value <= 74) return 'Growing demand';
    return 'Strong demand growth';
  }
}

class _UnavailableCard extends StatelessWidget {
  const _UnavailableCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(color: AppTheme.muted)),
          ],
        ),
      ),
    );
  }
}

class _SignalRow extends StatelessWidget {
  const _SignalRow({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11)),
          const SizedBox(height: 5),
          LinearProgressIndicator(
            value: value.clamp(0, 1).toDouble(),
            minHeight: 7,
            color: AppTheme.teal,
            backgroundColor: const Color(0xFFE6ECF3),
            borderRadius: BorderRadius.circular(7),
          ),
        ],
      ),
    );
  }
}

class _SmallStat extends StatelessWidget {
  const _SmallStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 5),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.muted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonLegend extends StatelessWidget {
  const _ComparisonLegend();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _Legend(color: AppTheme.blue, label: 'Price growth'),
        _Legend(color: AppTheme.green, label: 'Safety'),
        _Legend(color: AppTheme.teal, label: 'Infrastructure'),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.muted),
        ),
      ],
    );
  }
}

class _AreaBars extends StatelessWidget {
  const _AreaBars({required this.area, required this.propertyType});

  final AreaData area;
  final String propertyType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              area.name,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                area.priceGrowthFor(propertyType) == null
                    ? const SizedBox(
                        height: 8,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Price unavailable',
                            style: TextStyle(
                              color: AppTheme.muted,
                              fontSize: 8,
                            ),
                          ),
                        ),
                      )
                    : _Bar(
                        value: area.priceGrowthFor(propertyType)! / 10,
                        color: AppTheme.blue,
                      ),
                const SizedBox(height: 4),
                area.crimeYear == null
                    ? const SizedBox(
                        height: 8,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Safety unavailable - no data reference',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.muted,
                              fontSize: 8,
                            ),
                          ),
                        ),
                      )
                    : _Bar(
                        value: area.safetyScore == null
                            ? 0
                            : area.safetyScore! / 100,
                        color: AppTheme.green,
                      ),
                const SizedBox(height: 4),
                area.infrastructureScore == null
                    ? const SizedBox(
                        height: 8,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Infrastructure unavailable',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.muted,
                              fontSize: 8,
                            ),
                          ),
                        ),
                      )
                    : _Bar(
                        value: area.infrastructureScore! / 100,
                        color: AppTheme.teal,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: value.clamp(0, 1).toDouble(),
      minHeight: 8,
      borderRadius: BorderRadius.circular(8),
      color: color,
      backgroundColor: const Color(0xFFE7ECF3),
    );
  }
}

class _DataCaveat extends StatelessWidget {
  const _DataCaveat();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppTheme.blue),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Safety converts annual reported crimes per 100,000 '
              'residents to a 0-100 indicator (0 crimes = 100; 2,000 or '
              'more = 0). Police and administrative districts may not match '
              'exactly. Infrastructure combines schools (35%), public '
              'hospital beds (35%), and official GTFS stops (30%), all per '
              '10,000 residents. A total is shown only when all three dated '
              'sources are available.',
              style: TextStyle(color: AppTheme.navy, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

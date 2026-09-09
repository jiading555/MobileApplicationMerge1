import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
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
  String? comparisonState;
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
    selectedAreaId ??= state.areas.first.id;
    var area = state.areaFor(selectedAreaId!);
    final states = state.areas.map((item) => item.state).toSet().toList()
      ..sort();
    selectedState ??= area.state;
    var stateDistricts = state.areas
        .where((item) => item.state == selectedState)
        .toList()
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
    final refreshFailed = refreshMessage?.startsWith('Refresh failed.') ?? false;
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
                      final districts = state.areas
                          .where((item) => item.state == value)
                          .toList()
                        ..sort(
                          (left, right) => left.name.compareTo(right.name),
                        );
                      setState(() {
                        selectedState = value;
                        selectedAreaId = districts.first.id;
                      });
                    },
                  );
                  final districtSelect =
                      DropdownButtonFormField<String>(
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
                    onChanged: (value) =>
                        setState(() => selectedAreaId = value),
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
                  return constraints.maxWidth >= 900
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
                      const Icon(
                        Icons.error_outline,
                        color: Color(0xFFB3261E),
                      ),
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
                            side: const BorderSide(
                              color: Color(0xFFB8C7DA),
                            ),
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
                _Overview(area: area, sourceMode: sourceMode),
              if (selectedView == 'Price trend') _PriceTrend(area: area),
              if (selectedView == 'District comparison')
                _DistrictComparison(
                  areas: state.areas,
                  selectedState: comparisonState ?? area.state,
                  onStateChanged: (value) =>
                      setState(() => comparisonState = value),
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
    await state.refreshGovernmentData();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          state.governmentDataSyncMessage ?? 'Government data refresh done.',
        ),
      ),
    );
  }
}

class _DataSource {
  const _DataSource(this.name, this.detail, this.url);

  final String name;
  final String detail;
  final String url;
}

class _Overview extends StatelessWidget {
  const _Overview({required this.area, required this.sourceMode});

  final AreaData area;
  final String sourceMode;

  @override
  Widget build(BuildContext context) {
    final cards = [
      MetricCard(
        label: 'Population',
        value: area.populationYear == null
            ? 'Unavailable'
            : formatCount(area.population),
        trend: _yearLabel('Year', area.populationYear),
        icon: Icons.groups_2_outlined,
      ),
      MetricCard(
        label: 'Median household income',
        value: area.incomeYear == null
            ? 'Unavailable'
            : formatRinggit(area.medianIncome),
        trend: _yearLabel('Year', area.incomeYear),
        icon: Icons.account_balance_wallet_outlined,
        color: AppTheme.teal,
      ),
      MetricCard(
        label: 'Normalized safety',
        value: area.crimeYear == null
            ? 'Unavailable'
            : '${area.safetyScore.round()}/100',
        trend: area.crimeYear == null
            ? 'No crime data reference'
            : 'Crime data ${area.crimeYear}',
        icon: Icons.shield_outlined,
        color: const Color(0xFF7758C8),
      ),
      MetricCard(
        label: 'Infrastructure',
        value: area.educationYear == null &&
                area.hospitalYear == null &&
                area.transportYear == null
            ? 'Unavailable'
            : '${area.infrastructureScore.round()}/100',
        trend: area.educationYear == null
            ? '${area.schools} schools, ${area.hospitalBeds} hospital beds'
            : '${area.schools} schools (${area.educationYear}), '
                  '${area.hospitalBeds} beds'
                  '${area.hospitalYear == null ? '' : ' (${area.hospitalYear})'}, '
                  '${area.transportStopCount} transport stops'
                  '${area.transportYear == null ? '' : ' (${area.transportYear})'}',
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
            final columns = constraints.maxWidth >= 900
                ? 4
                : constraints.maxWidth >= 560
                ? 2
                : 1;
            final width = (constraints.maxWidth - (columns - 1) * 12)
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
        LayoutBuilder(
          builder: (context, constraints) {
            final price = area.hasMarketPrice
                ? _ChartCard(
                    title: 'Historical price indicator',
                    subtitle:
                        'NAPIC sample-weighted district median (RM/unit)',
                    value: formatRinggit(
                      area.medianResidentialPrice!.round(),
                    ),
                    trend: area.hasMarketHistory
                        ? '${area.priceGrowth >= 0 ? '+' : ''}'
                              '${area.priceGrowth.toStringAsFixed(1)}%'
                        : '1 quarter collected',
                    values: area.priceHistory,
                    labels: area.marketPricePeriods,
                  )
                : const _UnavailableCard(
                    title: 'Historical price indicator',
                    message:
                        'No NAPIC district data reference is available for '
                        'this district.',
                  );
            final demand = _DemandCard(area: area);
            return constraints.maxWidth >= 820
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: price),
                      const SizedBox(width: 14),
                      Expanded(flex: 2, child: demand),
                    ],
                  )
                : Column(children: [price, const SizedBox(height: 14), demand]);
          },
        ),
      ],
    );
  }

  String _yearLabel(String label, int? year) {
    return year == null ? 'Year unavailable' : '$label $year';
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
          _SourceItem(label: 'Latest year', value: area.snapshotDate),
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
  const _PriceTrend({required this.area});

  final AreaData area;

  @override
  Widget build(BuildContext context) {
    if (!area.hasMarketPrice) {
      return const _UnavailableCard(
        title: 'Historical price indicator',
        message:
            'No NAPIC district data reference is available for this district.',
      );
    }
    final changePercent = area.hasMarketHistory
        ? (area.priceHistory.last - area.priceHistory.first) /
              area.priceHistory.first *
              100
        : null;
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
        _ChartCard(
          title: 'Historical price indicator',
          subtitle: 'NAPIC sample-weighted district median (RM/unit)',
          value: formatRinggit(area.medianResidentialPrice!.round()),
          trend: changePercent == null
              ? 'More quarters required'
              : '${changePercent >= 0 ? '+' : ''}'
                    '${changePercent.toStringAsFixed(1)}% over the period',
          values: area.priceHistory,
          labels: area.marketPricePeriods,
          large: true,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _SmallStat(
                label: 'Latest quarterly price signal',
                value: area.hasMarketHistory
                    ? '${area.priceGrowth >= 0 ? '+' : ''}'
                          '${area.priceGrowth.toStringAsFixed(1)}%'
                    : 'Unavailable',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SmallStat(
                label: 'Latest NAPIC period',
                value: area.marketPeriod ?? 'Unavailable',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DistrictComparison extends StatelessWidget {
  const _DistrictComparison({
    required this.areas,
    required this.selectedState,
    required this.onStateChanged,
  });

  final List<AreaData> areas;
  final String selectedState;
  final ValueChanged<String> onStateChanged;

  @override
  Widget build(BuildContext context) {
    final states = areas.map((area) => area.state).toSet().toList()..sort();
    final activeState = states.contains(selectedState)
        ? selectedState
        : states.first;
    final ranked = areas.where((area) => area.state == activeState).toList()
      ..sort((left, right) => right.priceGrowth.compareTo(left.priceGrowth));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'District comparison',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        const Text(
          'Compare districts within one state using NAPIC and public-data metrics.',
          style: TextStyle(color: AppTheme.muted),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: activeState,
          isExpanded: true,
          menuMaxHeight: 420,
          decoration: const InputDecoration(
            labelText: 'Filter by state',
            prefixIcon: Icon(Icons.filter_alt_outlined),
          ),
          items: states
              .map(
                (state) => DropdownMenuItem(
                  value: state,
                  child: Text(
                    state,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) onStateChanged(value);
          },
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                const _ComparisonLegend(),
                const SizedBox(height: 18),
                ...ranked.map((area) => _AreaBars(area: area)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('District')),
                DataColumn(label: Text('Median price indicator')),
                DataColumn(label: Text('Market period')),
                DataColumn(label: Text('Population')),
                DataColumn(label: Text('Median income')),
              ],
              rows: ranked
                  .map(
                    (area) => DataRow(
                      cells: [
                        DataCell(
                          Text(
                            area.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        DataCell(
                          Text(
                            area.hasMarketPrice
                                ? formatRinggit(
                                    area.medianResidentialPrice!.round(),
                                  )
                                : 'Unavailable',
                          ),
                        ),
                        DataCell(Text(area.marketPeriod ?? 'Unavailable')),
                        DataCell(
                          Text(
                            area.populationYear == null
                                ? 'Unavailable'
                                : formatCount(area.population),
                          ),
                        ),
                        DataCell(
                          Text(
                            area.incomeYear == null
                                ? 'Unavailable'
                                : formatRinggit(area.medianIncome),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
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
              'Score: 60% volume growth + 40% value growth. '
              'Each growth rate is capped from -20% to +20%.',
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
      ('0–24', 'Significant demand decline'),
      ('25–44', 'Weak demand'),
      ('45–55', 'Broadly stable'),
      ('56–74', 'Growing demand'),
      ('75–100', 'Strong demand growth'),
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
            'It measures year-over-year residential transaction activity. '
            'A score near 50 means activity is broadly unchanged.',
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
  const _AreaBars({required this.area});

  final AreaData area;

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
                _Bar(value: area.priceGrowth / 10, color: AppTheme.blue),
                const SizedBox(height: 4),
                area.crimeYear == null
                    ? const SizedBox(
                        height: 8,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Safety unavailable — no data reference',
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
                        value: area.safetyScore / 100,
                        color: AppTheme.green,
                      ),
                const SizedBox(height: 4),
                _Bar(
                  value: area.infrastructureScore / 100,
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
              'Police districts and administrative districts are not always identical. Infrastructure combines schools (35%), hospital beds (35%), and official GTFS public-transport stops (30%), adjusted per 10,000 residents. Missing sources are excluded and the available weights are rescaled.',
              style: TextStyle(color: AppTheme.navy, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

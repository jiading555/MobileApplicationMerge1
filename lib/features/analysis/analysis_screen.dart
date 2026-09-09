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
  String selectedView = 'Overview';
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    selectedAreaId ??= state.areas.first.id;
    final area = state.areaFor(selectedAreaId!);
    final sourceMode = state.isUsingLiveAreaProfiles
        ? 'data.gov.my API'
        : state.isUsingCloudAreaProfiles
        ? 'Supabase snapshot'
        : state.isUsingProcessedAreaProfiles
        ? 'processed JSON'
        : 'local sample';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Market trend & analytics'),
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
                  final select = DropdownButtonFormField<String>(
                    initialValue: selectedAreaId,
                    decoration: const InputDecoration(
                      labelText: 'Selected district',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    items: state.areas
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text('${item.name}, ${item.state}'),
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
                  return constraints.maxWidth >= 720
                      ? Row(
                          children: [
                            Expanded(child: select),
                            const SizedBox(width: 12),
                            stamp,
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [select, const SizedBox(height: 10), stamp],
                        );
                },
              ),
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
                _DistrictComparison(areas: state.areas),
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
    ];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Official data sources',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
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
                    ScaffoldMessenger.of(context).showSnackBar(
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
        value: formatCount(area.population),
        trend: _yearLabel('Year', area.populationYear),
        icon: Icons.groups_2_outlined,
      ),
      MetricCard(
        label: 'Median household income',
        value: formatRinggit(area.medianIncome),
        trend: _yearLabel('Year', area.incomeYear),
        icon: Icons.account_balance_wallet_outlined,
        color: AppTheme.teal,
      ),
      MetricCard(
        label: 'Normalized safety',
        value: '${area.safetyScore.round()}/100',
        trend: area.crimeYear == null
            ? 'Compared signal'
            : 'Crime data ${area.crimeYear}',
        icon: Icons.shield_outlined,
        color: const Color(0xFF7758C8),
      ),
      MetricCard(
        label: 'Infrastructure',
        value: '${area.infrastructureScore.round()}/100',
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
            final price = _ChartCard(
              title: 'Historical price indicator',
              subtitle: 'Average RM per square foot - 2018-2024',
              value: '${formatRinggit(area.averagePricePsf)} psf',
              trend: '+${area.priceGrowth.toStringAsFixed(1)}%',
              values: area.priceHistory,
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
    final change = area.priceHistory.last - area.priceHistory.first;
    final changePercent = change / area.priceHistory.first * 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${area.name} price trend',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        const Text(
          'Historical sample series, normalized to RM per square foot.',
          style: TextStyle(color: AppTheme.muted),
        ),
        const SizedBox(height: 16),
        _ChartCard(
          title: 'Average transacted-price indicator',
          subtitle: '2018-2024 snapshot series',
          value: '${formatRinggit(area.averagePricePsf)} psf',
          trend: '+${changePercent.toStringAsFixed(1)}% over the period',
          values: area.priceHistory,
          large: true,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _SmallStat(
                label: 'Latest annual signal',
                value: '+${area.priceGrowth.toStringAsFixed(1)}%',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SmallStat(
                label: 'Rental yield estimate',
                value: '${area.rentalYield.toStringAsFixed(1)}%',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DistrictComparison extends StatelessWidget {
  const _DistrictComparison({required this.areas});

  final List<AreaData> areas;

  @override
  Widget build(BuildContext context) {
    final ranked = [...areas]
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
          'Compare price growth, safety and infrastructure on the same normalized scale.',
          style: TextStyle(color: AppTheme.muted),
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
                DataColumn(label: Text('Avg. price')),
                DataColumn(label: Text('Rental yield')),
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
                          Text('${formatRinggit(area.averagePricePsf)} psf'),
                        ),
                        DataCell(
                          Text('${area.rentalYield.toStringAsFixed(1)}%'),
                        ),
                        DataCell(Text(formatCount(area.population))),
                        DataCell(Text(formatRinggit(area.medianIncome))),
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
  });

  final String title;
  final String subtitle;
  final String value;
  final String trend;
  final List<double> values;
  final bool large;

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
            SimpleLineChart(values: values, height: large ? 300 : 205),
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
    final demand =
        ((area.populationGrowth * 9) +
                (area.rentalYield * 8) +
                (area.transportScore * 0.28))
            .clamp(0, 100)
            .toDouble();
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
            const SizedBox(height: 20),
            _SignalRow(
              label: 'Population growth',
              value: area.populationGrowth / 6,
            ),
            _SignalRow(label: 'Rental yield', value: area.rentalYield / 6),
            _SignalRow(
              label: 'Public transport',
              value: area.transportScore / 100,
            ),
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
                _Bar(value: area.safetyScore / 100, color: AppTheme.green),
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

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive_layout.dart';
import '../../core/widgets/page_container.dart';
import '../../core/widgets/property_art.dart';
import '../../models/property.dart';
import '../../models/recommendation.dart';

class PropertyDetailScreen extends StatelessWidget {
  const PropertyDetailScreen({required this.propertyId, super.key});

  final String propertyId;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final property = state.properties.firstWhere(
      (item) => item.id == propertyId,
    );
    final area = state.matchedAreaFor(property);
    PropertyRecommendation? recommendation;
    for (final item in state.recommendations) {
      if (item.property.id == property.id) {
        recommendation = item;
      }
    }
    final priceInfo = _priceInfo(property);
    final pricePerSqft = property.pricePerSqft;
    final tenureText = _tenureText(property);
    final propertyTypeText = _propertyTypeText(property);
    final hasMatchedAreaProfile = area?.isGovernmentProfile ?? false;
    final hasAreaSignals =
        area?.safetyScore != null ||
        area?.infrastructureScore != null ||
        area?.priceGrowth != null ||
        area?.rentalYield != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Property details'),
        actions: [
          ValueListenableBuilder<Set<String>>(
            valueListenable: state.favouriteIdsListenable,
            builder: (context, favouriteIds, _) {
              final isFavourite = favouriteIds.contains(property.id);
              return IconButton(
                onPressed: () => state.toggleFavourite(property.id),
                icon: Icon(
                  isFavourite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isFavourite ? const Color(0xFFE54865) : AppTheme.ink,
                ),
              );
            },
          ),
          IconButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Share preview prepared.')),
            ),
            icon: const Icon(Icons.share_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: PageContainer(
          maxWidth: 1000,
          child: SelectionArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = ResponsiveLayout.isTablet(context);
                final visual = PropertyArt(
                  palette: property.palette,
                  height: wide ? 430 : 250,
                );
                final details = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.name,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: AppTheme.muted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            property.address,
                            style: const TextStyle(color: AppTheme.muted),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (priceInfo.label != null) ...[
                      Text(
                        priceInfo.label!,
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      priceInfo.value,
                      style: const TextStyle(
                        color: AppTheme.green,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (pricePerSqft != null && tenureText != null)
                      Text(
                        '${formatRinggit(pricePerSqft.round())} psf - $tenureText',
                        style: const TextStyle(color: AppTheme.muted),
                      )
                    else if (pricePerSqft != null)
                      Text(
                        '${formatRinggit(pricePerSqft.round())} psf',
                        style: const TextStyle(color: AppTheme.muted),
                      )
                    else if (tenureText != null)
                      Text(
                        tenureText,
                        style: const TextStyle(color: AppTheme.muted),
                      ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        if (property.bedrooms != null)
                          _Fact(
                            icon: Icons.bed_rounded,
                            value: '${property.bedrooms}',
                            label: 'Bedrooms',
                          ),
                        if (property.bathrooms != null)
                          _Fact(
                            icon: Icons.bathtub_outlined,
                            value: '${property.bathrooms}',
                            label: 'Bathrooms',
                          ),
                        if (property.sizeSqft != null)
                          _Fact(
                            icon: Icons.square_foot_rounded,
                            value: '${property.sizeSqft}',
                            label: 'Sq ft',
                          ),
                        if (propertyTypeText != null)
                          _Fact(
                            icon: Icons.apartment_rounded,
                            value: propertyTypeText,
                            label: 'Type',
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'About this property',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(property.summary),
                    if (property.isGovernmentRecord) ...[
                      const SizedBox(height: 16),
                      _GovernmentProjectFacts(property: property),
                      if (property.unitOptions.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _UnitOptions(
                          unitOptions: property.unitOptions,
                          palette: property.palette,
                        ),
                      ] else if (property.unitTypes.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _UnitTypes(unitTypes: property.unitTypes),
                      ],
                    ],
                  ],
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 6, child: visual),
                          const SizedBox(width: 26),
                          Expanded(flex: 5, child: details),
                        ],
                      )
                    else ...[
                      visual,
                      const SizedBox(height: 22),
                      details,
                    ],
                    const SizedBox(height: 28),
                    _AdvisorSummary(
                      score: recommendation?.score,
                      reasons: recommendation?.reasons ?? const [],
                    ),
                    if (property.facilities.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Nearby facilities',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: property.facilities
                            .map(
                              (facility) => Chip(
                                avatar: const Icon(
                                  Icons.near_me_outlined,
                                  size: 17,
                                ),
                                label: Text(facility),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    if (hasMatchedAreaProfile) ...[
                      if (hasAreaSignals) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Area signals',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        GridView.count(
                          crossAxisCount: wide ? 4 : 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: wide ? 1.35 : 0.95,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          children: [
                            if (area!.safetyScore != null)
                              _Signal(
                                label: 'Safety',
                                value: _scoreText(area.safetyScore),
                              ),
                            if (area.infrastructureScore != null)
                              _Signal(
                                label: 'Infrastructure',
                                value: _scoreText(area.infrastructureScore),
                              ),
                            if (area.priceGrowth != null)
                              _Signal(
                                label: 'Price growth',
                                value: _percentText(area.priceGrowth),
                              ),
                            if (area.rentalYield != null)
                              _Signal(
                                label: 'Rental yield',
                                value: _percentText(area.rentalYield),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                      Text(
                        'Current area profile',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      _AreaProfileCard(
                        property: property,
                        areaName: '${area!.name}, ${area.state}',
                        population: area.population,
                        medianIncome: area.medianIncome,
                        schools: area.schools,
                        hospitals: area.hospitals,
                        snapshotDate: area.snapshotDate,
                        source: area.source,
                      ),
                    ] else if (property.isGovernmentRecord) ...[
                      const SizedBox(height: 20),
                      const _AreaProfileUnavailableNotice(),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      property.isGovernmentRecord
                          ? 'TEDUH records are Malaysian housing project data. Missing price, district, tenure, facility, or coordinate fields are left unavailable instead of filled with sample values.'
                          : 'Listing and scoring data are for assignment sample. Verify all facts before a property decision.',
                      style: TextStyle(color: AppTheme.muted, fontSize: 12),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  _PriceInfo _priceInfo(Property property) {
    final min = property.priceMin;
    final max = property.priceMax;
    if (min != null && max != null && min != max) {
      return _PriceInfo(
        value: '${formatRinggit(min)} - ${formatRinggit(max)}',
        label: property.isGovernmentRecord ? 'Project Price Range' : null,
      );
    }
    final price = property.price ?? min ?? max;
    if (price == null) {
      return const _PriceInfo(value: 'Price unavailable');
    }
    return _PriceInfo(
      value: formatRinggit(price),
      label: property.isGovernmentRecord ? 'Project Price' : null,
    );
  }

  String? _tenureText(Property property) {
    final text = property.tenure.trim();
    if (text.isEmpty) {
      return null;
    }
    final normalized = text.toLowerCase();
    if (normalized == 'tenure not available' ||
        normalized == 'tenure unavailable' ||
        normalized == 'not available' ||
        normalized == 'n/a' ||
        normalized == 'unknown') {
      return null;
    }
    return text;
  }

  String? _propertyTypeText(Property property) {
    final verified = property.verifiedPropertyType?.trim();
    if (verified != null && verified.isNotEmpty) {
      return verified;
    }
    if (property.isGovernmentRecord) {
      return null;
    }
    final type = property.type.trim();
    if (type.isEmpty) {
      return null;
    }
    return type;
  }
}

class _PriceInfo {
  const _PriceInfo({required this.value, this.label});

  final String value;
  final String? label;
}

class _UnitOptions extends StatelessWidget {
  const _UnitOptions({required this.unitOptions, required this.palette});

  final List<PropertyUnitOption> unitOptions;
  final int palette;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Available units',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 620;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: unitOptions
                      .map(
                        (option) => SizedBox(
                          width: wide
                              ? (constraints.maxWidth - 12) / 2
                              : constraints.maxWidth,
                          child: _UnitOptionTile(
                            option: option,
                            palette: palette,
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitOptionTile extends StatelessWidget {
  const _UnitOptionTile({required this.option, required this.palette});

  final PropertyUnitOption option;
  final int palette;

  @override
  Widget build(BuildContext context) {
    final sizeText = option.sizeText ?? _sizeText(option.sizeSqft);
    final priceText = option.priceStart == null
        ? option.priceFromText
        : 'From ${formatRinggit(option.priceStart!)}';
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (option.unitType != null)
                Text(
                  option.unitType!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              if (sizeText != null) ...[
                const SizedBox(height: 6),
                Text(sizeText, style: const TextStyle(color: AppTheme.muted)),
              ],
              if (priceText != null) ...[
                const SizedBox(height: 6),
                Text(
                  priceText,
                  style: const TextStyle(
                    color: AppTheme.green,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        );
        final image = _UnitImage(imageUrl: option.imageUrl, palette: palette);
        final tight = constraints.maxWidth < 260;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5EAF1)),
          ),
          clipBehavior: Clip.antiAlias,
          child: tight
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: double.infinity, height: 96, child: image),
                    content,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 108, height: 108, child: image),
                    Expanded(child: content),
                  ],
                ),
        );
      },
    );
  }

  String? _sizeText(int? sizeSqft) {
    if (sizeSqft == null) {
      return null;
    }
    return '$sizeSqft sq ft';
  }
}

class _UnitImage extends StatelessWidget {
  const _UnitImage({required this.imageUrl, required this.palette});

  final String? imageUrl;
  final int palette;

  @override
  Widget build(BuildContext context) {
    final uri = _validHttpUri(imageUrl);
    if (uri == null) {
      return PropertyArt(
        palette: palette,
        height: double.infinity,
        borderRadius: BorderRadius.zero,
      );
    }
    return Image.network(
      uri.toString(),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => PropertyArt(
        palette: palette,
        height: double.infinity,
        borderRadius: BorderRadius.zero,
      ),
    );
  }
}

class _UnitTypes extends StatelessWidget {
  const _UnitTypes({required this.unitTypes});

  final List<String> unitTypes;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Unit types', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: unitTypes
                  .map(
                    (unitType) => Chip(
                      avatar: const Icon(Icons.home_work_outlined, size: 17),
                      label: Text(unitType),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _AreaProfileUnavailableNotice extends StatelessWidget {
  const _AreaProfileUnavailableNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5EAF1)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 20, color: AppTheme.muted),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'No matched district area profile is available for this property.',
              style: TextStyle(color: AppTheme.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _GovernmentProjectFacts extends StatelessWidget {
  const _GovernmentProjectFacts({required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (property.scheme != null)
              _InfoRow(
                icon: Icons.account_balance_outlined,
                label: 'Scheme',
                value: property.scheme!,
              ),
            if (property.developerName != null)
              _InfoRow(
                icon: Icons.business_outlined,
                label: 'Developer',
                value: property.developerName!,
              ),
            if (property.totalUnits != null)
              _InfoRow(
                icon: Icons.home_work_outlined,
                label: 'Total units',
                value: '${property.totalUnits}',
              ),
            if (property.availableUnits != null)
              _InfoRow(
                icon: Icons.inventory_2_outlined,
                label: 'Available units',
                value: '${property.availableUnits}',
              ),
            _InfoRow(
              icon: Icons.dataset_outlined,
              label: 'Source',
              value: property.source,
            ),
            if (property.sourceUrl != null)
              _InfoRow(
                icon: Icons.link_outlined,
                label: 'Source URL',
                value: property.sourceUrl!,
                url: property.sourceUrl,
              ),
            if (property.externalProjectUrl != null)
              _InfoRow(
                icon: Icons.open_in_new_rounded,
                label: 'Official URL',
                value: property.externalProjectUrl!,
                url: property.externalProjectUrl,
              ),
            if (property.retrievedAt != null)
              _InfoRow(
                icon: Icons.schedule_outlined,
                label: 'Retrieved',
                value: property.retrievedAt!
                    .toLocal()
                    .toString()
                    .split('.')
                    .first,
                isLast: true,
              ),
          ],
        ),
      ),
    );
  }
}

class _AreaProfileCard extends StatelessWidget {
  const _AreaProfileCard({
    required this.property,
    required this.areaName,
    required this.population,
    required this.medianIncome,
    required this.schools,
    required this.hospitals,
    required this.snapshotDate,
    required this.source,
  });

  final Property property;
  final String areaName;
  final int? population;
  final int? medianIncome;
  final int? schools;
  final int? hospitals;
  final String? snapshotDate;
  final String source;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _InfoRow(
              icon: Icons.location_city_rounded,
              label: 'District',
              value: areaName,
            ),
            if (population != null)
              _InfoRow(
                icon: Icons.groups_2_outlined,
                label: 'Population',
                value: formatCount(population!),
              ),
            if (medianIncome != null)
              _InfoRow(
                icon: Icons.payments_outlined,
                label: 'Median household income',
                value: formatRinggit(medianIncome!),
              ),
            if (schools != null)
              _InfoRow(
                icon: Icons.school_outlined,
                label: 'Education institutions',
                value: formatCount(schools!),
              ),
            if (hospitals != null)
              _InfoRow(
                icon: Icons.local_hospital_outlined,
                label: 'Hospitals',
                value: formatCount(hospitals!),
              ),
            if (property.hasCoordinates)
              _InfoRow(
                icon: Icons.explore_outlined,
                label: 'Listing coordinates',
                value:
                    '${property.latitude!.toStringAsFixed(4)}, ${property.longitude!.toStringAsFixed(4)}',
              ),
            _InfoRow(
              icon: Icons.dataset_outlined,
              label: 'Area data source',
              value: snapshotDate == null
                  ? source
                  : '$source, snapshot $snapshotDate',
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
    this.url,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isLast;
  final String? url;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.blue, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          if (_validHttpUri(url) != null) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Open link',
              onPressed: () => _openExternalUrl(context, url),
              icon: const Icon(Icons.open_in_new_rounded),
            ),
          ],
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5EAF1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppTheme.blue),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            style: const TextStyle(color: AppTheme.muted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _AdvisorSummary extends StatelessWidget {
  const _AdvisorSummary({required this.score, required this.reasons});

  final double? score;
  final List<String> reasons;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A5FC6), Color(0xFF1CB7A5)],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 27,
            backgroundColor: Colors.white,
            child: Text(
              score == null ? '-' : score!.round().toString(),
              style: const TextStyle(
                color: AppTheme.blue,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Smart Property Advisor suitability',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  score == null
                      ? 'Change advisor filters to include this property.'
                      : reasons.take(2).join(' - '),
                  style: const TextStyle(color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Signal extends StatelessWidget {
  const _Signal({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

String _scoreText(double? value) {
  return value == null ? 'N/A' : '${value.round()}/100';
}

String _percentText(double? value) {
  return value == null ? 'Not available' : '${value.toStringAsFixed(1)}%';
}

Uri? _validHttpUri(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(text);
  if (uri == null || uri.host.isEmpty) {
    return null;
  }
  return uri.scheme == 'https' || uri.scheme == 'http' ? uri : null;
}

Future<void> _openExternalUrl(BuildContext context, String? value) async {
  final uri = _validHttpUri(value);
  if (uri == null) {
    return;
  }
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not open link.')));
  }
}

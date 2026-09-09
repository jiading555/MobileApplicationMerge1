import 'package:flutter/material.dart';

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
    final area = state.areaFor(property.areaId);
    PropertyRecommendation? recommendation;
    for (final item in state.recommendations) {
      if (item.property.id == property.id) {
        recommendation = item;
      }
    }
    final priceText = _priceText(property);
    final pricePerSqft = property.pricePerSqft;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Property details'),
        actions: [
          IconButton(
            onPressed: () => state.toggleFavourite(property.id),
            icon: Icon(
              state.isFavourite(property.id)
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: state.isFavourite(property.id)
                  ? const Color(0xFFE54865)
                  : AppTheme.ink,
            ),
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
                  Text(
                    priceText,
                    style: const TextStyle(
                      color: AppTheme.green,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (pricePerSqft != null)
                    Text(
                      '${formatRinggit(pricePerSqft.round())} psf - ${property.tenure}',
                      style: const TextStyle(color: AppTheme.muted),
                    )
                  else
                    Text(
                      property.tenure,
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
                      _Fact(
                        icon: Icons.apartment_rounded,
                        value: property.type,
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
                      _Signal(
                        label: 'Safety',
                        value: _scoreText(area.safetyScore),
                      ),
                      _Signal(
                        label: 'Infrastructure',
                        value: _scoreText(area.infrastructureScore),
                      ),
                      _Signal(
                        label: 'Price growth',
                        value: _percentText(area.priceGrowth),
                      ),
                      _Signal(
                        label: 'Rental yield',
                        value: _percentText(area.rentalYield),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Current area profile',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  _AreaProfileCard(
                    areaName: '${area.name}, ${area.state}',
                    population: _countText(area.population),
                    medianIncome: _ringgitText(area.medianIncome),
                    schools: _countText(area.schools),
                    hospitals: _countText(area.hospitals),
                    coordinates: property.hasCoordinates
                        ? '${property.latitude!.toStringAsFixed(4)}, ${property.longitude!.toStringAsFixed(4)}'
                        : 'Coordinates unavailable',
                    snapshotDate: area.snapshotDate ?? 'Not available',
                    source: area.source,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    property.isGovernmentRecord
                        ? 'TEDUH records are Malaysian public housing/project data. Missing price or coordinate fields are left unavailable instead of filled with sample values.'
                        : 'Listing and scoring data are for assignment sample. Verify all facts before a property decision.',
                    style: TextStyle(color: AppTheme.muted, fontSize: 12),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _priceText(Property property) {
    final min = property.priceMin;
    final max = property.priceMax;
    if (min != null && max != null && min != max) {
      return '${formatRinggit(min)} - ${formatRinggit(max)}';
    }
    final price = property.price ?? min ?? max;
    return price == null ? 'Price unavailable' : formatRinggit(price);
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
              ),
            _InfoRow(
              icon: Icons.schedule_outlined,
              label: 'Retrieved',
              value: property.retrievedAt == null
                  ? 'Unavailable'
                  : property.retrievedAt!.toLocal().toString().split('.').first,
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
    required this.areaName,
    required this.population,
    required this.medianIncome,
    required this.schools,
    required this.hospitals,
    required this.coordinates,
    required this.snapshotDate,
    required this.source,
  });

  final String areaName;
  final String population;
  final String medianIncome;
  final String schools;
  final String hospitals;
  final String coordinates;
  final String snapshotDate;
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
            _InfoRow(
              icon: Icons.groups_2_outlined,
              label: 'Population',
              value: population,
            ),
            _InfoRow(
              icon: Icons.payments_outlined,
              label: 'Median household income',
              value: medianIncome,
            ),
            _InfoRow(
              icon: Icons.school_outlined,
              label: 'Education institutions',
              value: schools,
            ),
            _InfoRow(
              icon: Icons.local_hospital_outlined,
              label: 'Hospitals',
              value: hospitals,
            ),
            _InfoRow(
              icon: Icons.explore_outlined,
              label: 'Listing coordinates',
              value: coordinates,
            ),
            _InfoRow(
              icon: Icons.dataset_outlined,
              label: 'Area data source',
              value: '$source, snapshot $snapshotDate',
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
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

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

String _countText(int? value) {
  return value == null ? 'Not available' : formatCount(value);
}

String _ringgitText(int? value) {
  return value == null ? 'Not available' : formatRinggit(value);
}

String _scoreText(double? value) {
  return value == null ? 'N/A' : '${value.round()}/100';
}

String _percentText(double? value) {
  return value == null ? 'Not available' : '${value.toStringAsFixed(1)}%';
}

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/metric_card.dart';
import '../../core/widgets/page_container.dart';
import '../../core/widgets/property_card.dart';
import '../../core/widgets/section_header.dart';
import '../search/property_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final featured = state.properties.take(4).toList();
    final topAreas = [...state.areas]
      ..sort((left, right) => right.priceGrowth.compareTo(left.priceGrowth));
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: PageContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _WelcomeHeader(name: state.user.name),
                    const SizedBox(height: 20),
                    _SearchLauncher(onTap: () => state.selectDestination(1)),
                    const SizedBox(height: 18),
                    _ModuleHub(onSelect: state.selectDestination),
                    const SizedBox(height: 30),
                    SectionHeader(
                      title: 'Market snapshot',
                      subtitle: 'Curated Malaysian open-data snapshot - 2024',
                      actionLabel: 'View analysis',
                      onAction: () => state.selectDestination(4),
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 900 ? 4 : 2;
                        final width =
                            (constraints.maxWidth - (columns - 1) * 12) /
                                columns;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: width,
                              child: const MetricCard(
                                label: 'Average price',
                                value: 'RM 596 psf',
                                trend: '+5.9% annual',
                                icon: Icons.home_work_outlined,
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: const MetricCard(
                                label: 'Population growth',
                                value: '3.5%',
                                trend: '+0.4 pt',
                                icon: Icons.groups_2_outlined,
                                color: AppTheme.teal,
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: const MetricCard(
                                label: 'Rental yield',
                                value: '4.25%',
                                trend: '+0.3 pt',
                                icon: Icons.percent_rounded,
                                color: AppTheme.green,
                              ),
                            ),
                            SizedBox(
                              width: width,
                              child: const MetricCard(
                                label: 'Areas compared',
                                value: '6',
                                trend: '4 data sources',
                                icon: Icons.compare_arrows_rounded,
                                color: Color(0xFF7758C8),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 30),
                    const SectionHeader(
                      title: 'Trending areas',
                      subtitle:
                      'Ranked by the price-growth signal in this snapshot',
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 136,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: topAreas.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final area = topAreas[index];
                          return _AreaCard(
                            name: area.name,
                            state: area.state,
                            growth: area.priceGrowth,
                            position: index + 1,
                            onTap: () => state.selectDestination(4),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 30),
                    SectionHeader(
                      title: 'Recommended for you',
                      subtitle: 'Based on your current property preferences',
                      actionLabel: 'Ask advisor',
                      onAction: () => state.selectDestination(3),
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 700) {
                          return Column(
                            children: featured
                                .map(
                                  (property) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: PropertyCard(
                                  property: property,
                                  compact: true,
                                  onTap: () =>
                                      _openProperty(context, property.id),
                                ),
                              ),
                            )
                                .toList(),
                          );
                        }
                        return GridView.builder(
                          itemCount: featured.length,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: constraints.maxWidth >= 1050
                                ? 4
                                : 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            mainAxisExtent: 370,
                          ),
                          itemBuilder: (context, index) => PropertyCard(
                            property: featured[index],
                            onTap: () =>
                                _openProperty(context, featured[index].id),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openProperty(BuildContext context, String propertyId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PropertyDetailScreen(propertyId: propertyId),
      ),
    );
  }
}

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final firstName = name.split(' ').first;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, $firstName',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 5),
              const Text(
                'Here is what is happening in your property market.',
                style: TextStyle(color: AppTheme.muted),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You have no new alerts.')),
          ),
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ],
    );
  }
}

class _SearchLauncher extends StatelessWidget {
  const _SearchLauncher({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFDCE3ED)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 17, vertical: 16),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: AppTheme.blue),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Search properties, locations, projects...',
                  style: TextStyle(color: AppTheme.muted),
                ),
              ),
              Icon(Icons.tune_rounded, color: AppTheme.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuleHub extends StatelessWidget {
  const _ModuleHub({required this.onSelect});

  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    const modules = [
      _ModuleEntry(
        title: 'Find Property',
        subtitle: 'Search by area, address, type and budget',
        icon: Icons.apartment_rounded,
        destination: 1,
      ),
      _ModuleEntry(
        title: 'Map & Facilities',
        subtitle: 'Inspect locations with nearby amenities',
        icon: Icons.map_rounded,
        destination: 2,
      ),
      _ModuleEntry(
        title: 'Smart Advisor',
        subtitle: 'Rank matches from saved preferences',
        icon: Icons.auto_awesome_rounded,
        destination: 3,
      ),
      _ModuleEntry(
        title: 'Market Analytics',
        subtitle: 'Compare districts and market signals',
        icon: Icons.insights_rounded,
        destination: 4,
      ),
      _ModuleEntry(
        title: 'Profile',
        subtitle: 'View account, favourites and preferences',
        icon: Icons.person_rounded,
        destination: 5,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'App hub',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 5),
        const Text(
          'Jump into each module from one place. Property and location tools use local sample data for this build.',
          style: TextStyle(color: AppTheme.muted),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 980
                ? 3
                : constraints.maxWidth >= 640
                ? 2
                : 1;

            final width =
                (constraints.maxWidth -
                    (columns - 1) * 12) /
                    columns;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: modules
                  .map(
                    (module) => SizedBox(
                  width: width,
                  child: _ModuleTile(
                    module: module,
                    onTap: () =>
                        onSelect(module.destination),
                  ),
                ),
              )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.module,
    required this.onTap,
  });

  final _ModuleEntry module;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: 118,
          ),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFFB7D6FF),
            ),
          ),
          child: Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.blue.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius:
                  BorderRadius.circular(8),
                ),
                child: Icon(
                  module.icon,
                  color: AppTheme.blue,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            module.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                              color:
                              AppTheme.blue,
                              fontWeight:
                              FontWeight.w800,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: AppTheme.blue,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      module.subtitle,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuleEntry {
  const _ModuleEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.destination,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final int destination;
}

class _AreaCard extends StatelessWidget {
  const _AreaCard({
    required this.name,
    required this.state,
    required this.growth,
    required this.position,
    required this.onTap,
  });

  final String name;
  final String state;
  final double growth;
  final int position;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: AppTheme.blue.withValues(alpha: 0.1),
                      child: Text(
                        '#$position',
                        style: const TextStyle(
                          color: AppTheme.blue,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.trending_up_rounded,
                      color: AppTheme.green,
                    ),
                  ],
                ),
                const Spacer(),
                Text(name, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  state,
                  style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                ),
                const SizedBox(height: 5),
                Text(
                  '+${growth.toStringAsFixed(1)}% price signal',
                  style: const TextStyle(
                    color: AppTheme.green,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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

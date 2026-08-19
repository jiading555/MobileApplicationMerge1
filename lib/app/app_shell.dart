import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/advisor_brand.dart';
import '../features/advisor/advisor_screen.dart';
import '../features/analysis/analysis_screen.dart';
import '../features/home/home_screen.dart';
import '../features/map/property_map_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/search/property_search_screen.dart';
import 'app_scope.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  static const destinations = [
    _Destination('Home', Icons.home_rounded, Icons.home_outlined),
    _Destination('Search', Icons.search_rounded, Icons.search_rounded),
    _Destination('Map', Icons.map_rounded, Icons.map_outlined),
    _Destination(
      'Advisor',
      Icons.auto_awesome_rounded,
      Icons.auto_awesome_outlined,
    ),
    _Destination('Analysis', Icons.insights_rounded, Icons.insights_outlined),
    _Destination('Profile', Icons.person_rounded, Icons.person_outline_rounded),
  ];

  static const screens = [
    HomeScreen(),
    PropertySearchScreen(),
    PropertyMapScreen(),
    AdvisorScreen(),
    AnalysisScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= 760;
        final content = IndexedStack(
          index: state.selectedIndex,
          children: screens,
        );
        if (isTablet) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  NavigationRail(
                    extended: constraints.maxWidth >= 1050,
                    selectedIndex: state.selectedIndex,
                    onDestinationSelected: state.selectDestination,
                    labelType: constraints.maxWidth >= 1050
                        ? NavigationRailLabelType.none
                        : NavigationRailLabelType.all,
                    leading: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
                      child: AdvisorBrand(compact: constraints.maxWidth < 1050),
                    ),
                    destinations: destinations
                        .map(
                          (item) => NavigationRailDestination(
                            icon: Icon(item.icon),
                            selectedIcon: Icon(item.selectedIcon),
                            label: Text(item.label),
                          ),
                        )
                        .toList(),
                  ),
                  const VerticalDivider(width: 1, color: Color(0xFFE5EAF1)),
                  Expanded(child: content),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          body: content,
          bottomNavigationBar: NavigationBar(
            selectedIndex: state.selectedIndex,
            onDestinationSelected: state.selectDestination,
            destinations: destinations
                .map(
                  (item) => NavigationDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon, color: AppTheme.blue),
                    label: item.label,
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

class _Destination {
  const _Destination(this.label, this.selectedIcon, this.icon);

  final String label;
  final IconData selectedIcon;
  final IconData icon;
}

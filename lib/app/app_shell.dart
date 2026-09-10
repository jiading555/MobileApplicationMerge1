import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/advisor_brand.dart';
import '../features/advisor/advisor_screen.dart';
import '../features/analysis/analysis_screen.dart';
import '../features/home/home_screen.dart';
import '../features/map/property_map_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/search/property_search_screen.dart';
import '../core/utils/responsive_layout.dart';
import 'app_navigation_scope.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selectedIndex = 0;
  late final ValueChanged<int> _selectDestinationCallback = selectDestination;

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

  void selectDestination(int index) {
    if (index == selectedIndex) {
      return;
    }
    setState(() => selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useSideNavigation = ResponsiveLayout.usesSideNavigation(context);
        final compactRail = ResponsiveLayout.isCompactLandscapePhone(context);
        final extendedRail =
            ResponsiveLayout.isDesktop(context) && !compactRail;
        final content = AppNavigationScope(
          selectDestination: _selectDestinationCallback,
          child: IndexedStack(index: selectedIndex, children: screens),
        );
        if (useSideNavigation) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  NavigationRail(
                    extended: extendedRail,
                    selectedIndex: selectedIndex,
                    onDestinationSelected: selectDestination,
                    labelType: compactRail || extendedRail
                        ? NavigationRailLabelType.none
                        : NavigationRailLabelType.all,
                    leading: Padding(
                      padding: compactRail
                          ? const EdgeInsets.fromLTRB(8, 8, 8, 10)
                          : const EdgeInsets.fromLTRB(8, 12, 8, 24),
                      child: AdvisorBrand(compact: !extendedRail),
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
          body: SafeArea(child: content),
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: selectDestination,
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

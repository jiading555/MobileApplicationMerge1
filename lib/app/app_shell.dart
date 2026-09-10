import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/responsive_layout.dart';
import '../core/widgets/advisor_brand.dart';
import '../features/advisor/advisor_screen.dart';
import '../features/analysis/analysis_screen.dart';
import '../features/home/home_screen.dart';
import '../features/map/property_map_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/search/property_search_screen.dart';
import 'app_navigation_scope.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selectedIndex = 0;
  late final ValueChanged<int> _selectDestinationCallback = selectDestination;
  final List<Widget?> _screenCache = List<Widget?>.filled(
    destinations.length,
    null,
  );

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

  @override
  void initState() {
    super.initState();
    _screenCache[0] = const HomeScreen();
  }

  Widget _buildScreen(int index) {
    return switch (index) {
      0 => const HomeScreen(),
      1 => const PropertySearchScreen(),
      2 => const PropertyMapScreen(),
      3 => const AdvisorScreen(),
      4 => const AnalysisScreen(),
      5 => const ProfileScreen(),
      _ => const SizedBox.shrink(),
    };
  }

  void selectDestination(int index) {
    if (index == selectedIndex) {
      return;
    }

    setState(() {
      _screenCache[index] ??= _buildScreen(index);
      selectedIndex = index;
    });
  }

  Widget _buildContent() {
    return AppNavigationScope(
      selectDestination: _selectDestinationCallback,
      child: IndexedStack(
        index: selectedIndex,
        children: [
          for (final screen in _screenCache)
            screen ?? const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildCompactSideNavigation() {
    return SizedBox(
      key: const ValueKey('compact-side-navigation'),
      width: 64,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 6),
          itemCount: destinations.length,
          itemBuilder: (context, index) {
            final destination = destinations[index];
            final selected = selectedIndex == index;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Tooltip(
                message: destination.label,
                child: IconButton(
                  key: ValueKey('compact-nav-${destination.label}'),
                  isSelected: selected,
                  onPressed: () => selectDestination(index),
                  icon: Icon(destination.icon),
                  selectedIcon: Icon(
                    destination.selectedIcon,
                    color: AppTheme.blue,
                  ),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(48, 44),
                    backgroundColor: selected
                        ? AppTheme.blue.withValues(alpha: 0.12)
                        : Colors.transparent,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final useSideNavigation = ResponsiveLayout.usesSideNavigation(context);
    final compactLandscape =
        ResponsiveLayout.isCompactLandscapePhone(context);
    final extendedRail =
        ResponsiveLayout.isDesktop(context) && !compactLandscape;
    final content = _buildContent();

    if (useSideNavigation) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              if (compactLandscape)
                _buildCompactSideNavigation()
              else
                NavigationRail(
                  extended: extendedRail,
                  selectedIndex: selectedIndex,
                  onDestinationSelected: selectDestination,
                  labelType: extendedRail
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
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
  }
}

class _Destination {
  const _Destination(this.label, this.selectedIcon, this.icon);

  final String label;
  final IconData selectedIcon;
  final IconData icon;
}

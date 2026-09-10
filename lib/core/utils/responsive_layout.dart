import 'package:flutter/material.dart';

class ResponsiveLayout {
  static const double phoneBreakpoint = 600;
  static const double tabletBreakpoint = 600;
  static const double desktopBreakpoint = 1050;
  static const double compactHeightBreakpoint = 500;

  static bool isPhone(BuildContext context) {
    return MediaQuery.sizeOf(context).shortestSide < phoneBreakpoint;
  }

  static bool isTablet(BuildContext context) {
    return MediaQuery.sizeOf(context).shortestSide >= phoneBreakpoint;
  }

  static bool isWideTablet(BuildContext context) {
    return MediaQuery.sizeOf(context).shortestSide >= tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.width >= desktopBreakpoint &&
        size.shortestSide >= phoneBreakpoint;
  }

  static bool isLandscape(BuildContext context) {
    return MediaQuery.orientationOf(context) == Orientation.landscape;
  }

  static bool hasCompactHeight(BuildContext context) {
    return MediaQuery.sizeOf(context).height < compactHeightBreakpoint;
  }

  static bool isCompactLandscapePhone(BuildContext context) {
    return isPhone(context) &&
        isLandscape(context) &&
        hasCompactHeight(context);
  }

  static bool usesSideNavigation(BuildContext context) {
    return isLandscape(context) || isTablet(context);
  }
}

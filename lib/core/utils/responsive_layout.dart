import 'package:flutter/material.dart';

class ResponsiveLayout {
  static const double phoneBreakpoint = 600;
  static const double tabletBreakpoint = 720;
  static const double desktopBreakpoint = 1050;

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
}

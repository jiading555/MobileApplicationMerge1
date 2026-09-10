import 'package:flutter/widgets.dart';

class AppNavigationScope extends InheritedWidget {
  const AppNavigationScope({
    required this.selectDestination,
    required super.child,
    super.key,
  });

  final ValueChanged<int> selectDestination;

  static ValueChanged<int> of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppNavigationScope>();
    assert(scope != null, 'AppNavigationScope is missing above this context');
    return scope!.selectDestination;
  }

  @override
  bool updateShouldNotify(AppNavigationScope oldWidget) {
    return selectDestination != oldWidget.selectDestination;
  }
}

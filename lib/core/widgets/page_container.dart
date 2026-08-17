import 'package:flutter/material.dart';

class PageContainer extends StatelessWidget {
  const PageContainer({
    required this.child,
    this.maxWidth = 1240,
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 28),
    super.key,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: double.infinity,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

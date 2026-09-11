import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AppFeedbackType { success, error, neutral }

void showAppSnackBar(
  BuildContext context, {
  required String message,
  AppFeedbackType type = AppFeedbackType.neutral,
}) {
  final backgroundColor = switch (type) {
    AppFeedbackType.success => AppTheme.green,
    AppFeedbackType.error => const Color(0xFFB42318),
    AppFeedbackType.neutral => null,
  };
  final foregroundColor = switch (type) {
    AppFeedbackType.success || AppFeedbackType.error => Colors.white,
    AppFeedbackType.neutral => null,
  };

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: foregroundColor == null
            ? null
            : TextStyle(color: foregroundColor),
      ),
      backgroundColor: backgroundColor,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

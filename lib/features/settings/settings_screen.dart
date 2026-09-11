import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final updatedAt = state.marketTrendCacheUpdatedAt;
    final updatedText = updatedAt == null
        ? 'No mobile cache timestamp available'
        : updatedAt.toLocal().toString().split('.').first;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text(
              'Data & storage',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.schedule_rounded),
                    title: const Text('Market data last refreshed'),
                    subtitle: Text(updatedText),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: state.isSyncingGovernmentData
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                    title: const Text('Refresh market snapshot'),
                    subtitle: const Text(
                      'Download the latest processed Supabase snapshot to this device.',
                    ),
                    enabled: !state.isSyncingGovernmentData,
                    onTap: state.isSyncingGovernmentData
                        ? null
                        : () => _refreshData(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Privacy & security',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.lock_outline_rounded),
                    title: Text('Account protection'),
                    subtitle: Text(
                      'Authentication and password recovery are handled by Supabase Auth.',
                    ),
                  ),
                  Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.storage_outlined),
                    title: Text('Stored account data'),
                    subtitle: Text(
                      'Your profile, preferences and favourites are protected by row-level security.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('About', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  const ListTile(
                    leading: Icon(Icons.dataset_outlined),
                    title: Text('Data sources'),
                    subtitle: Text(
                      'OpenDOSM, data.gov.my, NAPIC and TEDUH snapshots.',
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded),
                    title: const Text('Smart Property Advisor'),
                    subtitle: const Text('Version 1.0.0'),
                    onTap: () => showAboutDialog(
                      context: context,
                      applicationName: 'Smart Property Advisor',
                      applicationVersion: '1.0.0',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshData(BuildContext context) async {
    final state = AppScope.of(context);
    await state.refreshGovernmentData();
    if (!context.mounted) return;

    final message =
        state.governmentDataSyncMessage ?? 'Market snapshot refreshed.';
    final normalizedMessage = message.toLowerCase();
    final failed =
        normalizedMessage.contains('failed') ||
        normalizedMessage.contains('could not') ||
        normalizedMessage.contains('no internet');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: failed ? const Color(0xFFB42318) : AppTheme.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

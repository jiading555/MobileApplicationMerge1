import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/page_container.dart';
import '../../core/widgets/property_card.dart';
import '../../models/app_user.dart';
import '../search/property_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool notifications = true;
  bool dataSaver = false;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & settings'),
        actions: [
          IconButton(
            onPressed: () => _editProfile(context),
            tooltip: 'Edit profile',
            icon: const Icon(Icons.edit_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: PageContainer(
          maxWidth: 1000,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProfileHeader(
                user: state.user,
                favouriteCount: state.favouriteProperties.length,
              ),
              const SizedBox(height: 22),
              LayoutBuilder(
                builder: (context, constraints) {
                  final preferences = _PreferencesSummary();
                  final account = _AccountActions(
                    onEdit: () => _editProfile(context),
                    onPassword: () => _changePassword(context),
                    onAbout: () => _showAbout(context),
                  );
                  return constraints.maxWidth >= 760
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: preferences),
                            const SizedBox(width: 14),
                            Expanded(child: account),
                          ],
                        )
                      : Column(
                          children: [
                            preferences,
                            const SizedBox(height: 14),
                            account,
                          ],
                        );
                },
              ),
              const SizedBox(height: 22),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      value: notifications,
                      onChanged: (value) =>
                          setState(() => notifications = value),
                      secondary: const Icon(Icons.notifications_outlined),
                      title: const Text('Recommendation alerts'),
                      subtitle: const Text(
                        'Receive saved-area and data refresh reminders',
                      ),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      value: dataSaver,
                      onChanged: (value) => setState(() => dataSaver = value),
                      secondary: const Icon(Icons.data_saver_on_rounded),
                      title: const Text('Data saver'),
                      subtitle: const Text(
                        'Prefer the bundled snapshot over live refreshes',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  Text(
                    'Favourite properties',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  Text(
                    '${state.favouriteProperties.length} saved',
                    style: const TextStyle(color: AppTheme.muted),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (state.favouriteProperties.isEmpty)
                const _EmptyFavourites()
              else
                ...state.favouriteProperties.map(
                  (property) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: PropertyCard(
                      property: property,
                      compact: true,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              PropertyDetailScreen(propertyId: property.id),
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: state.logout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign out'),
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Smart Property Advisor v1.0.0 - Assignment sample',
                  style: TextStyle(color: AppTheme.muted, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editProfile(BuildContext context) async {
    final state = AppScope.of(context);
    final nameController = TextEditingController(text: state.user.name);
    final phoneController = TextEditingController(text: state.user.phone);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          2,
          22,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Edit personal information',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone number'),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () {
                if (nameController.text.trim().length >= 2) {
                  state.updateUser(
                    state.user.copyWith(
                      name: nameController.text.trim(),
                      phone: phoneController.text.trim(),
                    ),
                  );
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    phoneController.dispose();
  }

  Future<void> _changePassword(BuildContext context) async {
    final currentController = TextEditingController();
    final nextController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nextController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (nextController.text.length >= 8) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Sample password updated.')),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
    currentController.dispose();
    nextController.dispose();
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Smart Property Advisor',
      applicationVersion: '1.0.0',
      applicationIcon: const CircleAvatar(
        backgroundColor: Color(0xFFE5F0FF),
        child: Icon(Icons.home_work_rounded, color: AppTheme.blue),
      ),
      children: const [
        Text(
          'A smart property-advisor assignment combining Malaysian open data, market analytics and transparent weighted recommendations in support of SDG 9.',
        ),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user, required this.favouriteCount});

  final AppUser user;
  final int favouriteCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppTheme.navy, AppTheme.blue]),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: Colors.white,
            child: Text(
              user.name
                  .split(' ')
                  .where((part) => part.isNotEmpty)
                  .take(2)
                  .map((part) => part[0].toUpperCase())
                  .join(),
              style: const TextStyle(
                color: AppTheme.blue,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 17),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(user.email, style: const TextStyle(color: Colors.white70)),
                if (user.phone.isNotEmpty)
                  Text(
                    user.phone,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  '$favouriteCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text(
                  'saved',
                  style: TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreferencesSummary extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final preferences = state.preferences;
    final area = preferences.preferredAreaId == 'any'
        ? 'Any area'
        : state.areaFor(preferences.preferredAreaId).name;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune_rounded, color: AppTheme.blue),
                const SizedBox(width: 9),
                Text(
                  'Property preferences',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SummaryRow(
              label: 'Goal',
              value: preferences.goal.name == 'ownStay'
                  ? 'Own stay'
                  : 'Investment',
            ),
            _SummaryRow(label: 'Area', value: area),
            _SummaryRow(label: 'Type', value: preferences.propertyType),
            _SummaryRow(
              label: 'Budget',
              value: 'RM ${(preferences.budget / 1000).round()}K',
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => state.selectDestination(3),
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Update in Advisor'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountActions extends StatelessWidget {
  const _AccountActions({
    required this.onEdit,
    required this.onPassword,
    required this.onAbout,
  });

  final VoidCallback onEdit;
  final VoidCallback onPassword;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline_rounded),
            title: const Text('Personal information'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onEdit,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.lock_outline_rounded),
            title: const Text('Change password'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onPassword,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('About Smart Property Advisor'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onAbout,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _EmptyFavourites extends StatelessWidget {
  const _EmptyFavourites();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(26),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.favorite_border_rounded,
                size: 42,
                color: AppTheme.muted,
              ),
              SizedBox(height: 8),
              Text('No favourites saved yet.'),
            ],
          ),
        ),
      ),
    );
  }
}

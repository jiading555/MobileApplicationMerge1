import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/page_container.dart';
import '../../core/widgets/property_card.dart';
import '../../models/app_user.dart';
import '../../models/property.dart';
import '../../models/user_preferences.dart';
import '../search/property_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _showAllFavourites = false;

  Future<void> _pickAvatar() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 82,
    );
    if (file == null || !mounted) return;
    final extension = file.name.split('.').last;
    final error = await AppScope.of(context).uploadAvatar(
      await file.readAsBytes(),
      extension,
    );
    if (mounted) _message(error ?? 'Profile photo updated.', error != null);
  }

  void _message(String text, bool error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? const Color(0xFFB42318) : AppTheme.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile & settings')),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: PageContainer(
              maxWidth: 900,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileHeader(user: state.user, onAvatar: _pickAvatar),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final personal = _PersonalCard(
                        user: state.user,
                        onEdit: _editProfile,
                      );
                      final preferences = _PreferenceCard(
                        value: state.preferences,
                        onEdit: _editPreferences,
                      );
                      return constraints.maxWidth >= 700
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: personal),
                                const SizedBox(width: 14),
                                Expanded(child: preferences),
                              ],
                            )
                          : Column(
                              children: [
                                personal,
                                const SizedBox(height: 14),
                                preferences,
                              ],
                            );
                    },
                  ),
                  const SizedBox(height: 14),
                  _FavouriteProperties(
                    properties: state.favouriteProperties,
                    showAll: _showAllFavourites,
                    onToggle: () => setState(
                      () => _showAllFavourites = !_showAllFavourites,
                    ),
                    onOpen: (propertyId) => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PropertyDetailScreen(
                          propertyId: propertyId,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.lock_outline_rounded),
                          title: const Text('Change password'),
                          subtitle: const Text('Use at least 8 characters'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: _changePassword,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.info_outline_rounded),
                          title: const Text('About Smart Property Advisor'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => showAboutDialog(
                            context: context,
                            applicationName: 'Smart Property Advisor',
                            applicationVersion: '1.0.0',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => state.logout(),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Sign out'),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          if (state.isAccountBusy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x33000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _editProfile() async {
    final state = AppScope.of(context);
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: state.user.name);
    final phone = TextEditingController(text: state.user.phone);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      enableDrag: false,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          MediaQuery.of(sheetContext).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              Text('Personal information', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (value) => value == null || value.trim().length < 2
                    ? 'Enter at least 2 characters'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone number'),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final updated = state.user.copyWith(
                          name: name.text.trim(),
                          phone: phone.text.trim(),
                        );
                        final error = await state.saveUser(updated);
                        if (!mounted || !sheetContext.mounted) return;
                        if (error == null) {
                          Navigator.of(sheetContext).pop();
                        }
                        _message(
                          error ?? 'Profile updated successfully.',
                          error != null,
                        );
                      },
                      child: const Text('Save changes'),
                    ),
                  ),
                ],
              ),
              ],
            ),
          ),
        ),
      ),
    );
    name.dispose();
    phone.dispose();
  }

  Future<void> _editPreferences() async {
    final state = AppScope.of(context);
    final current = state.preferences;
    final formKey = GlobalKey<FormState>();
    final minimum = TextEditingController(
      text: current.minimumBudget.round().toString(),
    );
    final maximum = TextEditingController(
      text: current.maximumBudget.round().toString(),
    );

    final states = state.areas
        .map((area) => area.state.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    var selectedState = states.contains(current.preferredState)
        ? current.preferredState
        : '';

    List<String> districtsFor(String selected) {
      if (selected.isEmpty) return const [];
      final values = state.areas
          .where((area) => area.state == selected)
          .map((area) => area.name.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      return values;
    }

    var districts = districtsFor(selectedState);
    var selectedDistrict = districts.contains(current.preferredDistrict)
        ? current.preferredDistrict
        : '';

    final propertyTypes = <String>{
      'Any',
      ...state.properties
          .map((property) => property.type.trim())
          .where((value) => value.isNotEmpty),
    }.toList()
      ..sort((left, right) {
        if (left == 'Any') return -1;
        if (right == 'Any') return 1;
        return left.compareTo(right);
      });
    var type = propertyTypes.contains(current.propertyType)
        ? current.propertyType
        : 'Any';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      enableDrag: false,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Property preferences',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: selectedState,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Preferred state',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Any state'),
                      ),
                      ...states.map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value),
                        ),
                      ),
                    ],
                    onChanged: (value) => setSheetState(() {
                      selectedState = value ?? '';
                      districts = districtsFor(selectedState);
                      selectedDistrict = '';
                    }),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    key: ValueKey(selectedState),
                    initialValue: selectedDistrict,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Preferred district',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Any district'),
                      ),
                      ...districts.map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value),
                        ),
                      ),
                    ],
                    onChanged: selectedState.isEmpty
                        ? null
                        : (value) => setSheetState(
                            () => selectedDistrict = value ?? '',
                          ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Property type',
                    ),
                    items: propertyTypes
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setSheetState(
                      () => type = value ?? 'Any',
                    ),
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final minimumField = _BudgetField(
                        controller: minimum,
                        label: 'Minimum budget',
                      );
                      final maximumField = _BudgetField(
                        controller: maximum,
                        label: 'Maximum budget',
                      );
                      if (constraints.maxWidth < 520) {
                        return Column(
                          children: [
                            minimumField,
                            const SizedBox(height: 12),
                            maximumField,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: minimumField),
                          const SizedBox(width: 12),
                          Expanded(child: maximumField),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final min = double.parse(minimum.text);
                            final max = double.parse(maximum.text);
                            if (min > max) {
                              _message(
                                'Minimum budget cannot exceed maximum budget.',
                                true,
                              );
                              return;
                            }
                            final value = current.copyWith(
                              preferredState: selectedState,
                              preferredDistrict: selectedDistrict,
                              propertyType: type,
                              minimumBudget: min,
                              maximumBudget: max,
                              budget: max,
                            );
                            final error = await state.saveAccountPreferences(
                              value,
                            );
                            if (!mounted || !sheetContext.mounted) return;
                            if (error == null) {
                              Navigator.of(sheetContext).pop();
                            }
                            _message(
                              error ?? 'Preferences updated successfully.',
                              error != null,
                            );
                          },
                          child: const Text('Save preferences'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    minimum.dispose();
    maximum.dispose();
  }

  Future<void> _changePassword() async {
    final state = AppScope.of(context);
    final currentPassword = TextEditingController();
    final newPassword = TextEditingController();
    final confirmPassword = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change password'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: currentPassword,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(
                      labelText: 'Current password',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Enter your current password'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: newPassword,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: const InputDecoration(
                      labelText: 'New password',
                      prefixIcon: Icon(Icons.password_rounded),
                    ),
                    validator: (value) => value == null || value.length < 8
                        ? 'Use at least 8 characters'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmPassword,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: const InputDecoration(
                      labelText: 'Confirm new password',
                      prefixIcon: Icon(Icons.password_rounded),
                    ),
                    validator: (value) => value != newPassword.text
                        ? 'New passwords do not match'
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final error = await state.updatePassword(
                currentPassword: currentPassword.text,
                newPassword: newPassword.text,
              );
              if (!mounted || !dialogContext.mounted) return;
              if (error == null) Navigator.pop(dialogContext);
              _message(
                error ?? 'Password updated successfully.',
                error != null,
              );
            },
            child: const Text('Update password'),
          ),
        ],
      ),
    );
    currentPassword.dispose();
    newPassword.dispose();
    confirmPassword.dispose();
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user, required this.onAvatar});
  final AppUser user;
  final VoidCallback onAvatar;

  @override
  Widget build(BuildContext context) {
    final initials = user.name.split(' ').where((v) => v.isNotEmpty).take(2).map((v) => v[0].toUpperCase()).join();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppTheme.navy, AppTheme.blue]),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 38,
                backgroundColor: Colors.white,
                backgroundImage: user.avatarUrl == null ? null : NetworkImage(user.avatarUrl!),
                child: user.avatarUrl == null
                    ? Text(initials, style: const TextStyle(color: AppTheme.blue, fontSize: 22, fontWeight: FontWeight.w900))
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: IconButton.filled(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Change profile photo',
                  onPressed: onAvatar,
                  icon: const Icon(Icons.camera_alt_rounded, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(user.email, style: const TextStyle(color: Colors.white70)),
                if (user.isDemo) const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('SAMPLE MODE', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _FavouriteProperties extends StatelessWidget {
  const _FavouriteProperties({
    required this.properties,
    required this.showAll,
    required this.onToggle,
    required this.onOpen,
  });

  final List<Property> properties;
  final bool showAll;
  final VoidCallback onToggle;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final visible = showAll ? properties : properties.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Favourite properties',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Spacer(),
            Text(
              '${properties.length} saved',
              style: const TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (properties.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.favorite_border_rounded,
                      size: 40,
                      color: AppTheme.muted,
                    ),
                    SizedBox(height: 8),
                    Text('No favourite properties yet.'),
                  ],
                ),
              ),
            ),
          )
        else
          ...visible.map(
            (property) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PropertyCard(
                property: property,
                compact: true,
                onTap: () => onOpen(property.id),
              ),
            ),
          ),
        if (properties.length > 5)
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: onToggle,
              icon: Icon(
                showAll
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
              ),
              label: Text(showAll ? 'Show less' : 'Show all'),
            ),
          ),
      ],
    );
  }
}

class _PersonalCard extends StatelessWidget {
  const _PersonalCard({required this.user, required this.onEdit});
  final AppUser user;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TitleRow(title: 'Personal information', icon: Icons.person_outline_rounded, onEdit: onEdit),
          const SizedBox(height: 12),
          _InfoRow(label: 'Full name', value: user.name),
          _InfoRow(label: 'Email', value: user.email),
          _InfoRow(label: 'Phone', value: user.phone.isEmpty ? 'Not provided' : user.phone),
        ],
      ),
    ),
  );
}

class _PreferenceCard extends StatelessWidget {
  const _PreferenceCard({required this.value, required this.onEdit});
  final UserPreferences value;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TitleRow(title: 'Property preferences', icon: Icons.tune_rounded, onEdit: onEdit),
          const SizedBox(height: 12),
          _InfoRow(label: 'State', value: value.preferredState.isEmpty ? 'Any state' : value.preferredState),
          _InfoRow(label: 'District', value: value.preferredDistrict.isEmpty ? 'Any district' : value.preferredDistrict),
          _InfoRow(label: 'Type', value: value.propertyType),
          _InfoRow(label: 'Budget', value: '${formatRinggit(value.minimumBudget)} – ${formatRinggit(value.maximumBudget)}'),
        ],
      ),
    ),
  );
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.title, required this.icon, required this.onEdit});
  final String title;
  final IconData icon;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: AppTheme.blue),
      const SizedBox(width: 9),
      Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
      IconButton(onPressed: onEdit, tooltip: 'Edit', icon: const Icon(Icons.edit_outlined)),
    ],
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 72, child: Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 12))),
        Expanded(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
      ],
    ),
  );
}

class _BudgetField extends StatelessWidget {
  const _BudgetField({required this.controller, required this.label});
  final TextEditingController controller;
  final String label;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: TextInputType.number,
    decoration: InputDecoration(labelText: label, prefixText: 'RM '),
    validator: (value) {
      final amount = double.tryParse(value ?? '');
      return amount == null || amount < 0 ? 'Enter a valid amount' : null;
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/app_scope.dart';
import '../../core/constants/property_preference_options.dart';
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
    final updated = await showModalBottomSheet<AppUser>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      enableDrag: false,
      useSafeArea: true,
      builder: (context) => _EditProfileSheet(initialValue: state.user),
    );
    if (!mounted || updated == null) return;

    final error = await state.saveUser(updated);
    if (!mounted) return;
    _message(
      error ?? 'Profile updated successfully.',
      error != null,
    );
  }

  Future<void> _editPreferences() async {
    final state = AppScope.of(context);
    final updated = await showModalBottomSheet<UserPreferences>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      enableDrag: false,
      useSafeArea: true,
      builder: (context) => _PropertyPreferencesSheet(
        initialValue: state.preferences,
      ),
    );
    if (!mounted || updated == null) return;

    final error = await state.saveAccountPreferences(updated);
    if (!mounted) return;
    _message(
      error ?? 'Preferences updated successfully.',
      error != null,
    );
  }

  Future<void> _changePassword() async {
    final state = AppScope.of(context);
    final currentPassword = TextEditingController();
    final newPassword = TextEditingController();
    final confirmPassword = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var obscureCurrentPassword = true;
    var obscureNewPassword = true;
    var obscureConfirmPassword = true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
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
                    obscureText: obscureCurrentPassword,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Current password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: () => setDialogState(
                          () => obscureCurrentPassword = !obscureCurrentPassword,
                        ),
                        icon: Icon(
                          obscureCurrentPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Enter your current password'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: newPassword,
                    obscureText: obscureNewPassword,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: 'New password',
                      prefixIcon: const Icon(Icons.password_rounded),
                      suffixIcon: IconButton(
                        onPressed: () => setDialogState(
                          () => obscureNewPassword = !obscureNewPassword,
                        ),
                        icon: Icon(
                          obscureNewPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (value) => value == null || value.length < 8
                        ? 'Use at least 8 characters'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmPassword,
                    obscureText: obscureConfirmPassword,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: 'Confirm new password',
                      prefixIcon: const Icon(Icons.password_rounded),
                      suffixIcon: IconButton(
                        onPressed: () => setDialogState(
                          () => obscureConfirmPassword = !obscureConfirmPassword,
                        ),
                        icon: Icon(
                          obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
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
          );
        },
      ),
    );
    currentPassword.dispose();
    newPassword.dispose();
    confirmPassword.dispose();
  }
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.initialValue});

  final AppUser initialValue;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialValue.name);
    _phone = TextEditingController(text: widget.initialValue.phone);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return 'Enter your phone number.';
    final normalised = phone.replaceAll(RegExp(r'[\s\-()]'), '');
    if (!RegExp(r'^(?:\+60|0)1\d{8,9}$').hasMatch(normalised)) {
      return 'Use a Malaysian mobile number, e.g. 012-345 6789.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Personal information',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (value) => value == null || value.trim().length < 2
                    ? 'Enter at least 2 characters'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[0-9+\-()\s]'),
                  ),
                  LengthLimitingTextInputFormatter(18),
                ],
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  hintText: '012-345 6789',
                  helperText: 'Malaysia mobile format: 01X or +601X',
                ),
                validator: _validatePhone,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () {
                        if (!_formKey.currentState!.validate()) return;
                        Navigator.of(context).pop(
                          widget.initialValue.copyWith(
                            name: _name.text.trim(),
                            phone: _phone.text.trim(),
                          ),
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
    );
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

class _PropertyPreferencesSheet extends StatefulWidget {
  const _PropertyPreferencesSheet({required this.initialValue});

  final UserPreferences initialValue;

  @override
  State<_PropertyPreferencesSheet> createState() =>
      _PropertyPreferencesSheetState();
}

class _PropertyPreferencesSheetState
    extends State<_PropertyPreferencesSheet> {
  static const double _minimumBudget = 0;
  static const double _maximumBudget = 1600000;
  static const int _budgetDivisions = 32;

  late String selectedState;
  late String selectedDistrict;
  late String propertyType;
  late RangeValues budgetRange;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialValue;
    selectedState =
        PropertyPreferenceOptions.states.contains(initial.preferredState)
        ? initial.preferredState
        : '';
    final districts = PropertyPreferenceOptions.districtsFor(selectedState);
    selectedDistrict = districts.contains(initial.preferredDistrict)
        ? initial.preferredDistrict
        : '';
    propertyType =
        PropertyPreferenceOptions.propertyTypes.contains(initial.propertyType)
        ? initial.propertyType
        : 'Any';

    final minimum = initial.minimumBudget
        .clamp(_minimumBudget, _maximumBudget)
        .toDouble();
    final maximum = initial.maximumBudget
        .clamp(_minimumBudget, _maximumBudget)
        .toDouble();
    budgetRange = RangeValues(
      minimum <= maximum ? minimum : maximum,
      maximum,
    );
  }

  @override
  Widget build(BuildContext context) {
    final districts = PropertyPreferenceOptions.districtsFor(selectedState);
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Property preferences',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                          ...PropertyPreferenceOptions.states.map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          ),
                        ],
                        onChanged: (value) => setState(() {
                          selectedState = value ?? '';
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
                            : (value) => setState(
                                () => selectedDistrict = value ?? '',
                              ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: propertyType,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Property type',
                        ),
                        items: PropertyPreferenceOptions.propertyTypes
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(
                          () => propertyType = value ?? 'Any',
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Preferred budget range',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _BudgetValue(
                              label: 'Minimum',
                              value: budgetRange.start,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _BudgetValue(
                              label: 'Maximum',
                              value: budgetRange.end,
                              alignEnd: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      RangeSlider(
                        min: _minimumBudget,
                        max: _maximumBudget,
                        divisions: _budgetDivisions,
                        values: budgetRange,
                        labels: RangeLabels(
                          formatRinggit(budgetRange.start),
                          formatRinggit(budgetRange.end),
                        ),
                        onChanged: (value) =>
                            setState(() => budgetRange = value),
                      ),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'RM 0',
                            style: TextStyle(
                              color: AppTheme.muted,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            'RM 1.6M',
                            style: TextStyle(
                              color: AppTheme.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop(
                          widget.initialValue.copyWith(
                            preferredState: selectedState,
                            preferredDistrict: selectedDistrict,
                            propertyType: propertyType,
                            minimumBudget: budgetRange.start,
                            maximumBudget: budgetRange.end,
                            budget: budgetRange.end,
                          ),
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
    );
  }
}

class _BudgetValue extends StatelessWidget {
  const _BudgetValue({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final double value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment:
        alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(color: AppTheme.muted, fontSize: 12),
      ),
      const SizedBox(height: 3),
      Text(
        formatRinggit(value),
        style: const TextStyle(
          color: AppTheme.blue,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}


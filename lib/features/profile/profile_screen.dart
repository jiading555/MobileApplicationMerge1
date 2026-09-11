import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/app_scope.dart';
import '../../app/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/location_normalizer.dart';
import '../../core/utils/responsive_layout.dart';
import '../../core/widgets/page_container.dart';
import '../../core/widgets/property_card.dart';
import '../../models/app_user.dart';
import '../../models/area_data.dart';
import '../../models/property.dart';
import '../../models/user_preferences.dart';
import '../search/property_detail_screen.dart';
import '../settings/settings_screen.dart';

bool _isUsableProfileProperty(AppState state, Property property) {
  final area = state.matchedAreaFor(property);
  if (area == null) {
    return false;
  }

  final propertyState = property.state?.trim();
  if (propertyState != null &&
      propertyState.isNotEmpty &&
      !LocationNormalizer.stateMatches(area.state, propertyState)) {
    return false;
  }

  final district = property.district?.trim();
  if (district != null &&
      district.isNotEmpty &&
      !LocationNormalizer.districtMatches(
        area.name,
        district,
        state: area.state,
      )) {
    return false;
  }

  return true;
}

List<Property> _profileAdvisorProperties(AppState state) {
  return state.properties
      .where((property) => _isUsableProfileProperty(state, property))
      .toList();
}

String? _profileDisplayState(Property property) {
  return LocationNormalizer.nullableDisplayStateName(property.state);
}

String? _profileDisplayDistrict(Property property) {
  return LocationNormalizer.nullableDisplayDistrictName(property.district);
}

String _profileLocalityAreaId(Property property) {
  final displayState = _profileDisplayState(property);
  final displayDistrict = _profileDisplayDistrict(property);

  if (displayState == null || displayDistrict == null) {
    return '';
  }

  return LocationNormalizer.canonicalAreaId(displayState, displayDistrict);
}

int? _profileComparablePrice(Property property) {
  return property.price ?? property.priceMin ?? property.priceMax;
}

List<String> _profileStateOptions(Iterable<Property> properties) {
  final states =
      properties
          .map(_profileDisplayState)
          .whereType<String>()
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

  return states;
}

List<_ProfileAreaOption> _profileAreaOptions(
  Iterable<Property> properties,
  String selectedState,
) {
  if (selectedState.isEmpty) {
    return const [];
  }

  final labelsById = <String, String>{};

  for (final property in properties) {
    final displayState = _profileDisplayState(property);
    final displayDistrict = _profileDisplayDistrict(property);
    final localityAreaId = _profileLocalityAreaId(property);

    if (displayState == null ||
        displayDistrict == null ||
        localityAreaId.isEmpty ||
        !LocationNormalizer.stateMatches(displayState, selectedState)) {
      continue;
    }

    labelsById.putIfAbsent(localityAreaId, () => displayDistrict);
  }

  final options =
      labelsById.entries
          .map(
            (entry) => _ProfileAreaOption(value: entry.key, label: entry.value),
          )
          .toList()
        ..sort((left, right) => left.label.compareTo(right.label));

  return options;
}

List<String> _profilePropertyTypes({
  required Iterable<Property> properties,
  required double targetBudget,
  required String targetState,
  required String targetAreaId,
}) {
  final types =
      properties
          .where((property) {
            final price = _profileComparablePrice(property);

            if (price == null || price > targetBudget) {
              return false;
            }

            final displayState = _profileDisplayState(property);
            final localityAreaId = _profileLocalityAreaId(property);

            if (targetAreaId.isNotEmpty) {
              return localityAreaId == targetAreaId;
            }

            if (targetState.isNotEmpty) {
              return displayState != null &&
                  LocationNormalizer.stateMatches(displayState, targetState);
            }

            return true;
          })
          .expand((property) => property.normalizedPropertyTypes)
          .toSet()
          .toList()
        ..sort();

  return types;
}

class _ProfileAreaOption {
  const _ProfileAreaOption({required this.value, required this.label});

  final String value;
  final String label;
}

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
    final error = await AppScope.of(
      context,
    ).uploadAvatar(await file.readAsBytes(), extension);
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
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
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
                      return ResponsiveLayout.isTablet(context)
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
                        builder: (_) =>
                            PropertyDetailScreen(propertyId: propertyId),
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
    _message(error ?? 'Profile updated successfully.', error != null);
  }

  Future<void> _editPreferences() async {
    final state = AppScope.of(context);
    final updated = await showModalBottomSheet<UserPreferences>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      enableDrag: true,
      useSafeArea: true,
      useRootNavigator: true,
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 320),
        reverseDuration: Duration(milliseconds: 240),
      ),
      builder: (context) =>
          _PropertyPreferencesSheet(initialValue: state.preferences),
    );
    if (!mounted || updated == null) return;

    final error = await state.saveAccountPreferences(updated);
    if (!mounted) return;
    _message(error ?? 'Preferences updated successfully.', error != null);
  }

  Future<void> _changePassword() async {
    final state = AppScope.of(context);
    final currentPassword = TextEditingController();
    final newPassword = TextEditingController();
    final confirmPassword = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var hideCurrent = true;
    var hideNew = true;
    var hideConfirm = true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                      obscureText: hideCurrent,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Current password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip: hideCurrent
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () =>
                              setDialogState(() => hideCurrent = !hideCurrent),
                          icon: Icon(
                            hideCurrent
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
                      obscureText: hideNew,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: 'New password',
                        prefixIcon: const Icon(Icons.password_rounded),
                        suffixIcon: IconButton(
                          tooltip: hideNew ? 'Show password' : 'Hide password',
                          onPressed: () =>
                              setDialogState(() => hideNew = !hideNew),
                          icon: Icon(
                            hideNew
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
                      obscureText: hideConfirm,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: 'Confirm new password',
                        prefixIcon: const Icon(Icons.password_rounded),
                        suffixIcon: IconButton(
                          tooltip: hideConfirm
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () =>
                              setDialogState(() => hideConfirm = !hideConfirm),
                          icon: Icon(
                            hideConfirm
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
        ),
      ),
    );
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
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-()\s]')),
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
    final initials = user.name
        .split(' ')
        .where((v) => v.isNotEmpty)
        .take(2)
        .map((v) => v[0].toUpperCase())
        .join();
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
                backgroundImage: user.avatarUrl == null
                    ? null
                    : NetworkImage(user.avatarUrl!),
                child: user.avatarUrl == null
                    ? Text(
                        initials,
                        style: const TextStyle(
                          color: AppTheme.blue,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      )
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
                if (user.isDemo)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'SAMPLE MODE',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
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
                showAll ? Icons.expand_less_rounded : Icons.expand_more_rounded,
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
          _TitleRow(
            title: 'Personal information',
            icon: Icons.person_outline_rounded,
            onEdit: onEdit,
          ),
          const SizedBox(height: 12),
          _InfoRow(label: 'Full name', value: user.name),
          _InfoRow(label: 'Email', value: user.email),
          _InfoRow(
            label: 'Phone',
            value: user.phone.isEmpty ? 'Not provided' : user.phone,
          ),
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
          _TitleRow(
            title: 'Property preferences',
            icon: Icons.tune_rounded,
            onEdit: onEdit,
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: 'State',
            value: value.preferredState.isEmpty
                ? 'Any state'
                : value.preferredState,
          ),
          _InfoRow(
            label: 'Area',
            value: value.preferredDistrict.isEmpty
                ? 'Any area'
                : value.preferredDistrict,
          ),
          _InfoRow(label: 'Type', value: value.propertyType),
          _InfoRow(
            label: 'Maximum budget',
            value: formatRinggit(value.maximumBudget),
          ),
        ],
      ),
    ),
  );
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({
    required this.title,
    required this.icon,
    required this.onEdit,
  });

  final String title;
  final IconData icon;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: AppTheme.blue),
      const SizedBox(width: 9),
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
      IconButton(
        onPressed: onEdit,
        tooltip: 'Edit',
        icon: const Icon(Icons.edit_outlined),
      ),
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
        SizedBox(
          width: 108,
          child: Text(
            label,
            style: const TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppTheme.blue,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ProfileBudgetControl extends StatefulWidget {
  const _ProfileBudgetControl({
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.divisions,
    required this.onChangeEnd,
  });

  final double value;
  final double minimum;
  final double maximum;
  final int divisions;
  final ValueChanged<double> onChangeEnd;

  @override
  State<_ProfileBudgetControl> createState() => _ProfileBudgetControlState();
}

class _ProfileBudgetControlState extends State<_ProfileBudgetControl> {
  late double _draftValue;

  @override
  void initState() {
    super.initState();
    _draftValue = widget.value;
  }

  @override
  void didUpdateWidget(covariant _ProfileBudgetControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _draftValue = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              'Maximum budget',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            Text(
              formatRinggit(_draftValue),
              style: const TextStyle(
                color: AppTheme.blue,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        Slider(
          min: widget.minimum,
          max: widget.maximum,
          divisions: widget.divisions,
          value: _draftValue,
          onChanged: (value) {
            setState(() => _draftValue = value);
            widget.onChangeEnd(value);
          },
        ),
      ],
    );
  }
}

class _PropertyPreferencesSheet extends StatefulWidget {
  const _PropertyPreferencesSheet({required this.initialValue});

  final UserPreferences initialValue;

  @override
  State<_PropertyPreferencesSheet> createState() =>
      _PropertyPreferencesSheetState();
}

class _PropertyPreferencesSheetState extends State<_PropertyPreferencesSheet> {
  static const double _minimumBudget = 350000;
  static const double _maximumBudget = 1600000;
  static const int _budgetDivisions = 25;

  bool _seeded = false;
  List<Property> _usableProperties = const [];
  Map<Property, AreaData> _propertyAreas = const {};

  late double maximumBudget;
  late String selectedState;
  late String selectedAreaId;
  late String propertyType;

  @override
  void initState() {
    super.initState();

    final initial = widget.initialValue;

    final savedMaximum = initial.maximumBudget > 0
        ? initial.maximumBudget
        : initial.budget;

    maximumBudget = savedMaximum
        .clamp(_minimumBudget, _maximumBudget)
        .toDouble();

    selectedState = '';
    selectedAreaId = '';
    propertyType = initial.propertyType.trim().isEmpty
        ? 'Any'
        : initial.propertyType.trim();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_seeded) return;

    final state = AppScope.of(context);
    _usableProperties = _profileAdvisorProperties(state);
    _propertyAreas = <Property, AreaData>{};
    for (final property in _usableProperties) {
      final area = state.matchedAreaFor(property);
      if (area != null) {
        _propertyAreas[property] = area;
      }
    }
    _usableProperties = _usableProperties
        .where(_propertyAreas.containsKey)
        .toList(growable: false);

    final states = _profileStateOptions(_usableProperties);

    final savedState = LocationNormalizer.nullableDisplayStateName(
      widget.initialValue.preferredState,
    );

    if (savedState != null && states.contains(savedState)) {
      selectedState = savedState;
    }

    if (selectedState.isNotEmpty &&
        widget.initialValue.preferredDistrict.trim().isNotEmpty) {
      final areaOptions = _profileAreaOptions(_usableProperties, selectedState);

      final savedAreaId = LocationNormalizer.canonicalAreaId(
        selectedState,
        widget.initialValue.preferredDistrict.trim(),
      );

      if (areaOptions.any((option) => option.value == savedAreaId)) {
        selectedAreaId = savedAreaId;
      }
    }

    final availableTypes = _profilePropertyTypes(
      properties: _usableProperties,
      targetBudget: maximumBudget,
      targetState: selectedState,
      targetAreaId: selectedAreaId,
    );

    if (propertyType != 'Any' && !availableTypes.contains(propertyType)) {
      propertyType = 'Any';
    }

    _seeded = true;
  }

  void _changeBudget(double value) {
    setState(() {
      maximumBudget = value;

      final availableTypes = _profilePropertyTypes(
        properties: _usableProperties,
        targetBudget: maximumBudget,
        targetState: selectedState,
        targetAreaId: selectedAreaId,
      );

      if (propertyType != 'Any' && !availableTypes.contains(propertyType)) {
        propertyType = 'Any';
      }
    });
  }

  void _changeState(String value) {
    setState(() {
      selectedState = value;
      selectedAreaId = '';

      final availableTypes = _profilePropertyTypes(
        properties: _usableProperties,
        targetBudget: maximumBudget,
        targetState: selectedState,
        targetAreaId: selectedAreaId,
      );

      if (propertyType != 'Any' && !availableTypes.contains(propertyType)) {
        propertyType = 'Any';
      }
    });
  }

  void _changeArea(String value) {
    setState(() {
      selectedAreaId = value;

      final availableTypes = _profilePropertyTypes(
        properties: _usableProperties,
        targetBudget: maximumBudget,
        targetState: selectedState,
        targetAreaId: selectedAreaId,
      );

      if (propertyType != 'Any' && !availableTypes.contains(propertyType)) {
        propertyType = 'Any';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final availableStates = _profileStateOptions(_usableProperties);

    final effectiveState =
        selectedState.isEmpty || availableStates.contains(selectedState)
        ? selectedState
        : '';

    final availableAreas = _profileAreaOptions(
      _usableProperties,
      effectiveState,
    );

    final availableAreaIds = availableAreas
        .map((option) => option.value)
        .toSet();

    final effectiveAreaId =
        selectedAreaId.isNotEmpty && availableAreaIds.contains(selectedAreaId)
        ? selectedAreaId
        : '';

    final availablePropertyTypes = _profilePropertyTypes(
      properties: _usableProperties,
      targetBudget: maximumBudget,
      targetState: effectiveState,
      targetAreaId: effectiveAreaId,
    );

    final effectivePropertyType =
        propertyType == 'Any' || availablePropertyTypes.contains(propertyType)
        ? propertyType
        : 'Any';

    String effectiveDistrict = '';

    if (effectiveAreaId.isNotEmpty) {
      for (final option in availableAreas) {
        if (option.value == effectiveAreaId) {
          effectiveDistrict = option.label;
          break;
        }
      }
    }

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
              const SizedBox(height: 18),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ProfileBudgetControl(
                        value: maximumBudget,
                        minimum: _minimumBudget,
                        maximum: _maximumBudget,
                        divisions: _budgetDivisions,
                        onChangeEnd: _changeBudget,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'RM 350,000',
                              style: TextStyle(
                                color: AppTheme.muted,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              'RM 1,600,000',
                              style: TextStyle(
                                color: AppTheme.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              key: ValueKey('profile-state-$effectiveState'),
                              initialValue: effectiveState,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'State',
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: '',
                                  child: Text(
                                    'Any state',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                ...availableStates.map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(
                                      value,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                _changeState(value ?? '');
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              key: ValueKey(
                                'profile-area-$effectiveAreaId-$effectiveState',
                              ),
                              initialValue: effectiveAreaId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Area',
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: '',
                                  child: Text(
                                    effectiveState.isEmpty
                                        ? 'Any area'
                                        : 'Any area',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                ...availableAreas.map(
                                  (area) => DropdownMenuItem<String>(
                                    value: area.value,
                                    child: Text(
                                      area.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: effectiveState.isEmpty
                                  ? null
                                  : (value) {
                                      _changeArea(value ?? '');
                                    },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        key: ValueKey(
                          'profile-type-$effectivePropertyType-'
                          '$effectiveAreaId-$effectiveState-'
                          '${maximumBudget.round()}',
                        ),
                        initialValue: effectivePropertyType,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Property type',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 'Any',
                            child: Text(
                              'Any property type',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ...availablePropertyTypes.map(
                            (value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: availablePropertyTypes.isEmpty
                            ? null
                            : (value) {
                                setState(() {
                                  propertyType = value ?? 'Any';
                                });
                              },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          final finalState = effectiveState;
                          final finalDistrict = effectiveDistrict;

                          final hiddenMinimumBudget = widget
                              .initialValue
                              .minimumBudget
                              .clamp(0.0, maximumBudget)
                              .toDouble();

                          Navigator.of(context).pop(
                            widget.initialValue.copyWith(
                              preferredState: finalState,
                              preferredDistrict: finalDistrict,
                              preferredAreaId: 'any',

                              propertyType: effectivePropertyType,
                              minimumBudget: hiddenMinimumBudget,
                              maximumBudget: maximumBudget,
                              budget: maximumBudget,
                            ),
                          );
                        },
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Save preferences'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

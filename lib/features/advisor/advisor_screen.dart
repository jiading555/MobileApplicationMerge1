import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive_layout.dart';
import '../../core/widgets/page_container.dart';
import '../../core/widgets/property_art.dart';
import '../../models/recommendation.dart';
import '../../models/user_preferences.dart';
import '../search/property_detail_screen.dart';
import 'comparison_screen.dart';

class AdvisorScreen extends StatefulWidget {
  const AdvisorScreen({super.key});

  @override
  State<AdvisorScreen> createState() => _AdvisorScreenState();
}

class _AdvisorScreenState extends State<AdvisorScreen> {
  bool seeded = false;
  bool showResults = true;
  late PropertyGoal goal;
  late double budget;
  late String areaId;
  late String propertyType;
  late double safetyPriority;
  late double transportPriority;
  late double facilitiesPriority;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!seeded) {
      final preferences = AppScope.of(context).preferences;
      goal = preferences.goal;
      budget = preferences.budget;
      areaId = preferences.preferredAreaId;
      propertyType = preferences.propertyType;
      safetyPriority = preferences.safetyPriority;
      transportPriority = preferences.transportPriority;
      facilitiesPriority = preferences.facilitiesPriority;
      seeded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final recommendations = state.recommendations;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart property advisor'),
        actions: [
          IconButton(
            onPressed: () => _showMethod(context),
            tooltip: 'How scoring works',
            icon: const Icon(Icons.info_outline_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: PageContainer(
          maxWidth: 1100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AdvisorIntro(goal: goal),
              const SizedBox(height: 22),
              _PreferencePanel(
                goal: goal,
                budget: budget,
                areaId: areaId,
                propertyType: propertyType,
                safetyPriority: safetyPriority,
                transportPriority: transportPriority,
                facilitiesPriority: facilitiesPriority,
                onGoalChanged: (value) => setState(() => goal = value),
                onBudgetChanged: (value) => setState(() => budget = value),
                onAreaChanged: (value) => setState(() => areaId = value),
                onTypeChanged: (value) => setState(() => propertyType = value),
                onSafetyChanged: (value) =>
                    setState(() => safetyPriority = value),
                onTransportChanged: (value) =>
                    setState(() => transportPriority = value),
                onFacilitiesChanged: (value) =>
                    setState(() => facilitiesPriority = value),
                onGenerate: _generate,
              ),
              if (showResults) ...[
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Top matches from your preferences',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${recommendations.length} matches ranked with a transparent weighted score',
                            style: const TextStyle(color: AppTheme.muted),
                          ),
                        ],
                      ),
                    ),
                    if (recommendations.length >= 2)
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ComparisonScreen(
                              recommendations: recommendations.take(3).toList(),
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.compare_arrows_rounded),
                        label: const Text('Compare'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (recommendations.isEmpty)
                  const _NoMatches()
                else ...[
                  _TopRecommendation(recommendation: recommendations.first),
                  const SizedBox(height: 14),
                  ...recommendations
                      .skip(1)
                      .take(2)
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _RecommendationTile(recommendation: item),
                        ),
                      ),
                ],
                const SizedBox(height: 10),
                const _DecisionNotice(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _generate() {
    AppScope.of(context).updatePreferences(
      UserPreferences(
        goal: goal,
        budget: budget,
        preferredAreaId: areaId,
        propertyType: propertyType,
        safetyPriority: safetyPriority,
        transportPriority: transportPriority,
        facilitiesPriority: facilitiesPriority,
      ),
    );
    setState(() => showResults = true);
  }

  void _showMethod(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Transparent recommendation method',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              const Text(
                'Own-stay scores combine affordability, safety, accessibility, infrastructure and internet connectivity. Investment scores combine affordability, historical price growth, population growth, estimated rental yield and demand signals.',
              ),
              const SizedBox(height: 12),
              const Text(
                'The app uses a deterministic weighted formula. It does not send personal or property data to a generative AI service.',
                style: TextStyle(color: AppTheme.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdvisorIntro extends StatelessWidget {
  const _AdvisorIntro({required this.goal});

  final PropertyGoal goal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.navy, AppTheme.blue, AppTheme.teal],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppTheme.blue,
              size: 30,
            ),
          ),
          const SizedBox(width: 17),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal == PropertyGoal.ownStay
                      ? 'Find a home that fits your life'
                      : 'Explore investment potential',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Set your priorities and see how every score is calculated.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreferencePanel extends StatelessWidget {
  const _PreferencePanel({
    required this.goal,
    required this.budget,
    required this.areaId,
    required this.propertyType,
    required this.safetyPriority,
    required this.transportPriority,
    required this.facilitiesPriority,
    required this.onGoalChanged,
    required this.onBudgetChanged,
    required this.onAreaChanged,
    required this.onTypeChanged,
    required this.onSafetyChanged,
    required this.onTransportChanged,
    required this.onFacilitiesChanged,
    required this.onGenerate,
  });

  final PropertyGoal goal;
  final double budget;
  final String areaId;
  final String propertyType;
  final double safetyPriority;
  final double transportPriority;
  final double facilitiesPriority;
  final ValueChanged<PropertyGoal> onGoalChanged;
  final ValueChanged<double> onBudgetChanged;
  final ValueChanged<String> onAreaChanged;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<double> onSafetyChanged;
  final ValueChanged<double> onTransportChanged;
  final ValueChanged<double> onFacilitiesChanged;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your property goal',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 11),
            SegmentedButton<PropertyGoal>(
              segments: const [
                ButtonSegment(
                  value: PropertyGoal.ownStay,
                  icon: Icon(Icons.home_rounded),
                  label: Text('Own stay'),
                ),
                ButtonSegment(
                  value: PropertyGoal.investment,
                  icon: Icon(Icons.trending_up_rounded),
                  label: Text('Investment'),
                ),
              ],
              selected: {goal},
              onSelectionChanged: (values) => onGoalChanged(values.first),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text(
                  'Maximum budget',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  formatRinggit(budget),
                  style: const TextStyle(
                    color: AppTheme.blue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            Slider(
              min: 350000,
              max: 1600000,
              divisions: 25,
              value: budget,
              onChanged: onBudgetChanged,
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = ResponsiveLayout.isTablet(context);
                final area = DropdownButtonFormField<String>(
                  initialValue: areaId,
                  decoration: const InputDecoration(
                    labelText: 'Preferred area',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 'any',
                      child: Text('Any area'),
                    ),
                    ...state.areas.map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text('${item.name}, ${item.state}'),
                      ),
                    ),
                  ],
                  onChanged: (value) => onAreaChanged(value ?? 'any'),
                );
                final type = DropdownButtonFormField<String>(
                  initialValue: propertyType,
                  decoration: const InputDecoration(labelText: 'Property type'),
                  items:
                      const [
                            'Any',
                            'Condominium',
                            'Apartment',
                            'Terrace',
                            'Semi-D',
                          ]
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                  onChanged: (value) => onTypeChanged(value ?? 'Any'),
                );
                return wide
                    ? Row(
                        children: [
                          Expanded(child: area),
                          const SizedBox(width: 12),
                          Expanded(child: type),
                        ],
                      )
                    : Column(
                        children: [area, const SizedBox(height: 12), type],
                      );
              },
            ),
            if (goal == PropertyGoal.ownStay) ...[
              const SizedBox(height: 24),
              Text(
                'What matters most?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              _PrioritySlider(
                icon: Icons.shield_outlined,
                label: 'Safety',
                value: safetyPriority,
                onChanged: onSafetyChanged,
              ),
              _PrioritySlider(
                icon: Icons.train_outlined,
                label: 'Public transport',
                value: transportPriority,
                onChanged: onTransportChanged,
              ),
              _PrioritySlider(
                icon: Icons.local_hospital_outlined,
                label: 'Nearby facilities',
                value: facilitiesPriority,
                onChanged: onFacilitiesChanged,
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onGenerate,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Generate matches'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrioritySlider extends StatelessWidget {
  const _PrioritySlider({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: AppTheme.muted),
        const SizedBox(width: 8),
        SizedBox(
          width: 105,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: Slider(
            min: 0.2,
            max: 1,
            divisions: 4,
            value: value,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 50,
          child: Text(
            value >= 0.8
                ? 'High'
                : value >= 0.5
                ? 'Medium'
                : 'Low',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 11, color: AppTheme.muted),
          ),
        ),
      ],
    );
  }
}

class _TopRecommendation extends StatelessWidget {
  const _TopRecommendation({required this.recommendation});

  final PropertyRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final property = recommendation.property;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = ResponsiveLayout.isTablet(context);
          final art = Stack(
            children: [
              PropertyArt(palette: property.palette, height: wide ? 360 : 220),
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'HIGHEST MATCH',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          );
          final body = Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        property.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    _ScoreBadge(score: recommendation.score),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  property.address,
                  style: const TextStyle(color: AppTheme.muted),
                ),
                const SizedBox(height: 8),
                Text(
                  formatRinggit(property.price!),
                  style: const TextStyle(
                    color: AppTheme.green,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Why this matches you',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                ...recommendation.reasons.map(
                  (reason) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          color: AppTheme.green,
                          size: 18,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            reason,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            PropertyDetailScreen(propertyId: property.id),
                      ),
                    ),
                    child: const Text('View details'),
                  ),
                ),
              ],
            ),
          );
          return wide
              ? Row(
                  children: [
                    Expanded(flex: 6, child: art),
                    Expanded(flex: 5, child: body),
                  ],
                )
              : Column(children: [art, body]);
        },
      ),
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  const _RecommendationTile({required this.recommendation});

  final PropertyRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final property = recommendation.property;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PropertyDetailScreen(propertyId: property.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(
                width: 104,
                child: PropertyArt(
                  palette: property.palette,
                  height: 104,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      property.address,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatRinggit(property.price!),
                      style: const TextStyle(
                        color: AppTheme.green,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      recommendation.reasons.first,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              _ScoreBadge(score: recommendation.score),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.blue.withValues(alpha: 0.09),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.blue.withValues(alpha: 0.25),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            score.round().toString(),
            style: const TextStyle(
              color: AppTheme.blue,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Text(
            '/100',
            style: TextStyle(color: AppTheme.muted, fontSize: 8),
          ),
        ],
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Row(
          children: [
            Icon(Icons.filter_alt_off_rounded, color: AppTheme.muted),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'No listings match this area and property type. Try Any area or Any type.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecisionNotice extends StatelessWidget {
  const _DecisionNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF4D89A)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.fact_check_outlined, color: Color(0xFF9B6A08)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Decision support only. Scores depend on available official data and selected weights, not a professional valuation.',
              style: TextStyle(color: Color(0xFF70500C), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

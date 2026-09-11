import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/saved_recommendation_service.dart';

class SavedRecommendationsScreen extends StatefulWidget {
  const SavedRecommendationsScreen({super.key});

  @override
  State<SavedRecommendationsScreen> createState() =>
      _SavedRecommendationsScreenState();
}

class _SavedRecommendationsScreenState
    extends State<SavedRecommendationsScreen> {
  final SavedRecommendationService _service =
      const SavedRecommendationService();

  late Future<List<Map<String, dynamic>>> _savedFuture;

  @override
  void initState() {
    super.initState();
    _loadSavedRecommendations();
  }

  void _loadSavedRecommendations() {
    _savedFuture = _service.getSavedRecommendationSessions();
  }

  Future<void> _refresh() async {
    setState(_loadSavedRecommendations);
    await _savedFuture;
  }

  Future<void> _deleteSession({
    required String id,
    required String title,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete saved recommendation?'),
        content: Text(
          'Delete this saved recommendation session'
          '${title.trim().isEmpty ? '' : ' for "$title"'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _service.deleteRecommendationSession(id);

      if (!mounted) return;

      setState(_loadSavedRecommendations);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved recommendation deleted.')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete: '
            '${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Recommendations')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _savedFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 80),
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 52,
                    color: AppTheme.muted,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Unable to load saved recommendations.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString().replaceFirst('Exception: ', ''),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.muted, fontSize: 11),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () {
                      setState(_loadSavedRecommendations);
                    },
                    child: const Text('Try Again'),
                  ),
                ],
              );
            }

            final sessions = snapshot.data ?? const [];

            if (sessions.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 100),
                  Icon(
                    Icons.bookmarks_outlined,
                    size: 64,
                    color: AppTheme.muted,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No saved recommendations yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  SizedBox(height: 7),
                  Text(
                    'Generate recommendations in Smart Property Advisor '
                    'and save the current Top matches.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.muted, fontSize: 12),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sessions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final session = sessions[index];
                final recommendations = _mapList(session['recommendations']);

                final firstPropertyName = recommendations.isEmpty
                    ? ''
                    : recommendations.first['property_name']
                              ?.toString()
                              .trim() ??
                          '';

                return _SavedSessionCard(
                  record: session,
                  onDelete: () => _deleteSession(
                    id: session['id'].toString(),
                    title: firstPropertyName,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _SavedSessionCard extends StatelessWidget {
  const _SavedSessionCard({required this.record, required this.onDelete});

  final Map<String, dynamic> record;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final goal = _goalLabel(record['goal']?.toString());

    final budget = _toDouble(record['budget']);

    final state = record['preferred_state']?.toString().trim() ?? '';

    final district = record['preferred_district']?.toString().trim() ?? '';

    final propertyType = record['property_type']?.toString().trim() ?? '';

    final recommendations = _mapList(record['recommendations']);

    final appliedWeights = _mapList(record['applied_weights']);

    final createdAt = record['created_at']?.toString();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.blue.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.bookmark_rounded,
                    color: AppTheme.blue,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        createdAt == null || createdAt.trim().isEmpty
                            ? 'Saved recommendation'
                            : _formatDateTitle(createdAt),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _locationText(state: state, district: district),
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Delete saved session',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),

            const SizedBox(height: 14),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: goal == 'Investment'
                      ? Icons.trending_up_rounded
                      : Icons.home_rounded,
                  label: goal,
                ),
                if (budget > 0)
                  _InfoChip(
                    icon: Icons.payments_outlined,
                    label: _formatPrice(budget),
                  ),
                _InfoChip(
                  icon: Icons.home_work_outlined,
                  label: propertyType.isEmpty
                      ? 'Any property type'
                      : propertyType,
                ),
                _InfoChip(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Top ${recommendations.length}',
                ),
              ],
            ),

            if (appliedWeights.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Applied weights',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: appliedWeights.map((weight) {
                  final label = weight['label']?.toString().trim() ?? '';
                  final percentage = _toDouble(weight['percentage']);

                  return _WeightChip(label: label, percentage: percentage);
                }).toList(),
              ),
            ],

            const SizedBox(height: 16),
            const Divider(),

            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: false,
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 4, bottom: 2),
                leading: const Icon(
                  Icons.view_carousel_outlined,
                  color: AppTheme.blue,
                  size: 20,
                ),
                title: Text(
                  'Saved Top ${recommendations.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                subtitle: const Text(
                  'Tap to show saved properties',
                  style: TextStyle(color: AppTheme.muted, fontSize: 9),
                ),
                children: [
                  if (recommendations.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'No recommendation snapshot is stored in this session.',
                          style: TextStyle(color: AppTheme.muted, fontSize: 11),
                        ),
                      ),
                    )
                  else
                    ...recommendations.map(
                      (recommendation) =>
                          _SavedPropertyTile(record: recommendation),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedPropertyTile extends StatelessWidget {
  const _SavedPropertyTile({required this.record});

  final Map<String, dynamic> record;

  @override
  Widget build(BuildContext context) {
    final rank = _toInt(record['rank']);

    final name = record['property_name']?.toString().trim() ?? '';

    final address = record['address']?.toString().trim() ?? '';

    final score = _toDouble(record['score']);

    final price = _toDouble(record['price']);

    final propertyTypes = _stringList(record['property_types']);

    final factors = _mapList(record['factors']);

    final advantages = _stringList(record['advantages']);

    final cautions = _stringList(record['cautions']);

    final typeText = propertyTypes.join(' / ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.blue.withValues(alpha: 0.14)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: rank == 1
                ? AppTheme.green.withValues(alpha: 0.10)
                : AppTheme.blue.withValues(alpha: 0.09),
            shape: BoxShape.circle,
          ),
          child: Text(
            '#$rank',
            style: TextStyle(
              color: rank == 1 ? AppTheme.green : AppTheme.blue,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        title: Text(
          name.isEmpty ? 'Property' : name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            [
              if (price > 0) _formatPrice(price),
              if (typeText.isNotEmpty) typeText,
            ].join(' • '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.muted, fontSize: 10),
          ),
        ),
        trailing: _ScoreBadge(score: score),
        children: [
          if (address.isNotEmpty) _DetailRow(label: 'Address', value: address),

          if (typeText.isNotEmpty)
            _DetailRow(label: 'Property type', value: typeText),

          if (price > 0)
            _DetailRow(label: 'Saved price', value: _formatPrice(price)),

          _DetailRow(
            label: 'Overall score',
            value: '${score.toStringAsFixed(1)}/100',
          ),

          if (factors.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Score factors',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
              ),
            ),
            const SizedBox(height: 6),
            ...factors.map((factor) {
              final label = factor['label']?.toString() ?? 'Factor';
              final factorScore = _toDouble(factor['score']);
              final percentage = _toDouble(factor['percentage']);
              final contribution = _toDouble(factor['contribution']);

              return _FactorRow(
                label: label,
                score: factorScore,
                percentage: percentage,
                contribution: contribution,
              );
            }),
          ],

          if (advantages.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Advantages',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
              ),
            ),
            const SizedBox(height: 6),
            ...advantages.map((item) => _Bullet(text: item, positive: true)),
          ],

          if (cautions.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Watch out for',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
              ),
            ),
            const SizedBox(height: 6),
            ...cautions.map((item) => _Bullet(text: item, positive: false)),
          ],
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        score.toStringAsFixed(1),
        style: const TextStyle(
          color: AppTheme.blue,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.blue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.blue),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _WeightChip extends StatelessWidget {
  const _WeightChip({required this.label, required this.percentage});

  final String label;
  final double percentage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.green.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label ${percentage.toStringAsFixed(1)}%',
        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.muted, fontSize: 10),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _FactorRow extends StatelessWidget {
  const _FactorRow({
    required this.label,
    required this.score,
    required this.percentage,
    required this.contribution,
  });

  final String label;
  final double score;
  final double percentage;
  final double contribution;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 10))),
          const SizedBox(width: 8),
          Text(
            '${score.toStringAsFixed(0)}/100'
            ' × ${percentage.toStringAsFixed(1)}%'
            ' = ${contribution.toStringAsFixed(1)}',
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text, required this.positive});

  final String text;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            positive
                ? Icons.check_circle_outline_rounded
                : Icons.warning_amber_rounded,
            size: 15,
            color: positive ? AppTheme.green : const Color(0xFFB7791F),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 10))),
        ],
      ),
    );
  }
}

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is! List) {
    return [];
  }

  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

List<String> _stringList(dynamic value) {
  if (value is! List) {
    return [];
  }

  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

double _toDouble(dynamic value) {
  if (value == null) {
    return 0;
  }

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value.toString()) ?? 0;
}

int _toInt(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _goalLabel(String? value) {
  switch (value) {
    case 'ownStay':
      return 'Own Stay';
    case 'investment':
      return 'Investment';
    default:
      return value == null || value.trim().isEmpty ? 'Recommendation' : value;
  }
}

String _locationText({required String state, required String district}) {
  if (state.isEmpty && district.isEmpty) {
    return 'Any location';
  }

  if (state.isNotEmpty && district.isEmpty) {
    return '$state • Any area';
  }

  if (state.isEmpty) {
    return district;
  }

  return '$state • $district';
}

String _formatPrice(double price) {
  final number = price.round();
  final negative = number < 0;
  final digits = number.abs().toString();

  final buffer = StringBuffer();

  for (var index = 0; index < digits.length; index++) {
    final remaining = digits.length - index;

    buffer.write(digits[index]);

    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }

  return '${negative ? '-' : ''}RM $buffer';
}

String _formatDateTitle(String value) {
  final date = DateTime.tryParse(value)?.toLocal();

  if (date == null) {
    return 'Saved recommendation';
  }

  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';

  return '${date.day} ${months[date.month - 1]} ${date.year}, '
      '$hour12:$minute $period';
}

import 'package:flutter/material.dart';

import '../../services/saved_recommendation_service.dart';

class SavedRecommendationsScreen extends StatefulWidget {
  const SavedRecommendationsScreen({
    super.key,
  });

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
    _savedFuture =
        _service.getSavedRecommendations();
  }

  Future<void> _refresh() async {
    setState(() {
      _loadSavedRecommendations();
    });

    await _savedFuture;
  }

  Future<void> _deleteRecommendation({
    required String id,
    required String propertyName,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Delete recommendation?',
          ),
          content: Text(
            'Remove "$propertyName" from your saved recommendations?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _service.deleteRecommendation(
        id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _loadSavedRecommendations();
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Saved recommendation deleted.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Saved Recommendations',
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<
            List<Map<String, dynamic>>>(
          future: _savedFuture,
          builder: (
              context,
              snapshot,
              ) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child:
                CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return ListView(
                padding:
                const EdgeInsets.all(24),
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Unable to load saved recommendations.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        _loadSavedRecommendations();
                      });
                    },
                    child: const Text(
                      'Try Again',
                    ),
                  ),
                ],
              );
            }

            final saved =
                snapshot.data ?? [];

            if (saved.isEmpty) {
              return ListView(
                padding:
                const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 100),
                  Icon(
                    Icons.bookmark_border,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No saved recommendations yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight:
                      FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Save a property recommendation from the Advisor page and it will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding:
              const EdgeInsets.all(16),
              itemCount: saved.length,
              separatorBuilder:
                  (context, index) =>
              const SizedBox(
                height: 12,
              ),
              itemBuilder: (
                  context,
                  index,
                  ) {
                return _SavedRecommendationCard(
                  record: saved[index],
                  onDelete: () {
                    final record =
                    saved[index];

                    _deleteRecommendation(
                      id:
                      record['id'].toString(),
                      propertyName:
                      record['property_name']
                          ?.toString() ??
                          'Property',
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _SavedRecommendationCard
    extends StatelessWidget {
  const _SavedRecommendationCard({
    required this.record,
    required this.onDelete,
  });

  final Map<String, dynamic> record;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final propertyName =
        record['property_name']
            ?.toString() ??
            'Unknown property';

    final address =
        record['address']
            ?.toString() ??
            'Address unavailable';

    final propertyType =
        record['property_type']
            ?.toString() ??
            'Unknown';

    final goal =
        record['goal']?.toString() ??
            '';

    final score =
    _toDouble(
      record['score'],
    );

    final price =
    _toDouble(
      record['price'],
    );

    final aiSummary =
    record['ai_summary']
        ?.toString();

    final createdAt =
    record['created_at']
        ?.toString();

    final advantages =
    _toStringList(
      record['advantages'],
    );

    final cautions =
    _toStringList(
      record['cautions'],
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    propertyName,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline,
                  ),
                ),
              ],
            ),

            Text(
              address,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 14),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.flag_outlined,
                  label: goal == 'ownStay'
                      ? 'Own Stay'
                      : goal == 'investment'
                      ? 'Investment'
                      : goal,
                ),
                _InfoChip(
                  icon: Icons.home_outlined,
                  label: propertyType,
                ),
                _InfoChip(
                  icon: Icons.star_outline,
                  label:
                  '${score.toStringAsFixed(1)}/100',
                ),
              ],
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                const Text(
                  'Price',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  price <= 0
                      ? 'Unavailable'
                      : _formatPrice(price),
                  style: const TextStyle(
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ],
            ),

            if (aiSummary != null &&
                aiSummary.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 18,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'AI Recommendation Summary',
                    style: TextStyle(
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                aiSummary,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],

            if (advantages.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Advantages',
                style: TextStyle(
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              ...advantages.map(
                    (item) => _Bullet(
                  text: item,
                  positive: true,
                ),
              ),
            ],

            if (cautions.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                'Watch out for',
                style: TextStyle(
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              ...cautions.map(
                    (item) => _Bullet(
                  text: item,
                  positive: false,
                ),
              ),
            ],

            if (createdAt != null) ...[
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 6),
              Text(
                'Saved ${_formatDate(createdAt)}',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest,
        borderRadius:
        BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize:
        MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight:
              FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({
    required this.text,
    required this.positive,
  });

  final String text;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 5,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            positive
                ? Icons
                .check_circle_outline
                : Icons
                .warning_amber_outlined,
            size: 15,
            color: positive
                ? Colors.green
                : Colors.orange,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

double _toDouble(
    dynamic value,
    ) {
  if (value == null) {
    return 0;
  }

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(
    value.toString(),
  ) ??
      0;
}

List<String> _toStringList(
    dynamic value,
    ) {
  if (value is! List) {
    return [];
  }

  return value
      .map(
        (item) =>
        item.toString(),
  )
      .toList();
}

String _formatPrice(
    double price,
    ) {
  final value =
  price.round().toString();

  final buffer =
  StringBuffer();

  for (int i = 0;
  i < value.length;
  i++) {
    final remaining =
        value.length - i;

    buffer.write(value[i]);

    if (remaining > 1 &&
        remaining % 3 == 1) {
      buffer.write(',');
    }
  }

  return 'RM $buffer';
}

String _formatDate(
    String value,
    ) {
  final date =
  DateTime.tryParse(value)
      ?.toLocal();

  if (date == null) {
    return value;
  }

  String twoDigits(
      int number,
      ) =>
      number
          .toString()
          .padLeft(2, '0');

  return '${date.year}-'
      '${twoDigits(date.month)}-'
      '${twoDigits(date.day)} '
      '${twoDigits(date.hour)}:'
      '${twoDigits(date.minute)}';
}
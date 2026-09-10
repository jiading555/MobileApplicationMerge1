import 'package:flutter/material.dart';

import '../../models/recommendation.dart';
import '../../models/user_preferences.dart';
import '../../services/ai_comparison_service.dart';

class AiComparisonCard extends StatefulWidget {
  const AiComparisonCard({
    super.key,
    required this.recommendations,
    required this.goal,
  });

  final List<PropertyRecommendation> recommendations;
  final PropertyGoal goal;

  @override
  State<AiComparisonCard> createState() => _AiComparisonCardState();
}

class _AiComparisonCardState extends State<AiComparisonCard> {
  final AiComparisonService _service = const AiComparisonService();

  Future<String>? _comparisonFuture;

  void _generate() {
    setState(() {
      _comparisonFuture = _service.generateComparisonSummary(
        recommendations: widget.recommendations,
        goal: widget.goal,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI Comparison Summary',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            Text(
              'Compare ${widget.recommendations.length} '
              'selected properties using their '
              'calculated scores and factors.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),

            const SizedBox(height: 12),

            if (_comparisonFuture == null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _generate,
                  icon: const Icon(Icons.compare_arrows),
                  label: const Text('Generate AI Comparison'),
                ),
              )
            else
              FutureBuilder<String>(
                future: _comparisonFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                          SizedBox(width: 12),
                          Text('Comparing properties...'),
                        ],
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          snapshot.error.toString(),
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _generate,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                        ),
                      ],
                    );
                  }

                  if (snapshot.hasData) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          snapshot.data!,
                          style: const TextStyle(height: 1.5, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _generate,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Regenerate'),
                        ),
                        const Text(
                          'AI explains the existing '
                          'comparison. Scores are '
                          'calculated separately by '
                          'the recommendation algorithm.',
                          style: TextStyle(fontSize: 9, color: Colors.grey),
                        ),
                      ],
                    );
                  }

                  return const Text('No comparison available.');
                },
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/recommendation.dart';
import '../../models/user_preferences.dart';
import '../../services/ai_advisor_chat_service.dart';

class AiAdvisorChatScreen extends StatefulWidget {
  const AiAdvisorChatScreen({
    super.key,
    required this.recommendations,
    required this.preferences,
  });

  final List<PropertyRecommendation> recommendations;
  final UserPreferences preferences;

  @override
  State<AiAdvisorChatScreen> createState() => _AiAdvisorChatScreenState();
}

class _AiAdvisorChatScreenState extends State<AiAdvisorChatScreen> {
  final AiAdvisorChatService _aiService = const AiAdvisorChatService();

  final TextEditingController _controller = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  final List<_ChatMessage> _messages = [];

  bool _isLoading = false;

  List<String> get _suggestedQuestions {
    final questions = <String>[
      'Why is the first property ranked highest?',
      'What is the main weakness of the top property?',
      'Which factor affects my recommendation the most?',
      'Which property best matches my priorities?',
      'What should I consider before choosing a property?',
    ];

    if (widget.recommendations.length >= 2) {
      questions.insert(1, 'Compare Property #1 and Property #2');
    }

    if (widget.recommendations.length >= 3) {
      questions.add('Compare Property #1 and Property #3');
    }

    return questions;
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? suggestedQuestion]) async {
    final question = (suggestedQuestion ?? _controller.text).trim();

    if (question.isEmpty || _isLoading) {
      return;
    }

    if (widget.recommendations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generate property recommendations first.'),
        ),
      );
      return;
    }

    final history = _messages
        .map(
          (message) => {
            'role': message.isUser ? 'User' : 'AI Advisor',
            'text': message.text,
          },
        )
        .toList();

    setState(() {
      _messages.add(_ChatMessage(text: question, isUser: true));

      _isLoading = true;
    });

    _controller.clear();

    _scrollToBottom();

    try {
      final response = await _aiService.sendMessage(
        question: question,
        recommendations: widget.recommendations,
        preferences: widget.preferences,
        conversationHistory: history,
      );

      if (!mounted) return;

      setState(() {
        _messages.add(_ChatMessage(text: response, isUser: false));
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _messages.add(
          _ChatMessage(
            text: 'Sorry, I could not generate an AI advisor response.\n\n$e',
            isUser: false,
            isError: true,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _clearChat() {
    if (_isLoading) return;

    setState(() {
      _messages.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final goal = widget.preferences.goal == PropertyGoal.ownStay
        ? 'Own Stay'
        : 'Investment';

    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: isLandscape ? 48 : null,
        title: const Text('AI Property Advisor'),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              tooltip: 'Clear chat',
              onPressed: _isLoading ? null : _clearChat,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (isLandscape)
              _CompactAdvisorContext(
                goal: goal,
                recommendationCount: widget.recommendations.length,
              )
            else
              _AdvisorContextCard(
                goal: goal,
                recommendationCount: widget.recommendations.length,
              ),

            Expanded(
              child: _messages.isEmpty
                  ? _buildWelcomeView(isLandscape: isLandscape)
                  : _buildChatView(isLandscape: isLandscape),
            ),

            _buildBottomArea(isLandscape: isLandscape),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeView({required bool isLandscape}) {
    if (isLandscape) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        children: [
          const Text(
            'Ask about your recommendations',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose a suggested question or type your own question below.',
            style: TextStyle(color: AppTheme.muted, fontSize: 10),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestedQuestions
                .map(
                  (question) => ActionChip(
                    onPressed: _isLoading ? null : () => _sendMessage(question),
                    avatar: const Icon(
                      Icons.auto_awesome_rounded,
                      size: 14,
                      color: AppTheme.blue,
                    ),
                    label: Text(
                      question,
                      style: const TextStyle(
                        color: AppTheme.blue,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: AppTheme.blue.withValues(alpha: 0.06),
                    side: BorderSide(
                      color: AppTheme.blue.withValues(alpha: 0.20),
                    ),
                    visualDensity: isLandscape
                        ? const VisualDensity(horizontal: -2, vertical: -3)
                        : VisualDensity.compact,
                  ),
                )
                .toList(),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 12),

        const Icon(Icons.smart_toy_outlined, size: 64, color: AppTheme.blue),

        const SizedBox(height: 16),

        Text(
          'Ask about your recommendations',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 8),

        Text(
          'The AI advisor uses your current property '
          'recommendations, scores and priorities to '
          'help explain the results.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),

        const SizedBox(height: 24),

        Text(
          'Suggested questions',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),

        const SizedBox(height: 12),

        ..._suggestedQuestions.map(
          (question) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              onPressed: _isLoading ? null : () => _sendMessage(question),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.blue,
                side: BorderSide(color: AppTheme.blue.withValues(alpha: 0.25)),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 17,
                    color: AppTheme.blue,
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Text(
                      question,
                      style: const TextStyle(color: AppTheme.blue),
                    ),
                  ),

                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: AppTheme.blue,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChatView({required bool isLandscape}) {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(
        16,
        isLandscape ? 8 : 16,
        16,
        isLandscape ? 8 : 16,
      ),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isLoading && index == _messages.length) {
          return const _TypingBubble();
        }

        final message = _messages[index];

        return _MessageBubble(message: message, compact: isLandscape);
      },
    );
  }

  Widget _buildBottomArea({required bool isLandscape}) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_messages.isNotEmpty) ...[
              if (!isLandscape)
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 9, 14, 5),
                  child: Text(
                    'Suggested questions',
                    style: TextStyle(
                      color: AppTheme.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

              _buildHorizontalSuggestions(isLandscape: isLandscape),

              SizedBox(height: isLandscape ? 3 : 8),
            ],

            _buildInputArea(isLandscape: isLandscape),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalSuggestions({required bool isLandscape}) {
    return SizedBox(
      height: isLandscape ? 32 : 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: isLandscape ? 10 : 12),
        itemCount: _suggestedQuestions.length,
        separatorBuilder: (_, _) => SizedBox(width: isLandscape ? 6 : 8),
        itemBuilder: (context, index) {
          final question = _suggestedQuestions[index];

          return ActionChip(
            onPressed: _isLoading ? null : () => _sendMessage(question),
            avatar: Icon(
              Icons.auto_awesome_rounded,
              size: isLandscape ? 12 : 14,
              color: AppTheme.blue,
            ),
            label: Text(
              question,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.blue,
                fontSize: isLandscape ? 9 : 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: AppTheme.blue.withValues(alpha: 0.06),
            disabledColor: AppTheme.blue.withValues(alpha: 0.03),
            side: BorderSide(color: AppTheme.blue.withValues(alpha: 0.20)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }

  Widget _buildInputArea({required bool isLandscape}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        isLandscape ? 10 : 12,
        isLandscape ? 1 : 2,
        isLandscape ? 10 : 12,
        isLandscape ? 6 : 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: !_isLoading,
              minLines: 1,
              maxLines: isLandscape ? 2 : 4,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Ask about your recommendations...',
                isDense: isLandscape,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(
                    color: AppTheme.blue.withValues(alpha: 0.20),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(
                    color: AppTheme.blue,
                    width: 1.5,
                  ),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isLandscape ? 8 : 12,
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          IconButton.filled(
            tooltip: 'Send',
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.blue,
              foregroundColor: Colors.white,
            ),
            onPressed: _isLoading ? null : () => _sendMessage(),
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }
}

class _CompactAdvisorContext extends StatelessWidget {
  const _CompactAdvisorContext({
    required this.goal,
    required this.recommendationCount,
  });

  final String goal;
  final int recommendationCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.blue.withValues(alpha: 0.07),
        border: Border(
          bottom: BorderSide(color: AppTheme.blue.withValues(alpha: 0.12)),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.psychology_alt_outlined,
            color: AppTheme.blue,
            size: 17,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Goal: $goal  •  $recommendationCount properties',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdvisorContextCard extends StatelessWidget {
  const _AdvisorContextCard({
    required this.goal,
    required this.recommendationCount,
  });

  final String goal;
  final int recommendationCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.blue.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.psychology_alt_outlined, color: AppTheme.blue),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current recommendation context',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 4),

                Text(
                  'Goal: $goal  •  '
                  '$recommendationCount properties',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, this.compact = false});

  final _ChatMessage message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final backgroundColor = message.isUser
        ? AppTheme.blue.withValues(alpha: 0.10)
        : message.isError
        ? colorScheme.errorContainer
        : colorScheme.surfaceContainerHighest;

    final alignment = message.isUser
        ? Alignment.centerRight
        : Alignment.centerLeft;

    return Align(
      alignment: alignment,
      child: Container(
        constraints: BoxConstraints(maxWidth: compact ? 520 : 340),
        margin: EdgeInsets.only(bottom: compact ? 7 : 12),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 14,
          vertical: compact ? 8 : 12,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  message.isUser
                      ? Icons.person_outline
                      : Icons.smart_toy_outlined,
                  size: 16,
                  color: message.isUser ? AppTheme.blue : null,
                ),

                const SizedBox(width: 6),

                Text(
                  message.isUser ? 'You' : 'AI Advisor',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: message.isUser ? AppTheme.blue : null,
                  ),
                ),
              ],
            ),

            SizedBox(height: compact ? 4 : 7),

            SelectableText(
              message.text,
              style: TextStyle(
                fontSize: compact ? 11 : null,
                height: compact ? 1.3 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.blue,
              ),
            ),

            SizedBox(width: 10),

            Text('AI Advisor is thinking...'),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
  });

  final String text;
  final bool isUser;
  final bool isError;
}

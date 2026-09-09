import 'package:flutter/material.dart';

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
  State<AiAdvisorChatScreen> createState() =>
      _AiAdvisorChatScreenState();
}

class _AiAdvisorChatScreenState
    extends State<AiAdvisorChatScreen> {
  final AiAdvisorChatService _aiService =
  const AiAdvisorChatService();

  final TextEditingController _controller =
  TextEditingController();

  final ScrollController _scrollController =
  ScrollController();

  final List<_ChatMessage> _messages = [];

  bool _isLoading = false;

  final List<String> _suggestedQuestions = const [
    'Why is the first property ranked highest?',
    'What is the main weakness of the top property?',
    'Which factor affects my recommendation the most?',
    'Which property best matches my priorities?',
    'What should I consider before choosing a property?',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([
    String? suggestedQuestion,
  ]) async {
    final question =
    (suggestedQuestion ?? _controller.text).trim();

    if (question.isEmpty || _isLoading) {
      return;
    }

    if (widget.recommendations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Generate property recommendations first.',
          ),
        ),
      );
      return;
    }

    // Keep only previous messages as conversation history.
    final history = _messages
        .map(
          (message) => {
        'role':
        message.isUser ? 'User' : 'AI Advisor',
        'text': message.text,
      },
    )
        .toList();

    setState(() {
      _messages.add(
        _ChatMessage(
          text: question,
          isUser: true,
        ),
      );

      _isLoading = true;
    });

    _controller.clear();
    _scrollToBottom();

    try {
      final response =
      await _aiService.sendMessage(
        question: question,
        recommendations: widget.recommendations,
        preferences: widget.preferences,
        conversationHistory: history,
      );

      if (!mounted) return;

      setState(() {
        _messages.add(
          _ChatMessage(
            text: response,
            isUser: false,
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _messages.add(
          _ChatMessage(
            text:
            'Sorry, I could not generate an AI advisor response.\n\n$e',
            isUser: false,
            isError: true,
          ),
        );
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback(
          (_) {
        if (!_scrollController.hasClients) {
          return;
        }

        _scrollController.animateTo(
          _scrollController
              .position
              .maxScrollExtent,
          duration:
          const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      },
    );
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final goal =
    widget.preferences.goal ==
        PropertyGoal.ownStay
        ? 'Own Stay'
        : 'Investment';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AI Property Advisor',
        ),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              tooltip: 'Clear chat',
              onPressed:
              _isLoading ? null : _clearChat,
              icon: const Icon(
                Icons.delete_outline_rounded,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _AdvisorContextCard(
            goal: goal,
            recommendationCount:
            widget.recommendations.length,
          ),

          Expanded(
            child: _messages.isEmpty
                ? _buildWelcomeView()
                : _buildChatView(),
          ),

          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildWelcomeView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 12),

        const Icon(
          Icons.smart_toy_outlined,
          size: 64,
        ),

        const SizedBox(height: 16),

        Text(
          'Ask about your recommendations',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'The AI advisor uses your current property '
              'recommendations, scores and priorities to '
              'help explain the results.',
          textAlign: TextAlign.center,
          style:
          Theme.of(context).textTheme.bodyMedium,
        ),

        const SizedBox(height: 24),

        Text(
          'Suggested questions',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 12),

        ..._suggestedQuestions.map(
              (question) => Padding(
            padding:
            const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              onPressed: _isLoading
                  ? null
                  : () => _sendMessage(question),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.chat_bubble_outline,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(question),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChatView() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16,
      ),
      itemCount:
      _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isLoading &&
            index == _messages.length) {
          return const _TypingBubble();
        }

        final message = _messages[index];

        return _MessageBubble(
          message: message,
        );
      },
    );
  }

  Widget _buildInputArea() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          12,
          10,
          12,
          12,
        ),
        decoration: BoxDecoration(
          color:
          Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context)
                  .dividerColor
                  .withValues(alpha: 0.5),
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment:
          CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !_isLoading,
                minLines: 1,
                maxLines: 4,
                textInputAction:
                TextInputAction.newline,
                decoration: InputDecoration(
                  hintText:
                  'Ask about your recommendations...',
                  border: OutlineInputBorder(
                    borderRadius:
                    BorderRadius.circular(18),
                  ),
                  contentPadding:
                  const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            IconButton.filled(
              tooltip: 'Send',
              onPressed:
              _isLoading ? null : _sendMessage,
              icon: _isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child:
                CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
                  : const Icon(
                Icons.send_rounded,
              ),
            ),
          ],
        ),
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
      margin: const EdgeInsets.fromLTRB(
        12,
        12,
        12,
        0,
      ),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.psychology_alt_outlined,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current recommendation context',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
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
  const _MessageBubble({
    required this.message,
  });

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    final backgroundColor = message.isUser
        ? colorScheme.primaryContainer
        : message.isError
        ? colorScheme.errorContainer
        : colorScheme.surfaceContainerHighest;

    final alignment = message.isUser
        ? Alignment.centerRight
        : Alignment.centerLeft;

    return Align(
      alignment: alignment,
      child: Container(
        constraints:
        const BoxConstraints(maxWidth: 340),
        margin:
        const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  message.isUser
                      ? Icons.person_outline
                      : Icons.smart_toy_outlined,
                  size: 16,
                ),

                const SizedBox(width: 6),

                Text(
                  message.isUser
                      ? 'You'
                      : 'AI Advisor',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 7),

            SelectableText(
              message.text,
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
        margin:
        const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest,
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
              ),
            ),

            SizedBox(width: 10),

            Text(
              'AI Advisor is thinking...',
            ),
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
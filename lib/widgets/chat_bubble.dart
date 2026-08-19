import 'package:flutter/material.dart';

import 'auto_direction_text.dart';

/// One turn in a conversation with the assistant.
///
/// Shared by the onboarding interview and the "change what is watched" screen,
/// which are the same conversation seen from two entry points — the second one
/// just does not drag the whole interview along with it.
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.text,
    required this.fromAssistant,
  });

  final String text;
  final bool fromAssistant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: fromAssistant
          ? AlignmentDirectional.centerStart
          : AlignmentDirectional.centerEnd,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: fromAssistant
              ? theme.colorScheme.surfaceContainerHighest
              : theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        // The assistant mirrors whatever language the manager writes in, which
        // is not necessarily the language the app is set to.
        child: Text(
          text,
          style: theme.textTheme.bodyMedium,
          textDirection: detectDirection(
            text,
            fallback: Directionality.of(context),
          ),
        ),
      ),
    );
  }
}

/// Waiting for the assistant. A model turn takes a few seconds, and silence
/// with no indicator reads as a dropped message.
class TypingBubble extends StatelessWidget {
  const TypingBubble({super.key});

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: EdgeInsets.only(bottom: 10, left: 8, right: 8),
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

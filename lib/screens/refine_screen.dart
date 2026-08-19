import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/labels.dart';
import '../services/analyzer_api.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/topic_chips.dart';

/// How the manager changes what the system watches for.
///
/// There is no prompt editor any more. He asks — "also tell me when someone
/// promises a handover date", "stop flagging price questions" — and the model
/// rewrites the monitoring prompt behind the scenes. This is the same refine
/// flow the intake screen has after the interview ends, reached from Settings
/// and opening on a blank conversation instead of the whole interview: he is
/// making one change, not reviewing how he was onboarded.
///
/// Pops with the current topics so the caller can show the result immediately.
class RefineScreen extends StatefulWidget {
  const RefineScreen({super.key, required this.topics});

  /// What is being watched right now — shown at the top so the change is made
  /// against something visible rather than from memory.
  final List<String> topics;

  @override
  State<RefineScreen> createState() => _RefineScreenState();
}

class _RefineScreenState extends State<RefineScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  late List<String> _topics = widget.topics;
  final List<_Turn> _turns = [];
  bool _sending = false;

  String get _locale => Localizations.localeOf(context).languageCode;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    _input.clear();

    setState(() {
      _turns.add(_Turn(fromAssistant: false, text: text));
      _sending = true;
    });
    _scrollToEnd();

    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await context.read<AnalyzerApi>().answerIntake(
        text,
        _locale,
      );
      if (!mounted) return;
      setState(() {
        _turns.add(_Turn(fromAssistant: true, text: result.reply));
        // An empty list means the assistant asked a clarifying question rather
        // than rewriting anything — the old labels are still the true ones.
        if (result.topics.isNotEmpty) _topics = result.topics;
        _sending = false;
      });
      _scrollToEnd();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        // Drop the optimistic turn: nothing reached the server, so leaving it
        // on screen would imply a change that did not happen.
        _turns.removeLast();
        _sending = false;
      });
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.apiError(error.code))),
      );
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // Whatever the conversation settled on goes back to Settings, so the chips
    // there are never a screen behind what the system is doing. Intercepting
    // the pop covers the back gesture and the Android back button too, not
    // just the button in the app bar.
    return PopScope<List<String>>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_topics);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.refineTitle)),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.promptTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TopicChips(topics: _topics),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(16),
                itemCount: _turns.length + 1 + (_sending ? 1 : 0),
                itemBuilder: (context, index) {
                  // The screen opens mid-conversation on purpose: the question
                  // is already asked, so there is nothing to work out before
                  // typing.
                  if (index == 0) {
                    return ChatBubble(
                      text: l10n.refineOpeningLine,
                      fromAssistant: true,
                    );
                  }
                  if (index > _turns.length) return const TypingBubble();
                  final turn = _turns[index - 1];
                  return ChatBubble(
                    text: turn.text,
                    fromAssistant: turn.fromAssistant,
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        autofocus: true,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: l10n.refineHint,
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _sending ? null : _send,
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Turn {
  const _Turn({required this.fromAssistant, required this.text});

  final bool fromAssistant;
  final String text;
}

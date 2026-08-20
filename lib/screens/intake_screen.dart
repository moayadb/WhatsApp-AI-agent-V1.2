import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/app_user.dart';
import '../providers/auth_provider.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/content_width.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/topic_chips.dart';

/// Journey step 2 — the intake conversation.
///
/// It reads as a chat because that is what it is; whether the other side is a
/// scripted interview or an LLM in n8n is a server-side decision this screen
/// never has to know about.
class IntakeScreen extends StatefulWidget {
  const IntakeScreen({super.key});

  @override
  State<IntakeScreen> createState() => _IntakeScreenState();
}

class _IntakeScreenState extends State<IntakeScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  /// The interviewer is a model server-side, so it has to be told which
  /// language the app is currently showing — otherwise it answers in whatever
  /// language the manager happened to type in.
  String get _locale => Localizations.localeOf(context).languageCode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OnboardingProvider>().load(_locale);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    await context.read<OnboardingProvider>().send(text, _locale);
    _scrollToEnd();
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
    final intake = context.watch<OnboardingProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.intakeTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                l10n.intakeSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
      body: ContentWidth(
        child: Column(
          children: [
            Expanded(
              child: intake.loading && intake.turns.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: intake.turns.length + (intake.sending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= intake.turns.length) {
                          return const TypingBubble();
                        }
                        final turn = intake.turns[index];
                        return ChatBubble(
                          text: turn.text,
                          fromAssistant: turn.fromAssistant,
                        );
                      },
                    ),
            ),

            if (intake.done)
              _DoneFooter(
                settings: intake.settings,
                topics: intake.topics,
                aiEnabled: intake.aiEnabled,
              ),
            // The input never goes away: once the interview is done, whatever
            // the manager types becomes a change request against the generated
            // prompt ("also alert me when…"), applied by the model and shown
            // back immediately in the footer above.
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: intake.done
                              ? l10n.refineHint
                              : l10n.intakeHint,
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
                      onPressed: intake.sending ? null : _send,
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

/// Closes the loop.
///
/// The manager sees what the interview decided to watch for — in his own
/// language, in his own vocabulary. Not the prompt behind it: that is written
/// for a model, and a wall of instructions at the end of onboarding reads as
/// homework. A short list he recognises is what makes the later alerts feel
/// like his own rules firing rather than a black box.
class _DoneFooter extends StatelessWidget {
  const _DoneFooter({
    this.settings,
    this.topics = const [],
    this.aiEnabled = false,
  });

  final OrgSettings? settings;
  final List<String> topics;
  final bool aiEnabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.intakeDoneTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(l10n.intakeDoneBody, style: theme.textTheme.bodySmall),

            if (settings != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${l10n.firstResponseLabel} '
                      '${l10n.minutesShort(settings!.firstResponseMinutes)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.promptTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              aiEnabled ? l10n.promptSubtitle : l10n.promptScriptedNote,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(child: TopicChips(topics: topics)),
            ),

            const SizedBox(height: 16),
            FilledButton(
              onPressed: () =>
                  context.read<AuthProvider>().completeIntake(settings),
              child: Text(l10n.intakeContinue),
            ),
          ],
        ),
      ),
    );
  }
}

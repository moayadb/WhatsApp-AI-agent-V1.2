import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/generated/app_localizations.dart';
import '../providers/auth_provider.dart';

/// Passwordless sign-in. Phase 1 collects an email and runs it past the
/// Firestore allowlist; phase 2 tells the user to open the emailed link and
/// offers a resend.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-fill when a link was already requested in a previous run.
    _email.text = context.read<AuthProvider>().email;
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    if (auth.busy) return;
    final value = _email.text.trim();
    if (value.isEmpty) return;
    await auth.requestMagicLink(value);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();

    final errorText = switch (auth.errorCode) {
      'not_allowed' => l.notAuthorized,
      'send_failed' => l.sendFailed,
      'link_failed' => l.linkFailed,
      'google_failed' => l.googleFailed,
      _ => null,
    };

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    auth.phase == LoginPhase.linkSent
                        ? Icons.mark_email_read_outlined
                        : Icons.insights,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  switch (auth.phase) {
                    LoginPhase.linkSent => l.linkSentTitle,
                    LoginPhase.confirmEmail => l.confirmEmailTitle,
                    LoginPhase.enterEmail => l.appTitle,
                  },
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  switch (auth.phase) {
                    LoginPhase.linkSent => l.linkSentBody(auth.email),
                    LoginPhase.confirmEmail => l.confirmEmailBody,
                    LoginPhase.enterEmail => l.loginSubtitle,
                  },
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                if (auth.phase == LoginPhase.confirmEmail) ...[
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (v) =>
                        context.read<AuthProvider>().confirmEmailAndSignIn(v),
                    decoration: InputDecoration(
                      labelText: l.emailLabel,
                      prefixIcon: const Icon(Icons.alternate_email, size: 20),
                    ),
                  ),
                  _ErrorLine(text: errorText),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: auth.busy
                        ? null
                        : () => context
                            .read<AuthProvider>()
                            .confirmEmailAndSignIn(_email.text),
                    child: auth.busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l.completeSignIn),
                  ),
                ] else if (auth.phase == LoginPhase.enterEmail) ...[
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: l.emailLabel,
                      prefixIcon: const Icon(Icons.alternate_email, size: 20),
                    ),
                  ),
                  _ErrorLine(text: errorText),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: auth.busy ? null : _submit,
                    child: auth.busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l.sendMagicLink),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          l.orLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: auth.busy
                        ? null
                        : () => context.read<AuthProvider>().signInWithGoogle(),
                    icon: Text(
                      'G',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    label: Text(l.continueWithGoogle),
                  ),
                ] else ...[
                  _ErrorLine(text: errorText),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: auth.busy
                        ? null
                        : () => context.read<AuthProvider>().resend(),
                    icon: auth.busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 20),
                    label: Text(l.resendLink),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: auth.busy
                        ? null
                        : () => context.read<AuthProvider>().editEmail(),
                    child: Text(l.useDifferentEmail),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline error with reserved space, so the form does not jump.
class _ErrorLine extends StatelessWidget {
  const _ErrorLine({required this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      child: text == null
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, size: 16, color: theme.colorScheme.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      text!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

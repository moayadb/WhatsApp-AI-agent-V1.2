import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/generated/app_localizations.dart';
import '../l10n/labels.dart';
import '../providers/auth_provider.dart';

/// Journey step 1 — registration, with sign-in on the same screen.
///
/// One screen rather than two: a manager who was told about this by another
/// brokerage arrives without knowing whether they already have an account, and
/// bouncing them between routes to find out is friction at the worst moment.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _company = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();

  bool _registering = true;
  bool _acceptedTerms = false;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _company.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;

    if (_registering && !_acceptedTerms) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.errTermsRequired)));
      return;
    }

    final auth = context.read<AuthProvider>();
    final ok = _registering
        ? await auth.signUp(
            fullName: _name.text.trim(),
            email: _email.text.trim(),
            phone: _phone.text.trim(),
            password: _password.text,
            locale: Localizations.localeOf(context).languageCode,
            companyName: _company.text.trim(),
          )
        : await auth.signIn(_email.text.trim(), _password.text);

    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.apiError(auth.errorCode))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final busy = context.watch<AuthProvider>().busy;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              // The same build runs on a phone and on a wide browser window;
              // full-width form fields on a desktop monitor look broken.
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.insights_rounded,
                      size: 48,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.appTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.authSubtitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),

                    if (_registering) ...[
                      TextFormField(
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: l10n.fullNameLabel,
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        validator: (value) =>
                            (value == null || value.trim().length < 2)
                            ? l10n.errGeneric
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _company,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: l10n.companyLabel,
                          prefixIcon: const Icon(Icons.business_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: l10n.phoneLabel,
                          helperText: l10n.phoneHelp,
                          prefixIcon: const Icon(Icons.smartphone_outlined),
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          // Matches the server's E.164 rule, so the user finds
                          // out here rather than after a round trip.
                          return RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(text)
                              ? null
                              : l10n.errPhoneFormat;
                        },
                      ),
                      const SizedBox(height: 12),
                    ],

                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(
                        labelText: l10n.emailLabel,
                        prefixIcon: const Icon(Icons.alternate_email),
                      ),
                      validator: (value) =>
                          (value == null || !value.contains('@'))
                          ? l10n.errGeneric
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => busy ? null : _submit(),
                      decoration: InputDecoration(
                        labelText: l10n.passwordLabel,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (value) =>
                          (_registering && (value?.length ?? 0) < 8)
                          ? l10n.errPasswordShort
                          : null,
                    ),

                    if (_registering) ...[
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: _acceptedTerms,
                        onChanged: (value) =>
                            setState(() => _acceptedTerms = value ?? false),
                        title: Text(
                          l10n.acceptTerms,
                          style: theme.textTheme.bodySmall,
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ],

                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: busy ? null : _submit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _registering
                                  ? l10n.createAccount
                                  : l10n.signInAction,
                            ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() => _registering = !_registering),
                      child: Text(
                        _registering ? l10n.haveAccount : l10n.noAccount,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

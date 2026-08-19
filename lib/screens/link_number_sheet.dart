import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../l10n/generated/app_localizations.dart';
import '../l10n/labels.dart';
import '../models/team.dart';
import '../providers/team_provider.dart';

/// Connecting a WhatsApp number — the feature this whole product rests on.
///
/// Two routes to the same place. The pairing code is the default because it is
/// the one that works when the agent is not standing next to the manager: they
/// read out eight characters over the phone and the number is linked. The QR
/// path is there for when they are in the same room.
class LinkNumberSheet extends StatefulWidget {
  const LinkNumberSheet({
    super.key,
    this.agentId,
    this.agentName,
    this.phone,
  });

  /// Null means the manager is linking his own number, which onboarding allows.
  final String? agentId;
  final String? agentName;

  /// Prefilled when reconnecting a number that is already known, so nobody has
  /// to retype it to recover a dropped session.
  final String? phone;

  static Future<void> show(
    BuildContext context, {
    String? agentId,
    String? agentName,
    String? phone,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => LinkNumberSheet(
        agentId: agentId,
        agentName: agentName,
        phone: phone,
      ),
    );
  }

  @override
  State<LinkNumberSheet> createState() => _LinkNumberSheetState();
}

class _LinkNumberSheetState extends State<LinkNumberSheet> {
  final _phone = TextEditingController();
  final _consent = TextEditingController();

  LinkMethod _method = LinkMethod.pairingCode;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    _consent.text = widget.agentName ?? '';
    _phone.text = widget.phone ?? '';
  }

  @override
  void dispose() {
    _phone.dispose();
    _consent.dispose();
    // The session keeps running server-side; only the polling stops.
    context.read<TeamProvider>().stopLinking();
    super.dispose();
  }

  Future<void> _request() async {
    final l10n = AppLocalizations.of(context);
    final phone = _phone.text.trim();

    if (_method == LinkMethod.pairingCode &&
        !RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(phone)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.errPhoneFormat)));
      return;
    }

    setState(() => _requesting = true);
    final ok = await context.read<TeamProvider>().startLink(
      method: _method,
      phone: phone.isEmpty ? null : phone,
      agentId: widget.agentId,
      label: widget.agentName,
      consentName: _consent.text.trim(),
    );
    if (mounted) setState(() => _requesting = false);

    if (!ok && mounted) {
      final code = context.read<TeamProvider>().linkErrorCode;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.apiError(code))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final team = context.watch<TeamProvider>();
    final state = team.linkState;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.agentName ?? l10n.myOwnNumber,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l10n.linkTitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),

              if (state == null)
                _RequestForm(
                  method: _method,
                  onMethodChanged: (m) => setState(() => _method = m),
                  phone: _phone,
                  consent: _consent,
                  busy: _requesting,
                  onSubmit: _request,
                )
              else if (state.isLinked)
                const _LinkedPanel()
              // Which panel to show follows the method the user picked, not
              // whether a QR has arrived yet. Choosing by `qr != null` meant a
              // pending QR fell through to the pairing-code panel, so the user
              // stared at a spinner inside a box captioned "type this code".
              else if (_method == LinkMethod.qr)
                _QrPanel(state: state, onRefresh: () => team.refreshCode(_method))
              else
                _CodePanel(
                  state: state,
                  onRefresh: () => team.refreshCode(_method),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestForm extends StatelessWidget {
  const _RequestForm({
    required this.method,
    required this.onMethodChanged,
    required this.phone,
    required this.consent,
    required this.busy,
    required this.onSubmit,
  });

  final LinkMethod method;
  final ValueChanged<LinkMethod> onMethodChanged;
  final TextEditingController phone;
  final TextEditingController consent;
  final bool busy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<LinkMethod>(
          segments: [
            ButtonSegment(
              value: LinkMethod.pairingCode,
              icon: const Icon(Icons.dialpad),
              label: Text(l10n.linkMethodPhone),
            ),
            ButtonSegment(
              value: LinkMethod.qr,
              icon: const Icon(Icons.qr_code_2),
              label: Text(l10n.linkMethodQr),
            ),
          ],
          selected: {method},
          onSelectionChanged: (selection) => onMethodChanged(selection.first),
        ),
        const SizedBox(height: 20),

        if (method == LinkMethod.pairingCode) ...[
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: l10n.phoneLabel,
              helperText: l10n.phoneHelp,
              prefixIcon: const Icon(Icons.smartphone_outlined),
            ),
          ),
          const SizedBox(height: 16),
        ],

        TextField(
          controller: consent,
          decoration: InputDecoration(
            labelText: l10n.consentLabel,
            helperText: l10n.consentHelp,
            helperMaxLines: 2,
            prefixIcon: const Icon(Icons.verified_user_outlined),
          ),
        ),
        const SizedBox(height: 24),

        FilledButton(
          onPressed: busy ? null : onSubmit,
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
                  method == LinkMethod.pairingCode
                      ? l10n.getCodeAction
                      : l10n.linkMethodQr,
                ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.consentHelp,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// The eight characters, big enough to read aloud over a phone call.
class _CodePanel extends StatefulWidget {
  const _CodePanel({required this.state, required this.onRefresh});

  final LinkState state;
  final VoidCallback onRefresh;

  @override
  State<_CodePanel> createState() => _CodePanelState();
}

class _CodePanelState extends State<_CodePanel> {
  Timer? _tick;
  final _openedAt = DateTime.now();

  /// How long to wait for WhatsApp to hand back a code before admitting
  /// something is wrong. A spinner that never resolves and never explains is
  /// the worst possible failure mode — it is indistinguishable from "slow".
  static const _patience = Duration(seconds: 25);

  bool get _stalled =>
      widget.state.pairingCode == null &&
      DateTime.now().difference(_openedAt) > _patience;

  @override
  void initState() {
    super.initState();
    // Drives the countdown only; expiry itself is the server's business.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  int get _secondsLeft {
    final expires = widget.state.expiresAt;
    if (expires == null) return 0;
    return expires.difference(DateTime.now()).inSeconds.clamp(0, 999);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final code = widget.state.pairingCode;
    final expired = _secondsLeft <= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.codeTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 16),

        InkWell(
          onTap: code == null
              ? null
              : () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(code), duration: const Duration(seconds: 1)),
                  );
                },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                if (code == null)
                  const CircularProgressIndicator()
                else
                  Text(
                    code,
                    textAlign: TextAlign.center,
                    // Always latin digits, never Arabic-Indic: this is typed
                    // into WhatsApp character for character.
                    textDirection: TextDirection.ltr,
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 6,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  expired ? '—' : '0:${_secondsLeft.toString().padLeft(2, '0')}',
                  textDirection: TextDirection.ltr,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: expired
                        ? theme.colorScheme.error
                        : theme.colorScheme.onPrimaryContainer.withValues(
                            alpha: 0.7,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),
        _Step(number: 1, text: l10n.codeStep1),
        _Step(number: 2, text: l10n.codeStep2),
        _Step(number: 3, text: l10n.codeStep3),
        _Step(number: 4, text: l10n.codeStep4),

        const SizedBox(height: 20),

        if (widget.state.lastError != null || _stalled)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 18,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.state.lastError ?? l10n.linkStalled,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                height: 14,
                width: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Text(l10n.statusPairing, style: theme.textTheme.bodySmall),
            ],
          ),

        if (expired || _stalled || widget.state.lastError != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: widget.onRefresh,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.refreshCode),
          ),
        ],
      ],
    );
  }
}

class _QrPanel extends StatelessWidget {
  const _QrPanel({required this.state, required this.onRefresh});

  final LinkState state;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bytes = _decode(state.qr);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.qrTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: bytes == null
                ? const SizedBox(
                    height: 240,
                    width: 240,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Image.memory(bytes, height: 240, width: 240),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.qrSteps,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
          label: Text(l10n.refreshCode),
        ),
      ],
    );
  }

  /// The server hands back a `data:image/png;base64,…` URL.
  static Uint8List? _decode(String? dataUrl) {
    if (dataUrl == null) return null;
    final comma = dataUrl.indexOf(',');
    if (comma == -1) return null;
    try {
      return base64Decode(dataUrl.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }
}

class _LinkedPanel extends StatelessWidget {
  const _LinkedPanel();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Icon(
          Icons.check_circle_rounded,
          size: 64,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          l10n.linkedTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.linkedBody,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.doneAction),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 22,
            width: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Text('$number', style: theme.textTheme.labelSmall),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

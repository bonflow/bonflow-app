import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/network/api_error.dart';
import '../../../core/ui/error_text.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/data/auth_repository.dart';

/// Shared phones: pick your name from the list, then enter the PIN.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late Future<List<Waiter>> _waiters;

  @override
  void initState() {
    super.initState();
    _waiters = ref.read(authRepositoryProvider).waiters();
  }

  void _reload() {
    setState(() {
      _waiters = ref.read(authRepositoryProvider).waiters();
    });
  }

  Future<void> _askPin(Waiter waiter) {
    return showDialog<void>(
      context: context,
      builder: (context) => _PinDialog(waiter: waiter),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.loginTitle)),
      body: FutureBuilder<List<Waiter>>(
        future: _waiters,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _Message(
              text: errorText(l10n, snapshot.error!),
              action: FilledButton(
                onPressed: _reload,
                child: Text(l10n.retry),
              ),
            );
          }
          final waiters = snapshot.data;
          if (waiters == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (waiters.isEmpty) {
            return _Message(text: l10n.loginNoWaiters);
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  l10n.loginSelectWaiter,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              for (final waiter in waiters)
                Card(
                  child: ListTile(
                    key: Key('waiter-${waiter.id}'),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    title: Text(
                      waiter.displayName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _askPin(waiter),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class _PinDialog extends ConsumerStatefulWidget {
  const _PinDialog({required this.waiter});

  final Waiter waiter;

  @override
  ConsumerState<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends ConsumerState<_PinDialog> {
  final _pin = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (_pin.text.isEmpty || _busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    String? error;
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .login(widget.waiter.id, _pin.text);
    } on InvalidPinException {
      error = l10n.loginInvalidPin;
    } on LockedException catch (e) {
      error = l10n.loginLocked(e.retryAfterSeconds);
    } on ApiError catch (e) {
      error = errorText(l10n, e);
    }
    if (!mounted) {
      return;
    }
    if (error == null) {
      // the router leaves the login screen as soon as the session exists
      Navigator.of(context).pop();
      return;
    }
    _pin.clear();
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.loginPinTitle(widget.waiter.displayName)),
      content: TextField(
        key: const Key('pin-field'),
        controller: _pin,
        autofocus: true,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 8,
        decoration: InputDecoration(
          labelText: l10n.loginPin,
          errorText: _error,
          counterText: '',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('login-submit'),
          onPressed: _busy ? null : _submit,
          child: Text(l10n.loginSubmit),
        ),
      ],
    );
  }
}

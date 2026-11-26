import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.loginTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(decoration: InputDecoration(labelText: l10n.loginUser)),
            const SizedBox(height: 16),
            TextField(
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.loginPin),
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('login-submit'),
              // TODO: POST /auth/login, store tokens, then navigate.
              onPressed: () => context.go('/tables'),
              child: Text(l10n.loginSubmit),
            ),
          ],
        ),
      ),
    );
  }
}

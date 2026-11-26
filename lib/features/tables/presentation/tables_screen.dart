import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

/// Table overview per area; data comes from the cached master data (GET /masterdata).
class TablesScreen extends StatelessWidget {
  const TablesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).tablesTitle)),
      body: const SizedBox.shrink(),
    );
  }
}

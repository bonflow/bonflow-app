import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

/// Article picker (categories, articles, modifiers) backed by the local master data cache.
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).menuTitle)),
      body: const SizedBox.shrink(),
    );
  }
}

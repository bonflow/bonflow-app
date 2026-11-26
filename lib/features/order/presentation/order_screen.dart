import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

/// Order being assembled for one table. The order id is a client-generated UUID so that
/// retried submissions (POST /orders) are idempotent on the server.
class OrderScreen extends StatelessWidget {
  const OrderScreen({required this.tableId, super.key});

  final String tableId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.orderTitle)),
      body: Center(child: Text(l10n.orderForTable(tableId))),
    );
  }
}

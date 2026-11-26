import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/ui/error_text.dart';
import '../../../core/ui/hex_color.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/application/session_controller.dart';
import '../../masterdata/application/master_data_controller.dart';
import '../../masterdata/data/master_data.dart';
import '../../order/application/outbox_controller.dart';

/// Table overview per area; data comes from the cached master data (GET /masterdata).
class TablesScreen extends ConsumerWidget {
  const TablesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(masterDataControllerProvider);
    final session = ref.watch(sessionControllerProvider).session;
    final data = state.data;
    final outbox = ref.watch(outboxControllerProvider);

    Widget body;
    if (data == null) {
      body = state.loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    state.error == null
                        ? l10n.errorGeneric
                        : errorText(l10n, state.error!),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => ref
                        .read(masterDataControllerProvider.notifier)
                        .refresh(),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            );
    } else if (data.tables.isEmpty) {
      body = Center(child: Text(l10n.tablesEmpty));
    } else {
      body = RefreshIndicator(
        onRefresh: () async {
          await ref.read(masterDataControllerProvider.notifier).refresh();
          await ref.read(outboxControllerProvider.notifier).flush();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (outbox.pending.isNotEmpty)
              Card(
                key: const Key('outbox-banner'),
                child: ListTile(
                  leading: const Icon(Icons.cloud_off),
                  title: Text(l10n.outboxPending(outbox.pending.length)),
                  trailing: TextButton(
                    key: const Key('outbox-send'),
                    onPressed: () =>
                        ref.read(outboxControllerProvider.notifier).flush(),
                    child: Text(l10n.outboxSendNow),
                  ),
                ),
              ),
            if (outbox.dropped > 0)
              Card(
                key: const Key('outbox-dropped'),
                child: ListTile(
                  leading: Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(l10n.outboxDropped(outbox.dropped)),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () =>
                        ref.read(outboxControllerProvider.notifier).clearDropped(),
                  ),
                ),
              ),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  l10n.tablesOffline,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            for (final area in data.areas)
              if (data.tablesOf(area.id).isNotEmpty)
                _AreaSection(area: area, tables: data.tablesOf(area.id)),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tablesTitle),
        actions: [
          if (session != null)
            Center(child: Text(session.waiterName)),
          IconButton(
            key: const Key('logout'),
            tooltip: l10n.logout,
            icon: const Icon(Icons.logout),
            onPressed: () =>
                ref.read(sessionControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: body,
    );
  }
}

class _AreaSection extends StatelessWidget {
  const _AreaSection({required this.area, required this.tables});

  final Area area;
  final List<DiningTable> tables;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (parseHexColor(area.color) case final color?)
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              Text(area.name, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final table in tables)
                SizedBox(
                  width: 112,
                  height: 72,
                  child: ColoredButton(
                    key: Key('table-${table.id}'),
                    color: parseHexColor(table.color ?? area.color),
                    onPressed: () => context.push('/tables/${table.id}/order'),
                    child: Text(
                      table.label,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

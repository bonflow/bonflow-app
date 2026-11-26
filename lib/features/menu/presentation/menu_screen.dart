import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/ui/hex_color.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../masterdata/application/master_data_controller.dart';
import '../../masterdata/data/master_data.dart';
import '../../order/data/order_models.dart';

/// The menu. Picking an article opens a sheet for quantity, modifiers and note; the finished
/// [NewLine] is returned to the order screen.
class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final data = ref.watch(masterDataControllerProvider).data;

    Widget body;
    if (data == null || data.articles.isEmpty) {
      body = Center(child: Text(l10n.menuEmpty));
    } else {
      final categories = [...data.categories]
        ..sort((a, b) {
          final bySort = a.sortOrder.compareTo(b.sortOrder);
          return bySort != 0 ? bySort : a.name.compareTo(b.name);
        });
      body = ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          for (final category in categories)
            if (data.articlesOf(category.id).isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    if (parseHexColor(category.color) case final color?)
                      Container(
                        width: 14,
                        height: 14,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    Text(
                      category.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final article in data.articlesOf(category.id))
                      SizedBox(
                        width: 156,
                        height: 76,
                        child: ColoredButton(
                          key: Key('article-${article.id}'),
                          color: parseHexColor(category.color),
                          onPressed: () async {
                            final line = await showModalBottomSheet<NewLine>(
                              context: context,
                              isScrollControlled: true,
                              builder: (_) =>
                                  _ItemSheet(article: article, data: data),
                            );
                            if (line != null && context.mounted) {
                              context.pop(line);
                            }
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                article.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                article.price.toStringAsFixed(2),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.menuTitle)),
      body: body,
    );
  }
}

class _ItemSheet extends StatefulWidget {
  const _ItemSheet({required this.article, required this.data});

  final Article article;
  final MasterData data;

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  static const _courses = [1, 2, 3];

  final _note = TextEditingController();
  final Set<int> _modifiers = {};
  int _quantity = 1;
  int? _course;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _toggle(ModifierGroup group, Modifier modifier, bool selected) {
    setState(() {
      if (!group.multiSelect) {
        _modifiers.removeAll(group.modifiers.map((m) => m.id));
      }
      if (selected) {
        _modifiers.add(modifier.id);
      } else {
        _modifiers.remove(modifier.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final groups = [
      for (final id in widget.article.modifierGroupIds)
        if (widget.data.modifierGroup(id) != null)
          widget.data.modifierGroup(id)!,
    ];
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.article.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(l10n.menuQuantity),
                const Spacer(),
                IconButton.outlined(
                  key: const Key('quantity-minus'),
                  icon: const Icon(Icons.remove),
                  onPressed: _quantity > 1
                      ? () => setState(() => _quantity--)
                      : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '$_quantity',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton.outlined(
                  key: const Key('quantity-plus'),
                  icon: const Icon(Icons.add),
                  onPressed: _quantity < 99
                      ? () => setState(() => _quantity++)
                      : null,
                ),
              ],
            ),
            for (final group in groups) ...[
              const SizedBox(height: 12),
              Text(group.name, style: Theme.of(context).textTheme.titleSmall),
              Wrap(
                spacing: 8,
                children: [
                  for (final modifier in group.modifiers)
                    FilterChip(
                      key: Key('modifier-${modifier.id}'),
                      label: Text(modifier.name),
                      selected: _modifiers.contains(modifier.id),
                      onSelected: (selected) =>
                          _toggle(group, modifier, selected),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Text(l10n.menuCourse, style: Theme.of(context).textTheme.titleSmall),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(l10n.menuNoCourse),
                  selected: _course == null,
                  onSelected: (_) => setState(() => _course = null),
                ),
                for (final course in _courses)
                  ChoiceChip(
                    label: Text(l10n.menuCourseN(course)),
                    selected: _course == course,
                    onSelected: (_) => setState(() => _course = course),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('item-note'),
              controller: _note,
              maxLength: 500,
              decoration: InputDecoration(labelText: l10n.menuNote),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('item-add'),
                onPressed: () => Navigator.of(context).pop(
                  NewLine(
                    articleId: widget.article.id,
                    quantity: _quantity,
                    note: _note.text,
                    course: _course,
                    modifierIds: _modifiers.toList()..sort(),
                  ),
                ),
                child: Text(l10n.menuAdd),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

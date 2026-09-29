import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:pantrypal/core/theme/app_theme.dart';
import 'package:pantrypal/core/utils/food_emoji.dart';
import 'package:pantrypal/core/utils/grocery_ocr_parser.dart';
import 'package:pantrypal/core/utils/quick_add.dart';
import 'package:pantrypal/features/pantry/data/repositories/pantry_repository.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/pantry/domain/services/pantry_insights.dart';
import 'package:pantrypal/features/pantry/presentation/bloc/pantry_bloc.dart';
import 'package:pantrypal/features/pantry/presentation/bloc/shopping_cubit.dart';
import 'package:pantrypal/features/recipes/domain/entities/recipe.dart';
import 'package:pantrypal/features/recipes/domain/services/cook_tonight_service.dart';
import 'package:pantrypal/features/recipes/presentation/bloc/recipe_bloc.dart';
import 'package:pantrypal/injection_container.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

/// A shopping list built around what is actually missing: it warns before you
/// buy something you already own, suggests what you ran out of and what
/// tonight's recipe lacks, and files what you bought straight into the pantry.
class ShoppingPage extends StatefulWidget {
  const ShoppingPage({super.key});
  @override
  State<ShoppingPage> createState() => _ShoppingPageState();
}

class _ShoppingPageState extends State<ShoppingPage> {
  static const _uuid = Uuid();
  final _nameCtrl = TextEditingController();
  List<String> _usedUp = [];

  static const _suggestions = [
    'Apples', 'Avocado', 'Bacon', 'Bananas', 'Beans', 'Beef', 'Bread',
    'Broccoli', 'Butter', 'Carrots', 'Cheese', 'Chicken', 'Chips',
    'Coffee', 'Cream', 'Eggs', 'Fish', 'Flour', 'Garlic', 'Grapes',
    'Ham', 'Honey', 'Ice Cream', 'Juice', 'Ketchup', 'Lamb', 'Lemons',
    'Lettuce', 'Mayonnaise', 'Milk', 'Mushrooms', 'Mustard', 'Oats',
    'Oil', 'Onions', 'Orange Juice', 'Oranges', 'Pasta', 'Peanut Butter',
    'Peppers', 'Pork', 'Potatoes', 'Rice', 'Salmon', 'Salt', 'Sausage',
    'Shrimp', 'Spinach', 'Sugar', 'Tea', 'Tomatoes', 'Tuna', 'Turkey',
    'Vinegar', 'Water', 'Yogurt', 'Zucchini',
  ];

  @override
  void initState() {
    super.initState();
    context.read<ShoppingCubit>().load();
    _loadUsedUp();
    _nameCtrl.addListener(() => setState(() {}));
  }

  /// Foods finished in the last month that are not in the pantry any more.
  Future<void> _loadUsedUp() async {
    final repo = sl<PantryRepository>();
    final consumed = await repo.getRecentlyConsumed(days: 30);
    final active = await repo.getAllItems();
    final seen = <String>{};
    final names = <String>[];
    for (final c in consumed) {
      final key = c.name.toLowerCase().trim();
      if (!seen.add(key)) continue;
      if (active.any((a) => CookTonightService.namesMatch(a.name, c.name))) continue;
      names.add(c.name);
    }
    if (mounted) setState(() => _usedUp = names.take(8).toList());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  /// Returns the pantry item the user already has under this name, if any.
  Future<PantryItem?> _alreadyHave(String name) async {
    final active = await sl<PantryRepository>().getAllItems();
    for (final i in active) {
      if (i.expiryStatus == ExpiryStatus.expired) continue;
      if (CookTonightService.namesMatch(i.name, name)) return i;
    }
    return null;
  }

  Future<void> _addItem({String? overrideName}) async {
    final parsed = QuickAdd.parseLine((overrideName ?? _nameCtrl.text).trim());
    final name = parsed.name;
    if (name.isEmpty) return;

    final have = await _alreadyHave(name);
    if (have != null) {
      if (!mounted) return;
      final add = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('You already have ${have.name}'),
          content: Text(
            '${have.location.emoji} ${have.location.label} · ${have.expiryLabel.toLowerCase()}.\n\n'
            'Buy more anyway?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Skip it')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add anyway')),
          ],
        ),
      );
      if (add != true) {
        _nameCtrl.clear();
        return;
      }
    }
    if (!mounted) return;
    context.read<ShoppingCubit>().add(ShoppingItem(
      id: _uuid.v4(),
      name: name,
      category: GroceryOcrParser.guessCategory(name),
      quantity: parsed.quantity,
      unit: 'pcs',
      isChecked: false,
      addedDate: DateTime.now(),
    ));
    _nameCtrl.clear();
    setState(() {});
  }

  Future<void> _moveBoughtToPantry(List<ShoppingItem> bought) async {
    final items = bought
        .map((b) => QuickAdd.itemFor(b.name, category: b.category, quantity: b.quantity))
        .toList();
    context.read<PantryBloc>().add(PantryAddItems(items));
    await context.read<ShoppingCubit>().clearDone();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${items.length} item${items.length == 1 ? '' : 's'} added to your pantry'),
        backgroundColor: AppColors.primary,
      ));
  }

  void _shareList(BuildContext ctx, List<ShoppingItem> items) {
    final buf = StringBuffer('🛒 Shopping List\n\n');
    for (final i in items.where((i) => !i.isChecked)) {
      buf.writeln('• ${_qtyLabel(i)}${i.name}');
    }
    for (final i in items.where((i) => i.isChecked)) {
      buf.writeln('✓ ${_qtyLabel(i)}${i.name}');
    }
    final box = ctx.findRenderObject() as RenderBox?;
    Share.share(
      buf.toString().trim(),
      subject: 'Shopping List',
      sharePositionOrigin: box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : const Rect.fromLTWH(0, 0, 100, 50),
    );
  }

  String _qtyLabel(ShoppingItem i) {
    if (i.quantity == 1 && (i.unit == 'pcs' || i.unit == 'item')) return '';
    final qty = i.quantity == i.quantity.truncateToDouble()
        ? i.quantity.toInt().toString()
        : i.quantity.toString();
    return '$qty ${i.unit == 'pcs' ? '×' : i.unit} ';
  }

  List<String> _typeaheadMatches() {
    final q = _nameCtrl.text.toLowerCase();
    if (q.isEmpty) return [];
    return _suggestions
        .where((s) => s.toLowerCase().startsWith(q) && s.toLowerCase() != q)
        .take(5)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final matches = _typeaheadMatches();

    return SafeArea(
      child: BlocListener<PantryBloc, PantryState>(
        listenWhen: (a, b) => b is PantryLoaded,
        listener: (_, __) => _loadUsedUp(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Shopping list',
                            style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppColors.darkInk : AppColors.ink)),
                        const SizedBox(height: 2),
                        Text('We check it against what you already have.',
                            style: TextStyle(
                                fontSize: 13, color: isDark ? AppColors.darkInkMuted : AppColors.inkMuted)),
                      ],
                    ),
                  ),
                  BlocBuilder<ShoppingCubit, ShoppingState>(
                    builder: (context, state) {
                      if (state.items.isEmpty) return const SizedBox.shrink();
                      return IconButton(
                        icon: const Icon(Icons.share_outlined),
                        color: AppColors.primary,
                        onPressed: () => _shareList(context, state.items),
                        tooltip: 'Share list',
                      );
                    },
                  ),
                ],
              ),
            ),

            // ── Add row ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: 'Add item...',
                        prefixIcon: Icon(Icons.add, color: AppColors.primary),
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      onSubmitted: (_) => _addItem(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _addItem,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20)),
                      child: const Text('Add'),
                    ),
                  ),
                ],
              ),
            ),

            if (matches.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: matches
                      .map((s) => ActionChip(
                            label: Text(s, style: const TextStyle(fontSize: 12)),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            backgroundColor: isDark ? AppColors.darkCard : AppColors.card,
                            side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                            onPressed: () {
                              _nameCtrl.text = s;
                              _nameCtrl.selection = TextSelection.collapsed(offset: s.length);
                            },
                          ))
                      .toList(),
                ),
              ),

            // ── Smart suggestions ──────────────────────────────────────────
            _Suggestions(usedUp: _usedUp, onAdd: (n) => _addItem(overrideName: n)),

            // ── List ───────────────────────────────────────────────────────
            Expanded(
              child: BlocBuilder<ShoppingCubit, ShoppingState>(
                builder: (context, state) {
                  if (!state.loaded) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                  }
                  if (state.items.isEmpty) return _buildEmpty();
                  final unchecked = state.items.where((i) => !i.isChecked).toList();
                  final checked = state.items.where((i) => i.isChecked).toList();
                  return Column(
                    children: [
                      if (checked.isNotEmpty)
                        _BoughtBar(
                          count: checked.length,
                          onMove: () => _moveBoughtToPantry(checked),
                          onClear: () => context.read<ShoppingCubit>().clearDone(),
                        ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                          itemCount: unchecked.length + checked.length,
                          itemBuilder: (context, i) {
                            final item = i < unchecked.length ? unchecked[i] : checked[i - unchecked.length];
                            return _ShoppingItemTile(item: item, isDark: isDark);
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.shopping_cart_outlined, size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text('List is empty', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text(
              'Add what you need — or open a recipe on the Cook tab and add just what it is missing.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.inkMuted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Suggestions ───────────────────────────────────────────────────────────────

class _Suggestions extends StatelessWidget {
  final List<String> usedUp;
  final void Function(String) onAdd;
  const _Suggestions({required this.usedUp, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ShoppingCubit, ShoppingState>(
      builder: (context, shopping) {
        final onList = shopping.items.where((i) => !i.isChecked).map((i) => i.name.toLowerCase().trim()).toSet();
        return BlocBuilder<PantryBloc, PantryState>(
          builder: (context, pantryState) {
            return BlocBuilder<RecipeBloc, RecipeState>(
              builder: (context, recipeState) {
                final pantry = pantryState is PantryLoaded ? pantryState.allItems : <PantryItem>[];
                final recipes = recipeState is RecipeLoaded ? recipeState.all : <Recipe>[];
                final pick = PantryInsights.tonightPick(recipes, pantry);

                final forRecipe = (pick?.missingNames ?? <String>[])
                    .where((n) => !onList.contains(n.toLowerCase().trim()))
                    .toList();
                final ranOut = usedUp.where((n) => !onList.contains(n.toLowerCase().trim())).toList();

                if (forRecipe.isEmpty && ranOut.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (forRecipe.isNotEmpty) ...[
                        _label(context, 'FOR ${pick!.recipe.name.toUpperCase()}'),
                        _chips(context, forRecipe),
                      ],
                      if (ranOut.isNotEmpty) ...[
                        _label(context, 'RAN OUT RECENTLY'),
                        _chips(context, ranOut),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _label(BuildContext context, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: isDark ? AppColors.darkInkMuted : AppColors.inkMuted,
        ),
      ),
    );
  }

  Widget _chips(BuildContext context, List<String> names) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: names
            .map((n) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    avatar: Text(foodEmoji(n, GroceryOcrParser.guessCategory(n)), style: const TextStyle(fontSize: 14)),
                    label: Text(n, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    backgroundColor: AppColors.primarySurface,
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.35)),
                    onPressed: () => onAdd(n),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

/// Shown once something is ticked: closes the loop from shop to pantry.
class _BoughtBar extends StatelessWidget {
  final int count;
  final VoidCallback onMove, onClear;
  const _BoughtBar({required this.count, required this.onMove, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Bought $count item${count == 1 ? '' : 's'}?',
              style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryDark),
            ),
          ),
          TextButton(
            onPressed: onClear,
            child: const Text('Clear done', style: TextStyle(color: AppColors.inkMuted, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: onMove,
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 14)),
            child: const Text('Add to pantry'),
          ),
        ],
      ),
    );
  }
}

// ── Tile ──────────────────────────────────────────────────────────────────────

class _ShoppingItemTile extends StatelessWidget {
  final ShoppingItem item;
  final bool isDark;
  const _ShoppingItemTile({required this.item, required this.isDark});

  String get _qtySubtitle {
    const trivialUnits = {'pcs', 'item', 'items'};
    if (item.quantity == 1 && trivialUnits.contains(item.unit.toLowerCase())) return '';
    final qty = item.quantity == item.quantity.truncateToDouble()
        ? item.quantity.toInt().toString()
        : item.quantity.toString();
    return trivialUnits.contains(item.unit.toLowerCase()) ? '× $qty' : '$qty ${item.unit}';
  }

  @override
  Widget build(BuildContext context) {
    final sub = _qtySubtitle;
    return Slidable(
      key: ValueKey(item.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => context.read<ShoppingCubit>().delete(item.id),
            backgroundColor: AppColors.expired,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: 'Remove',
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
        child: ListTile(
          leading: Text(foodEmoji(item.name, item.category), style: const TextStyle(fontSize: 22)),
          title: Text(
            item.name,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              decoration: item.isChecked ? TextDecoration.lineThrough : null,
              color: item.isChecked ? AppColors.inkLight : (isDark ? AppColors.darkInk : AppColors.ink),
            ),
          ),
          subtitle: sub.isEmpty
              ? null
              : Text(sub,
                  style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkInkMuted : AppColors.inkMuted)),
          trailing: Checkbox(
            value: item.isChecked,
            onChanged: (val) => context.read<ShoppingCubit>().toggle(item.id, val ?? false),
            activeColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
      ),
    );
  }
}

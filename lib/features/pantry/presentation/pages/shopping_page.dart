import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:pantrypal/core/theme/app_theme.dart';
import 'package:pantrypal/core/utils/food_emoji.dart';
import 'package:pantrypal/features/pantry/data/repositories/pantry_repository.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/pantry/presentation/bloc/pantry_bloc.dart';
import 'package:pantrypal/injection_container.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

class ShoppingPage extends StatefulWidget {
  const ShoppingPage({super.key});
  @override
  State<ShoppingPage> createState() => _ShoppingPageState();
}

class _ShoppingPageState extends State<ShoppingPage> {
  static const _uuid = Uuid();
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  String _unit = 'pcs';
  List<PantryItem> _restock = [];

  static const _units = ['pcs', 'kg', 'g', 'L', 'mL', 'pack', 'box', 'bag', 'bottle', 'can'];

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
    context.read<PantryBloc>().add(ShoppingLoad());
    _loadRestock();
    _nameCtrl.addListener(() => setState(() {}));
  }

  Future<void> _loadRestock() async {
    final items = await sl<PantryRepository>().getAllItems();
    final seen = <String>{};
    final candidates = <PantryItem>[];
    for (final i in items) {
      if (i.expiryStatus == ExpiryStatus.expired ||
          i.expiryStatus == ExpiryStatus.expiringSoon ||
          i.quantity <= 1) {
        final key = i.name.toLowerCase().trim();
        if (seen.add(key)) candidates.add(i);
      }
    }
    if (mounted) setState(() => _restock = candidates);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _addItem({String? overrideName}) {
    final name = (overrideName ?? _nameCtrl.text).trim();
    if (name.isEmpty) return;
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 1.0;
    context.read<PantryBloc>().add(ShoppingAddItem(ShoppingItem(
      id: _uuid.v4(),
      name: name,
      category: _inferCategory(name),
      quantity: qty,
      unit: _unit,
      isChecked: false,
      addedDate: DateTime.now(),
    )));
    _nameCtrl.clear();
    _qtyCtrl.text = '1';
    setState(() {});
  }

  void _addFromPantry(PantryItem item) {
    context.read<PantryBloc>().add(ShoppingAddItem(ShoppingItem(
      id: _uuid.v4(),
      name: item.name,
      category: item.category,
      quantity: 1,
      unit: item.unit,
      isChecked: false,
      addedDate: DateTime.now(),
    )));
    setState(() => _restock.remove(item));
  }

  FoodCategory _inferCategory(String name) {
    final n = name.toLowerCase();
    if (['milk', 'cheese', 'butter', 'yogurt', 'cream'].any(n.contains)) return FoodCategory.dairy;
    if (['egg'].any(n.contains)) return FoodCategory.eggs;
    if (['chicken', 'beef', 'pork', 'lamb', 'turkey', 'bacon', 'sausage', 'ham', 'fish', 'salmon', 'tuna', 'shrimp'].any(n.contains)) return FoodCategory.meat;
    if (['apple', 'banana', 'orange', 'grape', 'lemon', 'avocado', 'mango', 'berry'].any(n.contains)) return FoodCategory.fruits;
    if (['broccoli', 'carrot', 'lettuce', 'spinach', 'onion', 'garlic', 'potato', 'tomato', 'pepper', 'zucchini', 'mushroom'].any(n.contains)) return FoodCategory.vegetables;
    if (['bread', 'rice', 'pasta', 'flour', 'oat', 'cereal'].any(n.contains)) return FoodCategory.grains;
    if (['juice', 'water', 'coffee', 'tea', 'soda'].any(n.contains)) return FoodCategory.beverages;
    if (['chip', 'cookie', 'snack', 'ice cream', 'chocolate', 'candy'].any(n.contains)) return FoodCategory.snacks;
    if (['ketchup', 'mustard', 'honey', 'oil', 'vinegar', 'salt', 'sugar', 'sauce', 'mayonnaise'].any(n.contains)) return FoodCategory.condiments;
    return FoodCategory.other;
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
    if (i.quantity == 1 && i.unit == 'pcs') return '';
    final qty = i.quantity == i.quantity.truncateToDouble()
        ? i.quantity.toInt().toString()
        : i.quantity.toString();
    return '$qty ${i.unit} ';
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
            child: Row(
              children: [
                Text('Shopping List',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkInk : AppColors.ink)),
                const Spacer(),
                BlocBuilder<PantryBloc, PantryState>(
                  buildWhen: (_, s) => s is ShoppingLoaded,
                  builder: (context, state) {
                    if (state is! ShoppingLoaded || state.items.isEmpty) return const SizedBox.shrink();
                    return IconButton(
                      icon: const Icon(Icons.share_outlined),
                      color: AppColors.primary,
                      onPressed: () => _shareList(context, state.items),
                      tooltip: 'Share list',
                    );
                  },
                ),
                BlocBuilder<PantryBloc, PantryState>(
                  buildWhen: (_, s) => s is ShoppingLoaded,
                  builder: (context, state) {
                    final hasDone = state is ShoppingLoaded && state.items.any((i) => i.isChecked);
                    if (!hasDone) return const SizedBox.shrink();
                    return TextButton(
                      onPressed: () => context.read<PantryBloc>().add(ShoppingClearDone()),
                      child: const Text('Clear done',
                          style: TextStyle(color: AppColors.expired, fontSize: 13, fontWeight: FontWeight.w600)),
                    );
                  },
                ),
              ],
            ),
          ),

          // ── Add row ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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

          // ── Type-ahead chips ──────────────────────────────────────────────
          if (matches.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: matches.map((s) => ActionChip(
                  label: Text(s, style: const TextStyle(fontSize: 12)),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: isDark ? AppColors.darkCard : AppColors.card,
                  side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                  onPressed: () {
                    _nameCtrl.text = s;
                    _nameCtrl.selection = TextSelection.collapsed(offset: s.length);
                  },
                )).toList(),
              ),
            ),

          // ── Qty + unit + Add ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                SizedBox(
                  width: 52,
                  child: TextField(
                    controller: _qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '1',
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      fillColor: isDark ? AppColors.darkCard : AppColors.card,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _unit,
                    isDense: true,
                    borderRadius: BorderRadius.circular(10),
                    items: _units
                        .map((u) => DropdownMenuItem(
                              value: u,
                              child: Text(u, style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _unit = v!),
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _addItem,
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
                  child: const Text('Add'),
                ),
              ],
            ),
          ),

          // ── Restock suggestions from pantry ───────────────────────────────
          BlocBuilder<PantryBloc, PantryState>(
            buildWhen: (_, s) => s is ShoppingLoaded,
            builder: (context, state) {
              final shoppingNames = state is ShoppingLoaded
                  ? state.items.map((i) => i.name.toLowerCase()).toSet()
                  : <String>{};
              final toShow = _restock
                  .where((i) => !shoppingNames.contains(i.name.toLowerCase()))
                  .toList();
              if (toShow.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RESTOCK SOON',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: isDark ? AppColors.darkInkMuted : AppColors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: toShow.map((item) {
                          final isExpired = item.expiryStatus == ExpiryStatus.expired;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              avatar: Text(foodEmoji(item.name, item.category),
                                  style: const TextStyle(fontSize: 14)),
                              label: Text(item.name,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              backgroundColor: isExpired
                                  ? AppColors.expired.withValues(alpha: 0.10)
                                  : AppColors.expiringSoon.withValues(alpha: 0.12),
                              side: BorderSide(
                                color: isExpired
                                    ? AppColors.expired.withValues(alpha: 0.4)
                                    : AppColors.expiringSoon.withValues(alpha: 0.5),
                              ),
                              onPressed: () => _addFromPantry(item),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Divider(
                        height: 1,
                        color: isDark ? AppColors.darkBorder : AppColors.border),
                  ],
                ),
              );
            },
          ),

          // ── List ──────────────────────────────────────────────────────────
          Expanded(
            child: BlocBuilder<PantryBloc, PantryState>(
              buildWhen: (_, s) => s is ShoppingLoaded,
              builder: (context, state) {
                if (state is! ShoppingLoaded) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }
                if (state.items.isEmpty) return _buildEmpty();
                final unchecked = state.items.where((i) => !i.isChecked).toList();
                final checked = state.items.where((i) => i.isChecked).toList();
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: unchecked.length + checked.length,
                  itemBuilder: (context, i) {
                    final item = i < unchecked.length ? unchecked[i] : checked[i - unchecked.length];
                    return _ShoppingItemTile(item: item, isDark: isDark);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.shopping_cart_outlined,
                size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text('List is empty',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Type an item above and tap Add',
              style: TextStyle(color: AppColors.inkMuted)),
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
    return '$qty ${item.unit}';
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
            onPressed: (_) =>
                context.read<PantryBloc>().add(ShoppingDeleteItem(item.id)),
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
          border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
        child: ListTile(
          leading: Text(foodEmoji(item.name, item.category),
              style: const TextStyle(fontSize: 22)),
          title: Text(
            item.name,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              decoration:
                  item.isChecked ? TextDecoration.lineThrough : null,
              color: item.isChecked
                  ? AppColors.inkLight
                  : (isDark ? AppColors.darkInk : AppColors.ink),
            ),
          ),
          subtitle: sub.isEmpty
              ? null
              : Text(sub,
                  style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkInkMuted
                          : AppColors.inkMuted)),
          trailing: Checkbox(
            value: item.isChecked,
            onChanged: (val) => context
                .read<PantryBloc>()
                .add(ShoppingToggleItem(item.id, val ?? false)),
            activeColor: AppColors.primary,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
      ),
    );
  }
}

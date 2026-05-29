import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:pantrypal/core/theme/app_theme.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/pantry/presentation/bloc/pantry_bloc.dart';
import 'package:uuid/uuid.dart';

class ShoppingPage extends StatefulWidget {
  const ShoppingPage({super.key});
  @override
  State<ShoppingPage> createState() => _ShoppingPageState();
}

class _ShoppingPageState extends State<ShoppingPage> {
  static const _uuid = Uuid();
  final _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<PantryBloc>().add(ShoppingLoad());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _addItem() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    _nameCtrl.clear();
    context.read<PantryBloc>().add(ShoppingAddItem(ShoppingItem(
      id: _uuid.v4(),
      name: name,
      category: FoodCategory.other,
      quantity: 1,
      unit: 'item',
      isChecked: false,
      addedDate: DateTime.now(),
    )));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: Column(
        children: [
          // Header
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

          // Add input
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
                ElevatedButton(
                  onPressed: _addItem,
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                  child: const Text('Add'),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: BlocBuilder<PantryBloc, PantryState>(
              buildWhen: (_, s) => s is ShoppingLoaded,
              builder: (context, state) {
                if (state is! ShoppingLoaded) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }
                if (state.items.isEmpty) {
                  return _buildEmpty();
                }
                final unchecked = state.items.where((i) => !i.isChecked).toList();
                final checked = state.items.where((i) => i.isChecked).toList();
                final all = [...unchecked, ...checked];
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: all.length,
                  itemBuilder: (context, i) => _ShoppingItemTile(item: all[i], isDark: isDark),
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
            width: 80, height: 80,
            decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.shopping_cart_outlined, size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text('List is empty', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Type an item above and tap Add', style: TextStyle(color: AppColors.inkMuted)),
        ],
      ),
    );
  }
}

class _ShoppingItemTile extends StatelessWidget {
  final ShoppingItem item;
  final bool isDark;
  const _ShoppingItemTile({required this.item, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Slidable(
      key: ValueKey(item.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => context.read<PantryBloc>().add(ShoppingDeleteItem(item.id)),
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
          leading: Text(item.category.emoji, style: const TextStyle(fontSize: 22)),
          title: Text(
            item.name,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              decoration: item.isChecked ? TextDecoration.lineThrough : null,
              color: item.isChecked ? AppColors.inkLight : (isDark ? AppColors.darkInk : AppColors.ink),
            ),
          ),
          trailing: Checkbox(
            value: item.isChecked,
            onChanged: (val) => context.read<PantryBloc>().add(ShoppingToggleItem(item.id, val ?? false)),
            activeColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
      ),
    );
  }
}

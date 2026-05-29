import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pantrypal/core/theme/app_theme.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/pantry/presentation/bloc/pantry_bloc.dart';
import 'package:pantrypal/features/pantry/presentation/widgets/pantry_item_card.dart';
import 'package:pantrypal/features/pantry/presentation/widgets/add_item_dialog.dart';

class PantryPage extends StatefulWidget {
  const PantryPage({super.key});
  @override
  State<PantryPage> createState() => _PantryPageState();
}

class _PantryPageState extends State<PantryPage> {
  final _searchCtrl = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
                Expanded(
                  child: _searching
                      ? TextField(
                          controller: _searchCtrl,
                          autofocus: true,
                          onChanged: (q) => context.read<PantryBloc>().add(
                                q.isEmpty ? PantryClearSearch() : PantrySearch(q),
                              ),
                          decoration: InputDecoration(
                            hintText: 'Search items...',
                            prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                setState(() => _searching = false);
                                _searchCtrl.clear();
                                context.read<PantryBloc>().add(PantryClearSearch());
                              },
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        )
                      : Text(
                          'My Pantry',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.darkInk : AppColors.ink,
                          ),
                        ),
                ),
                if (!_searching) ...[
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () => setState(() => _searching = true),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 28),
                    onPressed: _addItemManually,
                  ),
                ],
              ],
            ),
          ),

          // Location filter
          _LocationFilter(),

          // List
          Expanded(
            child: BlocBuilder<PantryBloc, PantryState>(
              builder: (context, state) {
                if (state is PantryLoading) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }
                if (state is PantryLoaded) {
                  if (state.items.isEmpty) {
                    return _EmptyState(isSearch: state.searchQuery.isNotEmpty, query: state.searchQuery);
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: state.items.length,
                    itemBuilder: (ctx, i) {
                      final item = state.items[i];
                      return PantryItemCard(
                        item: item,
                        onTap: () => _editItem(ctx, item),
                        onConsumed: () => context.read<PantryBloc>().add(PantryMarkConsumed(item.id)),
                        onWasted: () => context.read<PantryBloc>().add(PantryMarkWasted(item.id)),
                        onDelete: () => context.read<PantryBloc>().add(PantryDeleteItem(item.id)),
                      );
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addItemManually() async {
    final item = await showModalBottomSheet<PantryItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddItemDialog(),
    );
    if (item != null && mounted) {
      context.read<PantryBloc>().add(PantryAddItem(item));
    }
  }

  Future<void> _editItem(BuildContext context, PantryItem existing) async {
    final item = await showModalBottomSheet<PantryItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddItemDialog(existing: existing),
    );
    if (item != null && mounted) {
      context.read<PantryBloc>().add(PantryUpdateItem(item));
    }
  }
}

class _LocationFilter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PantryBloc, PantryState>(
      builder: (context, state) {
        final activeLocation = state is PantryLoaded ? state.activeLocation : null;
        return SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _LocationChip(label: 'All', emoji: '📋', active: activeLocation == null,
                  onTap: () => context.read<PantryBloc>().add(PantryFilterByLocation(null))),
              ...StorageLocation.values.map((loc) => _LocationChip(
                    label: loc.label,
                    emoji: loc.emoji,
                    active: activeLocation == loc,
                    onTap: () => context.read<PantryBloc>().add(
                          PantryFilterByLocation(activeLocation == loc ? null : loc),
                        ),
                  )),
            ],
          ),
        );
      },
    );
  }
}

class _LocationChip extends StatelessWidget {
  final String label, emoji;
  final bool active;
  final VoidCallback onTap;
  const _LocationChip({required this.label, required this.emoji, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : (isDark ? AppColors.darkCard : AppColors.card),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? AppColors.primary : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? Colors.white : (isDark ? AppColors.darkInk : AppColors.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isSearch;
  final String query;
  const _EmptyState({required this.isSearch, required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isSearch ? Icons.search_off : Icons.kitchen_outlined, size: 64, color: AppColors.inkLight),
            const SizedBox(height: 16),
            Text(isSearch ? 'No results for "$query"' : 'Nothing here yet', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(isSearch ? 'Try a different search' : 'Add items manually or scan a receipt', style: const TextStyle(color: AppColors.inkMuted, fontSize: 14), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

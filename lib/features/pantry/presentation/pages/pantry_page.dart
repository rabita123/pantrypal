import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pantrypal/core/theme/app_theme.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/pantry/presentation/bloc/pantry_bloc.dart';
import 'package:pantrypal/shared/services/review_service.dart';
import 'package:pantrypal/shared/widgets/happy_moment_sheet.dart';
import 'package:pantrypal/features/pantry/presentation/widgets/pantry_item_card.dart';
import 'package:pantrypal/features/pantry/presentation/widgets/add_item_dialog.dart';
import 'package:pantrypal/features/pantry/presentation/add_flow.dart';
import 'package:pantrypal/features/pantry/presentation/widgets/add_food_sheet.dart';

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
                    tooltip: 'Add food',
                    icon: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 28),
                    onPressed: () => AddFlow.start(context),
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
                  // Group into "use first" and everything else — but only when
                  // browsing the whole pantry, not while searching/filtering.
                  final grouped = state.searchQuery.isEmpty && state.activeLocation == null;
                  final urgent = grouped
                      ? state.items.where((i) => i.daysUntilExpiry <= 3).toList()
                      : <PantryItem>[];
                  final rest = grouped
                      ? state.items.where((i) => i.daysUntilExpiry > 3).toList()
                      : state.items;
                  final rows = <Object>[
                    if (urgent.isNotEmpty) 'Use first · ${urgent.length}',
                    ...urgent,
                    if (urgent.isNotEmpty && rest.isNotEmpty) 'Everything else · ${rest.length}',
                    ...rest,
                  ];
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                    itemCount: rows.length,
                    itemBuilder: (ctx, i) {
                      final row = rows[i];
                      if (row is String) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                          child: Text(
                            row.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: row.startsWith('Use first')
                                  ? AppColors.expiringSoon
                                  : (isDark ? AppColors.darkInkMuted : AppColors.inkMuted),
                            ),
                          ),
                        );
                      }
                      final item = row as PantryItem;
                      return PantryItemCard(
                        item: item,
                        onTap: () => _editItem(ctx, item),
                        onConsumed: () => _consume(ctx, item),
                        onWasted: () => context.read<PantryBloc>().add(PantryMarkWasted(item.id)),
                        onDelete: () => context.read<PantryBloc>().add(PantryDeleteItem(item.id)),
                        onFreeze: () {
                          final frozen = item.copyWith(
                            location: StorageLocation.freezer,
                            expiryDate: PantryItem.expiryInDays(90),
                          );
                          context.read<PantryBloc>().add(PantryUpdateItem(frozen));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${item.name} moved to freezer ❄️'),
                              backgroundColor: const Color(0xFF1565C0),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        },
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


  /// Using something before it expired is the app working as intended — the
  /// one place a review request is genuinely earned.
  Future<void> _consume(BuildContext context, PantryItem item) async {
    context.read<PantryBloc>().add(PantryMarkConsumed(item.id));
    await ReviewService.instance.recordHappyMoment();
    if (!context.mounted) return;
    await HappyMomentSheet.maybeShow(context);
  }

  Future<void> _editItem(BuildContext context, PantryItem existing) async {
    final item = await showModalBottomSheet<PantryItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddItemDialog(existing: existing),
    );
    if (item != null && context.mounted) {
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
            Text(isSearch ? 'No results for "$query"' : 'Nothing here yet',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              isSearch ? 'Try a different search' : 'Scan a receipt and your whole shop is added in seconds.',
              style: const TextStyle(color: AppColors.inkMuted, fontSize: 14, height: 1.4),
              textAlign: TextAlign.center,
            ),
            if (!isSearch) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => AddFlow.run(context, AddKind.receipt),
                icon: const Icon(Icons.document_scanner_outlined),
                label: const Text('Scan a receipt'),
              ),
              TextButton(
                onPressed: () => AddFlow.run(context, AddKind.tap),
                child: const Text('or tap what you have'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pantrypal/core/theme/app_theme.dart';
import 'package:pantrypal/core/utils/food_emoji.dart';
import 'package:pantrypal/features/dashboard/presentation/widgets/share_card_sheet.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/pantry/domain/services/pantry_insights.dart';
import 'package:pantrypal/features/pantry/presentation/add_flow.dart';
import 'package:pantrypal/features/pantry/presentation/bloc/pantry_bloc.dart';
import 'package:pantrypal/features/pantry/presentation/widgets/add_food_sheet.dart';
import 'package:pantrypal/features/recipes/domain/entities/recipe.dart';
import 'package:pantrypal/features/recipes/domain/services/cook_tonight_service.dart';
import 'package:pantrypal/features/recipes/presentation/bloc/recipe_bloc.dart';
import 'package:pantrypal/features/recipes/presentation/pages/cook_tonight_page.dart';
import 'package:pantrypal/features/plan/data/plan_repository.dart';
import 'package:pantrypal/features/plan/presentation/plan_cubit.dart';
import 'package:pantrypal/features/plan/presentation/widgets/plan_widgets.dart';
import 'package:pantrypal/features/settings/settings_page.dart';
import 'package:pantrypal/shared/services/analytics_service.dart';
import 'package:pantrypal/shared/services/review_service.dart';
import 'package:pantrypal/shared/widgets/happy_moment_sheet.dart';

/// "Use This First": the one screen that answers what to eat before it goes
/// off, what that is worth, and what to cook with it.
class HomeTab extends StatelessWidget {
  final VoidCallback onOpenPantry;
  final VoidCallback? onOpenPlan;
  const HomeTab({super.key, required this.onOpenPantry, this.onOpenPlan});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: BlocBuilder<PantryBloc, PantryState>(
        builder: (context, state) {
          if (state is PantryInitial || state is PantryLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (state is! PantryLoaded || state.allItems.isEmpty) {
            return const _EmptyHome();
          }
          return _Content(state: state, onOpenPantry: onOpenPantry, onOpenPlan: onOpenPlan);
        },
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting,
                    style: TextStyle(fontSize: 14, color: isDark ? AppColors.darkInkMuted : AppColors.inkMuted)),
                const SizedBox(height: 2),
                Text(
                  'Use this first',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: isDark ? AppColors.darkInk : AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            color: isDark ? AppColors.darkInkMuted : AppColors.inkMuted,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty ─────────────────────────────────────────────────────────────────────

class _EmptyHome extends StatelessWidget {
  const _EmptyHome();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.darkInk : AppColors.ink;
    final muted = isDark ? AppColors.darkInkMuted : AppColors.inkMuted;

    return ListView(
      children: [
        const _Header(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📸', style: TextStyle(fontSize: 38)),
                const SizedBox(height: 10),
                const Text(
                  'Fill your kitchen in\n10 seconds',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2),
                ),
                const SizedBox(height: 8),
                Text(
                  'Snap a receipt and PantryPal shows what to use first and what to cook tonight.',
                  style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.85), height: 1.45),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => AddFlow.run(context, AddKind.receipt),
                    icon: const Icon(Icons.document_scanner_outlined),
                    label: const Text('Scan a receipt', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text('No receipt handy?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: muted)),
        ),
        _AltAction(
          icon: Icons.touch_app_outlined,
          title: 'Tap what you have',
          subtitle: 'Pick from common foods — no typing',
          onTap: () => AddFlow.run(context, AddKind.tap),
          ink: ink,
          muted: muted,
          isDark: isDark,
        ),
        _AltAction(
          icon: Icons.kitchen_outlined,
          title: 'Photo of your fridge',
          subtitle: 'AI spots what is inside',
          onTap: () => AddFlow.run(context, AddKind.fridge),
          ink: ink,
          muted: muted,
          isDark: isDark,
        ),
        _AltAction(
          icon: Icons.edit_note,
          title: 'Type a few things',
          subtitle: 'milk, eggs, spinach…',
          onTap: () => AddFlow.start(context),
          ink: ink,
          muted: muted,
          isDark: isDark,
        ),
        const SizedBox(height: 100),
      ],
    );
  }
}

class _AltAction extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  final Color ink, muted;
  final bool isDark;
  const _AltAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.ink,
    required this.muted,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Material(
        color: isDark ? AppColors.darkCard : AppColors.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ink)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(fontSize: 12, color: muted)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 14, color: muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Content ───────────────────────────────────────────────────────────────────

class _Content extends StatelessWidget {
  final PantryLoaded state;
  final VoidCallback onOpenPantry;
  final VoidCallback? onOpenPlan;
  const _Content({required this.state, required this.onOpenPantry, this.onOpenPlan});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final all = state.allItems;
    final urgent = PantryInsights.useFirst(all);
    final comingUp = all
        .where((i) => i.daysUntilExpiry > 3)
        .toList()
      ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

    return ListView(
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        const _Header(),
        _Hero(all: all, urgent: urgent, comingUp: comingUp),
        // Cooked food in the fridge is the first thing to eat.
        BlocBuilder<PlanCubit, PlanState>(
          builder: (context, plan) {
            final chilled = plan.portions.where((p) => p.location == PortionLocation.fridge).toList();
            if (chilled.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle(
                  title: 'Eat leftovers first',
                  trailing: onOpenPlan != null ? 'Plan' : null,
                  onTrailing: onOpenPlan,
                  isDark: isDark,
                ),
                for (final p in chilled.take(2)) PortionRow(portion: p, compact: true),
              ],
            );
          },
        ),
        BlocBuilder<RecipeBloc, RecipeState>(
          builder: (context, recipeState) {
            final recipes = recipeState is RecipeLoaded ? recipeState.all : <Recipe>[];
            final pick = PantryInsights.tonightPick(recipes, all);
            if (pick == null) return const SizedBox.shrink();
            return _TonightCard(pick: pick);
          },
        ),
        if (urgent.isNotEmpty) ...[
          _SectionTitle(
            title: 'Use first',
            trailing: urgent.length > 5 ? 'See all ${urgent.length}' : null,
            onTrailing: onOpenPantry,
            isDark: isDark,
          ),
          for (final item in urgent.take(5)) _UseFirstRow(item: item),
        ] else ...[
          _SectionTitle(title: 'Coming up', isDark: isDark),
          for (final item in comingUp.take(3)) _UseFirstRow(item: item),
        ],
        if (all.length > 5 || (urgent.isNotEmpty && comingUp.isNotEmpty))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onOpenPantry,
                child: Text('See everything in your pantry (${all.length})'),
              ),
            ),
          ),
        _SavingsCard(stats: state.stats),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  final List<PantryItem> all, urgent, comingUp;
  const _Hero({required this.all, required this.urgent, required this.comingUp});

  @override
  Widget build(BuildContext context) {
    final expired = urgent.where((i) => i.daysUntilExpiry < 0).length;
    final soon = urgent.length - expired;
    final atRisk = PantryInsights.atRiskValue(all);
    final approx = urgent.any((i) => i.isValueEstimated);

    final calm = urgent.isEmpty;
    final colors = calm
        ? const [AppColors.primary, AppColors.primaryDark]
        : const [Color(0xFFEF6C00), Color(0xFFBF360C)];

    String headline;
    String sub;
    if (calm) {
      headline = 'All good 🎉';
      final next = comingUp.isEmpty ? null : comingUp.first;
      sub = next == null
          ? 'Nothing is about to go off.'
          : 'Nothing expires in the next 3 days. Next up: ${next.name} (${PantryInsights.shortWhen(next).toLowerCase()}).';
    } else if (soon > 0) {
      headline = '${PantryInsights.money(atRisk, approx: approx)} of food to use soon';
      sub = '$soon item${soon == 1 ? '' : 's'} need${soon == 1 ? 's' : ''} using in the next 3 days'
          '${expired > 0 ? ' · $expired already past date' : ''}.';
    } else {
      headline = '$expired item${expired == 1 ? ' is' : 's are'} past date';
      sub = 'Check ${expired == 1 ? 'it' : 'them'} below — use what is still good, toss the rest.';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              headline,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2),
            ),
            const SizedBox(height: 6),
            Text(sub, style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.9), height: 1.4)),
          ],
        ),
      ),
    );
  }
}

class _TonightCard extends StatelessWidget {
  final CookTonightResult pick;
  const _TonightCard({required this.pick});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uses = pick.matches.where((m) => m.expiringSoon).map((m) => m.ingredientName).toList();
    final detail = uses.isNotEmpty
        ? 'Uses ${uses.take(2).join(' & ')}'
        : pick.canCookNow
            ? 'You have everything'
            : 'Missing ${pick.missingCount}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: isDark ? AppColors.darkCard : AppColors.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CookTonightPage())),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(14)),
                  child: const Center(child: Text('🍳', style: TextStyle(fontSize: 26))),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Cook tonight',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                      const SizedBox(height: 1),
                      Text(
                        pick.recipe.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.darkInk : AppColors.ink,
                        ),
                      ),
                      Text('$detail · ${pick.recipe.timeLabel}',
                          style: const TextStyle(fontSize: 12, color: AppColors.inkMuted)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.inkLight),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTrailing;
  final bool isDark;
  const _SectionTitle({required this.title, this.trailing, this.onTrailing, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 6),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkInk : AppColors.ink,
            ),
          ),
          const Spacer(),
          if (trailing != null) TextButton(onPressed: onTrailing, child: Text(trailing!)),
        ],
      ),
    );
  }
}

/// One food that needs a decision, with the decision one tap away.
class _UseFirstRow extends StatelessWidget {
  final PantryItem item;
  const _UseFirstRow({required this.item});

  static const _freezable = {
    FoodCategory.meat,
    FoodCategory.grains,
    FoodCategory.dairy,
    FoodCategory.fruits,
    FoodCategory.vegetables,
  };

  Future<void> _used(BuildContext context) async {
    final bloc = context.read<PantryBloc>();
    final messenger = ScaffoldMessenger.of(context);
    Analytics.track('use_first_action', {'action': 'used', 'days_left': item.daysUntilExpiry});
    bloc.add(PantryMarkConsumed(item.id));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Nice — ${item.name} used, ${PantryInsights.money(item.estimatedValue, approx: item.isValueEstimated)} saved'),
        backgroundColor: AppColors.primary,
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.white,
          onPressed: () => bloc.add(PantryUpdateItem(item.copyWith(isConsumed: false))),
        ),
      ));
    await ReviewService.instance.recordHappyMoment();
    if (!context.mounted) return;
    await HappyMomentSheet.maybeShow(context);
  }

  void _toss(BuildContext context) {
    final bloc = context.read<PantryBloc>();
    Analytics.track('use_first_action', {'action': 'toss', 'days_left': item.daysUntilExpiry});
    bloc.add(PantryMarkWasted(item.id));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${item.name} tossed'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => bloc.add(PantryUpdateItem(item.copyWith(isWasted: false))),
        ),
      ));
  }

  void _freeze(BuildContext context) {
    context.read<PantryBloc>().add(PantryUpdateItem(item.copyWith(
      location: StorageLocation.freezer,
      expiryDate: PantryItem.expiryInDays(90),
    )));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${item.name} moved to the freezer — good for 90 days ❄️'),
        backgroundColor: const Color(0xFF1565C0),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final days = item.daysUntilExpiry;
    final color = days < 0
        ? AppColors.expired
        : days <= 1
            ? AppColors.expiringSoon
            : days <= 3
                ? AppColors.expiringSoon
                : AppColors.fresh;
    final canFreeze = days >= 0 &&
        days <= 1 &&
        item.location != StorageLocation.freezer &&
        _freezable.contains(item.category);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: days <= 3 ? color.withValues(alpha: 0.4) : (isDark ? AppColors.darkBorder : AppColors.border)),
      ),
      child: Row(
        children: [
          Text(foodEmoji(item.name, item.category), style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkInk : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  PantryInsights.shortWhen(item),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
                ),
              ],
            ),
          ),
          if (canFreeze)
            IconButton(
              tooltip: 'Freeze it',
              visualDensity: VisualDensity.compact,
              onPressed: () => _freeze(context),
              icon: const Text('❄️', style: TextStyle(fontSize: 18)),
            ),
          TextButton(
            onPressed: () => _toss(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.inkMuted,
              minimumSize: const Size(48, 40),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text('Toss', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => _used(context),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(64, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: const Text('Used', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _SavingsCard extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _SavingsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final saved = ((stats['savedValueMonth'] as num?) ?? 0).toDouble();
    final lost = ((stats['wastedValueMonth'] as num?) ?? 0).toDouble();
    final used = (stats['consumedMonth'] as int?) ?? 0;
    final tossed = (stats['wastedMonth'] as int?) ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'This month',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkInk : AppColors.ink,
                  ),
                ),
                const Spacer(),
                if (used + tossed > 0)
                  TextButton.icon(
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (_) => ShareCardSheet(stats: stats),
                    ),
                    icon: const Icon(Icons.ios_share, size: 16),
                    label: const Text('Share'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (used + tossed == 0)
              const Text(
                'Tap "Used" on food you finish before it expires and your savings show up here.',
                style: TextStyle(fontSize: 13, color: AppColors.inkMuted, height: 1.4),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _Stat(
                      value: PantryInsights.money(saved, approx: true),
                      label: 'saved · $used used',
                      color: AppColors.primary,
                    ),
                  ),
                  Expanded(
                    child: _Stat(
                      value: PantryInsights.money(lost, approx: true),
                      label: 'wasted · $tossed tossed',
                      color: lost > 0 ? AppColors.expired : AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value, label;
  final Color color;
  const _Stat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.inkMuted)),
      ],
    );
  }
}

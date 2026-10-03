import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pantrypal/core/theme/app_theme.dart';
import 'package:pantrypal/core/utils/food_emoji.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/pantry/presentation/bloc/pantry_bloc.dart';
import 'package:pantrypal/features/plan/data/plan_repository.dart';
import 'package:pantrypal/features/plan/domain/meal_planner.dart';
import 'package:pantrypal/features/plan/presentation/plan_cubit.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "Tonight", "Tomorrow", "Thu 9".
String planDayLabel(DateTime d) {
  final n = DateTime.now();
  final diff = DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(n.year, n.month, n.day)).inDays;
  if (diff == 0) return 'Tonight';
  if (diff == 1) return 'Tomorrow';
  return '${_weekdays[d.weekday - 1]} ${d.day}';
}

String _eatBy(PortionBatch p) {
  final d = p.daysLeft;
  if (d < 0) return 'past its eat-by';
  if (d == 0) return 'eat today';
  if (d == 1) return 'eat by tomorrow';
  if (p.location == PortionLocation.freezer && d > 14) return 'frozen · good for ${(d / 30).round()} months';
  return 'eat by ${_weekdays[p.eatBy.weekday - 1]}';
}

// ── Summary ───────────────────────────────────────────────────────────────────

/// The plan, told in terms of the user's own food.
class PlanSummaryCard extends StatelessWidget {
  final PlanInsight insight;
  final String headline;
  final Widget? action;
  final VoidCallback? onAddMissing;

  const PlanSummaryCard({
    super.key,
    required this.insight,
    required this.headline,
    this.action,
    this.onAddMissing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.darkInk : AppColors.ink;
    final muted = isDark ? AppColors.darkInkMuted : AppColors.inkMuted;
    final i = insight;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(headline,
              style:
                  TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: ink, height: 1.2, letterSpacing: -0.3)),
          const SizedBox(height: 14),
          if (i.needUsingSoon > 0)
            _Line(
              emoji: '🥕',
              text: '${i.needUsingSoon} ingredient${i.needUsingSoon == 1 ? '' : 's'} need using soon',
              trailing: i.usedSoonByPlan > 0 ? '${i.usedSoonByPlan} used here' : null,
              color: AppColors.expiringSoon,
            ),
          _Line(
            emoji: '🍳',
            text: '${i.noShoppingMeals} meal${i.noShoppingMeals == 1 ? '' : 's'} need no shopping',
            color: AppColors.primary,
          ),
          if (i.shoppingMeals > 0)
            _Line(
              emoji: '🛒',
              text: '${i.shoppingMeals} meal${i.shoppingMeals == 1 ? ' needs' : 's need'} '
                  '${i.toBuy.length} more ingredient${i.toBuy.length == 1 ? '' : 's'}',
              color: muted,
              onTap: onAddMissing,
              trailing: onAddMissing != null ? 'Add to list' : null,
            ),
          if (action != null) ...[const SizedBox(height: 10), action!],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final String emoji, text;
  final String? trailing;
  final Color color;
  final VoidCallback? onTap;
  const _Line({required this.emoji, required this.text, required this.color, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkInk : AppColors.ink,
                  )),
            ),
            if (trailing != null)
              Text(trailing!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}

// ── Meal card ─────────────────────────────────────────────────────────────────

class PlanMealCard extends StatelessWidget {
  final PlannedMeal meal;

  /// Live evaluation against the pantry; null when the recipe no longer exists.
  final MealOption? option;
  final VoidCallback? onCooked;
  final VoidCallback? onSwap;
  final VoidCallback? onRemove;
  final VoidCallback? onOpen;
  final String? label;

  const PlanMealCard({
    super.key,
    required this.meal,
    this.option,
    this.onCooked,
    this.onSwap,
    this.onRemove,
    this.onOpen,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.darkInk : AppColors.ink;
    final muted = isDark ? AppColors.darkInkMuted : AppColors.inkMuted;
    final o = option;
    final cooked = meal.status == MealStatus.cooked;
    final soon = o?.usesSoon ?? const <PantryItem>[];
    final have = o?.real.where((i) => i.have).toList() ?? const [];
    final missing = o?.missingIngredients ?? const [];

    return Opacity(
      opacity: cooked ? 0.6 : 1,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: soon.isNotEmpty && !cooked
                ? AppColors.expiringSoon.withValues(alpha: 0.45)
                : (isDark ? AppColors.darkBorder : AppColors.border),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        (label ?? planDayLabel(meal.date)).toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.9,
                          color: planDayLabel(meal.date) == 'Tonight' ? AppColors.primary : muted,
                        ),
                      ),
                      const Spacer(),
                      if (cooked)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Text('Cooked ✓',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary)),
                        )
                      else if (onRemove != null)
                        SizedBox(
                          height: 24,
                          child: PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            iconSize: 18,
                            icon: Icon(Icons.more_horiz, color: muted),
                            onSelected: (v) => v == 'remove' ? onRemove!() : null,
                            itemBuilder: (_) => const [PopupMenuItem(value: 'remove', child: Text('Remove from plan'))],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(meal.recipeName,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ink, letterSpacing: -0.2)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      '${meal.isBatch ? 'Makes' : 'Serves'} ${meal.servings}',
                      if (o != null) o.recipe.timeLabel,
                      if (o != null) o.noShopping ? 'No shopping' : '${o.missingCount} to buy',
                      if (o?.recipe.kcalPerServing != null) '≈${o!.recipe.kcalPerServing} kcal',
                    ].join(' · '),
                    style: TextStyle(
                      fontSize: 13,
                      color: o != null && o.noShopping ? AppColors.primary : muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (o != null && !cooked) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final p in soon) _Chip(text: p.name, kind: _ChipKind.soon),
                        for (final i in have.where((h) => !soon.any((s) => s.id == h.item?.id)).take(4))
                          _Chip(text: i.name, kind: _ChipKind.have),
                        for (final m in missing) _Chip(text: m.name, kind: _ChipKind.missing),
                      ],
                    ),
                  ],
                  if (!cooked && (onCooked != null || onSwap != null)) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (onCooked != null)
                          FilledButton.tonal(
                            onPressed: onCooked,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primarySurface,
                              foregroundColor: AppColors.primaryDark,
                              minimumSize: const Size(0, 38),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            child: const Text('Cooked it', style: TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        const SizedBox(width: 6),
                        if (onSwap != null)
                          TextButton.icon(
                            onPressed: onSwap,
                            icon: const Icon(Icons.swap_horiz, size: 18),
                            label: const Text('Swap'),
                            style: TextButton.styleFrom(foregroundColor: muted),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _ChipKind { soon, have, missing }

class _Chip extends StatelessWidget {
  final String text;
  final _ChipKind kind;
  const _Chip({required this.text, required this.kind});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (kind) {
      _ChipKind.soon => (AppColors.expiringSoonSurface, AppColors.expiringSoon, Icons.timer_outlined),
      _ChipKind.have => (AppColors.primarySurface, AppColors.primary, Icons.check),
      _ChipKind.missing => (AppColors.border, AppColors.inkMuted, Icons.add_shopping_cart),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }
}

// ── Portions ──────────────────────────────────────────────────────────────────

/// Cooked food waiting to be eaten — the last step of plan → cook → portions.
class PortionsSection extends StatelessWidget {
  final List<PortionBatch> portions;
  const PortionsSection({super.key, required this.portions});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = portions.fold<int>(0, (s, p) => s + p.remaining);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Text(
            'Ready to eat · $total portion${total == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkInk : AppColors.ink,
            ),
          ),
        ),
        for (final p in portions) PortionRow(portion: p),
      ],
    );
  }
}

class PortionRow extends StatelessWidget {
  final PortionBatch portion;
  final bool compact;
  const PortionRow({super.key, required this.portion, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = portion;
    final frozen = p.location == PortionLocation.freezer;
    final urgent = p.daysLeft <= 1;
    final cubit = context.read<PlanCubit>();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: urgent && !frozen
              ? AppColors.expiringSoon.withValues(alpha: 0.45)
              : (isDark ? AppColors.darkBorder : AppColors.border),
        ),
      ),
      child: Row(
        children: [
          Text(frozen ? '🧊' : '🍲', style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.recipeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkInk : AppColors.ink)),
                const SizedBox(height: 1),
                Text(
                  '${p.remaining} left · ${_eatBy(p)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: urgent && !frozen ? AppColors.expiringSoon : AppColors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          if (!compact)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz, color: AppColors.inkMuted, size: 20),
              onSelected: (v) {
                if (v == 'freeze') cubit.freezePortions(p);
                if (v == 'toss') cubit.tossPortions(p);
              },
              itemBuilder: (_) => [
                if (!frozen) const PopupMenuItem(value: 'freeze', child: Text('Move to freezer')),
                const PopupMenuItem(value: 'toss', child: Text('Throw the rest away')),
              ],
            ),
          FilledButton.tonal(
            onPressed: () {
              HapticFeedback.selectionClick();
              cubit.eatPortion(p);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primarySurface,
              foregroundColor: AppColors.primaryDark,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: const Text('Ate 1', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

// ── Cooked it ─────────────────────────────────────────────────────────────────

/// Confirms a cook: how many portions, how many eaten now, what to freeze, and
/// which pantry items were used. Nothing comes off the pantry without this.
class CookSheet extends StatefulWidget {
  final PlannedMeal meal;
  final MealOption? option;
  final int household;

  const CookSheet({super.key, required this.meal, required this.option, required this.household});

  static Future<void> show(
    BuildContext context, {
    required PlannedMeal meal,
    required MealOption? option,
    required int household,
  }) async {
    final created = await showModalBottomSheet<List<PortionBatch>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CookSheet(meal: meal, option: option, household: household),
    );
    if (created == null || !context.mounted) return;
    context.read<PantryBloc>().add(PantryLoad());
    final saved = created.fold<int>(0, (s, p) => s + p.total);
    final frozen = created.where((p) => p.location == PortionLocation.freezer).fold<int>(0, (s, p) => s + p.total);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        backgroundColor: AppColors.primary,
        content: Text(saved == 0
            ? 'Nice — pantry updated'
            : 'Pantry updated · $saved portion${saved == 1 ? '' : 's'} saved${frozen > 0 ? ' ($frozen in the freezer)' : ''}'),
      ));
  }

  @override
  State<CookSheet> createState() => _CookSheetState();
}

class _CookSheetState extends State<CookSheet> {
  late int _made;
  late int _eating;
  late int _freeze;
  late final Map<String, bool> _use;
  bool _saving = false;

  List<PantryItem> get _items => widget.option?.usedItems ?? const [];

  @override
  void initState() {
    super.initState();
    _made = widget.meal.servings.clamp(1, 40);
    _eating = widget.meal.isBatch ? widget.household.clamp(0, _made) : _made.clamp(0, widget.household);
    _freeze = widget.meal.freezePortions.clamp(0, _made - _eating);
    // Perishables are ticked; a bag of rice usually is not finished by one meal.
    _use = {for (final p in _items) p.id: !MealPlanner.isReusable(p)};
  }

  int get _leftover => (_made - _eating).clamp(0, 99);

  void _clampFreeze() => _freeze = _freeze.clamp(0, _leftover);

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    final created = await context.read<PlanCubit>().cooked(
          meal: widget.meal,
          portionsMade: _made,
          eatingNow: _eating,
          freeze: _freeze,
          used: _items.where((p) => _use[p.id] ?? false).toList(),
        );
    if (mounted) Navigator.pop(context, created);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.darkInk : AppColors.ink;
    final muted = isDark ? AppColors.darkInkMuted : AppColors.inkMuted;
    final chilled = _leftover - _freeze;

    return Material(
      color: isDark ? AppColors.darkCard : Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: isDark ? AppColors.darkBorder : AppColors.border,
                            borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Cooked ${widget.meal.recipeName}?',
                        style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: ink, letterSpacing: -0.3)),
                    const SizedBox(height: 16),
                    _Stepper(
                      label: 'Portions made',
                      value: _made,
                      min: 1,
                      max: 40,
                      onChanged: (v) => setState(() {
                        _made = v;
                        _eating = _eating.clamp(0, _made);
                        _clampFreeze();
                      }),
                    ),
                    _Stepper(
                      label: 'Eating now',
                      value: _eating,
                      min: 0,
                      max: _made,
                      onChanged: (v) => setState(() {
                        _eating = v;
                        _clampFreeze();
                      }),
                    ),
                    if (_leftover > 0)
                      _Stepper(
                        label: 'Freeze',
                        value: _freeze,
                        min: 0,
                        max: _leftover,
                        onChanged: (v) => setState(() => _freeze = v),
                      ),
                    if (_leftover > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 2, bottom: 6),
                        child: Text(
                          [
                            if (chilled > 0) '$chilled in the fridge · eat within ${PlanCubit.fridgeLifeDays} days',
                            if (_freeze > 0) '$_freeze in the freezer · good for 3 months',
                          ].join('\n'),
                          style: TextStyle(fontSize: 13, color: muted, height: 1.5),
                        ),
                      ),
                    if (_items.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text('Used from your pantry',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: muted)),
                      const SizedBox(height: 4),
                      for (final p in _items)
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: AppColors.primary,
                          value: _use[p.id],
                          onChanged: (v) => setState(() => _use[p.id] = v ?? false),
                          title: Text('${foodEmoji(p.name, p.category)}  ${p.name}',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ink)),
                          subtitle: Text(
                            p.quantity > 1
                                ? 'One of ${p.quantity % 1 == 0 ? p.quantity.toInt() : p.quantity} will be used'
                                : (_use[p.id] ?? false)
                                    ? 'Will be marked as used'
                                    : 'Keep it — some left',
                            style: TextStyle(fontSize: 12, color: muted),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            // Pinned so it is always reachable, however long the list.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    _leftover > 0 ? 'Done · save $_leftover portion${_leftover == 1 ? '' : 's'}' : 'Done',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final String label;
  final int value, min, max;
  final ValueChanged<int> onChanged;
  const _Stepper(
      {required this.label, required this.value, required this.min, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.darkInk : AppColors.ink;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ink))),
          IconButton.outlined(
            tooltip: 'Less',
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove, size: 18),
          ),
          SizedBox(
            width: 40,
            child: Text('$value',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: ink)),
          ),
          IconButton.outlined(
            tooltip: 'More',
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add, size: 18),
          ),
        ],
      ),
    );
  }
}

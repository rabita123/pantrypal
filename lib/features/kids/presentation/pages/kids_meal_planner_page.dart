import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pantrypal/core/theme/app_theme.dart';
import 'package:pantrypal/core/utils/food_emoji.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/recipes/domain/entities/recipe.dart';
import 'package:pantrypal/features/recipes/presentation/bloc/recipe_bloc.dart';
import 'package:pantrypal/features/recipes/presentation/pages/recipe_detail_page.dart';

class KidsMealPlannerPage extends StatefulWidget {
  const KidsMealPlannerPage({super.key});

  @override
  State<KidsMealPlannerPage> createState() => _KidsMealPlannerPageState();
}

class _KidsMealPlannerPageState extends State<KidsMealPlannerPage> {
  static const _prefKey = 'kids_meal_plan_v1';
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _daysFull = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static const _meals = [
    ('breakfast', '🌅', 'Breakfast'),
    ('lunch', '☀️', 'Lunch'),
    ('dinner', '🌙', 'Dinner'),
  ];

  late DateTime _weekStart;
  int _selectedDay = 0;
  // dateKey (YYYY-MM-DD) → mealType → recipeId
  final Map<String, Map<String, String>> _plan = {};

  @override
  void initState() {
    super.initState();
    _weekStart = _mondayOf(DateTime.now());
    _loadPlan();
    _ensureRecipesLoaded();
  }

  DateTime _mondayOf(DateTime d) => d.subtract(Duration(days: d.weekday - 1));

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime _dayDate(int i) => _weekStart.add(Duration(days: i));

  Future<void> _loadPlan() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw == null) return;
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    if (!mounted) return;
    setState(() {
      _plan.clear();
      for (final e in decoded.entries) {
        _plan[e.key] = Map<String, String>.from(e.value as Map);
      }
    });
  }

  Future<void> _savePlan() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, jsonEncode(_plan));
  }

  void _ensureRecipesLoaded() {
    final state = context.read<RecipeBloc>().state;
    if (state is! RecipeLoaded) {
      context.read<RecipeBloc>().add(RecipeLoad());
    }
  }

  String? _getMeal(int dayIndex, String mealType) =>
      _plan[_dateKey(_dayDate(dayIndex))]?[mealType];

  void _setMeal(int dayIndex, String mealType, String? recipeId) {
    final key = _dateKey(_dayDate(dayIndex));
    if (recipeId == null) {
      _plan[key]?.remove(mealType);
      if (_plan[key]?.isEmpty == true) _plan.remove(key);
    } else {
      _plan.putIfAbsent(key, () => {})[mealType] = recipeId;
    }
    setState(() {});
    _savePlan();
  }

  Recipe? _findRecipe(String? id) {
    if (id == null) return null;
    final state = context.read<RecipeBloc>().state;
    if (state is! RecipeLoaded) return null;
    try {
      return state.all.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  bool _hasMealsOnDay(int dayIndex) =>
      _meals.any((m) => _getMeal(dayIndex, m.$1) != null);

  void _autoFillWeek() {
    final state = context.read<RecipeBloc>().state;
    if (state is! RecipeLoaded) return;
    final kid = state.all
        .where((r) => r.dietaryTags.contains(DietaryTag.kidFriendly))
        .toList();
    if (kid.isEmpty) return;

    int idx = 0;
    for (int d = 0; d < 7; d++) {
      for (final m in _meals) {
        if (_getMeal(d, m.$1) == null) {
          _setMeal(d, m.$1, kid[idx % kid.length].id);
          idx++;
        }
      }
    }
  }

  Future<void> _pickMeal(int dayIndex, String mealType) async {
    final state = context.read<RecipeBloc>().state;
    if (state is! RecipeLoaded) return;

    final kid = state.all
        .where((r) => r.dietaryTags.contains(DietaryTag.kidFriendly))
        .toList();
    final rest = state.all
        .where((r) => !r.dietaryTags.contains(DietaryTag.kidFriendly))
        .toList();

    final picked = await showModalBottomSheet<Recipe>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecipePickerSheet(kidRecipes: kid, otherRecipes: rest),
    );

    if (picked != null) _setMeal(dayIndex, mealType, picked.id);
  }

  String _weekLabel() {
    final end = _weekStart.add(const Duration(days: 6));
    if (_weekStart.month == end.month) {
      return '${_weekStart.day}–${end.day} ${_months[end.month - 1]} ${end.year}';
    }
    return '${_weekStart.day} ${_months[_weekStart.month - 1]} – ${end.day} ${_months[end.month - 1]} ${end.year}';
  }

  bool _isToday(int dayIndex) {
    final d = _dayDate(dayIndex);
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.surface,
      appBar: AppBar(
        title: const Text('Kids Meal Planner',
            style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: isDark ? AppColors.darkBg : AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(
                () => _weekStart = _weekStart.subtract(const Duration(days: 7))),
            tooltip: 'Previous week',
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(
                () => _weekStart = _weekStart.add(const Duration(days: 7))),
            tooltip: 'Next week',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Week label
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(
              _weekLabel(),
              style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkInkMuted : AppColors.inkMuted),
            ),
          ),

          // Day selector
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 7,
              itemBuilder: (_, i) {
                final isSelected = _selectedDay == i;
                final isToday = _isToday(i);
                final hasMeals = _hasMealsOnDay(i);
                final date = _dayDate(i);

                return GestureDetector(
                  onTap: () => setState(() => _selectedDay = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : (isDark ? AppColors.darkCard : AppColors.card),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : isToday
                                ? AppColors.primary.withValues(alpha: 0.6)
                                : (isDark ? AppColors.darkBorder : AppColors.border),
                        width: isToday && !isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _days[i],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? AppColors.darkInk : AppColors.ink),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected
                                ? Colors.white70
                                : (isDark ? AppColors.darkInkMuted : AppColors.inkMuted),
                          ),
                        ),
                        if (hasMeals && !isSelected)
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 6),

          // Day header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Text(
              '${_daysFull[_selectedDay]}, ${_months[_dayDate(_selectedDay).month - 1]} ${_dayDate(_selectedDay).day}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkInk : AppColors.ink,
              ),
            ),
          ),

          // Meal slots
          Expanded(
            child: BlocBuilder<RecipeBloc, RecipeState>(
              builder: (context, state) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  children: _meals.map((m) {
                        final recipe = _findRecipe(_getMeal(_selectedDay, m.$1));
                        return _MealSlot(
                          mealType: m.$1,
                          mealEmoji: m.$2,
                          mealLabel: m.$3,
                          recipe: recipe,
                          isDark: isDark,
                          onTap: () => _pickMeal(_selectedDay, m.$1),
                          onClear: () => _setMeal(_selectedDay, m.$1, null),
                          onViewDetail: recipe == null
                              ? null
                              : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          RecipeDetailPage(recipe: recipe),
                                    ),
                                  ),
                        );
                      }).toList(),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ElevatedButton.icon(
            onPressed: _autoFillWeek,
            icon: const Text('🎲', style: TextStyle(fontSize: 18)),
            label: const Text('Auto-fill empty slots',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Meal slot card ────────────────────────────────────────────────────────────

class _MealSlot extends StatelessWidget {
  final String mealType;
  final String mealEmoji;
  final String mealLabel;
  final Recipe? recipe;
  final bool isDark;
  final VoidCallback onTap;       // opens picker (empty slot)
  final VoidCallback onClear;
  final VoidCallback? onViewDetail; // opens detail (filled slot)

  const _MealSlot({
    required this.mealType,
    required this.mealEmoji,
    required this.mealLabel,
    required this.recipe,
    required this.isDark,
    required this.onTap,
    required this.onClear,
    this.onViewDetail,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(mealEmoji, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 5),
              Text(
                mealLabel.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: isDark ? AppColors.darkInkMuted : AppColors.inkMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: recipe != null ? onViewDetail : onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: recipe != null
                    ? (isDark
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : AppColors.primarySurface)
                    : (isDark ? AppColors.darkCard : AppColors.card),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: recipe != null
                      ? AppColors.primary.withValues(alpha: 0.35)
                      : (isDark ? AppColors.darkBorder : AppColors.border),
                ),
              ),
              child: recipe != null ? _filledSlot(context) : _emptySlot(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filledSlot(BuildContext context) {
    final emoji = foodEmoji(recipe!.name, FoodCategory.other);
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 24)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                recipe!.name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${recipe!.timeLabel} · ${recipe!.servings} serves',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkInkMuted : AppColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: onClear,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(Icons.close,
                size: 18,
                color: isDark ? AppColors.darkInkMuted : AppColors.inkMuted),
          ),
        ),
      ],
    );
  }

  Widget _emptySlot() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBorder : AppColors.border,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.add,
              color: isDark ? AppColors.darkInkMuted : AppColors.inkMuted,
              size: 22),
        ),
        const SizedBox(width: 12),
        Text(
          'Tap to add a meal',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.darkInkMuted : AppColors.inkMuted,
          ),
        ),
      ],
    );
  }
}

// ── Recipe picker bottom sheet ────────────────────────────────────────────────

class _RecipePickerSheet extends StatefulWidget {
  final List<Recipe> kidRecipes;
  final List<Recipe> otherRecipes;

  const _RecipePickerSheet(
      {required this.kidRecipes, required this.otherRecipes});

  @override
  State<_RecipePickerSheet> createState() => _RecipePickerSheetState();
}

class _RecipePickerSheetState extends State<_RecipePickerSheet> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final list = _showAll
        ? [...widget.kidRecipes, ...widget.otherRecipes]
        : (widget.kidRecipes.isNotEmpty
            ? widget.kidRecipes
            : widget.otherRecipes);

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBorder : AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 12, 4),
            child: Row(
              children: [
                Text(
                  'Choose a recipe',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkInk : AppColors.ink,
                  ),
                ),
                const Spacer(),
                if (widget.otherRecipes.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => _showAll = !_showAll),
                    child: Text(
                      _showAll ? 'Kid-friendly only' : 'Show all',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.primary),
                    ),
                  ),
              ],
            ),
          ),
          // Kid-friendly badge row
          if (!_showAll && widget.kidRecipes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '👶 Kid-friendly recipes',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: list.length,
              itemBuilder: (ctx, i) {
                final recipe = list[i];
                final isKid =
                    recipe.dietaryTags.contains(DietaryTag.kidFriendly);
                final emoji = foodEmoji(recipe.name, FoodCategory.other);

                return GestureDetector(
                  onTap: () => Navigator.pop(ctx, recipe),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBg : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkCard
                                : AppColors.card,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(emoji,
                                style: const TextStyle(fontSize: 22)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      recipe.name,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? AppColors.darkInk
                                            : AppColors.ink,
                                      ),
                                    ),
                                  ),
                                  if (isKid && _showAll)
                                    Container(
                                      margin: const EdgeInsets.only(left: 6),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primarySurface,
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: const Text('👶',
                                          style: TextStyle(fontSize: 11)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${recipe.timeLabel} · ${recipe.servings} serves',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.darkInkMuted
                                      : AppColors.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios,
                            size: 14,
                            color: isDark
                                ? AppColors.darkInkMuted
                                : AppColors.inkLight),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

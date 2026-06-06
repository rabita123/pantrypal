import 'package:flutter/material.dart';
import 'package:pantrypal/core/theme/app_theme.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/recipes/domain/entities/recipe.dart';
import 'package:uuid/uuid.dart';

class AddRecipePage extends StatefulWidget {
  final Recipe? existing;
  const AddRecipePage({super.key, this.existing});

  @override
  State<AddRecipePage> createState() => _AddRecipePageState();
}

class _AddRecipePageState extends State<AddRecipePage> {
  static const _uuid = Uuid();

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  int _servings = 4;
  int _prepMin = 15;
  int _cookMin = 30;
  Cuisine _cuisine = Cuisine.other;
  final Set<DietaryTag> _dietary = {};
  final List<_IngRow> _ingredients = [];
  final List<TextEditingController> _stepCtrls = [];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _descCtrl.text = e.description ?? '';
      _servings = e.servings;
      _prepMin = e.prepMinutes;
      _cookMin = e.cookMinutes;
      _cuisine = e.cuisine;
      _dietary.addAll(e.dietaryTags);
      for (final ing in e.ingredients) {
        _ingredients.add(_IngRow(
          nameCtrl: TextEditingController(text: ing.name),
          qtyCtrl: TextEditingController(text: ing.quantity.toStringAsFixed(
            ing.quantity % 1 == 0 ? 0 : 1,
          )),
          unit: ing.unit,
          category: ing.category,
        ));
      }
      for (final step in e.steps) {
        _stepCtrls.add(TextEditingController(text: step));
      }
    }
    if (_ingredients.isEmpty) _addIngredient();
    if (_stepCtrls.isEmpty) _stepCtrls.add(TextEditingController());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    for (final r in _ingredients) {
      r.nameCtrl.dispose();
      r.qtyCtrl.dispose();
    }
    for (final c in _stepCtrls) { c.dispose(); }
    super.dispose();
  }

  void _addIngredient() {
    setState(() => _ingredients.add(_IngRow(
          nameCtrl: TextEditingController(),
          qtyCtrl: TextEditingController(),
          unit: 'item',
          category: FoodCategory.other,
        )));
  }

  Recipe _buildRecipe() {
    final ingredients = _ingredients
        .where((r) => r.nameCtrl.text.trim().isNotEmpty)
        .map((r) => RecipeIngredient(
              name: r.nameCtrl.text.trim(),
              quantity: double.tryParse(r.qtyCtrl.text) ?? 1.0,
              unit: r.unit,
              category: r.category,
            ))
        .toList();

    final steps = _stepCtrls
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return Recipe(
      id: widget.existing?.id ?? _uuid.v4(),
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      servings: _servings,
      prepMinutes: _prepMin,
      cookMinutes: _cookMin,
      ingredients: ingredients,
      steps: steps,
      dietaryTags: Set.from(_dietary),
      cuisine: _cuisine,
      isFavorite: widget.existing?.isFavorite ?? false,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEdit = widget.existing != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Recipe' : 'New Recipe'),
        actions: [
          TextButton(
            onPressed: () {
              if (_nameCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a recipe name')),
                );
                return;
              }
              Navigator.pop(context, _buildRecipe());
            },
            child: Text(
              isEdit ? 'Save' : 'Add',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          // Name
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Recipe name *',
              prefixIcon: Icon(Icons.menu_book_outlined),
            ),
          ),
          const SizedBox(height: 12),

          // Description
          TextField(
            controller: _descCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
          const SizedBox(height: 16),

          // Servings + Times
          _sectionLabel('Details'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _intField('Servings', _servings, (v) => setState(() => _servings = v), min: 1)),
            const SizedBox(width: 10),
            Expanded(child: _intField('Prep (min)', _prepMin, (v) => setState(() => _prepMin = v))),
            const SizedBox(width: 10),
            Expanded(child: _intField('Cook (min)', _cookMin, (v) => setState(() => _cookMin = v))),
          ]),
          const SizedBox(height: 16),

          // Cuisine
          _sectionLabel('Cuisine'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: Cuisine.values.map((c) {
              final sel = c == _cuisine;
              return GestureDetector(
                onTap: () => setState(() => _cuisine = c),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary : (isDark ? AppColors.darkCard : AppColors.card),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? AppColors.primary : AppColors.border),
                  ),
                  child: Text(
                    '${c.emoji} ${c.label}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      color: sel ? Colors.white : AppColors.inkMuted,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Dietary tags
          _sectionLabel('Dietary tags'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: DietaryTag.values.map((t) {
              final sel = _dietary.contains(t);
              return GestureDetector(
                onTap: () => setState(() => sel ? _dietary.remove(t) : _dietary.add(t)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primarySurface : (isDark ? AppColors.darkCard : AppColors.card),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? AppColors.primary : AppColors.border),
                  ),
                  child: Text(
                    '${t.emoji} ${t.label}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      color: sel ? AppColors.primary : AppColors.inkMuted,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Ingredients
          Row(
            children: [
              _sectionLabel('Ingredients'),
              const Spacer(),
              TextButton.icon(
                onPressed: _addIngredient,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ..._ingredients.asMap().entries.map((e) => _IngredientRow(
                key: ValueKey(e.key),
                row: e.value,
                isDark: isDark,
                onRemove: _ingredients.length > 1
                    ? () => setState(() => _ingredients.removeAt(e.key))
                    : null,
                onChanged: () => setState(() {}),
              )),
          const SizedBox(height: 16),

          // Steps
          Row(
            children: [
              _sectionLabel('Instructions'),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => _stepCtrls.add(TextEditingController())),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add step'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ..._stepCtrls.asMap().entries.map((e) => Padding(
                key: ValueKey(e.key),
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.only(top: 12),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${e.key + 1}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: e.value,
                        maxLines: 3,
                        minLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Step ${e.key + 1}…',
                          suffixIcon: _stepCtrls.length > 1
                              ? IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, size: 18, color: AppColors.expired),
                                  onPressed: () => setState(() {
                                    e.value.dispose();
                                    _stepCtrls.removeAt(e.key);
                                  }),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.inkMuted),
      );

  Widget _intField(String label, int value, ValueChanged<int> onChanged, {int min = 0}) {
    final ctrl = TextEditingController(text: '$value');
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      onChanged: (v) {
        final parsed = int.tryParse(v);
        if (parsed != null && parsed >= min) onChanged(parsed);
      },
    );
  }
}

// ── Ingredient row data ────────────────────────────────────────────────────

class _IngRow {
  final TextEditingController nameCtrl;
  final TextEditingController qtyCtrl;
  String unit;
  FoodCategory category;

  _IngRow({
    required this.nameCtrl,
    required this.qtyCtrl,
    required this.unit,
    required this.category,
  });
}

// ── Ingredient row widget ──────────────────────────────────────────────────

class _IngredientRow extends StatelessWidget {
  final _IngRow row;
  final bool isDark;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;

  static const _units = ['item', 'pcs', 'g', 'kg', 'ml', 'L', 'cup', 'tbsp', 'tsp', 'oz', 'lb', 'piece', 'pack', 'bunch', 'slice', 'can', 'bottle', 'box', 'bag'];

  const _IngredientRow({
    super.key,
    required this.row,
    required this.isDark,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Category emoji picker
              GestureDetector(
                onTap: () => _pickCategory(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(row.category.emoji, style: const TextStyle(fontSize: 20)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Name
              Expanded(
                flex: 3,
                child: TextField(
                  controller: row.nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Ingredient',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Quantity
              SizedBox(
                width: 56,
                child: TextField(
                  controller: row.qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    hintText: 'Qty',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Unit
              DropdownButton<String>(
                value: _units.contains(row.unit) ? row.unit : 'item',
                underline: const SizedBox.shrink(),
                isDense: true,
                items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) {
                  if (v != null) {
                    row.unit = v;
                    onChanged();
                  }
                },
              ),
              if (onRemove != null)
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 18, color: AppColors.expired),
                  onPressed: onRemove,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _pickCategory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => GridView.count(
        crossAxisCount: 5,
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        children: FoodCategory.values.map((cat) => GestureDetector(
          onTap: () {
            row.category = cat;
            onChanged();
            Navigator.pop(context);
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(cat.emoji, style: const TextStyle(fontSize: 28)),
              Text(cat.label, style: const TextStyle(fontSize: 9), textAlign: TextAlign.center, maxLines: 2),
            ],
          ),
        )).toList(),
      ),
    );
  }
}

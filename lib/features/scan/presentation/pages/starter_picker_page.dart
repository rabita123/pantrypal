import 'package:flutter/material.dart';
import 'package:pantrypal/core/constants/starter_foods.dart';
import 'package:pantrypal/core/theme/app_theme.dart';

/// Zero-typing way to fill a kitchen: tap the things you have. Each food
/// arrives with a realistic shelf life and storage place.
class StarterPickerPage extends StatefulWidget {
  final String actionLabel;
  const StarterPickerPage({super.key, this.actionLabel = 'Add'});

  @override
  State<StarterPickerPage> createState() => _StarterPickerPageState();
}

class _StarterPickerPageState extends State<StarterPickerPage> {
  final _selected = <StarterFood>{};

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final n = _selected.length;

    return Scaffold(
      appBar: AppBar(title: const Text('What do you have?')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Tap everything that\'s in your kitchen right now. We\'ll guess how long each lasts.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: isDark ? AppColors.darkInkMuted : AppColors.inkMuted,
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in starterFoods)
                    _FoodChip(
                      food: f,
                      selected: _selected.contains(f),
                      isDark: isDark,
                      onTap: () => setState(() {
                        _selected.contains(f) ? _selected.remove(f) : _selected.add(f);
                      }),
                    ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: n == 0 ? null : () => Navigator.pop(context, _selected.toList()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.35),
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    n == 0 ? 'Tap foods to add' : '${widget.actionLabel} $n item${n == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodChip extends StatelessWidget {
  final StarterFood food;
  final bool selected, isDark;
  final VoidCallback onTap;
  const _FoodChip({required this.food, required this.selected, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySurface : (isDark ? AppColors.darkCard : AppColors.card),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.border),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(food.emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text(
              food.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? AppColors.primaryDark : (isDark ? AppColors.darkInk : AppColors.ink),
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check_circle, size: 16, color: AppColors.primary),
            ],
          ],
        ),
      ),
    );
  }
}

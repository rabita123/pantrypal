import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pantrypal/core/constants/starter_foods.dart';
import 'package:pantrypal/core/theme/app_theme.dart';
import 'package:pantrypal/core/utils/food_emoji.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';

/// What the scan found, ready to confirm in one glance.
///
/// Items the AI was sure about are ticked; items it was unsure about are
/// UNticked and marked "check" — nothing doubtful is ever added silently.
/// Any row can be fixed in two taps, or swiped away.
class ScanResultsView extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final Set<int> selected;
  final String? imagePath;
  final bool offline;
  final void Function(int index) onToggle;
  final void Function(int index, Map<String, dynamic> changes) onEdit;
  final void Function(int index) onRemove;
  final VoidCallback onAdd;
  final VoidCallback onRescan;

  const ScanResultsView({
    super.key,
    required this.items,
    required this.selected,
    required this.onToggle,
    required this.onEdit,
    required this.onRemove,
    required this.onAdd,
    required this.onRescan,
    this.imagePath,
    this.offline = false,
  });

  bool _unsure(Map<String, dynamic> m) => m['confidence'] == 'low';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.darkInk : AppColors.ink;
    final muted = isDark ? AppColors.darkInkMuted : AppColors.inkMuted;

    final sure = <int>[for (var i = 0; i < items.length; i++) if (!_unsure(items[i])) i];
    final unsure = <int>[for (var i = 0; i < items.length; i++) if (_unsure(items[i])) i];
    final n = items.length;
    final count = selected.length;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Row(
                children: [
                  if (imagePath != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(File(imagePath!),
                          width: 56, height: 56, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(width: 56, height: 56)),
                    ),
                  if (imagePath != null) const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TweenAnimationBuilder<int>(
                          tween: IntTween(begin: 0, end: n),
                          duration: const Duration(milliseconds: 420),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, __) => Text(
                            '$v ${n == 1 ? 'item' : 'items'} detected',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: ink, letterSpacing: -0.4),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text('Tap to deselect · swipe to remove',
                            style: TextStyle(fontSize: 13, color: muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (offline)
              _Banner(
                icon: Icons.wifi_off,
                text: 'Offline — read on this phone, so it may be less exact. Fix anything that looks off.',
                color: AppColors.expiringSoon,
              ),
            if (unsure.isNotEmpty)
              _Banner(
                icon: Icons.help_outline,
                text: unsure.length == 1
                    ? '1 item needs a quick check. It is unticked until you confirm it.'
                    : '${unsure.length} items need a quick check. They are unticked until you confirm them.',
                color: AppColors.expiringSoon,
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                children: [
                  if (unsure.isNotEmpty) ...[
                    _Section(label: 'Please check · ${unsure.length}', color: AppColors.expiringSoon),
                    for (var k = 0; k < unsure.length; k++) _row(context, unsure[k], k, isDark),
                  ],
                  if (sure.isNotEmpty) ...[
                    _Section(label: 'Looks right · ${sure.length}', color: muted),
                    for (var k = 0; k < sure.length; k++) _row(context, sure[k], k + unsure.length, isDark),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBg : AppColors.surface,
                border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border)),
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: onRescan,
                    style: TextButton.styleFrom(foregroundColor: muted),
                    child: const Text('Rescan', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: count == 0
                            ? null
                            : () {
                                HapticFeedback.mediumImpact();
                                onAdd();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.35),
                          disabledForegroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          count == 0 ? 'Select items to add' : 'Add $count ${count == 1 ? 'item' : 'items'}',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, int index, int order, bool isDark) {
    final m = items[index];
    return _ResultRow(
      key: ValueKey(m['id'] ?? '$index-${m['name']}'),
      item: m,
      selected: selected.contains(index),
      unsure: _unsure(m),
      order: order,
      isDark: isDark,
      onToggle: () {
        HapticFeedback.selectionClick();
        onToggle(index);
      },
      onEdit: () async {
        final changes = await ScanItemEditSheet.show(context, m);
        if (changes != null) onEdit(index, changes);
      },
      onRemove: () => onRemove(index),
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _Banner({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.expiringSoonSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, color: color, height: 1.4, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  final Color color;
  const _Section({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
        child: Text(label.toUpperCase(),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: color)),
      );
}

class _ResultRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool selected, unsure, isDark;
  final int order;
  final VoidCallback onToggle, onEdit, onRemove;
  const _ResultRow({
    super.key,
    required this.item,
    required this.selected,
    required this.unsure,
    required this.isDark,
    required this.order,
    required this.onToggle,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final cat = item['category'] as FoodCategory;
    final name = item['name'] as String;
    final qty = (item['quantity'] as double?) ?? 1.0;
    final days = (item['estimatedExpiryDays'] as int?) ?? 7;
    final price = item['price'] as double?;
    final ink = isDark ? AppColors.darkInk : AppColors.ink;
    final muted = isDark ? AppColors.darkInkMuted : AppColors.inkMuted;

    final qtyText = qty == 1 ? '' : '×${qty == qty.roundToDouble() ? qty.toInt() : qty} · ';
    final sub = '$qtyText~${_lasts(days)}${price != null ? ' · \$${price.toStringAsFixed(2)}' : ''}';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + (order * 28).clamp(0, 280)),
      curve: Curves.easeOutCubic,
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 10 * (1 - t)), child: child),
      ),
      child: Dismissible(
        key: ValueKey('dismiss-${item['id'] ?? name}'),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => onRemove(),
        background: Container(
          margin: const EdgeInsets.only(bottom: 8),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(color: AppColors.expired, borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.delete_outline, color: Colors.white),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : unsure
                      ? AppColors.expiringSoon.withValues(alpha: 0.5)
                      : (isDark ? AppColors.darkBorder : AppColors.border),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                child: Row(
                  children: [
                    _Check(selected: selected, unsure: unsure),
                    const SizedBox(width: 12),
                    Text(foodEmoji(name, cat), style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: selected ? ink : muted,
                              )),
                          const SizedBox(height: 1),
                          Text(unsure && !selected ? 'Not sure — is this right?' : sub,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: unsure && !selected ? AppColors.expiringSoon : muted,
                                fontWeight: unsure && !selected ? FontWeight.w600 : FontWeight.w400,
                              )),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: onEdit,
                      icon: Icon(Icons.edit_outlined, size: 20, color: muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _lasts(int d) {
    if (d < 14) return '$d ${d == 1 ? 'day' : 'days'}';
    if (d < 60) return '${(d / 7).round()} weeks';
    if (d < 365) return '${(d / 30).round()} months';
    return '1 year';
  }
}

class _Check extends StatelessWidget {
  final bool selected, unsure;
  const _Check({required this.selected, required this.unsure});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.primary : Colors.transparent,
        border: Border.all(
          color: selected ? AppColors.primary : (unsure ? AppColors.expiringSoon : AppColors.inkLight),
          width: 1.8,
        ),
      ),
      child: selected
          ? const Icon(Icons.check, size: 15, color: Colors.white)
          : unsure
              ? const Center(child: Text('?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.expiringSoon)))
              : null,
    );
  }
}

// ── Quick edit ────────────────────────────────────────────────────────────────

/// Fix a result in two taps: retype the name (with suggestions), nudge the
/// quantity, pick how long it lasts. Returns the changes, or null if dismissed.
class ScanItemEditSheet extends StatefulWidget {
  final Map<String, dynamic> item;
  const ScanItemEditSheet({super.key, required this.item});

  static Future<Map<String, dynamic>?> show(BuildContext context, Map<String, dynamic> item) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScanItemEditSheet(item: item),
    );
  }

  @override
  State<ScanItemEditSheet> createState() => _ScanItemEditSheetState();
}

class _ScanItemEditSheetState extends State<ScanItemEditSheet> {
  late final TextEditingController _name;
  late double _qty;
  late int _days;
  late FoodCategory _category;

  static const _lifespans = [
    (2, '2 days'), (3, '3 days'), (5, '5 days'), (7, '1 week'),
    (14, '2 weeks'), (30, '1 month'), (90, '3 months'), (365, '1 year'),
  ];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.item['name'] as String);
    _qty = (widget.item['quantity'] as double?) ?? 1;
    _days = (widget.item['estimatedExpiryDays'] as int?) ?? 7;
    _category = widget.item['category'] as FoodCategory;
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  List<StarterFood> get _suggestions {
    final q = _name.text.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return starterFoods
        .where((f) => f.name.toLowerCase().contains(q) && f.name.toLowerCase() != q)
        .take(5)
        .toList();
  }

  void _pick(StarterFood f) {
    _name.text = f.name;
    _name.selection = TextSelection.collapsed(offset: f.name.length);
    setState(() {
      _category = f.category;
      _days = f.shelfDays;
    });
  }

  void _save() {
    final name = _name.text.trim();
    Navigator.pop(context, {
      'name': name.isEmpty ? widget.item['name'] : name,
      'quantity': _qty,
      'estimatedExpiryDays': _days,
      'category': _category,
      // The user has looked at it, so it is no longer a guess.
      'confidence': 'high',
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.darkInk : AppColors.ink;
    final muted = isDark ? AppColors.darkInkMuted : AppColors.inkMuted;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: isDark ? AppColors.darkBorder : AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text('What is it?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: ink)),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                decoration: const InputDecoration(hintText: 'Item name'),
              ),
              if (_suggestions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final f in _suggestions)
                      ActionChip(
                        label: Text('${f.emoji} ${f.name}', style: const TextStyle(fontSize: 12.5)),
                        onPressed: () => _pick(f),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Text('Quantity', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: muted)),
                  const Spacer(),
                  IconButton.outlined(
                    onPressed: _qty > 1 ? () => setState(() => _qty -= 1) : null,
                    icon: const Icon(Icons.remove, size: 18),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      _qty == _qty.roundToDouble() ? '${_qty.toInt()}' : '$_qty',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ink),
                    ),
                  ),
                  IconButton.outlined(
                    onPressed: _qty < 99 ? () => setState(() => _qty += 1) : null,
                    icon: const Icon(Icons.add, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Lasts about', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: muted)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final l in _lifespans)
                    ChoiceChip(
                      label: Text(l.$2),
                      selected: _days == l.$1,
                      selectedColor: AppColors.primarySurface,
                      onSelected: (_) => setState(() => _days = l.$1),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Done', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

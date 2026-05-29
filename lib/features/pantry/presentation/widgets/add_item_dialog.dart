import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pantrypal/core/constants/app_constants.dart';
import 'package:pantrypal/core/theme/app_theme.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:uuid/uuid.dart';

class AddItemDialog extends StatefulWidget {
  final PantryItem? existing;
  const AddItemDialog({super.key, this.existing});

  @override
  State<AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<AddItemDialog> {
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  static const _uuid = Uuid();

  FoodCategory _category = FoodCategory.other;
  StorageLocation _location = StorageLocation.fridge;
  String _unit = 'item';
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 7));

  final List<String> _units = ['item', 'kg', 'g', 'lb', 'oz', 'L', 'ml', 'pack', 'box', 'can', 'bottle', 'bunch'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _qtyCtrl.text = e.quantity.toString();
      _priceCtrl.text = e.price?.toString() ?? '';
      _notesCtrl.text = e.notes ?? '';
      _category = e.category;
      _location = e.location;
      _unit = e.unit;
      _expiryDate = e.expiryDate;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  PantryItem _buildItem() {
    final existing = widget.existing;
    final defaultDays = AppConstants.defaultShelfLife[_category.name] ?? 14;
    return PantryItem(
      id: existing?.id ?? _uuid.v4(),
      name: _nameCtrl.text.trim(),
      category: _category,
      location: _location,
      quantity: double.tryParse(_qtyCtrl.text) ?? 1.0,
      unit: _unit,
      expiryDate: _expiryDate,
      addedDate: existing?.addedDate ?? DateTime.now(),
      price: double.tryParse(_priceCtrl.text),
      notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
      isConsumed: false,
      isWasted: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEdit = widget.existing != null;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      minChildSize: 0.6,
      expand: false,
      builder: (context, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBg : AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Text(
                    isEdit ? 'Edit item' : 'Add item',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.darkInk : AppColors.ink,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      if (_nameCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter an item name')),
                        );
                        return;
                      }
                      Navigator.pop(context, _buildItem());
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
            ),
            const Divider(height: 16),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  // Name
                  TextField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Item name *',
                      prefixIcon: Icon(Icons.edit_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Qty + Unit
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _qtyCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Quantity'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          value: _unit,
                          decoration: const InputDecoration(labelText: 'Unit'),
                          items: _units
                              .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                              .toList(),
                          onChanged: (v) => setState(() => _unit = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Category
                  _SectionLabel('Category'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: FoodCategory.values.map((cat) {
                      final selected = cat == _category;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _category = cat;
                            if (widget.existing == null) {
                              final days = AppConstants.defaultShelfLife[cat.name] ?? 14;
                              _expiryDate = DateTime.now().add(Duration(days: days));
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? Color(cat.colorValue).withOpacity(0.15)
                                : (isDark ? AppColors.darkCard : AppColors.card),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? Color(cat.colorValue)
                                  : AppColors.border,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(cat.emoji, style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 5),
                              Text(
                                cat.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                  color: selected
                                      ? Color(cat.colorValue)
                                      : AppColors.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Location
                  _SectionLabel('Storage location'),
                  const SizedBox(height: 8),
                  Row(
                    children: StorageLocation.values.map((loc) {
                      final selected = loc == _location;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _location = loc),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: selected ? AppColors.primarySurface : (isDark ? AppColors.darkCard : AppColors.card),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected ? AppColors.primary : AppColors.border,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(loc.emoji, style: const TextStyle(fontSize: 18)),
                                const SizedBox(height: 4),
                                Text(
                                  loc.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                    color: selected ? AppColors.primary : AppColors.inkMuted,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Expiry date
                  _SectionLabel('Expiry date'),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _expiryDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (picked != null) setState(() => _expiryDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 20, color: AppColors.primary),
                          const SizedBox(width: 12),
                          Text(
                            DateFormat('MMM d, yyyy').format(_expiryDate),
                            style: TextStyle(
                              fontSize: 15,
                              color: isDark ? AppColors.darkInk : AppColors.ink,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_expiryDate.difference(DateTime.now()).inDays} days',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Price
                  TextField(
                    controller: _priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Price (optional)',
                      prefixIcon: Icon(Icons.attach_money_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Notes
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      prefixIcon: Icon(Icons.notes_outlined),
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
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.inkMuted,
      ),
    );
  }
}

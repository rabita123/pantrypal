import 'package:flutter/material.dart';
import 'package:pantrypal/core/theme/app_theme.dart';

enum AddKind { receipt, fridge, barcode, tap, typed, manual }

class AddChoice {
  final AddKind kind;
  final String text;
  const AddChoice(this.kind, [this.text = '']);
}

/// The single "add food" surface, ordered by how little effort each way takes.
class AddFoodSheet extends StatefulWidget {
  const AddFoodSheet({super.key});

  static Future<AddChoice?> show(BuildContext context) {
    return showModalBottomSheet<AddChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddFoodSheet(),
    );
  }

  @override
  State<AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends State<AddFoodSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submitTyped() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    Navigator.pop(context, AddChoice(AddKind.typed, text));
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Add food', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: ink)),
              const SizedBox(height: 12),

              // Primary: one photo adds a whole shop.
              GestureDetector(
                onTap: () => Navigator.pop(context, const AddChoice(AddKind.receipt)),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.document_scanner_outlined, color: Colors.white, size: 30),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Scan a receipt',
                                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text('A whole shop added in about 10 seconds',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _SmallOption(
                      icon: Icons.kitchen_outlined,
                      label: 'Fridge photo',
                      isDark: isDark,
                      onTap: () => Navigator.pop(context, const AddChoice(AddKind.fridge)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SmallOption(
                      icon: Icons.qr_code_scanner,
                      label: 'Barcode',
                      isDark: isDark,
                      onTap: () => Navigator.pop(context, const AddChoice(AddKind.barcode)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SmallOption(
                      icon: Icons.touch_app_outlined,
                      label: 'Tap foods',
                      isDark: isDark,
                      onTap: () => Navigator.pop(context, const AddChoice(AddKind.tap)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Or just type it', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: muted)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submitTyped(),
                      decoration: const InputDecoration(
                        hintText: 'milk, 2 eggs, spinach…',
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _submitTyped,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18)),
                      child: const Text('Add'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'We pick the category, where it lives and how long it lasts.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context, const AddChoice(AddKind.manual)),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Enter every detail yourself'),
                  style: TextButton.styleFrom(foregroundColor: muted, padding: EdgeInsets.zero),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;
  const _SmallOption({required this.icon, required this.label, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? AppColors.darkBg : AppColors.primarySurface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary, size: 24),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkInk : AppColors.primaryDark,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

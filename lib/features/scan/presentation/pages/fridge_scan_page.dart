import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:pantrypal/core/theme/app_theme.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/pantry/presentation/bloc/pantry_bloc.dart';
import 'package:pantrypal/features/scan/data/fridge_scan_service.dart';

enum _FridgeScanStatus { idle, loading, review, error }

class FridgeScanPage extends StatefulWidget {
  const FridgeScanPage({super.key});

  @override
  State<FridgeScanPage> createState() => _FridgeScanPageState();
}

class _FridgeScanPageState extends State<FridgeScanPage> {
  _FridgeScanStatus _status = _FridgeScanStatus.idle;
  List<Map<String, dynamic>> _items = [];
  final Set<int> _selected = {};
  String _errorMessage = '';
  static const _uuid = Uuid();

  Future<void> _pickAndScan(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 1600,
    );
    if (picked == null || !mounted) return;

    setState(() {
      _status = _FridgeScanStatus.loading;
      _items = [];
      _selected.clear();
    });

    try {
      final items = await FridgeScanService.analyzeImage(picked.path);
      if (!mounted) return;
      if (items.isEmpty) {
        setState(() {
          _status = _FridgeScanStatus.error;
          _errorMessage = 'No food items detected. Try a clearer photo with the fridge fully open.';
        });
        return;
      }
      setState(() {
        _status = _FridgeScanStatus.review;
        _items = items;
        _selected.addAll(List.generate(items.length, (i) => i));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _FridgeScanStatus.error;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _addSelected() {
    final now = DateTime.now();
    final pantryItems = _selected.map((i) {
      final m = _items[i];
      final days = (m['estimatedExpiryDays'] as int?) ?? 7;
      return PantryItem(
        id: _uuid.v4(),
        name: m['name'] as String,
        category: m['category'] as FoodCategory,
        location: StorageLocation.fridge,
        quantity: (m['quantity'] as double?) ?? 1.0,
        unit: (m['unit'] as String?) ?? 'item',
        expiryDate: now.add(Duration(days: days)),
        addedDate: now,
        isConsumed: false,
        isWasted: false,
      );
    }).toList();

    context.read<PantryBloc>().add(PantryAddItems(pantryItems));
    Navigator.pop(context, true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${pantryItems.length} item${pantryItems.length == 1 ? '' : 's'} added from fridge scan 🎉'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.surface,
      appBar: AppBar(
        title: const Text('Scan Fridge'),
        backgroundColor: isDark ? AppColors.darkBg : AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: _status == _FridgeScanStatus.review
            ? [
                TextButton(
                  onPressed: _selected.isEmpty ? null : _addSelected,
                  child: Text(
                    'Add ${_selected.length}',
                    style: TextStyle(
                      color: _selected.isEmpty ? AppColors.inkLight : AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ]
            : null,
      ),
      body: switch (_status) {
        _FridgeScanStatus.idle => _IdleView(onPick: _pickAndScan, isDark: isDark),
        _FridgeScanStatus.loading => const _LoadingView(),
        _FridgeScanStatus.review => _ReviewView(
            items: _items,
            selected: _selected,
            isDark: isDark,
            onToggle: (i) => setState(() {
              _selected.contains(i) ? _selected.remove(i) : _selected.add(i);
            }),
            onAdd: _selected.isEmpty ? null : _addSelected,
            onRescan: () => setState(() => _status = _FridgeScanStatus.idle),
          ),
        _FridgeScanStatus.error => _ErrorView(
            message: _errorMessage,
            onRetry: () => setState(() => _status = _FridgeScanStatus.idle),
            isDark: isDark,
          ),
      },
    );
  }
}

// ── Idle ──────────────────────────────────────────────────────────────────────

class _IdleView extends StatelessWidget {
  final Future<void> Function(ImageSource) onPick;
  final bool isDark;
  const _IdleView({required this.onPick, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: const Center(
                      child: Text('🧊', style: TextStyle(fontSize: 56)),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Scan your fridge',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.darkInk : AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Open your fridge, take one photo,\nand AI will detect everything inside.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: isDark ? AppColors.darkInkMuted : AppColors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const _Tip(emoji: '💡', text: 'Keep the fridge fully open and well-lit'),
                  const SizedBox(height: 10),
                  const _Tip(emoji: '📐', text: 'Step back so all shelves are visible'),
                  const SizedBox(height: 10),
                  const _Tip(emoji: '🚫', text: 'Avoid reflections on glass shelves'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => onPick(ImageSource.camera),
                icon: const Icon(Icons.camera_alt, size: 22),
                label: const Text('Take Fridge Photo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => onPick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined, size: 20),
                label: const Text('Pick from Gallery', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  final String emoji, text;
  const _Tip({required this.emoji, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(fontSize: 13, color: AppColors.inkMuted)),
      ],
    );
  }
}

// ── Loading ───────────────────────────────────────────────────────────────────

class _LoadingView extends StatefulWidget {
  const _LoadingView();

  @override
  State<_LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<_LoadingView> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  int _msgIndex = 0;

  static const _messages = [
    'Opening the fridge door… 🚪',
    'Scanning shelves… 👀',
    'Identifying food items… 🥦',
    'Checking expiry dates… 📅',
    'Almost done… ✨',
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    _rotateMsgs();
  }

  void _rotateMsgs() async {
    for (var i = 1; i < _messages.length; i++) {
      await Future.delayed(const Duration(milliseconds: 2200));
      if (!mounted) return;
      setState(() => _msgIndex = i);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 5,
            ),
          ),
          const SizedBox(height: 36),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Text(
              _messages[_msgIndex],
              key: ValueKey(_msgIndex),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.inkMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'AI is analysing your fridge',
            style: TextStyle(fontSize: 13, color: AppColors.inkLight),
          ),
        ],
      ),
    );
  }
}

// ── Review ────────────────────────────────────────────────────────────────────

class _ReviewView extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final Set<int> selected;
  final bool isDark;
  final void Function(int) onToggle;
  final VoidCallback? onAdd;
  final VoidCallback onRescan;

  const _ReviewView({
    required this.items,
    required this.selected,
    required this.isDark,
    required this.onToggle,
    required this.onAdd,
    required this.onRescan,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Text('🤖', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AI found ${items.length} items · Tap to deselect any you don\'t want',
                  style: const TextStyle(fontSize: 12, color: AppColors.primary, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: items.length,
            itemBuilder: (ctx, i) {
              final item = items[i];
              final isSelected = selected.contains(i);
              final cat = item['category'] as FoodCategory;
              final days = (item['estimatedExpiryDays'] as int?) ?? 7;

              return GestureDetector(
                onTap: () => onToggle(i),
                child: AnimatedOpacity(
                  opacity: isSelected ? 1.0 : 0.4,
                  duration: const Duration(milliseconds: 180),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : (isDark ? AppColors.darkBorder : AppColors.border),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(cat.emoji, style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['name'] as String,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppColors.darkInk : AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${cat.label} · ${days}d shelf life',
                                style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: isSelected ? AppColors.primary : AppColors.inkLight,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onRescan,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Rescan'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: onAdd,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: Text(
                      'Add ${selected.length} item${selected.length == 1 ? '' : 's'} to pantry',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Error ─────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final bool isDark;
  const _ErrorView({required this.message, required this.onRetry, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('😕', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 20),
            Text(
              'Could not scan fridge',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkInk : AppColors.ink,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.inkMuted, height: 1.5),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

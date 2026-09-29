import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pantrypal/core/utils/food_emoji.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/scan/data/ai_scan_client.dart';
import 'package:pantrypal/features/scan/presentation/widgets/scan_stage.dart';

/// The wait, designed: the photo with a scan beam, a status line that tells the
/// truth about what is happening, and items appearing as the AI finds them.
///
/// It adds no delay of its own — the caller swaps to the results the moment
/// the scan finishes.
class ScanningView extends StatefulWidget {
  final ScanKind kind;
  final String imagePath;
  final ScanPhase phase;
  final List<Map<String, dynamic>> items;
  final Size? imageSize;
  final VoidCallback onCancel;

  const ScanningView({
    super.key,
    required this.kind,
    required this.imagePath,
    required this.phase,
    required this.items,
    required this.onCancel,
    this.imageSize,
  });

  @override
  State<ScanningView> createState() => _ScanningViewState();
}

class _ScanningViewState extends State<ScanningView> {
  DateTime _lastTick = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void didUpdateWidget(ScanningView old) {
    super.didUpdateWidget(old);
    // A quiet tick as each batch of items lands, never more than ~6 a second.
    if (widget.items.length > old.items.length) {
      final now = DateTime.now();
      if (now.difference(_lastTick) > const Duration(milliseconds: 160)) {
        HapticFeedback.selectionClick();
        _lastTick = now;
      }
    }
  }

  String get _title {
    final n = widget.items.length;
    switch (widget.phase) {
      case ScanPhase.preparing:
        return 'Preparing your photo';
      case ScanPhase.analyzing:
        return widget.kind == ScanKind.fridge ? 'Looking through your fridge' : 'Reading your receipt';
      case ScanPhase.streaming:
      case ScanPhase.done:
        return '$n ${n == 1 ? 'item' : 'items'} found';
    }
  }

  String get _subtitle => switch (widget.phase) {
        ScanPhase.preparing => 'Getting it ready',
        ScanPhase.analyzing => 'This usually takes a few seconds',
        ScanPhase.streaming => 'Still looking…',
        ScanPhase.done => 'Almost there',
      };

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final shown = items.length > 12 ? items.sublist(items.length - 12) : items;
    final hidden = items.length - shown.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0C110D),
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: widget.onCancel,
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
                child: const Text('Cancel', style: TextStyle(fontSize: 16)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ScanStage(
                  imagePath: widget.imagePath,
                  imageSize: widget.imageSize,
                  items: items,
                  active: widget.phase != ScanPhase.done,
                ),
              ),
            ),
            const SizedBox(height: 18),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(anim),
                  child: child,
                ),
              ),
              child: Text(
                _title,
                key: ValueKey(_title),
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3),
              ),
            ),
            const SizedBox(height: 4),
            Text(_subtitle, style: const TextStyle(color: Colors.white54, fontSize: 14)),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 84, maxHeight: 112),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (hidden > 0) _Pill(label: '+$hidden more', dim: true),
                    for (final it in shown)
                      _Pill(
                        key: ValueKey(it['id'] ?? it['name']),
                        label: it['name'] as String,
                        emoji: foodEmoji(it['name'] as String, it['category'] as FoodCategory),
                        unsure: it['confidence'] == 'low',
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final String? emoji;
  final bool dim, unsure;
  const _Pill({super.key, required this.label, this.emoji, this.dim = false, this.unsure = false});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 8 * (1 - t)), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: dim ? 0.05 : 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: unsure ? const Color(0xFFFFC857).withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.14),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null) ...[Text(emoji!, style: const TextStyle(fontSize: 14)), const SizedBox(width: 6)],
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: dim ? 0.5 : 0.92),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// The photo being scanned, framed like a viewfinder: corner brackets, a slow
/// light beam sweeping over it, and — as the AI finds things — soft outlines
/// around them.
///
/// Everything here is decoration driven by REAL progress (`items` grows as the
/// AI reports). Nothing waits on the animation, and nothing is faked: a box
/// only appears where the AI actually located something.
class ScanStage extends StatefulWidget {
  final String imagePath;

  /// Pixel size of the analysed photo; keeps the frame the photo's own shape
  /// so boxes land where the AI saw the item.
  final Size? imageSize;

  /// Items found so far; ones with a `box` get an outline.
  final List<Map<String, dynamic>> items;

  /// Beam runs only while the AI is still working.
  final bool active;

  const ScanStage({
    super.key,
    required this.imagePath,
    required this.items,
    this.imageSize,
    this.active = true,
  });

  @override
  State<ScanStage> createState() => _ScanStageState();
}

class _ScanStageState extends State<ScanStage> with SingleTickerProviderStateMixin {
  late final AnimationController _beam;

  @override
  void initState() {
    super.initState();
    _beam = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBeam();
  }

  @override
  void didUpdateWidget(ScanStage old) {
    super.didUpdateWidget(old);
    _syncBeam();
  }

  void _syncBeam() {
    final reduce = MediaQuery.of(context).disableAnimations;
    if (widget.active && !reduce) {
      if (!_beam.isAnimating) _beam.repeat(reverse: true);
    } else {
      _beam.stop();
    }
  }

  @override
  void dispose() {
    _beam.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    final aspect = (widget.imageSize != null && widget.imageSize!.height > 0)
        ? widget.imageSize!.width / widget.imageSize!.height
        : 3 / 4;

    return LayoutBuilder(
      builder: (context, c) {
        var w = c.maxWidth;
        var h = w / aspect;
        if (h > c.maxHeight) {
          h = c.maxHeight;
          w = h * aspect;
        }
        final boxed = [
          for (final it in widget.items)
            if (it['box'] is List) it,
        ];

        return Center(
          child: SizedBox(
            width: w,
            height: h,
            child: RepaintBoundary(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(
                      File(widget.imagePath),
                      fit: BoxFit.fill,
                      errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF1B211C)),
                    ),
                    // Slight dim so outlines and the beam read on any photo.
                    ColoredBox(color: Colors.black.withValues(alpha: 0.16)),
                    for (var i = 0; i < boxed.length; i++)
                      _DetectionBox(
                        key: ValueKey(boxed[i]['id'] ?? i),
                        item: boxed[i],
                        width: w,
                        height: h,
                        showLabel: i >= boxed.length - 6,
                        animate: !reduce,
                      ),
                    AnimatedBuilder(
                      animation: _beam,
                      builder: (_, __) => CustomPaint(
                        painter: _StagePainter(
                          progress: Curves.easeInOut.transform(_beam.value),
                          beam: widget.active && !reduce,
                          pulse: reduce ? 1 : 0.7 + 0.3 * math.sin(_beam.value * math.pi),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StagePainter extends CustomPainter {
  final double progress;
  final bool beam;
  final double pulse;
  const _StagePainter({required this.progress, required this.beam, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    if (beam) {
      final y = size.height * progress;
      // Trailing light: fades up from the beam line.
      const trail = 90.0;
      final rect = Rect.fromLTWH(0, y - trail, size.width, trail);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(
            rect.bottomCenter,
            rect.topCenter,
            [Colors.white.withValues(alpha: 0.26), Colors.white.withValues(alpha: 0)],
          ),
      );
      // The beam itself: a thin bright line with a soft glow.
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.55)
          ..strokeWidth = 5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.95)
          ..strokeWidth = 1.2,
      );
    }

    // Viewfinder corners.
    final pen = Paint()
      ..color = Colors.white.withValues(alpha: 0.9 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    const inset = 12.0, len = 26.0;
    void corner(double x, double y, double dx, double dy) {
      canvas.drawLine(Offset(x, y + dy * len), Offset(x, y), pen);
      canvas.drawLine(Offset(x, y), Offset(x + dx * len, y), pen);
    }

    corner(inset, inset, 1, 1);
    corner(size.width - inset, inset, -1, 1);
    corner(inset, size.height - inset, 1, -1);
    corner(size.width - inset, size.height - inset, -1, -1);
  }

  @override
  bool shouldRepaint(_StagePainter old) =>
      old.progress != progress || old.beam != beam || old.pulse != pulse;
}

/// A soft outline that eases in around one detected item.
class _DetectionBox extends StatelessWidget {
  final Map<String, dynamic> item;
  final double width, height;
  final bool showLabel, animate;
  const _DetectionBox({
    super.key,
    required this.item,
    required this.width,
    required this.height,
    required this.showLabel,
    required this.animate,
  });

  @override
  Widget build(BuildContext context) {
    final b = (item['box'] as List).cast<double>();
    final left = b[0] * width, top = b[1] * height;
    final w = (b[2] - b[0]) * width, h = (b[3] - b[1]) * height;
    final low = item['confidence'] == 'low';
    final color = low ? const Color(0xFFFFC857) : Colors.white;
    final labelAbove = top > 26;

    return Positioned(
      left: left,
      top: top,
      width: w,
      height: h,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: animate ? 0 : 1, end: 1),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        builder: (_, t, child) => Opacity(
          opacity: t,
          child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: color.withValues(alpha: 0.92), width: 1.4),
                  color: color.withValues(alpha: 0.08),
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 12)],
                ),
              ),
            ),
            if (showLabel)
              Positioned(
                left: 0,
                top: labelAbove ? -24 : 4,
                child: _Label(text: item['name'] as String, low: low),
              ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final bool low;
  const _Label({required this.text, required this.low});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          color: Colors.black.withValues(alpha: 0.5),
          child: Text(
            low ? '$text ?' : text,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, height: 1.2),
          ),
        ),
      ),
    );
  }
}

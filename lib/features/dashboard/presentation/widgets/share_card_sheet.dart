import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pantrypal/core/theme/app_theme.dart';
import 'package:pantrypal/features/pantry/domain/services/pantry_insights.dart';
import 'package:share_plus/share_plus.dart';

class ShareCardSheet extends StatefulWidget {
  final Map<String, dynamic> stats;
  const ShareCardSheet({required this.stats});

  @override
  State<ShareCardSheet> createState() => ShareCardSheetState();
}

class ShareCardSheetState extends State<ShareCardSheet> {
  final _cardKey = GlobalKey();
  bool _sharing = false;

  Future<void> _captureAndShare() async {
    setState(() => _sharing = true);
    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        setState(() => _sharing = false);
        return;
      }
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        setState(() => _sharing = false);
        return;
      }
      final bytes = byteData.buffer.asUint8List();
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/pantrypal_stats.png');
      await file.writeAsBytes(bytes);
      final box = _cardKey.currentContext?.findRenderObject() as RenderBox?;
      final shareResult = await Share.shareXFiles(
        [XFile(file.path)],
        sharePositionOrigin: box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null,
      );
      if (mounted && shareResult.status == ShareResultStatus.success) {
        Navigator.pop(context);
      } else {
        setState(() => _sharing = false);
      }
    } catch (e) {
      debugPrint('[Share] error: $e');
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              RepaintBoundary(
                key: _cardKey,
                child: ShareCard(stats: widget.stats),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _sharing ? null : _captureAndShare,
                  icon: _sharing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.share_rounded),
                  label: Text(_sharing ? 'Preparing...' : 'Share Image'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ShareCard extends StatelessWidget {
  final Map<String, dynamic> stats;
  const ShareCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final consumed = (stats['consumedMonth'] as int?) ?? 0;
    final wasted = (stats['wastedMonth'] as int?) ?? 0;
    final saved = ((stats['savedValueMonth'] as num?) ?? 0).toDouble();
    final lost = ((stats['wastedValueMonth'] as num?) ?? 0).toDouble();
    final saveRate = consumed + wasted > 0
        ? ((consumed / (consumed + wasted)) * 100).round()
        : 100;
    final now = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.kitchen, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'PantryPal',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                '${now.day}/${now.month}/${now.year}',
                style:
                    const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'My food-saving month',
            style: TextStyle(
                color: Colors.white70, fontSize: 13, letterSpacing: 0.3),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _ShareStatTile(
                  emoji: '💚', value: PantryInsights.money(saved, approx: true), label: 'Saved'),
              const SizedBox(width: 12),
              _ShareStatTile(
                  emoji: '✅', value: '$consumed', label: 'Used on time'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _ShareStatTile(
                  emoji: '🎯', value: '$saveRate%', label: 'Save rate'),
              const SizedBox(width: 12),
              _ShareStatTile(
                  emoji: '💸', value: PantryInsights.money(lost, approx: true), label: 'Wasted'),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, thickness: 1),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              'Know what to use first. Waste less. Save more. 🌿',
              style: TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareStatTile extends StatelessWidget {
  final String emoji, value, label;
  const _ShareStatTile(
      {required this.emoji, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            Text(label,
                style:
                    const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}


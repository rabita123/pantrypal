import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pantrypal/core/theme/app_theme.dart';
import 'package:pantrypal/features/pantry/presentation/bloc/pantry_bloc.dart';
import 'package:pantrypal/features/scan/data/ai_scan_client.dart';
import 'package:pantrypal/features/scan/data/scan_bloc.dart';
import 'package:pantrypal/features/scan/presentation/widgets/scan_results_view.dart';
import 'package:pantrypal/features/scan/presentation/widgets/scanning_view.dart';

/// Fridge scan: take a photo, watch it being read, confirm what was found.
/// Shares its engine and screens with the receipt scan.
class FridgeScanPage extends StatelessWidget {
  const FridgeScanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ScanBloc(kind: ScanKind.fridge),
      child: const _FridgeView(),
    );
  }
}

class _FridgeView extends StatelessWidget {
  const _FridgeView();

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final bloc = context.read<ScanBloc>();
    // Downscaled natively by the picker, so the app never decodes a 12 MP photo
    // on the UI thread.
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1280,
    );
    if (picked == null) return;
    bloc.add(ScanImageSelected(picked.path));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<ScanBloc, ScanState>(
      builder: (context, state) {
        if (state is ScanStreaming) {
          return ScanningView(
            kind: ScanKind.fridge,
            imagePath: state.imagePath,
            phase: state.phase,
            items: state.items,
            imageSize: state.imageSize,
            onCancel: () => context.read<ScanBloc>().add(ScanReset()),
          );
        }
        if (state is ScanReviewReady) {
          final bloc = context.read<ScanBloc>();
          return ScanResultsView(
            items: state.parsedItems,
            selected: state.selectedIndices,
            imagePath: state.imagePath,
            onToggle: (i) => bloc.add(ScanItemToggle(i)),
            onEdit: (i, changes) => bloc.add(ScanUpdateItem(i, changes)),
            onRemove: (i) => bloc.add(ScanItemRemove(i)),
            onRescan: () => bloc.add(ScanReset()),
            onAdd: () {
              final items = bloc.buildPantryItems(state);
              context.read<PantryBloc>().add(PantryAddItems(items));
              Navigator.pop(context, items);
            },
          );
        }
        return Scaffold(
          backgroundColor: isDark ? AppColors.darkBg : AppColors.surface,
          appBar: AppBar(
            title: const Text('Scan Fridge'),
            backgroundColor: isDark ? AppColors.darkBg : AppColors.surface,
            elevation: 0,
            scrolledUnderElevation: 0,
          ),
          body: state is ScanError
              ? _ErrorView(
                  message: state.message,
                  onRetry: () => context.read<ScanBloc>().add(ScanReset()),
                  isDark: isDark,
                )
              : _IdleView(onPick: (src) => _pick(context, src), isDark: isDark),
        );
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

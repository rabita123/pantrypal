import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pantrypal/core/theme/app_theme.dart';
import 'package:pantrypal/features/pantry/presentation/bloc/pantry_bloc.dart';
import 'package:pantrypal/features/scan/data/ai_scan_client.dart';
import 'package:pantrypal/features/scan/data/scan_bloc.dart';
import 'package:pantrypal/features/scan/presentation/widgets/scan_results_view.dart';
import 'package:pantrypal/features/scan/presentation/widgets/scanning_view.dart';
import 'package:permission_handler/permission_handler.dart';

class ScanPage extends StatelessWidget {
  const ScanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ScanBloc(),
      child: const _ScanView(),
    );
  }
}

class _ScanView extends StatelessWidget {
  const _ScanView();

  @override
  Widget build(BuildContext context) {
    return BlocListener<ScanBloc, ScanState>(
      listener: (context, state) {
        if (state is ScanError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: AppColors.expired),
          );
          context.read<ScanBloc>().add(ScanReset());
        }
      },
      child: BlocBuilder<ScanBloc, ScanState>(
        builder: (context, state) {
          if (state is ScanStreaming) {
            return ScanningView(
              kind: ScanKind.receipt,
              imagePath: state.imagePath,
              phase: state.phase,
              items: state.items,
              imageSize: state.imageSize,
              onCancel: () => context.read<ScanBloc>().add(ScanReset()),
            );
          }
          if (state is ScanReviewReady) return _Results(state: state);
          return const _CameraView();
        },
      ),
    );
  }
}

// ── Camera View (live in-app preview) ─────────────────────────────────────────

class _CameraView extends StatefulWidget {
  const _CameraView();

  @override
  State<_CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<_CameraView> {
  CameraController? _ctrl;
  bool _ready = false;
  bool _capturing = false;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _permissionDenied = true);
        return;
      }
      _ctrl = CameraController(cameras.first, ResolutionPreset.high, enableAudio: false);
      await _ctrl!.initialize();
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _permissionDenied = true);
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_ctrl == null || !_ready || _capturing) return;
    setState(() => _capturing = true);
    try {
      final file = await _ctrl!.takePicture();
      if (mounted) context.read<ScanBloc>().add(ScanImageSelected(file.path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture failed: $e'), backgroundColor: AppColors.expired),
        );
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _pickGallery() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 2000,
    );
    if (picked != null && mounted) {
      context.read<ScanBloc>().add(ScanImageSelected(picked.path));
    }
  }

  void _showTips() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Scanning tips', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          '• Use good lighting\n• Keep receipt flat\n• Include full receipt\n• Avoid shadows and glare\n• Grocery receipts work best',
          style: TextStyle(height: 1.8),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_permissionDenied) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.no_photography_outlined, size: 72, color: Colors.white54),
              const SizedBox(height: 20),
              const Text('Camera access denied', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('Please enable camera access in\nSettings > PantryPal > Camera', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5)),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => openAppSettings(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                ),
                child: const Text('Open Settings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back', style: TextStyle(color: Colors.white54, fontSize: 15)),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Live camera preview
          if (_ready && _ctrl != null)
            CameraPreview(_ctrl!)
          else
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),

          // Dark overlay with transparent viewfinder cutout + corner brackets
          const _ViewfinderOverlay(),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Scan Receipt',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.info_outline, color: Colors.white),
                    onPressed: _showTips,
                  ),
                ],
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(40, 16, 40, 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _ScanBtn(
                      icon: Icons.photo_library_outlined,
                      label: 'Gallery',
                      onTap: _pickGallery,
                    ),
                    _CaptureBtn(onTap: _capturing ? null : _capture),
                    _ScanBtn(
                      icon: Icons.tips_and_updates_outlined,
                      label: 'Tips',
                      onTap: _showTips,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewfinderOverlay extends StatelessWidget {
  const _ViewfinderOverlay();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OverlayPainter(),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 360 + 48),
            Text(
              'Position your receipt within the frame',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  static const _w = 270.0;
  static const _h = 370.0;
  static const _r = 16.0;
  static const _corner = 26.0;

  @override
  void paint(Canvas canvas, Size size) {
    final left = (size.width - _w) / 2;
    final top = (size.height - _h) / 2 - 30;
    final rect = Rect.fromLTWH(left, top, _w, _h);

    // Semi-transparent overlay with cutout
    final overlay = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(_r)));
    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(path, overlay);

    // Corner brackets
    final pen = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    void bracket(double x, double y, double dx, double dy) {
      canvas.drawLine(Offset(x, y + dy * _corner), Offset(x, y), pen);
      canvas.drawLine(Offset(x, y), Offset(x + dx * _corner, y), pen);
    }

    bracket(left, top, 1, 1);
    bracket(left + _w, top, -1, 1);
    bracket(left, top + _h, 1, -1);
    bracket(left + _w, top + _h, -1, -1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScanBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ScanBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }
}

class _CaptureBtn extends StatelessWidget {
  final VoidCallback? onTap;
  const _CaptureBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.4 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
              ),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 32),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Results ───────────────────────────────────────────────────────────────────

class _Results extends StatelessWidget {
  final ScanReviewReady state;
  const _Results({required this.state});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ScanBloc>();
    return ScanResultsView(
      items: state.parsedItems,
      selected: state.selectedIndices,
      imagePath: state.imagePath,
      offline: state.isOfflineFallback,
      onToggle: (i) => bloc.add(ScanItemToggle(i)),
      onEdit: (i, changes) => bloc.add(ScanUpdateItem(i, changes)),
      onRemove: (i) => bloc.add(ScanItemRemove(i)),
      onRescan: () => bloc.add(ScanReset()),
      onAdd: () {
        final items = bloc.buildPantryItems(state);
        context.read<PantryBloc>().add(PantryAddItems(items));
        // The caller shows what it all means (use-first, at-risk, cook tonight).
        Navigator.pop(context, items);
      },
    );
  }
}

import 'dart:ui' show Size;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pantrypal/core/config/backend_config.dart';
import 'package:pantrypal/core/utils/grocery_ocr_parser.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/scan/data/ai_scan_client.dart';
import 'package:pantrypal/shared/services/analytics_service.dart';
import 'package:uuid/uuid.dart';

abstract class ScanEvent extends Equatable {
  @override List<Object?> get props => [];
}
class ScanImageSelected extends ScanEvent {
  final String imagePath;
  ScanImageSelected(this.imagePath);
  @override List<Object?> get props => [imagePath];
}
class ScanReset extends ScanEvent {}
class ScanItemToggle extends ScanEvent {
  final int index;
  ScanItemToggle(this.index);
  @override List<Object?> get props => [index];
}
class ScanUpdateItem extends ScanEvent {
  final int index;
  final Map<String, dynamic> data;
  ScanUpdateItem(this.index, this.data);
}
class ScanItemRemove extends ScanEvent {
  final int index;
  ScanItemRemove(this.index);
  @override List<Object?> get props => [index];
}

abstract class ScanState extends Equatable {
  @override List<Object?> get props => [];
}
class ScanIdle extends ScanState {}
class ScanProcessing extends ScanState {}

/// The scan is running: items appear here as the AI finds them.
class ScanStreaming extends ScanState {
  final String imagePath;
  final ScanPhase phase;
  final List<Map<String, dynamic>> items;
  final Size? imageSize;
  ScanStreaming(this.imagePath, this.phase, this.items, this.imageSize);
  @override List<Object?> get props => [imagePath, phase, items, imageSize];
}

class ScanReviewReady extends ScanState {
  final List<Map<String, dynamic>> parsedItems;
  final Set<int> selectedIndices;
  final bool isOfflineFallback;
  final String? imagePath;
  ScanReviewReady(this.parsedItems, this.selectedIndices,
      {this.isOfflineFallback = false, this.imagePath});
  @override List<Object?> get props => [parsedItems, selectedIndices, isOfflineFallback, imagePath];
}
class ScanError extends ScanState {
  final String message;
  ScanError(this.message);
  @override List<Object?> get props => [message];
}

class ScanBloc extends Bloc<ScanEvent, ScanState> {
  final ScanKind kind;

  /// False when the user has not allowed AI: receipts are read on the phone.
  final bool useAi;
  final Stream<ScanUpdate> Function(ScanKind, String) _scanner;
  TextRecognizer? _recognizer;
  static const _uuid = Uuid();

  /// Bumped whenever a scan starts or is cancelled, so a scan the user has
  /// walked away from can never write into the screen they moved on to.
  int _generation = 0;

  /// [scanner] is a test seam; production uses the real AI client.
  ScanBloc({this.kind = ScanKind.receipt, this.useAi = true, Stream<ScanUpdate> Function(ScanKind, String)? scanner})
      : _scanner = scanner ?? ((k, p) => AiScanClient.scan(k, p)),
        super(ScanIdle()) {
    on<ScanImageSelected>(_onImageSelected);
    on<ScanReset>(_onReset);
    on<ScanItemToggle>(_onToggle);
    on<ScanUpdateItem>(_onUpdateItem);
    on<ScanItemRemove>(_onRemove);
  }

  /// Everything the AI was sure about starts ticked; anything it was unsure
  /// about starts unticked so it can never be added without a look.
  static Set<int> _initialSelection(List<Map<String, dynamic>> items) => {
        for (var i = 0; i < items.length; i++)
          if (items[i]['confidence'] != 'low') i,
      };

  Future<void> _onImageSelected(
      ScanImageSelected event, Emitter<ScanState> emit) async {
    final path = event.imagePath;
    final gen = ++_generation;
    final started = DateTime.now();
    int msSince() => DateTime.now().difference(started).inMilliseconds;
    int? firstItemMs;
    Analytics.track('scan_started', {'kind': kind});
    emit(ScanStreaming(path, ScanPhase.preparing, const [], null));

    // 1. AI scan — items stream in as they are found.
    var items = <Map<String, dynamic>>[];
    String? failure;
    if (useAi) try {
      await for (final u in _scanner(kind, path)) {
        if (gen != _generation) return; // cancelled — stops the request too
        items = u.items;
        if (firstItemMs == null && items.isNotEmpty) firstItemMs = msSince();
        emit(ScanStreaming(path, u.phase, u.items, u.imageSize));
      }
    } catch (e) {
      failure = BackendException.from(e).message;
    }
    if (gen != _generation) return;
    if (items.isNotEmpty) {
      Analytics.track('scan_completed', {
        'kind': kind,
        'items': items.length,
        'unsure': items.where((m) => m['confidence'] == 'low').length,
        'total_ms': msSince(),
        'first_item_ms': firstItemMs,
      });
      emit(ScanReviewReady(items, _initialSelection(items), imagePath: path));
      return;
    }
    Analytics.track('scan_failed', {
      'kind': kind,
      'reason': failure != null ? 'error' : 'empty',
      'total_ms': msSince(),
    });

    // Fridge photos have no local fallback.
    if (kind == ScanKind.fridge) {
      emit(ScanError(failure ??
          'No food items detected. Try a clearer photo with the fridge fully open.'));
      return;
    }

    // 2. Receipts: offline fallback with local OCR + parser.
    emit(ScanStreaming(path, ScanPhase.analyzing, const [], null));
    try {
      _recognizer ??= TextRecognizer();
      final inputImage = InputImage.fromFilePath(path);
      final recognized = await _recognizer!.processImage(inputImage);
      final parsed = GroceryOcrParser.parseReceipt(recognized.text);
      if (gen != _generation) return;

      if (parsed.isEmpty) {
        emit(ScanError(
            'No food items detected. Try a clearer photo with good lighting.'));
        return;
      }

      emit(ScanReviewReady(
          parsed, Set<int>.from(List.generate(parsed.length, (i) => i)),
          isOfflineFallback: true, imagePath: path));
    } catch (e) {
      emit(ScanError('Could not process image: ${e.toString()}'));
    }
  }

  void _onReset(ScanReset event, Emitter<ScanState> emit) {
    if (state is ScanStreaming) Analytics.track('scan_cancelled', {'kind': kind});
    _generation++;
    emit(ScanIdle());
  }

  void _onToggle(ScanItemToggle event, Emitter<ScanState> emit) {
    final current = state;
    if (current is ScanReviewReady) {
      final selected = Set<int>.from(current.selectedIndices);
      if (selected.contains(event.index)) {
        selected.remove(event.index);
      } else {
        selected.add(event.index);
      }
      emit(ScanReviewReady(current.parsedItems, selected,
          isOfflineFallback: current.isOfflineFallback, imagePath: current.imagePath));
    }
  }

  void _onUpdateItem(ScanUpdateItem event, Emitter<ScanState> emit) {
    final current = state;
    if (current is ScanReviewReady) {
      final items = List<Map<String, dynamic>>.from(current.parsedItems);
      items[event.index] = {...items[event.index], ...event.data};
      // Confirming an item (the editor marks it high-confidence) also ticks it.
      final selected = Set<int>.from(current.selectedIndices);
      if (event.data.containsKey('confidence')) selected.add(event.index);
      emit(ScanReviewReady(items, selected,
          isOfflineFallback: current.isOfflineFallback, imagePath: current.imagePath));
    }
  }

  void _onRemove(ScanItemRemove event, Emitter<ScanState> emit) {
    final current = state;
    if (current is! ScanReviewReady) return;
    if (event.index < 0 || event.index >= current.parsedItems.length) return;
    final items = List<Map<String, dynamic>>.from(current.parsedItems)..removeAt(event.index);
    // Indices after the removed row shift up by one.
    final selected = <int>{
      for (final i in current.selectedIndices)
        if (i < event.index) i else if (i > event.index) i - 1,
    };
    emit(ScanReviewReady(items, selected,
        isOfflineFallback: current.isOfflineFallback, imagePath: current.imagePath));
  }

  List<PantryItem> buildPantryItems(ScanReviewReady state) {
    final now = DateTime.now();
    return state.selectedIndices.map((i) {
      final m = state.parsedItems[i];
      final days = (m['estimatedExpiryDays'] as int?) ?? 7;
      return PantryItem(
        id: _uuid.v4(),
        name: m['name'] as String,
        category: m['category'] as FoodCategory,
        // A fridge photo is by definition the fridge; a receipt is sorted by
        // where that food actually lives (rice → pantry, milk → fridge).
        location: kind == ScanKind.fridge
            ? StorageLocation.fridge
            : (m['category'] as FoodCategory).defaultLocation,
        quantity: (m['quantity'] as double?) ?? 1.0,
        unit: (m['unit'] as String?) ?? 'item',
        expiryDate: PantryItem.expiryInDays(days, from: now),
        addedDate: now,
        price: m['price'] as double?,
        isConsumed: false,
        isWasted: false,
      );
    }).toList();
  }

  @override
  Future<void> close() {
    // Asynchronous failures must be caught on the future, not by try/catch.
    _recognizer?.close().catchError((_) {});
    return super.close();
  }
}

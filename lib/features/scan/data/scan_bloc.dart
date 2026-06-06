import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pantrypal/core/utils/grocery_ocr_parser.dart';
import 'package:pantrypal/features/pantry/domain/entities/pantry_item.dart';
import 'package:pantrypal/features/scan/data/receipt_scan_service.dart';
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

abstract class ScanState extends Equatable {
  @override List<Object?> get props => [];
}
class ScanIdle extends ScanState {}
class ScanProcessing extends ScanState {}
class ScanReviewReady extends ScanState {
  final List<Map<String, dynamic>> parsedItems;
  final Set<int> selectedIndices;
  final bool isOfflineFallback;
  ScanReviewReady(this.parsedItems, this.selectedIndices, {this.isOfflineFallback = false});
  @override List<Object?> get props => [parsedItems, selectedIndices, isOfflineFallback];
}
class ScanError extends ScanState {
  final String message;
  ScanError(this.message);
  @override List<Object?> get props => [message];
}

class ScanBloc extends Bloc<ScanEvent, ScanState> {
  TextRecognizer? _recognizer;
  static const _uuid = Uuid();

  ScanBloc() : super(ScanIdle()) {
    on<ScanImageSelected>(_onImageSelected);
    on<ScanReset>(_onReset);
    on<ScanItemToggle>(_onToggle);
    on<ScanUpdateItem>(_onUpdateItem);
  }

  Future<void> _onImageSelected(
      ScanImageSelected event, Emitter<ScanState> emit) async {
    emit(ScanProcessing());

    // 1. Try Claude Vision — fails fast if offline (SocketException)
    try {
      final parsed = await ReceiptScanService.analyzeReceipt(event.imagePath);
      if (parsed.isNotEmpty) {
        emit(ScanReviewReady(
            parsed, Set<int>.from(List.generate(parsed.length, (i) => i)),
            isOfflineFallback: false));
        return;
      }
    } catch (_) {
      // Offline or API error — fall through to local OCR
    }

    // 2. Offline fallback: local MLKit OCR + parser ─────────────────────────
    try {
      _recognizer ??= TextRecognizer();
      final inputImage = InputImage.fromFilePath(event.imagePath);
      final recognized = await _recognizer!.processImage(inputImage);
      final parsed = GroceryOcrParser.parseReceipt(recognized.text);

      if (parsed.isEmpty) {
        emit(ScanError(
            'No food items detected. Try a clearer photo with good lighting.'));
        return;
      }

      emit(ScanReviewReady(
          parsed, Set<int>.from(List.generate(parsed.length, (i) => i)),
          isOfflineFallback: true));
    } catch (e) {
      emit(ScanError('Could not process image: ${e.toString()}'));
    }
  }

  void _onReset(ScanReset event, Emitter<ScanState> emit) => emit(ScanIdle());

  void _onToggle(ScanItemToggle event, Emitter<ScanState> emit) {
    final current = state;
    if (current is ScanReviewReady) {
      final selected = Set<int>.from(current.selectedIndices);
      if (selected.contains(event.index)) {
        selected.remove(event.index);
      } else {
        selected.add(event.index);
      }
      emit(ScanReviewReady(current.parsedItems, selected));
    }
  }

  void _onUpdateItem(ScanUpdateItem event, Emitter<ScanState> emit) {
    final current = state;
    if (current is ScanReviewReady) {
      final items = List<Map<String, dynamic>>.from(current.parsedItems);
      items[event.index] = {...items[event.index], ...event.data};
      emit(ScanReviewReady(items, current.selectedIndices));
    }
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
        location: StorageLocation.fridge,
        quantity: (m['quantity'] as double?) ?? 1.0,
        unit: (m['unit'] as String?) ?? 'item',
        expiryDate: now.add(Duration(days: days)),
        addedDate: now,
        price: m['price'] as double?,
        isConsumed: false,
        isWasted: false,
      );
    }).toList();
  }

  @override
  Future<void> close() {
    try { _recognizer?.close(); } catch (_) {}
    return super.close();
  }
}

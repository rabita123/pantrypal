import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:pantrypal/features/subscription/services/subscription_service.dart';

// ── States ────────────────────────────────────────────────────────────────────

abstract class SubscriptionState extends Equatable {
  const SubscriptionState();
  @override
  List<Object?> get props => [];
}

class SubscriptionLoading extends SubscriptionState {}

class SubscriptionReady extends SubscriptionState {
  final bool isPremium;
  final int scansUsed;
  final Offerings? offerings;

  const SubscriptionReady({
    required this.isPremium,
    required this.scansUsed,
    this.offerings,
  });

  @override
  List<Object?> get props => [isPremium, scansUsed, offerings];
}

class SubscriptionError extends SubscriptionState {
  final String message;
  const SubscriptionError(this.message);
  @override
  List<Object?> get props => [message];
}

// ── Cubit ─────────────────────────────────────────────────────────────────────

class SubscriptionCubit extends Cubit<SubscriptionState> {
  final SubscriptionService _service;

  SubscriptionCubit(this._service) : super(SubscriptionLoading());

  Future<void> load() async {
    emit(SubscriptionLoading());
    try {
      final premium = await _service.isPremium();
      final scansUsed = await _service.freeScanCount;
      Offerings? offerings;
      try {
        offerings = await _service.fetchOfferings();
      } catch (_) {
        // Non-fatal — paywall shows without price if offline
      }
      emit(SubscriptionReady(
        isPremium: premium,
        scansUsed: scansUsed,
        offerings: offerings,
      ));
    } catch (e) {
      emit(SubscriptionError(e.toString()));
    }
  }

  Future<void> purchase(Package package) async {
    try {
      await _service.purchasePackage(package);
      await load();
    } on PurchasesErrorCode catch (e) {
      if (e != PurchasesErrorCode.purchaseCancelledError) {
        emit(SubscriptionError(e.toString()));
      }
      // User-cancelled purchase: silently stay on paywall
    } catch (e) {
      emit(SubscriptionError(e.toString()));
    }
  }

  Future<void> restore() async {
    try {
      await _service.restorePurchases();
      await load();
    } catch (e) {
      emit(SubscriptionError('Restore failed: ${e.toString()}'));
    }
  }
}

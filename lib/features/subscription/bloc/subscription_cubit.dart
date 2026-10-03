import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:pantrypal/features/subscription/services/subscription_service.dart';
import 'package:pantrypal/shared/services/analytics_service.dart';

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
    final plan = package.packageType.name;
    try {
      await _service.purchasePackage(package);
      Analytics.track('purchase_succeeded', {'plan': plan});
      Analytics.instance.flush();
      await load();
    } on PurchasesErrorCode catch (e) {
      if (e != PurchasesErrorCode.purchaseCancelledError) {
        Analytics.track('purchase_failed', {'plan': plan});
        emit(SubscriptionError(e.toString()));
      } else {
        Analytics.track('purchase_cancelled', {'plan': plan});
      }
      // User-cancelled purchase: silently stay on paywall
    } catch (e) {
      if (e is PlatformException) {
        final code = (e.details as Map?)?.entries
            .firstWhere((entry) => entry.key == 'readableErrorCode', orElse: () => const MapEntry('', ''))
            .value as String? ?? '';
        if (e.details?['userCancelled'] == true || code == 'PURCHASE_CANCELLED') {
          Analytics.track('purchase_cancelled', {'plan': plan});
          return;
        }
      }
      Analytics.track('purchase_failed', {'plan': plan});
      emit(SubscriptionError(e.toString()));
    }
  }

  Future<void> restore() async {
    Analytics.track('restore_tapped');
    try {
      await _service.restorePurchases();
      await load();
    } catch (e) {
      emit(SubscriptionError('Restore failed: ${e.toString()}'));
    }
  }
}

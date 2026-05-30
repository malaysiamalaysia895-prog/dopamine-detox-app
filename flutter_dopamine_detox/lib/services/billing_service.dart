import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Product ID registered in Google Play Console.
const String kUnlockPenaltyProductId = 'unlock_penalty_99';

class BillingService {
  final InAppPurchase _iap = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  ProductDetails? _penaltyProduct;

  /// Callback fired after a successful purchase — wire up in main.
  VoidCallback? onPurchaseSuccess;

  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  Future<void> init() async {
    _isAvailable = await _iap.isAvailable();
    if (!_isAvailable) {
      debugPrint('[BillingService] Store not available.');
      return;
    }

    // Listen to purchase updates.
    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (e) {
        debugPrint('[BillingService] Purchase stream error: $e');
      },
    );

    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    final response = await _iap.queryProductDetails({kUnlockPenaltyProductId});
    if (response.error != null) {
      _error = response.error!.message;
      debugPrint('[BillingService] Product load error: $_error');
      return;
    }
    if (response.productDetails.isEmpty) {
      debugPrint('[BillingService] No products found.');
      return;
    }
    _penaltyProduct = response.productDetails.first;
    debugPrint('[BillingService] Product loaded: ${_penaltyProduct!.title}');
  }

  /// Initiates the ₹99 penalty purchase flow.
  Future<void> buyPenalty() async {
    if (_penaltyProduct == null) {
      debugPrint('[BillingService] Product not loaded yet, retrying...');
      await _loadProducts();
      if (_penaltyProduct == null) {
        _error = 'Could not load product. Try again.';
        return;
      }
    }

    _loading = true;
    _error = null;

    final purchaseParam = PurchaseParam(productDetails: _penaltyProduct!);

    // Use buyConsumable so the product can be repurchased each time.
    await _iap.buyConsumable(purchaseParam: purchaseParam);

    _loading = false;
  }

  void _handlePurchaseUpdates(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      debugPrint(
          '[BillingService] Purchase update: ${purchase.productID} '
          '— status: ${purchase.status}');

      if (purchase.productID == kUnlockPenaltyProductId) {
        switch (purchase.status) {
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            // Deliver the purchase.
            _iap.completePurchase(purchase);
            onPurchaseSuccess?.call();
            debugPrint('[BillingService] Purchase SUCCESS — unlocking.');
            break;

          case PurchaseStatus.error:
            _error = purchase.error?.message ?? 'Purchase failed.';
            debugPrint('[BillingService] Purchase ERROR: $_error');
            break;

          case PurchaseStatus.canceled:
            debugPrint('[BillingService] Purchase CANCELLED.');
            break;

          case PurchaseStatus.pending:
            debugPrint('[BillingService] Purchase PENDING...');
            break;
        }
      }
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}

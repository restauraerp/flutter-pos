import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api/api_client.dart';
import '../data/models/models.dart';
import '../data/repositories/pos_repository.dart';

/// Tabs on the orders screen. `all` shows everything for the branch; the rest
/// show only unfinished orders of that type, as the web screen does.
enum OrdersTab {
  all('all_orders', 'All'),
  dineIn('dine_in', 'Dine-in'),
  takeaway('takeaway', 'Takeaway'),
  delivery('delivery', 'Delivery'),
  catering('catering', 'Catering');

  const OrdersTab(this.value, this.label);

  final String value;
  final String label;
}

/// How the current tab's orders are ordered.
enum OrdersSort { placedAt, table, deliveryTime }

class OrdersController extends ChangeNotifier {
  OrdersController(this._repository);

  final PosRepository _repository;

  /// The restaurant's own combined tax rate, set by whoever loaded it.
  ///
  /// Defaulted to zero rather than a guess: charging a rate nobody configured
  /// is how the till came to quote 10% while the server computed something
  /// else. No rate means no tax, which is what the server does too.
  double _taxRate = 0;

  double get taxRate => _taxRate;

  set taxRate(double rate) {
    if (rate == _taxRate) return;
    _taxRate = rate;
    notifyListeners();
  }

  /// The web screen polls every 10 seconds; a POS terminal needs the same
  /// liveness so the kitchen and the till stay in step.
  static const Duration refreshInterval = Duration(seconds: 10);

  Timer? _timer;
  int? _locationId;

  List<OrderModel> _orders = const [];
  bool _loading = true;
  String? _error;
  OrdersTab _tab = OrdersTab.all;
  OrdersSort _sort = OrdersSort.placedAt;

  /// Ids with an in-flight mutation, so their buttons can show progress.
  final Set<int> _busyOrderIds = {};

  List<OrderModel> get orders => _orders;
  bool get loading => _loading;
  String? get error => _error;
  OrdersTab get tab => _tab;
  OrdersSort get sort => _sort;
  bool isBusy(int orderId) => _busyOrderIds.contains(orderId);

  /// Total active orders for the branch, for the badge on the POS screen.
  int get activeCount => _orders.where((o) => !o.isCompleted).length;

  /// Orders for the selected tab, sorted.
  List<OrderModel> get visibleOrders {
    final list = _orders.where((o) {
      if (_tab == OrdersTab.all) return true;
      if (o.orderType.value != _tab.value) return false;
      // Type tabs are a work queue: finished orders drop off.
      return !o.isCompleted;
    }).toList();

    list.sort((a, b) {
      switch (_sort) {
        case OrdersSort.table:
          return (a.tableName ?? '').compareTo(b.tableName ?? '');
        case OrdersSort.deliveryTime:
          final at = a.deliveryTime;
          final bt = b.deliveryTime;
          // ASAP orders (no time) stay at the top — they are the urgent ones.
          if (at == null && bt == null) break;
          if (at == null) return -1;
          if (bt == null) return 1;
          return at.compareTo(bt);
        case OrdersSort.placedAt:
          break;
      }
      final ac = a.createdAt;
      final bc = b.createdAt;
      if (ac == null || bc == null) return 0;
      return ac.compareTo(bc);
    });

    return list;
  }

  /// Sort options valid for the current tab.
  List<OrdersSort> get availableSorts => _tab == OrdersTab.dineIn
      ? const [OrdersSort.placedAt, OrdersSort.table]
      : const [OrdersSort.placedAt, OrdersSort.deliveryTime];

  void start(int? locationId) {
    _locationId = locationId;
    refresh();
    _timer?.cancel();
    _timer = Timer.periodic(refreshInterval, (_) => refresh(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// [silent] is used by the poll loop so a blip does not replace a screen full
  /// of orders with an error the cashier did not ask for.
  Future<void> refresh({bool silent = false}) async {
    if (!silent) {
      _loading = true;
      notifyListeners();
    }

    try {
      _orders = await _repository.activeOrders(locationId: _locationId);
      _error = null;
    } on ApiException catch (e) {
      if (!silent) _error = e.message;
    } catch (e) {
      if (!silent) _error = 'Could not load orders: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void selectTab(OrdersTab tab) {
    if (_tab == tab) return;
    _tab = tab;
    // The previous sort may not apply to this tab.
    if (!availableSorts.contains(_sort)) _sort = OrdersSort.placedAt;
    notifyListeners();
  }

  void selectSort(OrdersSort sort) {
    if (_sort == sort) return;
    _sort = sort;
    notifyListeners();
  }

  Future<void> advance(OrderModel order, String status) {
    return _mutate(
      order.id,
      () => _repository.updateOrderStatus(order.id, status),
    );
  }

  Future<void> cancel(OrderModel order) {
    return _mutate(order.id, () => _repository.cancelOrder(order.id));
  }

  Future<void> pay({
    required OrderModel order,
    required PaymentMethod method,
    required DiscountModel? discount,
    String? note,
  }) {
    final totals = totalsFor(order, discount);
    return _mutate(
      order.id,
      () => _repository.payOrder(
        orderId: order.id,
        paymentMethod: method.value,
        discountId: discount?.id,
        discountAmount: totals.discount,
        taxAmount: totals.tax,
        deliveryCharge: order.deliveryCharge,
        total: totals.total,
        paymentNote: note,
      ),
    );
  }

  /// Lets an order leave unpaid, to be collected later.
  Future<void> markDue(OrderModel order, String note) =>
      _mutate(order.id, () => _repository.markOrderDue(order.id, note));

  /// Records money collected against a due order, in part or in full.
  Future<void> settle(
    OrderModel order, {
    required double amount,
    required String method,
    String? note,
  }) => _mutate(
    order.id,
    () => _repository.settleOrder(
      orderId: order.id,
      amount: amount,
      method: method,
      note: note,
    ),
  );

  /// Recomputes an order's totals for a coupon applied at the till, using the
  /// same arithmetic as the POS screen.
  ({double discount, double tax, double total}) totalsFor(
    OrderModel order,
    DiscountModel? discount,
  ) {
    final discountAmount = discount?.amountFor(order.subtotal) ?? 0;
    final afterDiscount = order.subtotal - discountAmount;
    final tax = afterDiscount * _taxRate;
    return (
      discount: discountAmount,
      tax: tax,
      total: afterDiscount + tax + order.deliveryCharge,
    );
  }

  Future<void> _mutate(int orderId, Future<void> Function() action) async {
    _busyOrderIds.add(orderId);
    notifyListeners();

    try {
      await action();
      await refresh(silent: true);
    } finally {
      _busyOrderIds.remove(orderId);
      notifyListeners();
    }
  }
}

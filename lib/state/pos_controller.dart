import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api/api_client.dart';
import '../core/config/app_config.dart';
import '../data/models/models.dart';
import '../data/repositories/pos_repository.dart';

/// Holds the whole POS screen's state — the Flutter counterpart of the
/// `useState` block in the Next.js POS page.
class PosController extends ChangeNotifier {
  PosController(this._repository);

  final PosRepository _repository;

  static const String _locationKey = 'restora_active_location_id';

  // ---- Catalogue -----------------------------------------------------------
  List<ProductModel> _products = const [];
  List<CategoryModel> _categories = const [];
  List<CustomerModel> _customers = const [];
  List<DiscountModel> _discounts = const [];
  List<LocationModel> _locations = const [];
  Map<String, String> _settings = const {};

  bool _loading = true;
  String? _loadError;

  bool get loading => _loading;
  String? get loadError => _loadError;
  List<CategoryModel> get categories => _categories;
  List<CustomerModel> get customers => _customers;
  List<DiscountModel> get discounts => _discounts;
  List<LocationModel> get locations => _locations;

  String get currency => _settings['currency_symbol'] ?? '৳';

  /// Venue settings from `/website-settings`, used for receipt headers.
  Map<String, String> get settings => _settings;

  // ---- Order configuration -------------------------------------------------

  /// The branch this user belongs to, from `users.location_id`.
  ///
  /// When set, the terminal is pinned to it and the branch switcher is hidden:
  /// a manager for one branch must not be able to file orders against another.
  int? _assignedLocationId;

  /// True only for accounts with no branch of their own (admins), and only when
  /// there is more than one branch to choose between.
  bool get canSwitchLocation => _assignedLocationId == null && _locations.length > 1;

  int? _activeLocationId;
  OrderType _orderType = OrderType.dineIn;
  List<TableModel> _tables = const [];
  bool _tablesLoading = false;
  int? _selectedTableId;
  int? _selectedCustomerId;
  DiscountModel? _appliedDiscount;
  double _deliveryCharge = 0;
  DateTime? _deliveryTime;
  String _deliveryAddress = '';
  double? _latitude;
  double? _longitude;

  int? get activeLocationId => _activeLocationId;
  OrderType get orderType => _orderType;
  List<TableModel> get tables => _tables;
  bool get tablesLoading => _tablesLoading;
  int? get selectedTableId => _selectedTableId;
  int? get selectedCustomerId => _selectedCustomerId;
  DiscountModel? get appliedDiscount => _appliedDiscount;
  double get deliveryCharge => _deliveryCharge;
  DateTime? get deliveryTime => _deliveryTime;
  String get deliveryAddress => _deliveryAddress;

  CustomerModel? get selectedCustomer {
    if (_selectedCustomerId == null) return null;
    for (final c in _customers) {
      if (c.id == _selectedCustomerId) return c;
    }
    return null;
  }

  // ---- Browsing ------------------------------------------------------------
  int? _selectedCategoryId;
  String _searchQuery = '';

  int? get selectedCategoryId => _selectedCategoryId;
  String get searchQuery => _searchQuery;

  // ---- Cart ----------------------------------------------------------------
  final List<CartItem> _cart = [];
  final List<HeldOrder> _heldOrders = [];
  bool _checkingOut = false;

  List<CartItem> get cart => List.unmodifiable(_cart);
  List<HeldOrder> get heldOrders => List.unmodifiable(_heldOrders);
  bool get checkingOut => _checkingOut;
  bool get hasItems => _cart.isNotEmpty;
  int get cartCount => _cart.fold(0, (sum, i) => sum + i.qty);

  // ---- Derived values ------------------------------------------------------

  /// Products for the active location, category, and search — the Dart
  /// equivalent of the `filteredProducts` memo on the web.
  List<ProductModel> get filteredProducts {
    final query = _searchQuery.trim().toLowerCase();
    return _products.where((p) {
      if (!p.isAvailableAt(_activeLocationId)) return false;
      if (_selectedCategoryId != null && p.categoryId != _selectedCategoryId) {
        return false;
      }
      if (query.isNotEmpty && !p.name.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Categories that actually have products, with their counts.
  List<({CategoryModel category, int count})> get categoriesWithProducts {
    final result = <({CategoryModel category, int count})>[];
    for (final cat in _categories) {
      final count = _products.where((p) => p.categoryId == cat.id).length;
      if (count > 0) result.add((category: cat, count: count));
    }
    return result;
  }

  double get subtotal => _cart.fold(0, (sum, item) => sum + item.lineTotal);

  double get discountAmount => _appliedDiscount?.amountFor(subtotal) ?? 0;

  double get afterDiscount => subtotal - discountAmount;

  double get tax => afterDiscount * AppConfig.taxRate;

  double get effectiveDeliveryCharge =>
      _orderType.needsDeliveryCharge ? _deliveryCharge : 0;

  double get total => afterDiscount + tax + effectiveDeliveryCharge;

  // ---- Loading -------------------------------------------------------------

  Future<void> load() async {
    _loading = true;
    _loadError = null;
    notifyListeners();

    try {
      final data = await _repository.bootstrap();
      _products = data.products;
      _categories = data.categories;
      _customers = data.customers;
      _discounts = data.discounts;
      _locations = data.locations;
      _settings = data.settings;

      await _restoreActiveLocation();
      _loadError = null;
    } on ApiException catch (e) {
      _loadError = e.message;
    } catch (e) {
      _loadError = 'Could not load POS data: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }

    if (_loadError == null) await _refreshTables();
  }

  Future<void> _restoreActiveLocation() async {
    // A branch-scoped user is pinned to their own branch, whatever this
    // terminal last had selected. Deliberately not persisted: the next user to
    // sign in here may belong somewhere else.
    if (_assignedLocationId != null) {
      _activeLocationId = _assignedLocationId;
      return;
    }

    if (_locations.isEmpty) {
      _activeLocationId = null;
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_locationKey);

    final savedIsValid = saved != null && _locations.any((l) => l.id == saved);
    if (savedIsValid) {
      _activeLocationId = saved;
    } else {
      _activeLocationId = _locations.first.id;
      await prefs.setInt(_locationKey, _activeLocationId!);
    }
  }

  /// Name of the active branch, for the header on a pinned terminal.
  String? get activeLocationName {
    for (final loc in _locations) {
      if (loc.id == _activeLocationId) return loc.name;
    }
    return null;
  }

  Future<void> _refreshTables() async {
    // Tables only matter for dine-in.
    if (!_orderType.needsTable || _activeLocationId == null) {
      _tables = const [];
      _selectedTableId = null;
      notifyListeners();
      return;
    }

    _tablesLoading = true;
    notifyListeners();

    try {
      _tables = await _repository.tablesFor(_activeLocationId!);
    } catch (_) {
      _tables = const [];
    } finally {
      _tablesLoading = false;
      notifyListeners();
    }
  }

  // ---- Mutations -----------------------------------------------------------

  /// Ties the terminal to the signed-in user before loading. Call once per
  /// session, ahead of [load].
  void bindUser(UserModel? user) {
    _assignedLocationId = user?.locationId;
  }

  Future<void> setActiveLocation(int id) async {
    // Guards the pin even if a stale switcher somehow issues a change.
    if (!canSwitchLocation) return;
    if (_activeLocationId == id) return;
    _activeLocationId = id;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_locationKey, id);
    await _refreshTables();
  }

  Future<void> setOrderType(OrderType type) async {
    if (_orderType == type) return;
    _orderType = type;
    if (!type.needsTable) _selectedTableId = null;
    notifyListeners();
    await _refreshTables();
  }

  void selectTable(int? id) {
    _selectedTableId = _selectedTableId == id ? null : id;
    notifyListeners();
  }

  void selectCustomer(int? id) {
    _selectedCustomerId = id;
    notifyListeners();
  }

  void selectCategory(int? id) {
    _selectedCategoryId = _selectedCategoryId == id ? null : id;
    notifyListeners();
  }

  void search(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setDeliveryCharge(double value) {
    _deliveryCharge = value < 0 ? 0 : value;
    notifyListeners();
  }

  void setDeliveryTime(DateTime? value) {
    _deliveryTime = value;
    notifyListeners();
  }

  void setDeliveryAddress(String value, {double? latitude, double? longitude}) {
    _deliveryAddress = value;
    _latitude = latitude;
    _longitude = longitude;
    notifyListeners();
  }

  // ---- Cart ----------------------------------------------------------------

  void addToCart(ProductModel product) {
    final index = _cart.indexWhere((i) => i.id == product.id);
    if (index >= 0) {
      _cart[index].qty += 1;
    } else {
      _cart.add(CartItem(product: product));
    }
    notifyListeners();
  }

  void updateQty(int productId, int delta) {
    final index = _cart.indexWhere((i) => i.id == productId);
    if (index < 0) return;

    final next = _cart[index].qty + delta;
    if (next <= 0) {
      _cart.removeAt(index);
    } else {
      _cart[index].qty = next;
    }
    notifyListeners();
  }

  void removeItem(int productId) {
    _cart.removeWhere((i) => i.id == productId);
    notifyListeners();
  }

  void updateNotes(int productId, String notes) {
    final index = _cart.indexWhere((i) => i.id == productId);
    if (index < 0) return;
    _cart[index].notes = notes;
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  /// Parks the current order so the terminal can start a new one.
  void holdOrder() {
    if (_cart.isEmpty) return;

    _heldOrders.add(
      HeldOrder(
        id: DateTime.now().millisecondsSinceEpoch,
        items: _cart.map((i) => i.copy()).toList(),
        orderType: _orderType.value,
        tableId: _selectedTableId,
        customerId: _selectedCustomerId,
      ),
    );
    _resetOrder();
    notifyListeners();
  }

  /// Brings a held order back. Anything currently in the cart is parked first,
  /// so nothing is silently lost.
  Future<void> recallOrder(int heldId) async {
    final index = _heldOrders.indexWhere((o) => o.id == heldId);
    if (index < 0) return;

    final order = _heldOrders[index];
    if (_cart.isNotEmpty) holdOrder();

    _heldOrders.removeWhere((o) => o.id == heldId);
    _cart
      ..clear()
      ..addAll(order.items);
    _selectedTableId = order.tableId;
    _selectedCustomerId = order.customerId;

    final restoredType = OrderType.fromValue(order.orderType);
    if (restoredType != _orderType) {
      _orderType = restoredType;
      notifyListeners();
      await _refreshTables();
    } else {
      notifyListeners();
    }
  }

  void discardHeldOrder(int heldId) {
    _heldOrders.removeWhere((o) => o.id == heldId);
    notifyListeners();
  }

  // ---- Discounts -----------------------------------------------------------

  /// Validates a coupon locally against the discount list, matching the web
  /// `DiscountInput`. Returns an error message, or null on success.
  String? applyDiscountCode(String code) {
    final normalized = code.trim().toLowerCase();
    if (normalized.isEmpty) return 'Enter a code.';

    DiscountModel? found;
    for (final d in _discounts) {
      if (d.code?.toLowerCase() == normalized) {
        found = d;
        break;
      }
    }

    if (found == null) return 'Invalid code';
    if (!found.isActive) return 'Coupon is inactive';
    if (found.isExpired) return 'Coupon expired';

    _appliedDiscount = found;
    notifyListeners();
    return null;
  }

  void removeDiscount() {
    _appliedDiscount = null;
    notifyListeners();
  }

  // ---- Customers -----------------------------------------------------------

  Future<void> addCustomer({
    required String name,
    required String phone,
    String? email,
    String? address,
    String? organizationName,
    String? googleMapLocation,
  }) async {
    final customer = await _repository.createCustomer(
      name: name,
      phone: phone,
      email: email,
      address: address,
      organizationName: organizationName,
      googleMapLocation: googleMapLocation,
    );
    _customers = [..._customers, customer];
    _selectedCustomerId = customer.id;
    notifyListeners();
  }

  // ---- Checkout ------------------------------------------------------------

  /// Places the order. Returns the new order id, or throws [ApiException].
  Future<int> checkout() async {
    if (_cart.isEmpty) {
      throw ApiException('The cart is empty.');
    }

    _checkingOut = true;
    notifyListeners();

    try {
      final id = await _repository.placeOrder({
        'location_id': _activeLocationId,
        'order_type': _orderType.value,
        'status': 'pending',
        'subtotal': subtotal.toStringAsFixed(2),
        'tax_amount': tax.toStringAsFixed(2),
        'discount_amount': discountAmount.toStringAsFixed(2),
        'delivery_charge': effectiveDeliveryCharge.toStringAsFixed(2),
        'total': total.toStringAsFixed(2),
        'table_id': _orderType.needsTable ? _selectedTableId : null,
        'customer_id': _selectedCustomerId,
        'discount_id': _appliedDiscount?.id,
        'delivery_time': _formatDeliveryTime(),
        'delivery_address': _deliveryAddress.isEmpty ? null : _deliveryAddress,
        'latitude': _latitude,
        'longitude': _longitude,
        'items': _cart
            .map(
              (item) => {
                'product_id': item.id,
                'qty': item.qty,
                'price': item.product.price.toStringAsFixed(2),
                'notes': item.notes.isEmpty ? null : item.notes,
              },
            )
            .toList(),
      });

      _cart.clear();
      _resetOrder();
      return id;
    } finally {
      _checkingOut = false;
      notifyListeners();
    }
  }

  /// `null` means ASAP, matching the web behaviour of an empty time field.
  String? _formatDeliveryTime() {
    final dt = _deliveryTime;
    if (dt == null) return null;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}:00';
  }

  /// Wipes all state from the previous sign-in.
  ///
  /// This controller is app-scoped and outlives a single session, so without
  /// this the next user to log in at the terminal would inherit the previous
  /// cashier's cart and held orders. Called when a session starts, which covers
  /// both a deliberate logout and a token that expired underneath us.
  void resetSession() {
    _cart.clear();
    _heldOrders.clear();
    _products = const [];
    _categories = const [];
    _customers = const [];
    _discounts = const [];
    _locations = const [];
    _settings = const {};
    _tables = const [];
    _selectedCategoryId = null;
    _searchQuery = '';
    _orderType = OrderType.dineIn;
    _assignedLocationId = null;
    _activeLocationId = null;
    _loading = true;
    _loadError = null;
    _resetOrder();
    notifyListeners();
  }

  /// Bumped every time the order is reset. Widgets holding their own
  /// `TextEditingController` watch this to clear stale text — otherwise the next
  /// customer would see the previous one's delivery address.
  int _orderResetToken = 0;

  int get orderResetToken => _orderResetToken;

  /// Clears per-order selections but keeps location and order type, since the
  /// next customer at the same terminal usually shares those.
  void _resetOrder() {
    _orderResetToken++;
    _selectedTableId = null;
    _selectedCustomerId = null;
    _appliedDiscount = null;
    _deliveryCharge = 0;
    _deliveryTime = null;
    _deliveryAddress = '';
    _latitude = null;
    _longitude = null;
  }
}

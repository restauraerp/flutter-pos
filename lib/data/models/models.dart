import '../../core/sales/discount_calculator.dart';
import '../../core/config/app_config.dart';

/// The API returns numerics inconsistently (`"12.50"`, `12.5`, `null`), so all
/// parsing funnels through these helpers.
double asDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse('$v') ?? 0;
}

int? asIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  return int.tryParse('$v');
}

int asInt(dynamic v) => asIntOrNull(v) ?? 0;

bool asBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = '$v'.toLowerCase();
  return s == 'true' || s == '1';
}

String? asStringOrNull(dynamic v) {
  if (v == null) return null;
  final s = '$v'.trim();
  return s.isEmpty ? null : s;
}

class LocationModel {
  LocationModel({required this.id, required this.name});

  final int id;
  final String name;

  factory LocationModel.fromJson(Map<String, dynamic> json) => LocationModel(
    id: asInt(json['id']),
    name: asStringOrNull(json['name']) ?? 'Location ${json['id']}',
  );
}

class CategoryModel {
  CategoryModel({required this.id, required this.name});

  final int id;
  final String name;

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel(
    id: asInt(json['id']),
    name: asStringOrNull(json['name']) ?? 'Uncategorized',
  );
}

/// One line inside a set-menu / combo product: what it is and how many.
///
/// The server sends a combo product's contents as `combo_items`, each pointing
/// at either a sellable product or a raw inventory item, with a quantity. The
/// POS never prices these - a combo is sold as its own product at its own
/// price - it only shows what is inside, so the kitchen making a "Lunch Combo"
/// can see it is a burger, fries and a drink. Mirrors the web combo breakdown.
class ComboComponent {
  const ComboComponent({required this.name, required this.quantity});

  final String name;
  final double quantity;

  /// "2 × Coke" when more than one, otherwise just the name.
  String get label {
    if (quantity <= 1) return name;
    final q = quantity == quantity.roundToDouble()
        ? quantity.toInt().toString()
        : quantity.toString();
    return '$q × $name';
  }

  /// Reads a product's `combo_items`, tolerant of either a product component
  /// (`product.name`) or a raw ingredient (`inventory_item.title`).
  static List<ComboComponent> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    final out = <ComboComponent>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final product = entry['product'];
      final inventory = entry['inventory_item'];
      final name = (product is Map ? asStringOrNull(product['name']) : null) ??
          (inventory is Map ? asStringOrNull(inventory['title']) : null) ??
          'Item';
      final qty = asDouble(entry['quantity']);
      out.add(ComboComponent(name: name, quantity: qty <= 0 ? 1 : qty));
    }
    return out;
  }
}

class ProductModel {
  ProductModel({
    required this.id,
    required this.name,
    required this.price,
    required this.categoryId,
    required this.imageUrl,
    required this.locationAvailability,
    this.type,
    this.comboItems = const [],
  });

  final int id;
  final String name;
  final double price;
  final int? categoryId;
  final String? imageUrl;

  /// The product's kind, e.g. 'combo' for a set menu. Null on older payloads,
  /// which the POS treats as an ordinary single product.
  final String? type;

  /// A combo's contents, empty for an ordinary product. See [ComboComponent].
  final List<ComboComponent> comboItems;

  bool get isCombo => type == 'combo' || comboItems.isNotEmpty;

  /// locationId -> is_available, from the `locations` pivot. Empty means the
  /// product is not location-scoped and is therefore available everywhere.
  final Map<int, bool> locationAvailability;

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    String? image;
    final images = json['images'];
    if (images is List && images.isNotEmpty) {
      final first = images.first;
      if (first is Map) {
        final url = asStringOrNull(first['url']);
        if (url != null) image = AppConfig.mediaUrl(url);
      }
    }

    final availability = <int, bool>{};
    final locations = json['locations'];
    if (locations is List) {
      for (final loc in locations) {
        if (loc is! Map) continue;
        final id = asIntOrNull(loc['id']);
        if (id == null) continue;
        final pivot = loc['pivot'];
        availability[id] = pivot is Map
            ? asBool(pivot['is_available'])
            : true;
      }
    }

    return ProductModel(
      id: asInt(json['id']),
      name: asStringOrNull(json['name']) ?? 'Unnamed item',
      price: asDouble(json['price']),
      categoryId: asIntOrNull(json['category_id']),
      imageUrl: image,
      locationAvailability: availability,
      type: asStringOrNull(json['type']),
      comboItems: ComboComponent.listFrom(json['combo_items']),
    );
  }

  /// Mirrors the web POS rule: a product with no location pivot is available
  /// everywhere; otherwise it must be flagged available at this location.
  bool isAvailableAt(int? locationId) {
    if (locationId == null) return true;
    if (locationAvailability.isEmpty) return true;
    return locationAvailability[locationId] ?? false;
  }

  /// Two-letter fallback shown when the product has no image.
  String get initials {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '🍽️';
    return trimmed.length >= 2
        ? trimmed.substring(0, 2).toUpperCase()
        : trimmed.toUpperCase();
  }
}

class TableModel {
  TableModel({
    required this.id,
    required this.name,
    required this.capacity,
    required this.ordersCount,
  });

  final int id;
  final String name;
  final int? capacity;
  final int ordersCount;

  bool get isOccupied => ordersCount > 0;

  factory TableModel.fromJson(Map<String, dynamic> json) => TableModel(
    id: asInt(json['id']),
    name: asStringOrNull(json['name']) ?? 'Table ${json['id']}',
    capacity: asIntOrNull(json['capacity']),
    ordersCount: asInt(json['orders_count']),
  );
}

class CustomerModel {
  CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
  });

  final int id;
  final String? name;
  final String? phone;
  final String? email;

  String get displayName => name ?? phone ?? 'Customer $id';

  bool matches(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return true;
    return (name?.toLowerCase().contains(q) ?? false) ||
        (phone?.contains(q) ?? false);
  }

  factory CustomerModel.fromJson(Map<String, dynamic> json) => CustomerModel(
    id: asInt(json['id']),
    name: asStringOrNull(json['name']),
    phone: asStringOrNull(json['phone']),
    email: asStringOrNull(json['email']),
  );
}

class DiscountModel {
  DiscountModel({
    required this.id,
    required this.code,
    required this.discountType,
    required this.value,
    required this.validUntil,
    required this.isActive,
  });

  final int id;
  final String? code;
  final String? discountType;
  final double value;
  final DateTime? validUntil;
  final bool isActive;

  bool get isPercentage => discountType == 'percentage';
  bool get isExpired =>
      validUntil != null && validUntil!.isBefore(DateTime.now());

  double amountFor(double subtotal) =>
      isPercentage ? subtotal * (value / 100) : value;

  factory DiscountModel.fromJson(Map<String, dynamic> json) => DiscountModel(
    id: asInt(json['id']),
    code: asStringOrNull(json['code']),
    discountType: asStringOrNull(json['discount_type']),
    value: asDouble(json['value']),
    validUntil: DateTime.tryParse('${json['valid_until']}'),
    isActive: asBool(json['is_active']),
  );
}

class UserModel {
  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.locationId,
    required this.permissions,
  });

  final int id;
  final String name;
  final String email;
  final int? locationId;
  final List<String> permissions;

  /// The POS terminal is gated on this permission — see `RolePermissionSeeder`,
  /// where `pos_manager` and above are granted it.
  bool get canUsePos => permissions.contains('view_pos');
  bool get canCreateOrder => permissions.contains('create_pos_order');
  bool get canViewOrders => permissions.contains('view_orders');
  bool get canUpdateOrderStatus => permissions.contains('update_order_status');

  /// Cancelling (and full-editing) an order is gated on `edit_order`, which the
  /// server enforces on DELETE /orders and on an items edit - see
  /// OrderController::destroy/update. `update_order_status` is not enough:
  /// pos_manager and branch_manager can advance and settle but not cancel.
  /// restaurant_admin carries every permission, so it includes this one.
  bool get canEditOrder => permissions.contains('edit_order');

  /// True when this user is tied to a single branch.
  ///
  /// `users.location_id` is a `belongsTo`, so staff belong to exactly one
  /// branch. Only accounts with no branch (admins overseeing every site) may
  /// switch between locations.
  bool get isBranchScoped => locationId != null;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final raw = json['all_permissions'];
    final perms = raw is List ? raw.map((p) => '$p').toList() : <String>[];
    return UserModel(
      id: asInt(json['id']),
      name: asStringOrNull(json['name']) ?? 'User',
      email: asStringOrNull(json['email']) ?? '',
      locationId: asIntOrNull(json['location_id']),
      permissions: perms,
    );
  }
}

/// Lifecycle of a placed order, mirroring the web `statusConfig`.
enum OrderStatus {
  pending('pending', 'Pending'),
  cooking('cooking', 'Cooking'),
  cooked('cooked', 'Cooked'),
  served('served', 'Served'),
  packed('packed', 'Packed'),
  picked('picked', 'Picked Up'),
  delivered('delivered', 'Delivered'),
  paid('paid', 'Paid');

  const OrderStatus(this.value, this.label);

  final String value;
  final String label;

  static OrderStatus? fromValue(String? value) {
    for (final s in OrderStatus.values) {
      if (s.value == value) return s;
    }
    return null;
  }
}

/// A single action a cashier can take to advance an order.
class OrderTransition {
  const OrderTransition(this.label, this.status);

  final String label;
  final String status;
}

/// A line on a placed order. Note the API returns `quantity` here, unlike the
/// `qty` accepted when creating an order.
class OrderItemModel {
  OrderItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.imageUrl,
    required this.quantity,
    required this.price,
    required this.notes,
    this.comboItems = const [],
  });

  final int id;
  final int? productId;
  final String? productName;
  final String? imageUrl;
  final int quantity;
  final double price;
  final String? notes;

  /// When this line is a combo product, the things inside it - so the kitchen
  /// ticket and the order card can list them. Empty for an ordinary line.
  final List<ComboComponent> comboItems;

  bool get isCombo => comboItems.isNotEmpty;

  String get displayName => productName ?? 'Item ${productId ?? id}';

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    String? image;
    String? name;

    var combo = const <ComboComponent>[];
    final product = json['product'];
    if (product is Map) {
      name = asStringOrNull(product['name']);
      final images = product['images'];
      if (images is List && images.isNotEmpty && images.first is Map) {
        final url = asStringOrNull((images.first as Map)['url']);
        if (url != null) image = AppConfig.mediaUrl(url);
      }
      combo = ComboComponent.listFrom(product['combo_items']);
    }

    return OrderItemModel(
      id: asInt(json['id']),
      productId: asIntOrNull(json['product_id']),
      productName: name,
      imageUrl: image,
      quantity: asInt(json['quantity']),
      price: asDouble(json['price']),
      notes: asStringOrNull(json['notes']),
      comboItems: combo,
    );
  }
}

/// An order already placed, as shown on the orders screen.
class OrderModel {
  OrderModel({
    required this.id,
    required this.tokenNumber,
    required this.locationId,
    required this.orderType,
    required this.status,
    required this.rawStatus,
    required this.paymentStatus,
    required this.subtotal,
    required this.taxAmount,
    required this.discountAmount,
    required this.deliveryCharge,
    required this.total,
    required this.discountId,
    required this.tableName,
    required this.customerName,
    required this.deliveryTime,
    required this.deliveryAddress,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    required this.items,
    required this.paidVia,
  });

  final int id;

  /// The counter number for the day, issued by the API and reset each morning
  /// at 00:15. Null only for orders taken before the feature existed.
  final int? tokenNumber;

  final int? locationId;
  final OrderType orderType;
  final OrderStatus? status;
  final String rawStatus;
  final String? paymentStatus;
  final double subtotal;
  final double taxAmount;
  final double discountAmount;
  final double deliveryCharge;
  final double total;
  final int? discountId;
  final String? tableName;
  final String? customerName;
  final DateTime? deliveryTime;
  final String? deliveryAddress;
  final double? latitude;
  final double? longitude;
  final DateTime? createdAt;
  final List<OrderItemModel> items;

  /// Method of the first completed payment, printed on the receipt.
  final String? paidVia;

  bool get isPaid => paymentStatus == 'paid';
  String get statusLabel => status?.label ?? rawStatus;
  bool get hasLogistics =>
      orderType == OrderType.delivery || orderType == OrderType.catering;

  /// Cancelling is only offered before the kitchen has finished.
  bool get isCancellable =>
      status == OrderStatus.pending || status == OrderStatus.cooking;

  /// Heading shown on the card: the table for dine-in, else the order type.
  String get heading =>
      tableName ?? orderType.label.toUpperCase().replaceAll('-', ' ');

  /// The next step(s) available, mirroring the web `getNextActions`.
  List<OrderTransition> get nextTransitions {
    if (status == OrderStatus.pending) {
      return const [OrderTransition('Cook', 'cooking')];
    }
    if (status == OrderStatus.cooking) {
      return const [OrderTransition('Cooked', 'cooked')];
    }

    switch (orderType) {
      case OrderType.dineIn:
        if (status == OrderStatus.cooked) {
          return const [OrderTransition('Serve', 'served')];
        }
      case OrderType.takeaway:
        if (status == OrderStatus.cooked) {
          return const [OrderTransition('Pack', 'packed')];
        }
      case OrderType.delivery:
      case OrderType.catering:
        if (status == OrderStatus.cooked) {
          return const [OrderTransition('Pack', 'packed')];
        }
        if (status == OrderStatus.packed) {
          return const [OrderTransition('Pick Up', 'picked')];
        }
        if (status == OrderStatus.picked) {
          return const [OrderTransition('Deliver', 'delivered')];
        }
    }
    return const [];
  }

  /// An order is finished once it is paid and has reached its final state.
  /// Matches the `isCompleted` rule the web orders screen filters on.
  bool get isCompleted {
    if (!isPaid) return false;
    return status == OrderStatus.served ||
        status == OrderStatus.delivered ||
        (status == OrderStatus.packed && orderType == OrderType.takeaway);
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final table = json['table'];
    final customer = json['customer'];
    final rawItems = json['items'];

    String? paidVia;
    final payments = json['payments'];
    if (payments is List) {
      for (final p in payments) {
        if (p is! Map) continue;
        final method = asStringOrNull(p['method']);
        if (method != null) {
          paidVia = method;
          break;
        }
      }
    }

    return OrderModel(
      id: asInt(json['id']),
      tokenNumber: asIntOrNull(json['token_number']),
      locationId: asIntOrNull(json['location_id']),
      orderType: OrderType.fromValue('${json['order_type']}'),
      status: OrderStatus.fromValue(asStringOrNull(json['status'])),
      rawStatus: asStringOrNull(json['status']) ?? 'pending',
      paymentStatus: asStringOrNull(json['payment_status']),
      subtotal: asDouble(json['subtotal']),
      taxAmount: asDouble(json['tax_amount']),
      discountAmount: asDouble(json['discount_amount']),
      deliveryCharge: asDouble(json['delivery_charge']),
      total: asDouble(json['total']),
      discountId: asIntOrNull(json['discount_id']),
      tableName: table is Map ? asStringOrNull(table['name']) : null,
      customerName: customer is Map ? asStringOrNull(customer['name']) : null,
      deliveryTime: DateTime.tryParse('${json['delivery_time']}'),
      deliveryAddress: asStringOrNull(json['delivery_address']),
      latitude: json['latitude'] == null ? null : asDouble(json['latitude']),
      longitude: json['longitude'] == null ? null : asDouble(json['longitude']),
      createdAt: DateTime.tryParse('${json['created_at']}'),
      paidVia: paidVia,
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map((i) => OrderItemModel.fromJson(Map<String, dynamic>.from(i)))
                .toList()
          : const [],
    );
  }
}

/// Payment methods offered at checkout, from the web `PaymentMethodSelector`.
enum PaymentMethod {
  cash('cash', 'Cash'),
  card('card', 'Card'),
  mfs('mfs', 'MFS');

  const PaymentMethod(this.value, this.label);

  final String value;
  final String label;
}

/// A line in the current order.
class CartItem {
  CartItem({
    required this.product,
    this.qty = 1,
    this.notes = '',
    this.discountKind,
    this.discountValue,
  });

  final ProductModel product;
  int qty;
  String notes;

  /// "The steak came out cold, take 200 off it." Priced by the server; this is
  /// what the cashier chose. See core-api's DiscountCalculator.
  DiscountKind? discountKind;
  double? discountValue;

  int get id => product.id;
  double get lineTotal => product.price * qty;

  double get lineDiscount =>
      DiscountCalculator.amount(discountKind, discountValue, lineTotal);

  double get lineNet => lineTotal - lineDiscount;

  CartItem copy() => CartItem(
    product: product,
    qty: qty,
    notes: notes,
    discountKind: discountKind,
    discountValue: discountValue,
  );
}

/// An order parked so the terminal can serve the next customer.
class HeldOrder {
  HeldOrder({
    required this.id,
    required this.items,
    required this.orderType,
    required this.tableId,
    required this.customerId,
  });

  final int id;
  final List<CartItem> items;
  final String orderType;
  final int? tableId;
  final int? customerId;

  int get itemCount => items.fold(0, (sum, i) => sum + i.qty);
}

/// Order types supported by the POS, matching the web `OrderTypeSelector`.
enum OrderType {
  dineIn('dine_in', 'Dine-in'),
  takeaway('takeaway', 'Takeaway'),
  delivery('delivery', 'Delivery'),
  catering('catering', 'Catering');

  const OrderType(this.value, this.label);

  final String value;
  final String label;

  static OrderType fromValue(String value) => OrderType.values.firstWhere(
    (t) => t.value == value,
    orElse: () => OrderType.dineIn,
  );

  bool get needsTable => this == OrderType.dineIn;
  bool get needsTime =>
      this == OrderType.takeaway ||
      this == OrderType.delivery ||
      this == OrderType.catering;
  bool get needsAddress => this == OrderType.delivery || this == OrderType.catering;
  bool get needsDeliveryCharge => this == OrderType.delivery;
}

/// Somebody who can be credited with a sale.
///
/// Distinct from the account running the till, which is very often shared —
/// see core-api's served_by_user_id migration.
class EmployeeModel {
  const EmployeeModel({required this.id, required this.name, this.email});

  final int id;
  final String name;
  final String? email;

  factory EmployeeModel.fromJson(Map<String, dynamic> json) => EmployeeModel(
    id: asIntOrNull(json['id']) ?? 0,
    name: asStringOrNull(json['name']) ?? 'Employee',
    email: asStringOrNull(json['email']),
  );
}

/// A third party that sends the restaurant orders and keeps a cut.
class PartnerModel {
  const PartnerModel({
    required this.id,
    required this.name,
    required this.commissionRate,
  });

  final int id;
  final String name;
  final double commissionRate;

  factory PartnerModel.fromJson(Map<String, dynamic> json) => PartnerModel(
    id: asIntOrNull(json['id']) ?? 0,
    name: asStringOrNull(json['name']) ?? 'Partner',
    commissionRate: asDouble(json['commission_rate']),
  );
}

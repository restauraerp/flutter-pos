import '../../core/api/api_client.dart';
import '../models/models.dart';

/// Everything the POS screen loads on boot, fetched in one round trip.
class PosBootstrap {
  PosBootstrap({
    required this.products,
    required this.categories,
    required this.customers,
    required this.discounts,
    required this.locations,
    required this.settings,
    required this.taxRate,
    required this.employees,
    required this.partners,
  });

  final List<ProductModel> products;
  final List<CategoryModel> categories;
  final List<CustomerModel> customers;
  final List<DiscountModel> discounts;
  final List<LocationModel> locations;
  final Map<String, String> settings;

  /// The restaurant's own combined tax rate, as a fraction.
  ///
  /// Read from its tax rules rather than hardcoded. The till used to carry a
  /// constant 10%, which is the fault TaxCalculator was written to fix on the
  /// server: a rate that appears nowhere in the system, shown to a customer on
  /// a total the server then computes differently.
  final double taxRate;

  final List<EmployeeModel> employees;
  final List<PartnerModel> partners;
}

class PosRepository {
  PosRepository(this._api);

  final ApiClient _api;

  Future<PosBootstrap> bootstrap() async {
    final responses = await Future.wait([
      _api.get('/products', query: {'nopaginate': 1}),
      _api.get('/website-settings'),
      _api.get('/product-categories', query: {'nopaginate': 1}),
      _api.get('/customers', query: {'nopaginate': 1}),
      _api.get('/discounts'),
      _api.get('/locations'),
      _api.get('/tax-rules'),
      // Both are optional: a tier without them answers 403, and a till that
      // cannot open because it could not list employees is worse than one that
      // simply does not offer the picker.
      _optional('/users', query: {'nopaginate': 1}),
      _optional('/partners', query: {'nopaginate': 1, 'active_only': 1}),
    ]);

    final settings = <String, String>{};
    for (final row in ApiClient.unwrapList(responses[1])) {
      final key = asStringOrNull(row['key']);
      if (key != null) settings[key] = '${row['value'] ?? ''}';
    }

    return PosBootstrap(
      products: ApiClient.unwrapList(
        responses[0],
      ).map(ProductModel.fromJson).toList(),
      settings: settings,
      categories: ApiClient.unwrapList(
        responses[2],
      ).map(CategoryModel.fromJson).toList(),
      customers: ApiClient.unwrapList(
        responses[3],
      ).map(CustomerModel.fromJson).toList(),
      discounts: ApiClient.unwrapList(
        responses[4],
      ).map(DiscountModel.fromJson).toList(),
      locations: ApiClient.unwrapList(
        responses[5],
      ).map(LocationModel.fromJson).toList(),
      // Summed, not compounded: two 5% rules are 10% of the same base.
      taxRate: ApiClient.unwrapList(responses[6])
              .where((rule) => rule['is_active'] == true || rule['is_active'] == 1)
              .fold<double>(0, (sum, rule) => sum + asDouble(rule['percentage'])) /
          100,
      employees: ApiClient.unwrapList(
        responses[7],
      ).map(EmployeeModel.fromJson).toList(),
      partners: ApiClient.unwrapList(
        responses[8],
      ).map(PartnerModel.fromJson).toList(),
    );
  }

  /// A call whose failure should not stop the till opening.
  Future<dynamic> _optional(String path, {Map<String, dynamic>? query}) async {
    try {
      return await _api.get(path, query: query);
    } on ApiException {
      return <dynamic>[];
    }
  }

  Future<List<TableModel>> tablesFor(int locationId) async {
    final response = await _api.get('/locations/$locationId/tables');
    return ApiClient.unwrapList(response).map(TableModel.fromJson).toList();
  }

  Future<CustomerModel> createCustomer({
    required String name,
    required String phone,
    String? email,
    String? address,
    String? organizationName,
    String? googleMapLocation,
  }) async {
    final response = await _api.post(
      '/customers',
      body: {
        'name': name,
        'phone': phone,
        if (email != null && email.isNotEmpty) 'email': email,
        if (address != null && address.isNotEmpty) 'address': address,
        if (organizationName != null && organizationName.isNotEmpty)
          'organization_name': organizationName,
        if (googleMapLocation != null && googleMapLocation.isNotEmpty)
          'google_map_location': googleMapLocation,
      },
    );
    return CustomerModel.fromJson(ApiClient.unwrapMap(response));
  }

  /// Active orders for a branch — anything not yet paid *and* finished.
  ///
  /// `active_only` is applied server-side; the location filter is passed as a
  /// query param so a busy branch does not download every other branch's
  /// orders on a 10-second refresh.
  Future<List<OrderModel>> activeOrders({int? locationId}) async {
    final response = await _api.get(
      '/orders',
      query: {
        'nopaginate': 1,
        'active_only': 1,
        'location_id': ?locationId,
      },
    );
    return ApiClient.unwrapList(response).map(OrderModel.fromJson).toList();
  }

  /// A single order with its items, products, and payments — everything the
  /// kitchen ticket and the customer receipt need to print.
  Future<OrderModel> order(int orderId) async {
    final response = await _api.get('/orders/$orderId');
    return OrderModel.fromJson(ApiClient.unwrapMap(response));
  }

  Future<void> updateOrderStatus(int orderId, String status) async {
    await _api.put('/orders/$orderId', body: {'status': status});
  }

  /// Settles an order: records the payment method and the final amounts, which
  /// may have changed if a coupon was applied at the till.
  Future<void> payOrder({
    required int orderId,
    required String paymentMethod,
    required int? discountId,
    required double discountAmount,
    required double taxAmount,
    required double deliveryCharge,
    required double total,
    String? paymentNote,
  }) async {
    await _api.put(
      '/orders/$orderId',
      body: {
        'payment_method': paymentMethod,
        // Why this payment looks the way it does - a bKash transaction id, a
        // card's last four, which guest settled a shared table.
        if (paymentNote != null && paymentNote.isNotEmpty) 'payment_note': paymentNote,
        'discount_id': discountId,
        'discount_amount': discountAmount.toStringAsFixed(2),
        'delivery_charge': deliveryCharge.toStringAsFixed(2),
        'tax_amount': taxAmount.toStringAsFixed(2),
        'total': total.toStringAsFixed(2),
      },
    );
  }

  /// Lets an order leave unpaid, to be collected later.
  ///
  /// The API insists on a customer and a note: an unnamed debt cannot be
  /// collected, and the arrangement - a room number, a company account - would
  /// otherwise live only in the memory of whoever was on shift.
  Future<void> markOrderDue(int orderId, String note) async {
    await _api.post('/orders/$orderId/due', body: {'due_note': note});
  }

  /// Records money collected against a due order, in part or in full.
  Future<void> settleOrder({
    required int orderId,
    required double amount,
    required String method,
    String? note,
  }) async {
    await _api.post(
      '/orders/$orderId/settle',
      body: {
        'amount': amount.toStringAsFixed(2),
        'method': method,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
  }

  /// Orders the restaurant is owed for.
  Future<List<OrderModel>> dueOrders({int? locationId}) async {
    final response = await _api.get(
      '/orders',
      query: {'nopaginate': 1, 'due_only': 1, 'location_id': ?locationId},
    );
    return ApiClient.unwrapList(response).map(OrderModel.fromJson).toList();
  }

  Future<void> cancelOrder(int orderId) async {
    await _api.delete('/orders/$orderId');
  }

  /// Submits the order. Returns the new order id.
  Future<int> placeOrder(Map<String, dynamic> payload) async {
    final response = await _api.post('/orders', body: payload);
    final order = ApiClient.unwrapMap(response);
    final id = asIntOrNull(order['id']);
    if (id == null) {
      throw ApiException('The order was submitted but the server returned no id.');
    }
    return id;
  }
}

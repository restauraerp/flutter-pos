import 'package:flutter_test/flutter_test.dart';
import 'package:pos/data/models/models.dart';
import 'package:pos/services/ticket_printer.dart';

OrderModel order({
  String type = 'dine_in',
  String status = 'pending',
  String? paymentStatus,
  Map<String, dynamic> extra = const {},
}) => OrderModel.fromJson({
  'id': 1,
  'order_type': type,
  'status': status,
  'payment_status': paymentStatus,
  'subtotal': '100',
  ...extra,
});

void main() {
  group('OrderModel.nextTransitions', () {
    test('a new order goes to the kitchen first', () {
      expect(
        order(status: 'pending').nextTransitions.single.status,
        'cooking',
      );
      expect(
        order(status: 'cooking').nextTransitions.single.status,
        'cooked',
      );
    });

    test('dine-in is served once cooked', () {
      expect(
        order(type: 'dine_in', status: 'cooked').nextTransitions.single.status,
        'served',
      );
    });

    test('takeaway is packed and then finished', () {
      expect(
        order(type: 'takeaway', status: 'cooked').nextTransitions.single.status,
        'packed',
      );
      expect(
        order(type: 'takeaway', status: 'packed').nextTransitions,
        isEmpty,
      );
    });

    test('delivery runs pack -> pick up -> deliver', () {
      expect(
        order(type: 'delivery', status: 'cooked').nextTransitions.single.status,
        'packed',
      );
      expect(
        order(type: 'delivery', status: 'packed').nextTransitions.single.status,
        'picked',
      );
      expect(
        order(type: 'delivery', status: 'picked').nextTransitions.single.status,
        'delivered',
      );
      expect(
        order(type: 'delivery', status: 'delivered').nextTransitions,
        isEmpty,
      );
    });

    test('catering follows the delivery flow', () {
      expect(
        order(type: 'catering', status: 'packed').nextTransitions.single.status,
        'picked',
      );
    });
  });

  group('OrderModel.isCompleted', () {
    test('an unpaid order is never complete, however far along', () {
      expect(order(type: 'dine_in', status: 'served').isCompleted, isFalse);
    });

    test('paid and served/delivered is complete', () {
      expect(
        order(
          type: 'dine_in',
          status: 'served',
          paymentStatus: 'paid',
        ).isCompleted,
        isTrue,
      );
      expect(
        order(
          type: 'delivery',
          status: 'delivered',
          paymentStatus: 'paid',
        ).isCompleted,
        isTrue,
      );
    });

    test('packed completes takeaway but not delivery', () {
      expect(
        order(
          type: 'takeaway',
          status: 'packed',
          paymentStatus: 'paid',
        ).isCompleted,
        isTrue,
      );
      expect(
        order(
          type: 'delivery',
          status: 'packed',
          paymentStatus: 'paid',
        ).isCompleted,
        isFalse,
      );
    });

    test('a paid order still cooking is not complete', () {
      expect(
        order(status: 'cooking', paymentStatus: 'paid').isCompleted,
        isFalse,
      );
    });
  });

  group('OrderModel', () {
    test('cancelling is only offered before the food is cooked', () {
      expect(order(status: 'pending').isCancellable, isTrue);
      expect(order(status: 'cooking').isCancellable, isTrue);
      expect(order(status: 'cooked').isCancellable, isFalse);
      expect(order(status: 'served').isCancellable, isFalse);
    });

    test('heading prefers the table, falling back to the order type', () {
      expect(
        order(extra: {
          'table': {'name': 'VIP Table 1'},
        }).heading,
        'VIP Table 1',
      );
      expect(order(type: 'takeaway').heading, 'TAKEAWAY');
    });

    test('reads line items using the quantity field the API returns', () {
      final o = order(extra: {
        'items': [
          {'id': 5, 'product_id': 9, 'quantity': 3, 'price': '12.50'},
        ],
      });
      expect(o.items.single.quantity, 3);
      expect(o.items.single.price, 12.5);
    });

    test('reads the day\'s token number the API issued', () {
      expect(order(extra: {'token_number': 42}).tokenNumber, 42);
      // Sent as a string by some JSON encoders - still a number here.
      expect(order(extra: {'token_number': '7'}).tokenNumber, 7);
    });

    test('an order taken before token numbers existed has none', () {
      // The slip builders check for null and print no banner rather than an
      // empty one, so this must not become 0.
      expect(order().tokenNumber, isNull);
      expect(order(extra: {'token_number': null}).tokenNumber, isNull);
    });

    test('an unknown status still renders rather than crashing', () {
      final o = order(status: 'something_new');
      expect(o.status, isNull);
      expect(o.statusLabel, 'something_new');
      expect(o.nextTransitions, isEmpty);
    });
  });

  group('UserModel branch scoping', () {
    test('a user with a location is tied to that branch', () {
      final u = UserModel.fromJson({
        'id': 1,
        'name': 'POS Manager',
        'email': 'p@e.com',
        'location_id': 2,
        'all_permissions': ['view_pos'],
      });
      expect(u.isBranchScoped, isTrue);
      expect(u.locationId, 2);
    });

    test('a user with no location may oversee every branch', () {
      final u = UserModel.fromJson({
        'id': 1,
        'name': 'Admin',
        'email': 'a@e.com',
        'all_permissions': ['view_pos'],
      });
      expect(u.isBranchScoped, isFalse);
    });

    test('order permissions are read independently of POS access', () {
      final u = UserModel.fromJson({
        'id': 1,
        'name': 'POS Manager',
        'email': 'p@e.com',
        'all_permissions': ['view_pos', 'view_orders'],
      });
      expect(u.canViewOrders, isTrue);
      expect(u.canUpdateOrderStatus, isFalse);
    });
  });

  group('VenueDetails', () {
    test('reads the venue header from website settings', () {
      final v = VenueDetails.fromSettings({
        'site_name': 'La Bella Cucina',
        'address': 'Road 27, Banani',
        'contact_phone': '+880 1700-000000',
        'currency_symbol': '\u09f3',
      });
      expect(v.name, 'La Bella Cucina');
      expect(v.address, 'Road 27, Banani');
      expect(v.phone, '+880 1700-000000');
      expect(v.currency, '\u09f3');
    });

    test('falls back when settings are missing or blank', () {
      final v = VenueDetails.fromSettings({'site_name': '   '});
      expect(v.name, 'RestoraERP');
      expect(v.address, isNull);
      expect(v.phone, isNull);
      expect(v.currency, '\u09f3');
    });
  });
}

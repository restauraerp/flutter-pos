import 'package:flutter_test/flutter_test.dart';
import 'package:pos/data/models/models.dart';

void main() {
  group('ProductModel.isAvailableAt', () {
    ProductModel product(Map<String, dynamic> json) =>
        ProductModel.fromJson({'id': 1, 'name': 'Burger', 'price': '10', ...json});

    test('a product with no location pivot is available everywhere', () {
      expect(product({}).isAvailableAt(7), isTrue);
    });

    test('respects an is_available pivot flag', () {
      final p = product({
        'locations': [
          {
            'id': 7,
            'pivot': {'is_available': 1},
          },
          {
            'id': 8,
            'pivot': {'is_available': 0},
          },
        ],
      });

      expect(p.isAvailableAt(7), isTrue);
      expect(p.isAvailableAt(8), isFalse);
    });

    test('a location absent from the pivot is unavailable', () {
      final p = product({
        'locations': [
          {
            'id': 7,
            'pivot': {'is_available': true},
          },
        ],
      });

      expect(p.isAvailableAt(9), isFalse);
    });

    test('no active location means no filtering', () {
      final p = product({
        'locations': [
          {
            'id': 7,
            'pivot': {'is_available': 0},
          },
        ],
      });

      expect(p.isAvailableAt(null), isTrue);
    });
  });

  group('ProductModel parsing', () {
    test('reads prices sent as strings or numbers', () {
      expect(
        ProductModel.fromJson({'id': 1, 'name': 'A', 'price': '12.50'}).price,
        12.5,
      );
      expect(
        ProductModel.fromJson({'id': 1, 'name': 'A', 'price': 12.5}).price,
        12.5,
      );
      expect(
        ProductModel.fromJson({'id': 1, 'name': 'A', 'price': null}).price,
        0,
      );
    });
  });

  group('DiscountModel', () {
    test('percentage discounts scale with the subtotal', () {
      final d = DiscountModel.fromJson({
        'id': 1,
        'code': 'SAVE10',
        'discount_type': 'percentage',
        'value': '10',
        'is_active': 1,
      });

      expect(d.amountFor(200), 20);
    });

    test('fixed discounts ignore the subtotal', () {
      final d = DiscountModel.fromJson({
        'id': 2,
        'code': 'FLAT50',
        'discount_type': 'fixed',
        'value': '50',
        'is_active': 1,
      });

      expect(d.amountFor(200), 50);
      expect(d.amountFor(10), 50);
    });

    test('flags an expired coupon', () {
      final d = DiscountModel.fromJson({
        'id': 3,
        'code': 'OLD',
        'discount_type': 'fixed',
        'value': '5',
        'valid_until': '2020-01-01T00:00:00Z',
        'is_active': 1,
      });

      expect(d.isExpired, isTrue);
    });

    test('a coupon with no end date never expires', () {
      final d = DiscountModel.fromJson({
        'id': 4,
        'code': 'FOREVER',
        'discount_type': 'fixed',
        'value': '5',
        'is_active': 1,
      });

      expect(d.isExpired, isFalse);
    });
  });

  group('UserModel', () {
    test('gates the terminal on view_pos', () {
      final allowed = UserModel.fromJson({
        'id': 1,
        'name': 'Manager',
        'email': 'm@e.com',
        'all_permissions': ['view_pos', 'create_pos_order'],
      });
      final denied = UserModel.fromJson({
        'id': 2,
        'name': 'Chef',
        'email': 'c@e.com',
        'all_permissions': ['view_kitchen_kiosk'],
      });

      expect(allowed.canUsePos, isTrue);
      expect(denied.canUsePos, isFalse);
    });

    test('a user with no permissions payload is denied', () {
      final user = UserModel.fromJson({
        'id': 3,
        'name': 'Nobody',
        'email': 'n@e.com',
      });

      expect(user.canUsePos, isFalse);
    });
  });

  group('CartItem', () {
    test('line total multiplies price by quantity', () {
      final item = CartItem(
        product: ProductModel.fromJson({
          'id': 1,
          'name': 'Pizza',
          'price': '12.50',
        }),
        qty: 3,
      );

      expect(item.lineTotal, 37.5);
    });
  });

  group('OrderType', () {
    test('maps API values and falls back to dine-in', () {
      expect(OrderType.fromValue('delivery'), OrderType.delivery);
      expect(OrderType.fromValue('nonsense'), OrderType.dineIn);
    });

    test('only dine-in needs a table', () {
      expect(OrderType.dineIn.needsTable, isTrue);
      expect(OrderType.delivery.needsTable, isFalse);
    });

    test('only delivery carries a delivery charge', () {
      expect(OrderType.delivery.needsDeliveryCharge, isTrue);
      expect(OrderType.catering.needsDeliveryCharge, isFalse);
    });
  });

  group('ComboComponent & combo products', () {
    Map<String, dynamic> comboProduct() => {
          'id': 5,
          'name': 'Lunch Combo',
          'price': '350',
          'type': 'combo',
          'combo_items': [
            {'quantity': 1, 'product': {'name': 'Burger'}},
            {'quantity': 2, 'product': {'name': 'Coke'}},
            {'quantity': 1, 'inventory_item': {'title': 'Fries'}},
          ],
        };

    test('a combo product parses its type and contents', () {
      final p = ProductModel.fromJson(comboProduct());
      expect(p.isCombo, isTrue);
      expect(p.comboItems.map((c) => c.name),
          containsAll(<String>['Burger', 'Coke', 'Fries']));
    });

    test('an inventory component falls back to its title', () {
      final p = ProductModel.fromJson(comboProduct());
      expect(p.comboItems.any((c) => c.name == 'Fries'), isTrue);
    });

    test('a quantity above one is shown, a single unit is not', () {
      final p = ProductModel.fromJson(comboProduct());
      final coke = p.comboItems.firstWhere((c) => c.name == 'Coke');
      final burger = p.comboItems.firstWhere((c) => c.name == 'Burger');
      expect(coke.label, '2 × Coke');
      expect(burger.label, 'Burger');
    });

    test('an ordinary product is not a combo', () {
      final p = ProductModel.fromJson({'id': 1, 'name': 'Tea', 'price': '20'});
      expect(p.isCombo, isFalse);
      expect(p.comboItems, isEmpty);
    });

    test('an order line carries the combo breakdown from its product', () {
      final item = OrderItemModel.fromJson({
        'id': 1,
        'product_id': 5,
        'quantity': 1,
        'price': '350',
        'product': comboProduct(),
      });
      expect(item.isCombo, isTrue);
      expect(item.comboItems.map((c) => c.label), contains('2 × Coke'));
    });
  });
}

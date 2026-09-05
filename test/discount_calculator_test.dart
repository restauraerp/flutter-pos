import 'package:flutter_test/flutter_test.dart';
import 'package:pos/core/sales/discount_calculator.dart';
import 'package:pos/data/models/models.dart';

/// The till's arithmetic has to agree with the server's, because the server is
/// what actually charges. These figures are the same ones asserted in core-api's
/// tests/Unit/DiscountCalculatorTest.php — if the two ever drift, the till will
/// quote one total and take another.
void main() {
  ProductModel product(double price) => ProductModel(
    id: 1,
    name: 'Test',
    price: price,
    categoryId: 1,
    imageUrl: null,
    locationAvailability: const {},
  );

  group('one reduction against one base', () {
    test('a flat reduction comes straight off', () {
      expect(DiscountCalculator.amount(DiscountKind.flat, 200, 1000), 200);
    });

    test('a percentage is of the base it is applied to', () {
      expect(DiscountCalculator.amount(DiscountKind.percent, 10, 1000), 100);
    });

    test('nothing can be discounted below zero', () {
      expect(DiscountCalculator.amount(DiscountKind.flat, 99999, 100), 100);
    });

    test('a negative or zero value takes nothing off', () {
      expect(DiscountCalculator.amount(DiscountKind.flat, -50, 1000), 0);
      expect(DiscountCalculator.amount(DiscountKind.percent, 0, 1000), 0);
      expect(DiscountCalculator.amount(DiscountKind.flat, 50, 0), 0);
    });
  });

  group('a cart line', () {
    test('a percentage applies to the whole line, not the unit price', () {
      final item = CartItem(product: product(500), qty: 2)
        ..discountKind = DiscountKind.percent
        ..discountValue = 10;

      expect(item.lineTotal, 1000);
      expect(item.lineDiscount, 100);
      expect(item.lineNet, 900);
    });

    test('a line with no discount loses nothing', () {
      final item = CartItem(product: product(500), qty: 2);

      expect(item.lineDiscount, 0);
      expect(item.lineNet, 1000);
    });

    test('a copy carries the discount, so holding an order keeps it', () {
      final item = CartItem(product: product(500), qty: 1)
        ..discountKind = DiscountKind.flat
        ..discountValue = 50;

      expect(item.copy().lineDiscount, 50);
    });
  });

  group('the coupon table spells percentage differently', () {
    test('both spellings mean the same thing', () {
      expect(DiscountCalculator.kindFromApi('percent'), DiscountKind.percent);
      expect(DiscountCalculator.kindFromApi('percentage'), DiscountKind.percent);
      expect(DiscountCalculator.kindFromApi('flat'), DiscountKind.flat);
      expect(DiscountCalculator.kindFromApi(null), isNull);
    });
  });
}

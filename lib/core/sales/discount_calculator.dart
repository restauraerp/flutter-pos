/// What comes off a bill, mirroring core-api's App\Support\Sales\DiscountCalculator.
///
/// The server decides what is stored — it recomputes every figure from the
/// lines and overwrites whatever the till posts. This exists so the number on
/// the screen is the number that will be charged: a till that quotes one total
/// and takes another is its own problem, whichever of the two is right.
///
/// Three reductions can hit one bill and the order they stack in changes the
/// answer, so it is the same order here as on the server:
///
///   1. Per-item discounts.
///   2. A redeemed coupon, against what is left.
///   3. A discount on the bill, against what is left after that.
///
/// Percentages apply to what remains at their step, so two 50% reductions take
/// three quarters off rather than all of it. Nothing goes below zero: a flat
/// discount larger than what it applies to is capped, never a refund.
library;

enum DiscountKind {
  flat('flat'),
  percent('percent');

  const DiscountKind(this.value);

  final String value;
}

class DiscountCalculator {
  const DiscountCalculator._();

  /// One reduction against one base.
  static double amount(DiscountKind? kind, double? value, double base) {
    final v = value ?? 0;
    if (v <= 0 || base <= 0) return 0;

    final off = kind == DiscountKind.percent ? base * v / 100 : v;

    return _round(off < base ? off : base);
  }

  /// The coupon table stores `percentage`; the till sends `percent`. Both mean
  /// the same thing and both have to work.
  static DiscountKind? kindFromApi(String? type) {
    if (type == null) return null;
    if (type == 'percent' || type == 'percentage') return DiscountKind.percent;
    if (type == 'flat') return DiscountKind.flat;
    return null;
  }

  static double _round(double value) => (value * 100).roundToDouble() / 100;
}

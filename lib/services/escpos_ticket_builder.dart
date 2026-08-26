import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import '../data/models/models.dart';
import 'ticket_printer.dart' show VenueDetails;

/// Builds the raw ESC/POS byte stream for the two thermal documents, laid out
/// for a 58mm roll (the MPT-II and most handheld Bluetooth POS printers).
///
/// This is the direct-print counterpart to [TicketPrinter], which produces a
/// PDF for the system print path. Here the commands are sent straight to the
/// printer over Bluetooth, so there is no preview step.
///
/// ESC/POS printers render a single-byte code page (Latin-1 here), so every
/// dynamic string is passed through [_safe]: the Taka sign becomes `Tk` and any
/// other non-Latin glyph is dropped to `?` rather than crashing the encoder.
class EscPosTicketBuilder {
  const EscPosTicketBuilder._();

  static const PaperSize _paper = PaperSize.mm58;

  /// Kitchen Order Ticket — what to cook, with no prices.
  static Future<List<int>> kitchenTicket(OrderModel order) async {
    final profile = await CapabilityProfile.load();
    final g = Generator(_paper, profile);
    var bytes = <int>[];

    bytes += _tokenBanner(g, order);
    bytes += g.text(
      'KITCHEN ORDER TICKET',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += g.text(
      _safe(order.orderType.label.toUpperCase()),
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    bytes += g.hr();

    bytes += g.row([
      PosColumn(
        text: 'Order #${order.id}',
        width: 6,
        styles: const PosStyles(bold: true),
      ),
      PosColumn(
        text: _time(order.createdAt),
        width: 6,
        styles: const PosStyles(bold: true, align: PosAlign.right),
      ),
    ]);
    if (order.tableName != null) {
      bytes += g.text(
        _safe('Table: ${order.tableName}'),
        styles: const PosStyles(bold: true),
      );
    }
    if (order.hasLogistics) {
      bytes += g.text(
        order.deliveryTime == null
            ? 'Deliver: ASAP'
            : 'Deliver: ${_dateTime(order.deliveryTime)}',
        styles: const PosStyles(bold: true),
      );
    }
    bytes += g.hr(ch: '=');

    for (final item in order.items) {
      // Quantity first and bold — the kitchen reads counts at a glance.
      bytes += g.row([
        PosColumn(
          text: '${item.quantity}x',
          width: 2,
          styles: const PosStyles(bold: true),
        ),
        PosColumn(
          text: _safe(item.displayName),
          width: 10,
          styles: const PosStyles(bold: true),
        ),
      ]);
      if (item.notes != null) {
        bytes += g.text(
          _safe('  * ${item.notes}'),
          styles: const PosStyles(fontType: PosFontType.fontB),
        );
      }
    }

    bytes += g.hr();
    bytes += g.feed(2);
    bytes += g.cut();
    return bytes;
  }

  /// Customer receipt — itemised, with totals and payment method.
  static Future<List<int>> receipt(OrderModel order, VenueDetails venue) async {
    final profile = await CapabilityProfile.load();
    final g = Generator(_paper, profile);
    var bytes = <int>[];

    String money(double v) => '${_safe(venue.currency)}${v.toStringAsFixed(2)}';

    bytes += _tokenBanner(g, order);
    bytes += g.text(
      _safe(venue.name.toUpperCase()),
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    if (venue.address != null) {
      bytes += g.text(
        _safe(venue.address!),
        styles: const PosStyles(align: PosAlign.center),
      );
    }
    if (venue.phone != null) {
      bytes += g.text(
        _safe(venue.phone!),
        styles: const PosStyles(align: PosAlign.center),
      );
    }
    bytes += g.hr();

    bytes += _kv(g, 'Order #${order.id}', _dateTime(order.createdAt));
    bytes += _kv(
      g,
      _safe(order.orderType.label.toUpperCase()),
      _safe(order.statusLabel.toUpperCase()),
    );
    if (order.tableName != null) {
      bytes += _kv(g, 'Table', _safe(order.tableName!));
    }
    if (order.customerName != null) {
      bytes += _kv(g, 'Customer', _safe(order.customerName!));
    }
    bytes += g.hr();

    for (final item in order.items) {
      bytes += g.row([
        PosColumn(text: _safe(item.displayName), width: 7),
        PosColumn(
          text: '${item.quantity}',
          width: 2,
          styles: const PosStyles(align: PosAlign.center),
        ),
        PosColumn(
          text: money(item.price * item.quantity),
          width: 3,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
      if (item.notes != null) {
        bytes += g.text(
          _safe('  * ${item.notes}'),
          styles: const PosStyles(fontType: PosFontType.fontB),
        );
      }
    }
    bytes += g.hr();

    bytes += _kv(g, 'Subtotal', money(order.subtotal));
    if (order.discountAmount > 0) {
      bytes += _kv(g, 'Discount', '-${money(order.discountAmount)}');
    }
    bytes += _kv(g, 'Tax', money(order.taxAmount));
    if (order.deliveryCharge > 0) {
      bytes += _kv(g, 'Delivery', money(order.deliveryCharge));
    }
    bytes += g.hr(ch: '=');

    bytes += g.row([
      PosColumn(
        text: 'TOTAL',
        width: 6,
        styles: const PosStyles(
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
      PosColumn(
        text: money(order.total),
        width: 6,
        styles: const PosStyles(
          bold: true,
          align: PosAlign.right,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
    ]);

    if (order.paidVia != null) {
      bytes += g.feed(1);
      bytes += g.text(
        _safe('PAID VIA ${order.paidVia!.toUpperCase()}'),
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
    }

    bytes += g.feed(1);
    bytes += g.text(
      'Thank you for your visit!',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += g.text(
      'Powered by RestoraERP',
      styles: const PosStyles(align: PosAlign.center, fontType: PosFontType.fontB),
    );
    bytes += g.feed(2);
    bytes += g.cut();
    return bytes;
  }

  /// The day's counter number, as large as the roll allows, at the very top of
  /// every document.
  ///
  /// It leads because it is the only thing on the slip anyone reads from across
  /// a room - the customer checking whether 42 has been called, the runner
  /// matching a bag to a ticket. The order id stays further down: it is unique
  /// forever but five digits long by now, and nobody shouts it.
  ///
  /// Orders taken before token numbers existed have none, and get no banner
  /// rather than a blank one.
  static List<int> _tokenBanner(Generator g, OrderModel order) {
    if (order.tokenNumber == null) return const [];

    return [
      ...g.text(
        'TOKEN ${order.tokenNumber}',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
      ...g.hr(ch: '='),
    ];
  }

  /// A label/value line spanning the full width, value right-aligned.
  static List<int> _kv(Generator g, String left, String right) => g.row([
    PosColumn(text: left, width: 6),
    PosColumn(text: right, width: 6, styles: const PosStyles(align: PosAlign.right)),
  ]);

  /// Collapses a string to what a single-byte-codepage printer can render.
  static String _safe(String input) {
    final out = StringBuffer();
    for (final rune in input.runes) {
      switch (rune) {
        case 0x09F3: // ৳ Bengali Taka sign
          out.write('Tk');
        case _ when rune <= 0xFF:
          out.writeCharCode(rune);
        case _:
          out.write('?');
      }
    }
    return out.toString();
  }

  static String _time(DateTime? dt) {
    if (dt == null) return '';
    final l = dt.toLocal();
    return '${_two(l.hour)}:${_two(l.minute)}';
  }

  static String _dateTime(DateTime? dt) {
    if (dt == null) return '';
    final l = dt.toLocal();
    return '${l.year}-${_two(l.month)}-${_two(l.day)} ${_two(l.hour)}:${_two(l.minute)}';
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
}

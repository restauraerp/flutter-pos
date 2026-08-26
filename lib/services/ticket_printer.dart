import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/models/models.dart';

/// Venue details printed at the top of a customer receipt, taken from
/// `/website-settings` rather than hardcoded as the web receipt does.
class VenueDetails {
  const VenueDetails({
    required this.name,
    required this.address,
    required this.phone,
    required this.currency,
  });

  final String name;
  final String? address;
  final String? phone;
  final String currency;

  factory VenueDetails.fromSettings(Map<String, String> settings) {
    String? clean(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();
    return VenueDetails(
      name: clean(settings['site_name']) ?? 'RestoraERP',
      address: clean(settings['address']),
      phone: clean(settings['contact_phone']),
      currency: clean(settings['currency_symbol']) ?? '৳',
    );
  }
}

/// Builds and prints the two thermal documents a POS produces: the kitchen
/// order ticket and the customer receipt.
///
/// Both are laid out for an 80mm roll and returned as PDF bytes. The UI hands
/// them to an in-app [PdfPreview] page (see `PdfPreviewPage`), whose Print
/// action opens the platform print dialog (Android print service, AirPrint,
/// CUPS, Windows) — where a thermal printer appears once it is installed.
class TicketPrinter {
  const TicketPrinter._();

  /// The MPT-II (and most handheld Bluetooth POS printers) use a 58mm roll,
  /// whose printable area is ~48mm. `roll57` matches that; switch to `roll80`
  /// if a venue runs the wider 80mm desktop paper.
  static const PdfPageFormat _roll = PdfPageFormat.roll57;

  /// Characters in a full-width dashed rule. Tuned to the 58mm printable width
  /// so the line fills the paper without overflowing and clipping mid-dash.
  static const int _dashCount = 32;

  static pw.Font? _regular;

  /// The bundled subset of FreeSans. The PDF standard fonts have no glyph for
  /// ৳ (U+09F3), so a currency symbol would print as a blank box without this.
  static Future<pw.Font> _font() async {
    final cached = _regular;
    if (cached != null) return cached;
    final data = await rootBundle.load('assets/fonts/ReceiptSans.ttf');
    final font = pw.Font.ttf(data);
    _regular = font;
    return font;
  }

  /// Kitchen Order Ticket — what to cook, with no prices. Returns the PDF bytes
  /// for previewing/printing.
  static Future<Uint8List> buildKitchenTicket(OrderModel order) async {
    final font = await _font();
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: _roll,
        theme: pw.ThemeData.withFont(base: font, bold: font),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            ..._tokenBanner(order),
            pw.Center(
              child: pw.Text(
                'KITCHEN ORDER TICKET',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Center(
              child: pw.Text(
                order.orderType.label.toUpperCase(),
                style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Divider(thickness: 1.4, height: 6),

            _row('Order #${order.id}', _time(order.createdAt), bold: true),
            if (order.tableName != null) ...[
              pw.SizedBox(height: 3),
              pw.Text(
                'Table: ${order.tableName}',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
              ),
            ],
            if (order.hasLogistics) ...[
              pw.SizedBox(height: 3),
              pw.Text(
                order.deliveryTime == null
                    ? 'Deliver: ASAP'
                    : 'Deliver: ${_dateTime(order.deliveryTime)}',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
            ],

            pw.SizedBox(height: 4),
            _dashed(),
            pw.SizedBox(height: 4),

            // Quantity first and oversized — the kitchen reads counts at a glance.
            ...order.items.map(
              (item) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 7),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(
                      width: 32,
                      child: pw.Text(
                        '${item.quantity}x',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            item.displayName,
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          if (item.notes != null)
                            pw.Text(
                              '* ${item.notes}',
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontStyle: pw.FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            _dashed(),
            pw.SizedBox(height: 10),
          ],
        ),
      ),
    );

    return doc.save();
  }

  /// Customer receipt — itemised, with totals and payment method. Returns the
  /// PDF bytes for previewing/printing.
  static Future<Uint8List> buildReceipt(
    OrderModel order,
    VenueDetails venue,
  ) async {
    final font = await _font();
    final doc = pw.Document();
    String money(double v) => '${venue.currency}${v.toStringAsFixed(2)}';

    doc.addPage(
      pw.Page(
        pageFormat: _roll,
        theme: pw.ThemeData.withFont(base: font, bold: font),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            ..._tokenBanner(order),
            pw.Center(
              child: pw.Text(
                venue.name.toUpperCase(),
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
            ),
            if (venue.address != null) ...[
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(
                  venue.address!,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
            ],
            if (venue.phone != null) ...[
              pw.SizedBox(height: 1),
              pw.Center(
                child: pw.Text(
                  venue.phone!,
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
            ],

            pw.SizedBox(height: 8),
            _dashed(),
            pw.SizedBox(height: 4),

            _row('Order #${order.id}', _dateTime(order.createdAt)),
            pw.SizedBox(height: 2),
            _row(
              order.orderType.label.toUpperCase(),
              order.statusLabel.toUpperCase(),
            ),
            if (order.tableName != null) ...[
              pw.SizedBox(height: 2),
              _row('Table', order.tableName!),
            ],
            if (order.customerName != null) ...[
              pw.SizedBox(height: 2),
              _row('Customer', order.customerName!),
            ],

            pw.SizedBox(height: 4),
            _dashed(),
            pw.SizedBox(height: 4),

            ...order.items.map(
              (item) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            item.displayName,
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                        pw.SizedBox(
                          width: 20,
                          child: pw.Text(
                            '${item.quantity}',
                            textAlign: pw.TextAlign.center,
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                        pw.SizedBox(
                          width: 50,
                          child: pw.Text(
                            money(item.price * item.quantity),
                            textAlign: pw.TextAlign.right,
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                      ],
                    ),
                    if (item.notes != null)
                      pw.Text(
                        '* ${item.notes}',
                        style: pw.TextStyle(
                          fontSize: 7.5,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            pw.SizedBox(height: 2),
            _dashed(),
            pw.SizedBox(height: 4),

            _row('Subtotal', money(order.subtotal), size: 9),
            if (order.discountAmount > 0) ...[
              pw.SizedBox(height: 2),
              _row('Discount', '-${money(order.discountAmount)}', size: 9),
            ],
            pw.SizedBox(height: 2),
            _row('Tax', money(order.taxAmount), size: 9),
            if (order.deliveryCharge > 0) ...[
              pw.SizedBox(height: 2),
              _row('Delivery', money(order.deliveryCharge), size: 9),
            ],

            pw.SizedBox(height: 4),
            pw.Divider(thickness: 1, height: 4),
            _row('TOTAL', money(order.total), size: 13, bold: true),

            if (order.paidVia != null) ...[
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'PAID VIA ${order.paidVia!.toUpperCase()}',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                ),
              ),
            ],

            pw.SizedBox(height: 14),
            pw.Center(
              child: pw.Text(
                'Thank you for your visit!',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Center(
              child: pw.Text(
                'Powered by RestoraERP',
                style: const pw.TextStyle(fontSize: 7),
              ),
            ),
            pw.SizedBox(height: 10),
          ],
        ),
      ),
    );

    return doc.save();
  }

  /// The day's counter number, at the very top of every document.
  ///
  /// Matches the ESC/POS builder's banner so the same order reads the same on
  /// either print path. It leads because it is the only thing on the slip
  /// anyone reads from across a room; the order id stays further down, unique
  /// forever but far too long to shout.
  ///
  /// Orders taken before token numbers existed have none, and get no banner
  /// rather than a blank one.
  static List<pw.Widget> _tokenBanner(OrderModel order) {
    if (order.tokenNumber == null) return const [];

    return [
      pw.Center(
        child: pw.Text(
          'TOKEN ${order.tokenNumber}',
          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
        ),
      ),
      pw.SizedBox(height: 2),
      _dashed(),
      pw.SizedBox(height: 6),
    ];
  }

  static pw.Widget _row(
    String left,
    String right, {
    double size = 10,
    bool bold = false,
  }) {
    final style = pw.TextStyle(
      fontSize: size,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(left, style: style),
        pw.Text(right, style: style),
      ],
    );
  }

  /// A dashed rule, drawn as repeated hyphens so it survives on any thermal
  /// printer regardless of how it renders vector strokes.
  static pw.Widget _dashed() => pw.Text(
    '-' * _dashCount,
    maxLines: 1,
    overflow: pw.TextOverflow.clip,
    style: const pw.TextStyle(fontSize: 8),
  );

  static String _time(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    return '${_two(local.hour)}:${_two(local.minute)}';
  }

  static String _dateTime(DateTime? dt) {
    if (dt == null) return '';
    final l = dt.toLocal();
    return '${l.year}-${_two(l.month)}-${_two(l.day)} ${_two(l.hour)}:${_two(l.minute)}';
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
}

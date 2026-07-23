import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../../data/models/models.dart';
import '../../services/escpos_ticket_builder.dart';
import '../../services/thermal_printer.dart';
import '../../services/ticket_printer.dart';
import '../theme.dart';
import 'pdf_preview_page.dart';
import 'printer_picker.dart';

/// Single entry point the UI uses to print an order document.
///
/// On Android and iOS the ESC/POS bytes are streamed straight to the paired
/// Bluetooth printer — no preview. On desktop, where Bluetooth thermal printing
/// isn't available, it falls back to the in-app [PdfPreviewPage] and the system
/// print path.
Future<void> printOrderTicket(
  BuildContext context, {
  required OrderModel order,
  required VenueDetails venue,
  required bool kitchen,
}) async {
  final label = kitchen ? 'Kitchen ticket #${order.id}' : 'Receipt #${order.id}';

  if (Platform.isAndroid || Platform.isIOS) {
    await _printThermal(
      context,
      jobLabel: label,
      build: () => kitchen
          ? EscPosTicketBuilder.kitchenTicket(order)
          : EscPosTicketBuilder.receipt(order, venue),
    );
    return;
  }

  // Desktop: keep the previewable PDF path.
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PdfPreviewPage(
        title: kitchen ? 'Kitchen Ticket · #${order.id}' : 'Receipt · #${order.id}',
        documentName: kitchen ? 'KOT-${order.id}' : 'Receipt-${order.id}',
        buildDocument: (_) => kitchen
            ? TicketPrinter.buildKitchenTicket(order)
            : TicketPrinter.buildReceipt(order, venue),
      ),
    ),
  );
}

/// Streams a prepared ESC/POS job to the saved Bluetooth printer, prompting for
/// one on first use and surfacing any failure as a snackbar.
Future<void> _printThermal(
  BuildContext context, {
  required String jobLabel,
  required Future<List<int>> Function() build,
}) async {
  final messenger = ScaffoldMessenger.of(context);

  try {
    final permission = await ThermalPrinter.ensurePermission();
    if (permission != PermissionOutcome.granted) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            permission == PermissionOutcome.permanentlyDenied
                ? 'Nearby devices (Bluetooth) permission is turned off. Enable '
                      'it in Settings to reach the printer.'
                : 'Bluetooth permission is required to reach the printer.',
          ),
          backgroundColor: AppColors.danger,
          action: permission == PermissionOutcome.permanentlyDenied
              ? SnackBarAction(
                  label: 'Settings',
                  textColor: Colors.white,
                  onPressed: ThermalPrinter.openSettings,
                )
              : null,
        ),
      );
      return;
    }

    if (!await ThermalPrinter.bluetoothEnabled) {
      throw const ThermalPrinterException(
        'Bluetooth is off. Turn it on and try again.',
      );
    }

    var printer = await ThermalPrinter.savedPrinter();
    if (printer == null) {
      if (!context.mounted) return;
      printer = await showPrinterPicker(context);
      if (printer == null) return; // operator dismissed the picker
      await ThermalPrinter.savePrinter(printer);
    }

    // Build after a printer is chosen so a cancelled pick does no wasted work.
    final bytes = await build();
    await ThermalPrinter.printBytes(printer.macAdress, bytes);

    messenger.showSnackBar(
      SnackBar(content: Text('$jobLabel sent to ${printer.name}.')),
    );
  } on ThermalPrinterException catch (e) {
    if (e.reselect) await ThermalPrinter.forgetPrinter();
    messenger.showSnackBar(
      SnackBar(content: Text(e.message), backgroundColor: AppColors.danger),
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text('Print failed: $e'),
        backgroundColor: AppColors.danger,
      ),
    );
  }
}

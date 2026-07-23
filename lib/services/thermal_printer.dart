import 'dart:io' show Platform;

import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Failure surfaced to the operator while printing over Bluetooth.
///
/// [reselect] is set when the saved printer could not be reached, so the caller
/// can forget it and prompt for a new one on the next attempt.
class ThermalPrinterException implements Exception {
  const ThermalPrinterException(this.message, {this.reselect = false});

  final String message;
  final bool reselect;

  @override
  String toString() => message;
}

/// Result of asking for the Bluetooth runtime permission.
///
/// [permanentlyDenied] means Android will no longer show the popup, so the only
/// way forward is the app's system settings page.
enum PermissionOutcome { granted, denied, permanentlyDenied }

/// Thin wrapper over `print_bluetooth_thermal`: remembers the chosen printer,
/// requests the Android 12+ runtime permission, and sends a prepared ESC/POS
/// byte stream to the device.
class ThermalPrinter {
  const ThermalPrinter._();

  static const _prefMac = 'thermal_printer_mac';
  static const _prefName = 'thermal_printer_name';

  // Android's Bluetooth socket calls (connect/write) have no built-in timeout
  // and block when the printer is off or out of range; the status method
  // channel can also stall on hardware without a radio. Every call below is
  // time-boxed so the print UI can never spin forever.
  static const _statusTimeout = Duration(seconds: 6);
  static const _connectTimeout = Duration(seconds: 15);
  static const _writeTimeout = Duration(seconds: 15);

  static Future<bool> get bluetoothEnabled => PrintBluetoothThermal
      .bluetoothEnabled
      .timeout(_statusTimeout, onTimeout: () => false);

  static Future<List<BluetoothInfo>> pairedPrinters() =>
      PrintBluetoothThermal.pairedBluetooths.timeout(
        _statusTimeout,
        onTimeout: () => <BluetoothInfo>[],
      );

  /// Requests the runtime Bluetooth permission (Android 12+). On older Android,
  /// iOS, and desktop the permission is either implicit or granted at install,
  /// so this resolves to [PermissionOutcome.granted].
  static Future<PermissionOutcome> ensurePermission() async {
    if (!Platform.isAndroid) return PermissionOutcome.granted;
    final statuses = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ].request().timeout(
      const Duration(seconds: 30),
      onTimeout: () => <Permission, PermissionStatus>{},
    );
    final connect =
        statuses[Permission.bluetoothConnect] ?? PermissionStatus.denied;
    if (connect.isGranted) return PermissionOutcome.granted;
    if (connect.isPermanentlyDenied) return PermissionOutcome.permanentlyDenied;
    return PermissionOutcome.denied;
  }

  /// Opens this app's system settings page so the operator can flip the
  /// "Nearby devices" permission on after a permanent denial.
  static Future<void> openSettings() => openAppSettings();

  /// The printer the operator last selected, or `null` if none is saved yet.
  static Future<BluetoothInfo?> savedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final mac = prefs.getString(_prefMac);
    if (mac == null || mac.isEmpty) return null;
    return BluetoothInfo(
      name: prefs.getString(_prefName) ?? mac,
      macAdress: mac,
    );
  }

  static Future<void> savePrinter(BluetoothInfo printer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefMac, printer.macAdress);
    await prefs.setString(_prefName, printer.name);
  }

  static Future<void> forgetPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefMac);
    await prefs.remove(_prefName);
  }

  /// Connects to [mac] if not already connected, then writes [bytes].
  ///
  /// The connection is left open so repeat prints (kitchen then receipt) are
  /// fast. Throws a [ThermalPrinterException] on any failure.
  static Future<void> printBytes(String mac, List<int> bytes) async {
    final connected = await PrintBluetoothThermal.connectionStatus.timeout(
      _statusTimeout,
      onTimeout: () => false,
    );
    if (!connected && !await _connectWithRetry(mac)) {
      throw const ThermalPrinterException(
        'Could not connect to the printer. Make sure it is on, in range, '
        'paired in Bluetooth settings, and not connected to another device.',
        reselect: true,
      );
    }

    final wrote = await PrintBluetoothThermal.writeBytes(bytes)
        .timeout(_writeTimeout, onTimeout: () => false);
    if (!wrote) {
      throw const ThermalPrinterException(
        'Connected, but sending the print data timed out. Try again.',
      );
    }
  }

  /// RFCOMM's first connect after the printer has gone idle often fails with
  /// "read failed … read ret: -1"; a clean retry usually succeeds, so try a few
  /// times, tearing down any half-open socket between attempts. Each attempt is
  /// time-boxed because Android's connect() can otherwise block indefinitely.
  static Future<bool> _connectWithRetry(String mac, {int attempts = 3}) async {
    for (var attempt = 0; attempt < attempts; attempt++) {
      final ok = await PrintBluetoothThermal.connect(macPrinterAddress: mac)
          .timeout(_connectTimeout, onTimeout: () => false);
      if (ok) return true;

      // Drop any half-open socket, wait for the radio to settle, then retry.
      await PrintBluetoothThermal.disconnect.timeout(
        const Duration(seconds: 3),
        onTimeout: () => false,
      );
      await Future<void>.delayed(const Duration(milliseconds: 700));
    }
    return false;
  }
}

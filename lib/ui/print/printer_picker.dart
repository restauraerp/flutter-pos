import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../services/thermal_printer.dart';
import '../theme.dart';

/// Lets the operator pick which paired Bluetooth device is the receipt printer.
/// Returns the chosen device, or `null` if dismissed.
Future<BluetoothInfo?> showPrinterPicker(BuildContext context) {
  return showModalBottomSheet<BluetoothInfo>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.box)),
    ),
    builder: (_) => const _PrinterPicker(),
  );
}

class _PrinterPicker extends StatefulWidget {
  const _PrinterPicker();

  @override
  State<_PrinterPicker> createState() => _PrinterPickerState();
}

class _PrinterPickerState extends State<_PrinterPicker> {
  late Future<List<BluetoothInfo>> _devices;

  @override
  void initState() {
    super.initState();
    _devices = _load();
  }

  Future<List<BluetoothInfo>> _load() async {
    if (!await ThermalPrinter.bluetoothEnabled) {
      throw const ThermalPrinterException(
        'Bluetooth is off. Turn it on, pair the printer, then try again.',
      );
    }
    return ThermalPrinter.pairedPrinters();
  }

  void _refresh() => setState(() => _devices = _load());

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Select receipt printer',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Refresh',
                  onPressed: _refresh,
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Showing devices already paired in the system Bluetooth settings.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: FutureBuilder<List<BluetoothInfo>>(
                future: _devices,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return _Notice(
                      icon: Icons.bluetooth_disabled,
                      text: '${snapshot.error}',
                    );
                  }
                  final devices = snapshot.data ?? const [];
                  if (devices.isEmpty) {
                    return const _Notice(
                      icon: Icons.print_disabled_outlined,
                      text: 'No paired devices found. Pair the printer in the '
                          'system Bluetooth settings first.',
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: devices.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, index) {
                      final device = devices[index];
                      return ListTile(
                        leading: const Icon(Icons.print_outlined),
                        title: Text(device.name),
                        subtitle: Text(
                          device.macAdress,
                          style: const TextStyle(fontSize: 11),
                        ),
                        onTap: () => Navigator.of(context).pop(device),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

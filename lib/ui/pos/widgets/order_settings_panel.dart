import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/models.dart';
import '../../../state/pos_controller.dart';
import '../../theme.dart';
import 'customer_picker.dart';
import 'order_type_selector.dart';
import 'table_selector.dart';

/// Collapsible panel holding order type, table, delivery details, and customer.
class OrderSettingsPanel extends StatefulWidget {
  const OrderSettingsPanel({super.key, this.initiallyExpanded = true});

  final bool initiallyExpanded;

  @override
  State<OrderSettingsPanel> createState() => _OrderSettingsPanelState();
}

class _OrderSettingsPanelState extends State<OrderSettingsPanel> {
  late bool _expanded = widget.initiallyExpanded;
  final _deliveryChargeController = TextEditingController();
  final _addressController = TextEditingController();

  /// Last reset we reacted to, so a completed order clears these fields exactly
  /// once rather than fighting the cashier while they type.
  int _seenResetToken = 0;

  void _syncWithResets(PosController pos) {
    if (pos.orderResetToken == _seenResetToken) return;
    _seenResetToken = pos.orderResetToken;
    _addressController.clear();
    _deliveryChargeController.clear();
  }

  @override
  void dispose() {
    _deliveryChargeController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickDeliveryTime(PosController pos) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: pos.deliveryTime ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(pos.deliveryTime ?? now),
    );
    if (time == null) return;

    pos.setDeliveryTime(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosController>();
    final type = pos.orderType;
    _syncWithResets(pos);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.box),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Order Settings',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 10),
            OrderTypeSelector(value: type, onChanged: pos.setOrderType),

            // Who to credit for the sale. Hidden when there is nobody to choose
            // between - a restaurant with one staff account has no attribution
            // question to answer. Searchable, because a real one has dozens and
            // a dropdown that long cannot be used mid-service.
            if (pos.employees.length > 1) ...[
              const SizedBox(height: 12),
              const _SectionLabel('SERVED BY (OPTIONAL)'),
              DropdownButtonFormField<int?>(
                initialValue: pos.servedByUserId,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true),
                hint: const Text('Nobody in particular', style: TextStyle(fontSize: 12.5)),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Nobody in particular', style: TextStyle(fontSize: 12.5)),
                  ),
                  ...pos.employees.map(
                    (e) => DropdownMenuItem<int?>(
                      value: e.id,
                      child: Text(e.name, style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: pos.setServedBy,
              ),
            ],

            // A third party that sent this order in. Only for the order types
            // an aggregator actually sends, and only once one exists.
            if (pos.partners.isNotEmpty &&
                (type == OrderType.delivery || type == OrderType.takeaway)) ...[
              const SizedBox(height: 12),
              const _SectionLabel('CAME THROUGH (OPTIONAL)'),
              DropdownButtonFormField<int?>(
                initialValue: pos.partnerId,
                isExpanded: true,
                decoration: const InputDecoration(isDense: true),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Direct — not through a partner', style: TextStyle(fontSize: 12.5)),
                  ),
                  ...pos.partners.map(
                    (p) => DropdownMenuItem<int?>(
                      value: p.id,
                      // The rate is shown so whoever rings it up can see what
                      // the sale is really worth. It is never sent - the server
                      // prices the commission from its own record.
                      child: Text(
                        '${p.name} (${p.commissionRate.toStringAsFixed(0)}%)',
                        style: const TextStyle(fontSize: 12.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: pos.setPartner,
              ),
            ],

            if (type.needsTable) ...[
              const SizedBox(height: 12),
              const _SectionLabel('SELECT TABLE'),
              TableSelector(
                tables: pos.tables,
                selectedId: pos.selectedTableId,
                loading: pos.tablesLoading,
                onSelect: pos.selectTable,
              ),
            ],

            if (type.needsTime) ...[
              const SizedBox(height: 12),
              _SectionLabel(
                type == OrderType.catering ? 'DATE & TIME' : 'DELIVERY TIME',
              ),
              OutlinedButton.icon(
                onPressed: () => _pickDeliveryTime(pos),
                icon: const Icon(Icons.schedule, size: 15),
                label: Text(
                  pos.deliveryTime == null
                      ? 'ASAP (tap to schedule)'
                      : _formatDateTime(pos.deliveryTime!),
                  style: const TextStyle(fontSize: 12.5),
                ),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  foregroundColor: AppColors.textPrimary,
                  backgroundColor: AppColors.surface,
                  side: const BorderSide(color: AppColors.border),
                  minimumSize: const Size.fromHeight(40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.field),
                  ),
                ),
              ),
              if (pos.deliveryTime != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => pos.setDeliveryTime(null),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Clear — deliver ASAP',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ),
            ],

            if (type.needsAddress) ...[
              const SizedBox(height: 12),
              const _SectionLabel('DELIVERY ADDRESS'),
              TextField(
                controller: _addressController,
                maxLines: 2,
                minLines: 1,
                onChanged: pos.setDeliveryAddress,
                decoration: const InputDecoration(
                  hintText: 'Street, area, landmark…',
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ],

            if (type.needsDeliveryCharge) ...[
              const SizedBox(height: 12),
              const _SectionLabel('DELIVERY CHARGE'),
              TextField(
                controller: _deliveryChargeController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (v) =>
                    pos.setDeliveryCharge(double.tryParse(v) ?? 0),
                decoration: InputDecoration(
                  prefixText: '${pos.currency} ',
                  hintText: '0.00',
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ],

            const SizedBox(height: 12),
            const _SectionLabel('CUSTOMER (OPTIONAL)'),
            const CustomerPicker(),
          ],
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime dt) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${dt.year}-${two(dt.month)}-${two(dt.day)}  ${two(dt.hour)}:${two(dt.minute)}';
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

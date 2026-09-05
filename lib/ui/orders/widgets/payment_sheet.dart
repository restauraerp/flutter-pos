import 'package:flutter/material.dart';

import '../../../data/models/models.dart';
import '../../theme.dart';

/// What the cashier chose when settling an order.
class PaymentResult {
  const PaymentResult({required this.method, this.note});

  final PaymentMethod method;

  /// Why this payment looks the way it does - a bKash transaction id, a card's
  /// last four, which guest settled a shared table. "3,500 by bKash" answers
  /// what but never why, and the why is what somebody reconciling the till at
  /// midnight needs.
  final String? note;
}

/// Takes payment for an order: shows what is owed and captures how it arrived.
///
/// The amounts are the order's own and are only displayed here. Everything that
/// came off the bill - a cook's mistake taken off one dish, a reduction the
/// manager decided on - was priced by the server when the order was placed.
/// This sheet used to rebuild the total from the subtotal and a coupon typed at
/// the till, which dropped all of it: a discounted order came back up at full
/// price, and confirming it posted that figure back and erased the discount
/// from the order too.
class PaymentSheet extends StatefulWidget {
  const PaymentSheet({
    super.key,
    required this.order,
    required this.currency,
  });

  final OrderModel order;
  final String currency;

  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<PaymentSheet> {
  PaymentMethod _method = PaymentMethod.cash;
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.box),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Text(
                'Complete payment  •  Order #${order.id}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),

              // Amount due
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.canvas,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppRadius.box),
                ),
                child: Column(
                  children: [
                    const Text(
                      'AMOUNT DUE',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      money(widget.currency, order.total),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      children: [
                        _MiniTotal(
                          label: 'Sub',
                          value: money(widget.currency, order.subtotal),
                        ),
                        // Spelled out rather than folded into the total: a
                        // cashier being told 900 for a 1,000 bill needs to
                        // see why.
                        if (order.discountAmount > 0)
                          _MiniTotal(
                            label: 'Discount',
                            value:
                                '-${money(widget.currency, order.discountAmount)}',
                            color: AppColors.success,
                          ),
                        _MiniTotal(
                          label: 'Tax',
                          value: money(widget.currency, order.taxAmount),
                        ),
                        if (order.deliveryCharge > 0)
                          _MiniTotal(
                            label: 'Del',
                            value: money(
                              widget.currency,
                              order.deliveryCharge,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Method
              const _Label('PAYMENT METHOD'),
              Row(
                children: PaymentMethod.values.map((m) {
                  final active = _method == m;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () => setState(() => _method = m),
                        borderRadius: BorderRadius.circular(AppRadius.field),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.primary.withValues(alpha: 0.08)
                                : AppColors.surface,
                            border: Border.all(
                              color: active
                                  ? AppColors.primary
                                  : AppColors.border,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(
                              AppRadius.field,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                switch (m) {
                                  PaymentMethod.cash => Icons.payments_outlined,
                                  PaymentMethod.card => Icons.credit_card,
                                  PaymentMethod.mfs =>
                                    Icons.smartphone_outlined,
                                },
                                size: 22,
                                color: active
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                m.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: active
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: 'Reference or note (optional)',
                  isDense: true,
                  hintText: switch (_method) {
                    PaymentMethod.mfs => 'e.g. bKash TrxID BKS8891',
                    PaymentMethod.card => 'e.g. Visa ending 4421',
                    PaymentMethod.cash => 'e.g. paid by the host',
                  },
                  hintStyle: const TextStyle(fontSize: 12.5),
                ),
                style: const TextStyle(fontSize: 13),
                textCapitalization: TextCapitalization.sentences,
              ),

              const SizedBox(height: 20),

              FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  PaymentResult(
                    method: _method,
                    note: _noteController.text.trim().isEmpty
                        ? null
                        : _noteController.text.trim(),
                  ),
                ),
                child: Text(
                  'Confirm ${money(widget.currency, order.total)}',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
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

class _MiniTotal extends StatelessWidget {
  const _MiniTotal({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: $value',
      style: TextStyle(
        fontSize: 11.5,
        color: color ?? AppColors.textSecondary,
        fontWeight: color != null ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }
}

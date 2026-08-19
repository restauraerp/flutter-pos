import 'package:flutter/material.dart';

import '../../../data/models/models.dart';
import '../../../state/orders_controller.dart';
import '../../theme.dart';

/// What the cashier chose when settling an order.
class PaymentResult {
  const PaymentResult({
    required this.method,
    required this.discount,
    this.note,
  });

  final PaymentMethod method;
  final DiscountModel? discount;

  /// Why this payment looks the way it does - a bKash transaction id, a card's
  /// last four, which guest settled a shared table. "3,500 by bKash" answers
  /// what but never why, and the why is what somebody reconciling the till at
  /// midnight needs.
  final String? note;
}

/// Takes payment for an order: shows the amount due, allows a coupon to be
/// applied at the till, and captures the payment method.
class PaymentSheet extends StatefulWidget {
  const PaymentSheet({
    super.key,
    required this.order,
    required this.currency,
    required this.discounts,
    required this.controller,
  });

  final OrderModel order;
  final String currency;
  final List<DiscountModel> discounts;
  final OrdersController controller;

  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<PaymentSheet> {
  PaymentMethod _method = PaymentMethod.cash;
  DiscountModel? _discount;
  final _codeController = TextEditingController();
  final _noteController = TextEditingController();
  String? _codeError;

  @override
  void initState() {
    super.initState();
    // Carry over a coupon already attached to the order when it was placed.
    final existing = widget.order.discountId;
    if (existing != null) {
      for (final d in widget.discounts) {
        if (d.id == existing) {
          _discount = d;
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _applyCode() {
    final code = _codeController.text.trim().toLowerCase();
    if (code.isEmpty) {
      setState(() => _codeError = 'Enter a code.');
      return;
    }

    DiscountModel? found;
    for (final d in widget.discounts) {
      if (d.code?.toLowerCase() == code) {
        found = d;
        break;
      }
    }

    setState(() {
      if (found == null) {
        _codeError = 'Invalid code';
      } else if (!found.isActive) {
        _codeError = 'Coupon is inactive';
      } else if (found.isExpired) {
        _codeError = 'Coupon expired';
      } else {
        _discount = found;
        _codeError = null;
        _codeController.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final totals = widget.controller.totalsFor(order, _discount);
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
                      money(widget.currency, totals.total),
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
                        if (totals.discount > 0)
                          _MiniTotal(
                            label: 'Disc',
                            value:
                                '-${money(widget.currency, totals.discount)}',
                            color: AppColors.success,
                          ),
                        _MiniTotal(
                          label: 'Tax',
                          value: money(widget.currency, totals.tax),
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

              // Coupon
              const _Label('COUPON'),
              if (_discount != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successBg,
                    border: Border.all(color: AppColors.successBorder),
                    borderRadius: BorderRadius.circular(AppRadius.selector),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.local_offer_outlined,
                        size: 14,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _discount!.code ?? 'Discount',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.successText,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 15),
                        color: AppColors.textMuted,
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        tooltip: 'Remove coupon',
                        onPressed: () => setState(() => _discount = null),
                      ),
                    ],
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        onChanged: (_) {
                          if (_codeError != null) {
                            setState(() => _codeError = null);
                          }
                        },
                        onSubmitted: (_) => _applyCode(),
                        decoration: InputDecoration(
                          hintText: 'Discount code',
                          errorText: _codeError,
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      height: 44,
                      child: FilledButton(
                        onPressed: _applyCode,
                        child: const Icon(Icons.check, size: 17),
                      ),
                    ),
                  ],
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
                    discount: _discount,
                    note: _noteController.text.trim().isEmpty
                        ? null
                        : _noteController.text.trim(),
                  ),
                ),
                child: Text(
                  'Confirm ${money(widget.currency, totals.total)}',
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

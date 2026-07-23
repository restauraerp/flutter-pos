import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/models/models.dart';
import '../../theme.dart';

/// One order in the work queue, with its status, contents, and next actions.
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.currency,
    required this.busy,
    required this.canAct,
    required this.onPay,
    required this.onCancel,
    required this.onAdvance,
    required this.onPrintKitchen,
    required this.onPrintReceipt,
  });

  final OrderModel order;
  final String currency;
  final bool busy;
  final bool canAct;
  final VoidCallback onPay;
  final VoidCallback onCancel;
  final void Function(OrderTransition) onAdvance;
  final VoidCallback onPrintKitchen;
  final VoidCallback onPrintReceipt;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.box),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(order: order),
          if (order.hasLogistics) ...[
            const SizedBox(height: 10),
            _Logistics(order: order),
          ],
          const SizedBox(height: 10),
          _TimerRow(order: order, currency: currency),
          if (order.items.isNotEmpty) ...[
            const SizedBox(height: 10),
            _Items(order: order),
          ],
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 10),
          // Printing needs no write permission — anyone who can see the order
          // may reprint its ticket or receipt.
          _PrintActions(
            onPrintKitchen: onPrintKitchen,
            onPrintReceipt: onPrintReceipt,
          ),
          if (canAct) ...[
            const SizedBox(height: 8),
            _Actions(
              order: order,
              busy: busy,
              onPay: onPay,
              onCancel: onCancel,
              onAdvance: onAdvance,
            ),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.heading,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Order #${order.id}  •  ${order.customerName ?? 'Walk-in'}',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _StatusChip(order: order),
            const SizedBox(height: 4),
            _Chip(
              label: order.isPaid ? 'Paid' : 'Unpaid',
              background: order.isPaid
                  ? AppColors.successBg
                  : AppColors.dangerBg,
              border: order.isPaid
                  ? AppColors.successBorder
                  : AppColors.dangerBorder,
              foreground: order.isPaid
                  ? AppColors.successText
                  : AppColors.dangerText,
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.order});

  final OrderModel order;

  /// Colour by how far along the order is, using the semantic palette.
  ({Color bg, Color border, Color fg}) get _colors {
    switch (order.status) {
      case OrderStatus.pending:
        return (
          bg: AppColors.warningBg,
          border: AppColors.warningBorder,
          fg: AppColors.warningText,
        );
      case OrderStatus.cooking:
      case OrderStatus.packed:
      case OrderStatus.picked:
        return (
          bg: AppColors.info.withValues(alpha: 0.10),
          border: AppColors.info.withValues(alpha: 0.35),
          fg: AppColors.info,
        );
      case OrderStatus.cooked:
      case OrderStatus.served:
      case OrderStatus.delivered:
      case OrderStatus.paid:
        return (
          bg: AppColors.successBg,
          border: AppColors.successBorder,
          fg: AppColors.successText,
        );
      case null:
        return (
          bg: AppColors.canvas,
          border: AppColors.border,
          fg: AppColors.textSecondary,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _colors;
    return _Chip(
      label: order.statusLabel,
      background: c.bg,
      border: c.border,
      foreground: c.fg,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.background,
    required this.border,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color border;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(AppRadius.selector),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

class _Logistics extends StatelessWidget {
  const _Logistics({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final time = order.deliveryTime;

    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.06),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.20)),
        borderRadius: BorderRadius.circular(AppRadius.selector),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, size: 13, color: AppColors.primary),
              const SizedBox(width: 5),
              Text(
                time == null ? 'ASAP' : _formatDateTime(time),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.place_outlined, size: 13, color: AppColors.danger),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  order.deliveryAddress ?? 'No address provided',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ticking time-since-placed, so staff can see which orders are ageing.
class _TimerRow extends StatefulWidget {
  const _TimerRow({required this.order, required this.currency});

  final OrderModel order;
  final String currency;

  @override
  State<_TimerRow> createState() => _TimerRowState();
}

class _TimerRowState extends State<_TimerRow> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.order.createdAt != null) {
      _timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => setState(() {}),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _elapsed {
    final placed = widget.order.createdAt;
    if (placed == null) return '—';
    final diff = DateTime.now().difference(placed);
    if (diff.isNegative) return '0m 0s';
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    final s = diff.inSeconds % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(AppRadius.selector),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(
            _elapsed,
            style: const TextStyle(
              fontSize: 11.5,
              fontFamily: 'monospace',
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            money(widget.currency, widget.order.total),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _Items extends StatelessWidget {
  const _Items({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: order.items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: item.imageUrl == null
                      ? const ColoredBox(
                          color: AppColors.canvas,
                          child: Icon(
                            Icons.restaurant,
                            size: 14,
                            color: AppColors.textMuted,
                          ),
                        )
                      : Image.network(
                          item.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: AppColors.canvas,
                            child: Icon(
                              Icons.restaurant,
                              size: 14,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (item.notes != null)
                      Text(
                        '📝 ${item.notes}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.primary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '×${item.quantity}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _PrintActions extends StatelessWidget {
  const _PrintActions({
    required this.onPrintKitchen,
    required this.onPrintReceipt,
  });

  final VoidCallback onPrintKitchen;
  final VoidCallback onPrintReceipt;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActionButton(
          label: 'Kitchen ticket',
          icon: Icons.soup_kitchen_outlined,
          background: AppColors.canvas,
          border: AppColors.border,
          foreground: AppColors.textSecondary,
          onTap: onPrintKitchen,
        ),
        const SizedBox(width: 6),
        _ActionButton(
          label: 'Receipt',
          icon: Icons.receipt_outlined,
          background: AppColors.canvas,
          border: AppColors.border,
          foreground: AppColors.textSecondary,
          onTap: onPrintReceipt,
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.order,
    required this.busy,
    required this.onPay,
    required this.onCancel,
    required this.onAdvance,
  });

  final OrderModel order;
  final bool busy;
  final VoidCallback onPay;
  final VoidCallback onCancel;
  final void Function(OrderTransition) onAdvance;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const Row(
        children: [
          SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Text(
            'Updating…',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final transition in order.nextTransitions)
          _ActionButton(
            label: transition.label,
            icon: Icons.arrow_forward,
            background: AppColors.info.withValues(alpha: 0.10),
            border: AppColors.info.withValues(alpha: 0.35),
            foreground: AppColors.info,
            onTap: () => onAdvance(transition),
          ),
        if (!order.isPaid)
          _ActionButton(
            label: 'Pay',
            icon: Icons.payments_outlined,
            background: AppColors.successBg,
            border: AppColors.successBorder,
            foreground: AppColors.successText,
            onTap: onPay,
          ),
        if (order.isCancellable)
          _ActionButton(
            label: 'Cancel',
            icon: Icons.close,
            background: AppColors.dangerBg,
            border: AppColors.dangerBorder,
            foreground: AppColors.dangerText,
            onTap: onCancel,
          ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.border,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color border;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.selector),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(AppRadius.selector),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime dt) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${dt.year}-${two(dt.month)}-${two(dt.day)}  ${two(dt.hour)}:${two(dt.minute)}';
}

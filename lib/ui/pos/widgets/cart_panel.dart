import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../data/models/models.dart';
import '../../../state/pos_controller.dart';
import '../../../data/repositories/pos_repository.dart';
import '../../../services/ticket_printer.dart';
import '../../print/print_ticket.dart';
import '../../theme.dart';
import '../../../core/sales/discount_calculator.dart';
import 'discount_field.dart';

/// The current order: line items, totals, and checkout.
class CartPanel extends StatelessWidget {
  const CartPanel({super.key, this.onOrderPlaced});

  /// Lets the phone layout close the cart sheet once an order goes through.
  final VoidCallback? onOrderPlaced;

  Future<void> _checkout(BuildContext context) async {
    final pos = context.read<PosController>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      final orderId = await pos.checkout();
      if (!context.mounted) return;

      onOrderPlaced?.call();
      await showDialog<void>(
        context: context,
        builder: (_) => _OrderPlacedDialog(orderId: orderId),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.danger,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to place order: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosController>();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.box),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isTooShort = constraints.maxHeight < 350;

          final content = Column(
            children: [
              _CartHeader(pos: pos),
              if (isTooShort)
                if (pos.cart.isEmpty)
                  const SizedBox(height: 100, child: _EmptyCart())
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(8),
                    itemCount: pos.cart.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) =>
                        _CartLine(item: pos.cart[index], pos: pos),
                  )
              else
                Expanded(
                  child: pos.cart.isEmpty
                      ? const _EmptyCart()
                      : ListView.separated(
                          padding: const EdgeInsets.all(8),
                          itemCount: pos.cart.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 6),
                          itemBuilder: (context, index) =>
                              _CartLine(item: pos.cart[index], pos: pos),
                        ),
                ),
              _CartFooter(pos: pos, onCheckout: () => _checkout(context)),
            ],
          );

          if (isTooShort) {
            return SingleChildScrollView(child: content);
          }
          return content;
        },
      ),
    );
  }
}

class _CartHeader extends StatelessWidget {
  const _CartHeader({required this.pos});

  final PosController pos;

  /// A whole order is too much to lose to a stray tap, so clearing confirms —
  /// the same guard the logout and cancel-order flows use.
  Future<void> _confirmClear(BuildContext context) async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear order?'),
        content: const Text(
          'All items in the current order will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (proceed == true) pos.clearCart();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.canvas)),
      ),
      child: Row(
        children: [
          const Text(
            'Current Order',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          if (pos.hasItems) ...[
            _MiniButton(
              label: 'Hold',
              icon: Icons.pause,
              background: AppColors.warningBg,
              border: AppColors.warningBorder,
              foreground: AppColors.warningText,
              onTap: pos.holdOrder,
            ),
            const SizedBox(width: 6),
            _MiniButton(
              label: 'Clear',
              icon: Icons.delete_outline,
              background: AppColors.dangerBg,
              border: AppColors.dangerBorder,
              foreground: AppColors.danger,
              onTap: () => _confirmClear(context),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(AppRadius.selector),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
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

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 30,
            color: AppColors.textMuted,
          ),
          SizedBox(height: 8),
          Text(
            'Cart is empty',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _CartLine extends StatefulWidget {
  const _CartLine({required this.item, required this.pos});

  final CartItem item;
  final PosController pos;

  @override
  State<_CartLine> createState() => _CartLineState();
}

class _CartLineState extends State<_CartLine> {
  bool _editingNotes = false;
  bool _editingDiscount = false;
  late final TextEditingController _notesController = TextEditingController(
    text: widget.item.notes,
  );
  late final TextEditingController _discountController = TextEditingController(
    text: widget.item.discountValue?.toString() ?? '',
  );

  @override
  void dispose() {
    _notesController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  /// Tap-to-type quantity, so a large count is one entry instead of many taps.
  Future<void> _editQty() async {
    final controller = TextEditingController(text: '${widget.item.qty}');
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          widget.item.product.name,
          style: const TextStyle(fontSize: 15),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(labelText: 'Quantity'),
          onSubmitted: (v) =>
              Navigator.of(dialogContext).pop(int.tryParse(v.trim())),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(int.tryParse(controller.text.trim())),
            child: const Text('Set'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) widget.pos.setQty(widget.item.id, result);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final pos = widget.pos;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      money(pos.currency, item.product.price),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (item.product.isCombo)
                      Text(
                        '🍱 ${item.product.comboItems.map((c) => c.label).join(', ')}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              _QtyButton(
                icon: Icons.remove,
                onTap: () => pos.updateQty(item.id, -1),
              ),
              InkWell(
                onTap: _editQty,
                borderRadius: BorderRadius.circular(AppRadius.selector),
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  child: Text(
                    '${item.qty}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              _QtyButton(
                icon: Icons.add,
                onTap: () => pos.updateQty(item.id, 1),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 62,
                child: Text(
                  money(pos.currency, item.lineTotal),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // "The steak came out cold, take 200 off it." Priced by the
              // server; this records what the cashier chose.
              IconButton(
                icon: const Icon(Icons.local_offer_outlined, size: 18),
                color: item.discountValue != null
                    ? AppColors.success
                    : AppColors.textMuted,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                tooltip: 'Discount this item',
                onPressed: () =>
                    setState(() => _editingDiscount = !_editingDiscount),
              ),
              IconButton(
                icon: const Icon(Icons.sticky_note_2_outlined, size: 18),
                color: item.notes.isNotEmpty
                    ? AppColors.primary
                    : AppColors.textMuted,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                tooltip: 'Item note',
                onPressed: () =>
                    setState(() => _editingNotes = !_editingNotes),
              ),
            ],
          ),
          if (_editingNotes)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: TextField(
                controller: _notesController,
                autofocus: true,
                onChanged: (v) => pos.updateNotes(item.id, v),
                onSubmitted: (_) => setState(() => _editingNotes = false),
                decoration: const InputDecoration(
                  hintText: 'e.g. no onion, extra spicy…',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          if (_editingDiscount)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  DropdownButton<DiscountKind>(
                    value: item.discountKind ?? DiscountKind.percent,
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    items: [
                      const DropdownMenuItem(
                        value: DiscountKind.percent,
                        child: Text('%', style: TextStyle(fontSize: 12)),
                      ),
                      DropdownMenuItem(
                        value: DiscountKind.flat,
                        child: Text(pos.currency, style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                    onChanged: (kind) => pos.setItemDiscount(
                      item.id,
                      kind,
                      double.tryParse(_discountController.text),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _discountController,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (v) => pos.setItemDiscount(
                        item.id,
                        item.discountKind ?? DiscountKind.percent,
                        double.tryParse(v),
                      ),
                      onSubmitted: (_) => setState(() => _editingDiscount = false),
                      decoration: const InputDecoration(
                        hintText: 'Amount off',
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          if (item.lineDiscount > 0 && !_editingDiscount)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  '-${money(pos.currency, item.lineDiscount)} off this item',
                  style: const TextStyle(fontSize: 11, color: AppColors.success),
                ),
              ),
            ),
          if (item.notes.isNotEmpty && !_editingNotes)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  '📝 ${item.notes}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.primary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.selector),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.selector),
        ),
        child: Icon(icon, size: 18, color: AppColors.textPrimary),
      ),
    );
  }
}

class _CartFooter extends StatelessWidget {
  const _CartFooter({required this.pos, required this.onCheckout});

  final PosController pos;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final taxLabel = 'Tax (${(pos.taxRate * 100).toStringAsFixed(0)}%)';
    final disabled = !pos.hasItems || pos.checkingOut;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.canvas)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DiscountField(),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 8),
          _TotalRow(label: 'Subtotal', value: money(pos.currency, pos.subtotal)),
          // Broken out rather than one lump: the three come from different
          // decisions - a cook's mistake on one dish, a coupon the customer
          // brought, and a call the manager made.
          if (pos.itemDiscount > 0)
            _TotalRow(
              label: 'Item discounts',
              value: '-${money(pos.currency, pos.itemDiscount)}',
              color: AppColors.success,
            ),
          if (pos.couponDiscount > 0)
            _TotalRow(
              label: 'Coupon',
              value: '-${money(pos.currency, pos.couponDiscount)}',
              color: AppColors.success,
            ),
          if (pos.billDiscount > 0)
            _TotalRow(
              label: 'Bill discount',
              value: '-${money(pos.currency, pos.billDiscount)}',
              color: AppColors.success,
            ),
          _TotalRow(label: taxLabel, value: money(pos.currency, pos.tax)),
          if (pos.orderType.needsDeliveryCharge)
            _TotalRow(
              label: 'Delivery charge',
              value: money(pos.currency, pos.effectiveDeliveryCharge),
            ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              Text(
                money(pos.currency, pos.total),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _CheckoutButton(
            disabled: disabled,
            busy: pos.checkingOut,
            onPressed: onCheckout,
          ),
        ],
      ),
    );
  }
}

class _CheckoutButton extends StatelessWidget {
  const _CheckoutButton({
    required this.disabled,
    required this.busy,
    required this.onPressed,
  });

  final bool disabled;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: disabled ? null : AppColors.primaryGradient,
        color: disabled ? AppColors.border : null,
        borderRadius: BorderRadius.circular(AppRadius.field),
        boxShadow: disabled
            ? null
            : [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: TextButton(
        onPressed: disabled ? null : onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size.fromHeight(46),
          foregroundColor: AppColors.primaryContent,
          disabledForegroundColor: AppColors.textMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.field),
          ),
        ),
        child: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppColors.primaryContent),
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.point_of_sale, size: 17),
                  SizedBox(width: 8),
                  Text(
                    'Place Order',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 12.5,
      color: color ?? AppColors.textSecondary,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}

/// Confirmation after checkout, offering to print straight away — the kitchen
/// ticket is what actually starts the food being cooked.
class _OrderPlacedDialog extends StatefulWidget {
  const _OrderPlacedDialog({required this.orderId});

  final int orderId;

  @override
  State<_OrderPlacedDialog> createState() => _OrderPlacedDialogState();
}

class _OrderPlacedDialogState extends State<_OrderPlacedDialog> {
  bool _printing = false;

  /// Checkout only returns the new id, so the full order is fetched here before
  /// sending it to the printer.
  Future<void> _print({required bool kitchen}) async {
    setState(() => _printing = true);

    final pos = context.read<PosController>();
    final repository = PosRepository(context.read<ApiClient>());
    final messenger = ScaffoldMessenger.of(context);

    try {
      final order = await repository.order(widget.orderId);
      if (!mounted) return;
      final venue = VenueDetails.fromSettings(pos.settings);

      await printOrderTicket(
        context,
        order: order,
        venue: venue,
        kitchen: kitchen,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not print: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.box),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎉', style: TextStyle(fontSize: 42)),
          const SizedBox(height: 10),
          const Text(
            'Order placed!',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Order #${widget.orderId} has been submitted successfully.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          if (_printing)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _print(kitchen: true),
                    icon: const Icon(Icons.soup_kitchen_outlined, size: 15),
                    label: const Text(
                      'Kitchen',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _print(kitchen: false),
                    icon: const Icon(Icons.receipt_outlined, size: 15),
                    label: const Text(
                      'Receipt',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton.icon(
          onPressed: _printing ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('New order'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../data/models/models.dart';
import '../../data/repositories/pos_repository.dart';
import '../../state/orders_controller.dart';
import '../../state/pos_controller.dart';
import '../../state/auth_controller.dart';
import '../../services/ticket_printer.dart';
import '../print/print_ticket.dart';
import '../theme.dart';
import 'widgets/order_card.dart';
import 'widgets/payment_sheet.dart';

/// Order management for the branch this terminal is signed in to.
///
/// Ported from the web `/admin/orders` screen, trimmed to what a POS operator
/// needs: work through active orders, advance their status, take payment, and
/// cancel mistakes.
class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final pos = context.read<PosController>();

    return ChangeNotifierProvider(
      create: (_) =>
          OrdersController(PosRepository(context.read<ApiClient>()))
            ..start(pos.activeLocationId),
      child: const _OrdersView(),
    );
  }
}

class _OrdersView extends StatelessWidget {
  const _OrdersView();

  Future<void> _pay(BuildContext context, OrderModel order) async {
    final orders = context.read<OrdersController>();
    final pos = context.read<PosController>();
    final messenger = ScaffoldMessenger.of(context);

    final result = await showModalBottomSheet<PaymentResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PaymentSheet(order: order, currency: pos.currency),
    );
    if (result == null) return;

    try {
      await orders.pay(order: order, method: result.method, note: result.note);
      messenger.showSnackBar(
        SnackBar(content: Text('Order #${order.id} paid.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Payment failed: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  /// Prints a kitchen ticket or receipt.
  ///
  /// The list endpoint already eager-loads items, products, and payments, so
  /// the order in hand is complete — no refetch needed before printing.
  Future<void> _print(
    BuildContext context,
    OrderModel order, {
    required bool kitchen,
  }) {
    final venue = VenueDetails.fromSettings(context.read<PosController>().settings);
    return printOrderTicket(context, order: order, venue: venue, kitchen: kitchen);
  }

  Future<void> _cancel(BuildContext context, OrderModel order) async {
    final orders = context.read<OrdersController>();
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Cancel order #${order.id}?'),
        content: const Text('This removes the order. It cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep order'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await orders.cancel(order);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not cancel: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _advance(
    BuildContext context,
    OrderModel order,
    OrderTransition transition,
  ) async {
    final orders = context.read<OrdersController>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      await orders.advance(order, transition.status);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not update order: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrdersController>();
    final pos = context.watch<PosController>();
    final canAct =
        context.select<AuthController, bool>(
          (c) => c.user?.canUpdateOrderStatus ?? false,
        );
    // Cancelling needs edit_order, a stronger permission than advancing status.
    // Gated separately so a pos_manager still gets Pay and the status buttons
    // but not a Cancel the server would refuse with a 403.
    final canCancel =
        context.select<AuthController, bool>(
          (c) => c.user?.canEditOrder ?? false,
        );

    final branch = pos.activeLocationName;
    final visible = orders.visibleOrders;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Order Management',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            if (branch != null)
              Text(
                branch,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Refresh',
            onPressed: orders.loading ? null : () => orders.refresh(),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(84),
          child: Column(
            children: [
              _TabBar(orders: orders),
              _SortBar(orders: orders),
              const Divider(height: 1, color: AppColors.border),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => orders.refresh(),
        child: _Body(
          orders: orders,
          visible: visible,
          currency: pos.currency,
          canAct: canAct,
          canCancel: canCancel,
          onPay: (o) => _pay(context, o),
          onCancel: (o) => _cancel(context, o),
          onAdvance: (o, t) => _advance(context, o, t),
          onPrintKitchen: (o) => _print(context, o, kitchen: true),
          onPrintReceipt: (o) => _print(context, o, kitchen: false),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.orders,
    required this.visible,
    required this.currency,
    required this.canAct,
    required this.canCancel,
    required this.onPay,
    required this.onCancel,
    required this.onAdvance,
    required this.onPrintKitchen,
    required this.onPrintReceipt,
  });

  final OrdersController orders;
  final List<OrderModel> visible;
  final String currency;
  final bool canAct;
  final bool canCancel;
  final void Function(OrderModel) onPay;
  final void Function(OrderModel) onCancel;
  final void Function(OrderModel, OrderTransition) onAdvance;
  final void Function(OrderModel) onPrintKitchen;
  final void Function(OrderModel) onPrintReceipt;

  @override
  Widget build(BuildContext context) {
    if (orders.loading && orders.orders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (orders.error != null && orders.orders.isEmpty) {
      return _Message(
        icon: Icons.cloud_off_outlined,
        title: orders.error!,
        action: FilledButton.icon(
          onPressed: () => orders.refresh(),
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Retry'),
        ),
      );
    }

    if (visible.isEmpty) {
      return _Message(
        icon: Icons.receipt_long_outlined,
        title: 'No active ${orders.tab.label.toLowerCase()} orders.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 24),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: visible.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final order = visible[index];
        return OrderCard(
          order: order,
          currency: currency,
          busy: orders.isBusy(order.id),
          canAct: canAct,
          canCancel: canCancel,
          onPay: () => onPay(order),
          onCancel: () => onCancel(order),
          onAdvance: (t) => onAdvance(order, t),
          onPrintKitchen: () => onPrintKitchen(order),
          onPrintReceipt: () => onPrintReceipt(order),
        );
      },
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.orders});

  final OrdersController orders;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        children: OrdersTab.values.map((tab) {
          final active = orders.tab == tab;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              onTap: () => orders.selectTab(tab),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : AppColors.surface,
                  border: Border.all(
                    color: active ? AppColors.primary : AppColors.border,
                    width: active ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  tab.label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: active
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SortBar extends StatelessWidget {
  const _SortBar({required this.orders});

  final OrdersController orders;

  String _label(OrdersSort sort) => switch (sort) {
    OrdersSort.placedAt => 'Placement time',
    OrdersSort.table => 'Table',
    OrdersSort.deliveryTime => 'Delivery time',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Row(
        children: [
          const Text(
            'Sort by',
            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 8),
          ...orders.availableSorts.map((sort) {
            final active = orders.sort == sort;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                onTap: () => orders.selectSort(sort),
                borderRadius: BorderRadius.circular(AppRadius.selector),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : Colors.transparent,
                    border: Border.all(
                      color: active ? AppColors.primary : AppColors.border,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.selector),
                  ),
                  child: Text(
                    _label(sort),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: active
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, this.action});

  final IconData icon;
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    // Scrollable so pull-to-refresh still works on an empty screen.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 44, color: AppColors.textMuted),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  if (action != null) ...[
                    const SizedBox(height: 18),
                    action!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

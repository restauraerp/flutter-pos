import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/auth_controller.dart';
import '../../state/pos_controller.dart';
import '../theme.dart';
import '../orders/orders_page.dart';
import 'widgets/cart_panel.dart';
import 'widgets/order_settings_panel.dart';
import 'widgets/product_grid.dart';

/// Breakpoint above which the cart gets its own permanent column, as on the web.
/// Below it (phones, the emulator) the cart lives in a bottom sheet.
const double _wideBreakpoint = 900;

class PosPage extends StatefulWidget {
  const PosPage({super.key});

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pos = context.read<PosController>();
      // Nothing from the previous cashier's session should carry over.
      pos.resetSession();
      // Pins the terminal to this user's branch before anything loads.
      pos.bindUser(context.read<AuthController>().user);
      pos.load();
    });
  }

  Future<void> _confirmLogout() async {
    final pos = context.read<PosController>();

    if (pos.hasItems || pos.heldOrders.isNotEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Log out?'),
          content: const Text(
            'The current order and any held orders will be discarded.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Log out'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    if (!mounted) return;
    await context.read<AuthController>().logout();
  }

  void _openCartSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.canvas,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.box)),
          ),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: Column(
            children: [
              Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: _OrderColumn(
                  scrollController: scrollController,
                  onOrderPlaced: () => Navigator.of(sheetContext).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= _wideBreakpoint;

    return Scaffold(
      appBar: _PosAppBar(onLogout: _confirmLogout),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: const [
                    Expanded(flex: 2, child: _CatalogueColumn()),
                    SizedBox(width: 12),
                    SizedBox(width: 380, child: _OrderColumn()),
                  ],
                )
              : const _CatalogueColumn(),
        ),
      ),
      bottomNavigationBar: isWide ? null : _CartBar(onTap: _openCartSheet),
    );
  }
}

/// Search, location switcher, category tabs, and the product grid.
class _CatalogueColumn extends StatefulWidget {
  const _CatalogueColumn();

  @override
  State<_CatalogueColumn> createState() => _CatalogueColumnState();
}

class _CatalogueColumnState extends State<_CatalogueColumn> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: pos.search,
                decoration: InputDecoration(
                  hintText: 'Search products…',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: pos.searchQuery.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            pos.search('');
                          },
                        ),
                ),
                style: const TextStyle(fontSize: 13.5),
              ),
            ),
            // Only unscoped accounts (admins) may move between branches. Staff
            // tied to one branch get a read-only badge in the same spot, so the
            // branch they are selling for is always on screen.
            if (pos.canSwitchLocation) ...[
              const SizedBox(width: 8),
              _LocationSwitcher(pos: pos),
            ] else if (pos.activeLocationName != null) ...[
              const SizedBox(width: 8),
              _BranchBadge(name: pos.activeLocationName!),
            ],
          ],
        ),
        const SizedBox(height: 10),
        _CategoryTabs(pos: pos),
        if (pos.heldOrders.isNotEmpty) ...[
          const SizedBox(height: 8),
          _HeldOrdersBar(pos: pos),
        ],
        const SizedBox(height: 10),
        const Expanded(child: ProductGrid()),
      ],
    );
  }
}

class _LocationSwitcher extends StatelessWidget {
  const _LocationSwitcher({required this.pos});

  final PosController pos;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: pos.activeLocationId,
          isDense: true,
          icon: const Icon(Icons.expand_more, size: 18),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
          items: pos.locations
              .map(
                (loc) => DropdownMenuItem(
                  value: loc.id,
                  child: Text('📍 ${loc.name}'),
                ),
              )
              .toList(),
          onChanged: (id) {
            if (id != null) pos.setActiveLocation(id);
          },
        ),
      ),
    );
  }
}

/// The branch a pinned terminal is selling for. Deliberately not a control —
/// this user cannot sell anywhere else.
class _BranchBadge extends StatelessWidget {
  const _BranchBadge({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      constraints: const BoxConstraints(maxWidth: 170),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.30)),
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.place, size: 15, color: AppColors.primary),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({required this.pos});

  final PosController pos;

  @override
  Widget build(BuildContext context) {
    final categories = pos.categoriesWithProducts;
    if (categories.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _CategoryChip(
            label: 'All Items',
            active: pos.selectedCategoryId == null,
            onTap: () => pos.selectCategory(null),
          ),
          for (final entry in categories)
            _CategoryChip(
              label: '${entry.category.name} (${entry.count})',
              active: pos.selectedCategoryId == entry.category.id,
              onTap: () => pos.selectCategory(entry.category.id),
            ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
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
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: active ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeldOrdersBar extends StatelessWidget {
  const _HeldOrdersBar({required this.pos});

  final PosController pos;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        border: Border.all(color: AppColors.warningBorder),
        borderRadius: BorderRadius.circular(AppRadius.field),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HELD ORDERS (${pos.heldOrders.length})',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.warningText,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: pos.heldOrders.map((order) {
              return InkWell(
                onTap: () => pos.recallOrder(order.id),
                onLongPress: () => pos.discardHeldOrder(order.id),
                borderRadius: BorderRadius.circular(AppRadius.selector),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.warningBorder),
                    borderRadius: BorderRadius.circular(AppRadius.selector),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.play_arrow,
                        size: 12,
                        color: AppColors.warningText,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${order.itemCount} items',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.warningText,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Order settings above, cart below — used as the right column on wide screens
/// and as the bottom-sheet body on phones.
class _OrderColumn extends StatelessWidget {
  const _OrderColumn({this.scrollController, this.onOrderPlaced});

  final ScrollController? scrollController;
  final VoidCallback? onOrderPlaced;

  @override
  Widget build(BuildContext context) {
    // In the sheet the whole column scrolls; in the side panel the cart list
    // scrolls on its own so the totals stay pinned.
    if (scrollController != null) {
      return ListView(
        controller: scrollController,
        padding: EdgeInsets.zero,
        children: [
          const OrderSettingsPanel(),
          const SizedBox(height: 10),
          SizedBox(
            height: 480,
            child: CartPanel(onOrderPlaced: onOrderPlaced),
          ),
          const SizedBox(height: 10),
        ],
      );
    }

    return Column(
      children: [
        const OrderSettingsPanel(),
        const SizedBox(height: 10),
        Expanded(child: CartPanel(onOrderPlaced: onOrderPlaced)),
        const SizedBox(height: 10),
      ],
    );
  }
}

/// Phone-only bar showing the running total and opening the cart.
class _CartBar extends StatelessWidget {
  const _CartBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosController>();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: AppColors.primaryContent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Badge(
                  isLabelVisible: pos.cartCount > 0,
                  label: Text('${pos.cartCount}'),
                  backgroundColor: AppColors.primaryContent,
                  textColor: AppColors.primary,
                  child: const Icon(Icons.shopping_cart_outlined, size: 21),
                ),
                const SizedBox(width: 12),
                const Text(
                  'View order',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  money(pos.currency, pos.total),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PosAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _PosAppBar({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final pos = context.watch<PosController>();

    // The branch is shown as a badge beside the search field, so the subtitle
    // stays short enough not to truncate.
    final subtitle = auth.user?.name ?? '';

    return AppBar(
      titleSpacing: 14,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Point of Sale',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          if (subtitle.isNotEmpty)
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w400,
              ),
            ),
        ],
      ),
      actions: [
        if (auth.user?.canViewOrders ?? false)
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined, size: 20),
            tooltip: 'Orders',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const OrdersPage()),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.refresh, size: 20),
          tooltip: 'Reload products',
          onPressed: pos.loading ? null : pos.load,
        ),
        IconButton(
          icon: const Icon(Icons.logout, size: 20),
          tooltip: 'Log out',
          onPressed: onLogout,
        ),
        const SizedBox(width: 4),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: AppColors.border),
      ),
    );
  }
}

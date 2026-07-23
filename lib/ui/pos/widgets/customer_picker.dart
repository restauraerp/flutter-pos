import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../state/pos_controller.dart';
import '../../theme.dart';

/// Search-and-attach a customer, with an inline "new customer" form.
class CustomerPicker extends StatefulWidget {
  const CustomerPicker({super.key});

  @override
  State<CustomerPicker> createState() => _CustomerPickerState();
}

class _CustomerPickerState extends State<CustomerPicker> {
  final _searchController = TextEditingController();
  bool _showAddForm = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openAddForm() async {
    setState(() => _showAddForm = true);
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddCustomerSheet(),
    );
    if (!mounted) return;
    setState(() => _showAddForm = false);
    if (added == true) _searchController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosController>();
    final selected = pos.selectedCustomer;

    if (selected != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.successBg,
          border: Border.all(color: AppColors.successBorder),
          borderRadius: BorderRadius.circular(AppRadius.selector),
        ),
        child: Row(
          children: [
            Flexible(
              child: Text(
                '👤 ${selected.displayName}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.successText,
                ),
              ),
            ),
            if (selected.phone != null) ...[
              const SizedBox(width: 6),
              Text(
                '(${selected.phone})',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close, size: 15),
              color: AppColors.textMuted,
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
              tooltip: 'Remove customer',
              onPressed: () => pos.selectCustomer(null),
            ),
          ],
        ),
      );
    }

    final query = _searchController.text;
    final matches = query.trim().isEmpty
        ? const []
        : pos.customers.where((c) => c.matches(query)).take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search name/phone…',
                  prefixIcon: Icon(Icons.search, size: 16),
                  prefixIconConstraints: BoxConstraints(
                    minWidth: 34,
                    minHeight: 34,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              height: 40,
              child: OutlinedButton.icon(
                onPressed: _openAddForm,
                icon: const Icon(Icons.person_add_alt, size: 15),
                label: const Text('New', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  backgroundColor: _showAddForm
                      ? AppColors.warningBg
                      : AppColors.surface,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.field),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (matches.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxHeight: 170),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.selector),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: matches.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: AppColors.canvas),
              itemBuilder: (context, index) {
                final customer = matches[index];
                return ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  title: Text(
                    customer.displayName,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: customer.phone == null
                      ? null
                      : Text(
                          customer.phone!,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                  onTap: () {
                    pos.selectCustomer(customer.id);
                    _searchController.clear();
                    setState(() {});
                  },
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _AddCustomerSheet extends StatefulWidget {
  const _AddCustomerSheet();

  @override
  State<_AddCustomerSheet> createState() => _AddCustomerSheetState();
}

class _AddCustomerSheetState extends State<_AddCustomerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _org = TextEditingController();
  final _mapLocation = TextEditingController();

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _org.dispose();
    _mapLocation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await context.read<PosController>().addCustomer(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        address: _address.text.trim(),
        organizationName: _org.text.trim(),
        googleMapLocation: _mapLocation.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.box)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
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
                const Text(
                  'New customer',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: 'Full name *'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(hintText: 'Phone number *'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Phone is required'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'Email (optional)',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _address,
                  decoration: const InputDecoration(
                    hintText: 'Home / delivery address (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warningBg,
                    border: Border.all(color: AppColors.warningBorder),
                    borderRadius: BorderRadius.circular(AppRadius.selector),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'COMPANY INFO (OPTIONAL)',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.warningText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _org,
                        decoration: const InputDecoration(
                          hintText: 'Company / organization name',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _mapLocation,
                        decoration: const InputDecoration(
                          hintText: 'Map location or "lat,lng"',
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.danger,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save customer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

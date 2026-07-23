import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../state/pos_controller.dart';
import '../../theme.dart';

/// Coupon entry, validated locally against the loaded discount list — the same
/// approach the web `DiscountInput` takes.
class DiscountField extends StatefulWidget {
  const DiscountField({super.key});

  @override
  State<DiscountField> createState() => _DiscountFieldState();
}

class _DiscountFieldState extends State<DiscountField> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply() {
    final pos = context.read<PosController>();
    final problem = pos.applyDiscountCode(_controller.text);
    setState(() => _error = problem);
    if (problem == null) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final pos = context.watch<PosController>();
    final applied = pos.appliedDiscount;

    if (applied != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            Flexible(
              child: Text(
                applied.code ?? 'Discount',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.successText,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '(-${money(pos.currency, pos.discountAmount)})',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close, size: 15),
              color: AppColors.textMuted,
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
              tooltip: 'Remove discount',
              onPressed: pos.removeDiscount,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _apply(),
                decoration: InputDecoration(
                  hintText: 'Discount code',
                  prefixIcon: const Icon(
                    Icons.local_offer_outlined,
                    size: 15,
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 34,
                    minHeight: 34,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  errorText: null,
                  enabledBorder: _error != null
                      ? OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.field),
                          borderSide: const BorderSide(
                            color: AppColors.dangerBorder,
                          ),
                        )
                      : null,
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              height: 40,
              child: FilledButton(
                onPressed: _apply,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.field),
                  ),
                ),
                child: const Icon(Icons.check, size: 17),
              ),
            ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 2),
            child: Text(
              _error!,
              style: const TextStyle(fontSize: 11.5, color: AppColors.danger),
            ),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../data/models/models.dart';
import '../../theme.dart';

/// Order types are colour-coded from the brand palette rather than the ad-hoc
/// Tailwind hues the web POS used, so all four stay distinguishable while
/// belonging to the same system.
const Map<OrderType, ({IconData icon, Color color})> _style = {
  OrderType.dineIn: (icon: Icons.restaurant, color: AppColors.primary),
  OrderType.takeaway: (
    icon: Icons.shopping_bag_outlined,
    color: AppColors.warningText,
  ),
  OrderType.delivery: (icon: Icons.local_shipping_outlined, color: AppColors.info),
  OrderType.catering: (
    icon: Icons.room_service_outlined,
    color: AppColors.success,
  ),
};

class OrderTypeSelector extends StatelessWidget {
  const OrderTypeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final OrderType value;
  final ValueChanged<OrderType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: OrderType.values.map((type) {
        final style = _style[type]!;
        final active = value == type;

        return InkWell(
          onTap: () => onChanged(type),
          borderRadius: BorderRadius.circular(AppRadius.field),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: active
                  ? style.color.withValues(alpha: 0.08)
                  : AppColors.surface,
              border: Border.all(
                color: active ? style.color : AppColors.border,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(AppRadius.field),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  style.icon,
                  size: 15,
                  color: active ? style.color : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  type.label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: active ? style.color : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

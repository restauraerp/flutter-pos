import 'package:flutter/material.dart';

import '../../../data/models/models.dart';
import '../../theme.dart';

class TableSelector extends StatelessWidget {
  const TableSelector({
    super.key,
    required this.tables,
    required this.selectedId,
    required this.loading,
    required this.onSelect,
  });

  final List<TableModel> tables;
  final int? selectedId;
  final bool loading;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text(
          'Loading tables…',
          style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
        ),
      );
    }

    if (tables.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text(
          'No tables available',
          style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
        ),
      );
    }

    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: tables.map((table) {
        final active = selectedId == table.id;
        final occupied = table.isOccupied;

        return Tooltip(
          message: occupied ? 'Table is currently occupied' : '',
          child: InkWell(
            onTap: occupied ? null : () => onSelect(table.id),
            borderRadius: BorderRadius.circular(AppRadius.selector),
            child: Opacity(
              opacity: occupied ? 0.7 : 1,
              child: Container(
                constraints: const BoxConstraints(minWidth: 62),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : (occupied ? AppColors.canvas : AppColors.surface),
                  border: Border.all(
                    color: active
                        ? AppColors.primary
                        : (occupied
                              ? AppColors.border
                              : AppColors.border),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.selector),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      table.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: active
                            ? AppColors.primary
                            : (occupied
                                  ? AppColors.textMuted
                                  : AppColors.textPrimary),
                      ),
                    ),
                    if (table.capacity != null)
                      Text(
                        '👤 ${table.capacity}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

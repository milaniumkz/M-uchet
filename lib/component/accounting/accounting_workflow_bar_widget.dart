import '/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';

class AccountingWorkflowBarWidget extends StatelessWidget {
  const AccountingWorkflowBarWidget({
    super.key,
    required this.currentStage,
  });

  final String currentStage;

  static const _stages = <_StageItem>[
    _StageItem('purchase', '1. Закупка'),
    _StageItem('warehouse', '2. Склад'),
    _StageItem('sales', '3. Реализация'),
    _StageItem('plan_fact', '4. План/факт'),
    _StageItem('reconciliation', '5. Сверка'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD9E2EC)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _stages.map((stage) {
          final selected = stage.id == currentStage;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFCBD5E1),
              ),
            ),
            child: Text(
              stage.label,
              style: theme.bodySmall.override(
                color: selected ? Colors.white : const Color(0xFF334155),
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StageItem {
  const _StageItem(this.id, this.label);
  final String id;
  final String label;
}

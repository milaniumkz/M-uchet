import '/app_state.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AccountingModeBarWidget extends StatelessWidget {
  const AccountingModeBarWidget({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final mode = context.watch<FFAppState>().accountingMode;
    final upSelected = mode == 'Up1';
    final buSelected = mode == 'Bu';
    final theme = FlutterFlowTheme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD9E2EC)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.bodyMedium.override(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.bodySmall.override(
                    color: const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Управленческий (С)'),
                selected: upSelected,
                selectedColor: const Color(0xFFDBEAFE),
                side: BorderSide(
                  color: upSelected
                      ? const Color(0xFF2563EB)
                      : const Color(0xFFCBD5E1),
                ),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: upSelected
                      ? const Color(0xFF1D4ED8)
                      : const Color(0xFF334155),
                ),
                onSelected: (_) => FFAppState().update(() {
                  FFAppState().accountingMode = 'Up1';
                }),
              ),
              ChoiceChip(
                label: const Text('Бухгалтерский'),
                selected: buSelected,
                selectedColor: const Color(0xFFE2E8F0),
                side: BorderSide(
                  color: buSelected
                      ? const Color(0xFF334155)
                      : const Color(0xFFCBD5E1),
                ),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: buSelected
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF334155),
                ),
                onSelected: (_) => FFAppState().update(() {
                  FFAppState().accountingMode = 'Bu';
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

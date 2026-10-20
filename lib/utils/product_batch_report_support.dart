import 'package:cloud_firestore/cloud_firestore.dart';

import 'inventory_costing_method.dart';
import 'ledger_scope.dart';

double _num(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
}

String _text(dynamic value) => value?.toString().trim() ?? '';

DateTime? _date(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return DateTime.tryParse(value.toString());
}

String _ledgerScopeLabel(LedgerScope scope) {
  switch (scope) {
    case LedgerScope.management:
      return 'Управленческий';
    case LedgerScope.accounting:
      return 'Бухгалтерский';
    case LedgerScope.both:
      return 'Общий';
  }
}

List<Map<String, dynamic>> buildProductBatchRows({
  required Map<String, dynamic> product,
  required List<Map<String, dynamic>> inventoryBatches,
}) {
  final productId = _text(product['id']);
  if (productId.isEmpty) return const [];

  final method = resolveInventoryCostingMethod(productData: product);
  final methodLabel = inventoryCostingMethodLabel(method);

  final rows = inventoryBatches
      .where((batch) {
        if (_text(batch['product_id'] ?? batch['productId']) != productId) {
          return false;
        }
        final qty = _num(batch['qty_remaining'] ?? batch['qtyRemaining']);
        if (qty <= 0) return false;
        if (batch['is_active'] == false || batch['isActive'] == false) {
          return false;
        }
        final status = _text(batch['status']).toLowerCase();
        return status != 'archived' &&
            status != 'closed' &&
            status != 'inactive';
      })
      .map((batch) {
        final qty = _num(batch['qty_remaining'] ?? batch['qtyRemaining']);
        final unitCost = _num(batch['unit_cost'] ?? batch['unitCost']);
        final totalCost = _num(batch['total_cost'] ?? batch['totalCost']);
        final ledgerScope = ledgerScopeFromData(batch);
        return <String, dynamic>{
          'batch_id': _text(batch['id']),
          'warehouse_name': _text(
            batch['warehouse_name'] ?? batch['warehouse'] ?? batch['warehouse_id'],
          ),
          'ledger_scope': ledgerScope.storageValue,
          'ledger_scope_label': _ledgerScopeLabel(ledgerScope),
          'costing_method': method.storageValue,
          'costing_method_label': methodLabel,
          'qty_remaining': qty,
          'unit_cost': unitCost,
          'total_value': totalCost > 0 ? totalCost : qty * unitCost,
          'received_at': _date(
            batch['received_at'] ?? batch['receivedAt'] ?? batch['created_at'],
          ),
          'source_type': _text(batch['source_type'] ?? batch['sourceType']),
        };
      })
      .toList();

  rows.sort((a, b) {
    final dateA = a['received_at'] as DateTime?;
    final dateB = b['received_at'] as DateTime?;
    final compare = (dateB ?? DateTime(1970)).compareTo(
      dateA ?? DateTime(1970),
    );
    if (compare != 0) return compare;
    return (a['warehouse_name'] ?? '')
        .toString()
        .compareTo((b['warehouse_name'] ?? '').toString());
  });

  return rows;
}

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
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
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

Map<String, dynamic> buildWarehouseBatchReport({
  required List<Map<String, dynamic>> inventoryBatches,
  required List<Map<String, dynamic>> products,
}) {
  final productById = <String, Map<String, dynamic>>{
    for (final product in products)
      _text(product['id']): product,
  };

  final rows = <Map<String, dynamic>>[];
  final methodCounts = <String, int>{};
  var totalQty = 0.0;
  var totalValue = 0.0;

  for (final batch in inventoryBatches) {
    final qtyRemaining =
        _num(batch['qty_remaining'] ?? batch['qtyRemaining']);
    if (qtyRemaining <= 0) continue;
    if (batch['is_active'] == false || batch['isActive'] == false) continue;
    final status = _text(batch['status']).toLowerCase();
    if (status == 'archived' || status == 'closed' || status == 'inactive') {
      continue;
    }

    final productId = _text(batch['product_id'] ?? batch['productId']);
    final product = productById[productId] ?? const <String, dynamic>{};
    final unitCost = _num(batch['unit_cost'] ?? batch['unitCost']);
    final totalCost = _num(batch['total_cost'] ?? batch['totalCost']);
    final value = totalCost > 0 ? totalCost : qtyRemaining * unitCost;
    final ledgerScope = ledgerScopeFromData(batch);
    final method = resolveInventoryCostingMethod(
      explicitValue:
          batch['inventory_costing_method'] ?? batch['costing_method'],
      productData: product,
    );
    final methodLabel = inventoryCostingMethodLabel(method);
    final receivedAt = _date(
      batch['received_at'] ?? batch['receivedAt'] ?? batch['created_at'],
    );

    methodCounts[methodLabel] = (methodCounts[methodLabel] ?? 0) + 1;
    totalQty += qtyRemaining;
    totalValue += value;

    rows.add({
      'batch_id': _text(batch['id']),
      'product_id': productId,
      'product_name': _text(batch['product_name']).isNotEmpty
          ? _text(batch['product_name'])
          : _text(product['name']),
      'warehouse_name':
          _text(batch['warehouse_name'] ?? batch['warehouse'] ?? batch['warehouse_id']),
      'ledger_scope': ledgerScope.storageValue,
      'ledger_scope_label': _ledgerScopeLabel(ledgerScope),
      'costing_method': method.storageValue,
      'costing_method_label': methodLabel,
      'qty_remaining': qtyRemaining,
      'unit_cost': unitCost,
      'total_value': value,
      'received_at': receivedAt,
      'source_type': _text(batch['source_type'] ?? batch['sourceType']),
      'source_document_id':
          _text(batch['source_document_id'] ?? batch['sourceDocumentId']),
    });
  }

  rows.sort((a, b) {
    final dateA = a['received_at'] as DateTime?;
    final dateB = b['received_at'] as DateTime?;
    final compare = (dateB ?? DateTime(1970)).compareTo(
      dateA ?? DateTime(1970),
    );
    if (compare != 0) return compare;
    return (a['product_name'] ?? '')
        .toString()
        .compareTo((b['product_name'] ?? '').toString());
  });

  return {
    'rows': rows,
    'total_batches': rows.length,
    'total_qty': totalQty,
    'total_value': totalValue,
    'method_counts': methodCounts,
  };
}

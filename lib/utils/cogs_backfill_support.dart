import '/utils/inventory_costing_method.dart';
import '/utils/ledger_scope.dart';

double _num(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
}

String _string(dynamic value) => value?.toString().trim() ?? '';

Map<String, dynamic> _removeNulls(Map<String, dynamic> data) =>
    Map<String, dynamic>.from(data)
      ..removeWhere((key, value) => value == null);

String legacyCogsBackfillDocId({
  required String legacyDocId,
  required String prefix,
}) {
  final normalized = legacyDocId.trim().isEmpty ? 'unknown' : legacyDocId.trim();
  return '${prefix}_$normalized';
}

Map<String, dynamic>? buildBackfillCogsEntryPayloadFromLegacy({
  required String legacyDocId,
  required Map<String, dynamic> legacyData,
}) {
  final companyId = _string(legacyData['idCompany']);
  final saleId = _string(legacyData['sale_id']);
  final saleItemId = _string(legacyData['sale_item_id']);
  final productId = _string(legacyData['product_id']);
  final quantity = _num(legacyData['qty'] ?? legacyData['quantity']);
  final totalCost = _num(legacyData['total_cost'] ?? legacyData['totalCost']);
  if (companyId.isEmpty ||
      saleId.isEmpty ||
      saleItemId.isEmpty ||
      productId.isEmpty ||
      quantity <= 0 ||
      totalCost <= 0) {
    return null;
  }

  final ledgerScope = ledgerScopeFromData(legacyData);
  final costingMethod = inventoryCostingMethodFromValue(
    legacyData['costing_method'] ?? legacyData['costingMethod'],
  );
  final unitCostApplied = _num(
    legacyData['unit_cost_applied'] ??
        legacyData['cost_basis_unit_cost'] ??
        legacyData['unit_cost'],
  );
  final batchId = _string(
    legacyData['source_batch_id'] ?? legacyData['batch_id'],
  );

  return _removeNulls(<String, dynamic>{
    'legacy_source_id': legacyDocId.trim(),
    'legacy_source_collection': 'sale_item_cogs',
    'idCompany': companyId,
    'item_kind': 'product',
    'sale_id': saleId,
    'sale_item_id': saleItemId,
    'product_id': productId,
    'product_name': _string(legacyData['product_name']),
    'warehouse_id': _string(legacyData['warehouse_id']),
    'warehouse_name': _string(legacyData['warehouse_name']),
    ...ledgerScopeFields(ledgerScope: ledgerScope),
    ...inventoryCostingMethodFields(costingMethod),
    'quantity': quantity,
    'qty': quantity,
    'unit_cost': unitCostApplied,
    'cost_basis_unit_cost': unitCostApplied,
    'total_cost': totalCost,
    'batch_id': batchId.isEmpty ? null : batchId,
    'source_batch_id': batchId.isEmpty ? null : batchId,
  });
}

Map<String, dynamic>? buildBackfillBatchConsumptionPayloadFromLegacy({
  required String legacyDocId,
  required Map<String, dynamic> legacyData,
}) {
  final companyId = _string(legacyData['idCompany']);
  final saleId = _string(legacyData['sale_id']);
  final saleItemId = _string(legacyData['sale_item_id']);
  final batchId = _string(
    legacyData['source_batch_id'] ?? legacyData['batch_id'],
  );
  final quantity = _num(legacyData['qty'] ?? legacyData['quantity']);
  final totalCost = _num(legacyData['total_cost'] ?? legacyData['totalCost']);
  final unitCost = _num(legacyData['unit_cost']);
  if (companyId.isEmpty ||
      saleId.isEmpty ||
      saleItemId.isEmpty ||
      batchId.isEmpty ||
      quantity <= 0 ||
      totalCost <= 0) {
    return null;
  }

  final ledgerScope = ledgerScopeFromData(legacyData);

  return _removeNulls(<String, dynamic>{
    'legacy_source_id': legacyDocId.trim(),
    'legacy_source_collection': 'sale_item_cogs',
    'idCompany': companyId,
    'sale_id': saleId,
    'sale_item_id': saleItemId,
    'batch_id': batchId,
    'source_batch_id': batchId,
    ...ledgerScopeFields(ledgerScope: ledgerScope),
    'quantity': quantity,
    'qty': quantity,
    'unit_cost': unitCost > 0 ? unitCost : (totalCost / quantity),
    'total_cost': totalCost,
  });
}

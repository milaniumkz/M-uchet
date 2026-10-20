double inventoryBatchNum(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
}

String inventoryBatchText(dynamic value) => value?.toString().trim() ?? '';

String _productKey(Map<String, dynamic> data) {
  return (data['product_id'] ?? data['id'] ?? '').toString().trim();
}

String _productWarehouseKey(Map<String, dynamic> data) {
  final productId = _productKey(data);
  final warehouseId =
      (data['warehouse_id'] ?? data['warehouse'] ?? '').toString().trim();
  return '$productId::$warehouseId';
}

Map<String, dynamic> enrichProductsWithBatchValuation({
  required List<Map<String, dynamic>> products,
  required List<Map<String, dynamic>> inventoryBatches,
}) {
  final metrics = <String, Map<String, double>>{};
  for (final batch in inventoryBatches) {
    final key = _productKey(batch);
    if (key.isEmpty) continue;
    final qty = inventoryBatchNum(
      batch['qty_remaining'] ?? batch['qtyRemaining'],
    );
    final unitCost = inventoryBatchNum(
      batch['unit_cost'] ?? batch['unitCost'],
    );
    final row = metrics.putIfAbsent(
      key,
      () => <String, double>{'qty': 0, 'value': 0, 'cost': 0},
    );
    row['qty'] = (row['qty'] ?? 0) + qty;
    row['value'] = (row['value'] ?? 0) + (qty * unitCost);
    row['cost'] = (row['cost'] ?? 0) + (qty * unitCost);
  }

  final enriched = products.map((product) {
    final key = _productKey(product);
    final metric = metrics[key];
    if (metric == null) return product;
    final qty = metric['qty'] ?? 0;
    final value = metric['value'] ?? 0;
    final averageCost = qty <= 0 ? 0 : value / qty;
    return {
      ...product,
      'stock': qty,
      'stock_value': value,
      'purchase_price':
          averageCost > 0 ? averageCost : product['purchase_price'],
      'cost_price': averageCost > 0 ? averageCost : product['cost_price'],
      'inventory_costing_method': inventoryBatchText(
        product['inventory_costing_method'] ?? product['costing_method'],
      ).isEmpty
          ? 'FIFO'
          : inventoryBatchText(
              product['inventory_costing_method'] ?? product['costing_method'],
            ),
    };
  }).toList();

  return <String, dynamic>{'items': enriched};
}

Map<String, dynamic> enrichWarehouseItemsWithBatchValuation({
  required List<Map<String, dynamic>> items,
  required List<Map<String, dynamic>> inventoryBatches,
}) {
  final metrics = <String, Map<String, double>>{};
  for (final batch in inventoryBatches) {
    final key = _productWarehouseKey(batch);
    if (key == '::') continue;
    final qty = inventoryBatchNum(
      batch['qty_remaining'] ?? batch['qtyRemaining'],
    );
    final unitCost = inventoryBatchNum(
      batch['unit_cost'] ?? batch['unitCost'],
    );
    final row = metrics.putIfAbsent(
      key,
      () => <String, double>{'qty': 0, 'value': 0},
    );
    row['qty'] = (row['qty'] ?? 0) + qty;
    row['value'] = (row['value'] ?? 0) + (qty * unitCost);
  }

  final enriched = items.map((item) {
    final key = _productWarehouseKey(item);
    final metric = metrics[key];
    if (metric == null) return item;
    return {
      ...item,
      'stock': metric['qty'] ?? 0,
      'stock_value': metric['value'] ?? 0,
    };
  }).toList();

  return <String, dynamic>{'items': enriched};
}

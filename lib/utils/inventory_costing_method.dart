enum InventoryCostingMethod {
  fifo('FIFO'),
  weightedAverage('WEIGHTED_AVERAGE');

  const InventoryCostingMethod(this.storageValue);

  final String storageValue;
}

InventoryCostingMethod inventoryCostingMethodFromValue(dynamic raw) {
  final normalized = raw?.toString().trim().toUpperCase() ?? '';
  switch (normalized) {
    case 'WEIGHTED_AVERAGE':
    case 'WEIGHTED':
    case 'AVERAGE':
    case 'AVG':
      return InventoryCostingMethod.weightedAverage;
    case 'FIFO':
    default:
      return InventoryCostingMethod.fifo;
  }
}

InventoryCostingMethod resolveInventoryCostingMethod({
  dynamic explicitValue,
  Map<String, dynamic>? productData,
  Map<String, dynamic>? warehouseData,
  Map<String, dynamic>? companyData,
}) {
  final explicit = explicitValue?.toString().trim();
  if (explicit != null && explicit.isNotEmpty) {
    return inventoryCostingMethodFromValue(explicit);
  }

  for (final data in [productData, warehouseData, companyData]) {
    if (data == null) continue;
    final raw = data['inventory_costing_method'] ??
        data['costing_method'] ??
        data['inventoryCostingMethod'];
    final normalized = raw?.toString().trim() ?? '';
    if (normalized.isNotEmpty) {
      return inventoryCostingMethodFromValue(normalized);
    }
  }

  return InventoryCostingMethod.fifo;
}

Map<String, dynamic> inventoryCostingMethodFields(
  InventoryCostingMethod method,
) {
  return <String, dynamic>{
    'inventory_costing_method': method.storageValue,
    'costing_method': method.storageValue,
  };
}

String inventoryCostingMethodLabel(InventoryCostingMethod method) {
  switch (method) {
    case InventoryCostingMethod.weightedAverage:
      return 'Средневзвешенная';
    case InventoryCostingMethod.fifo:
      return 'FIFO';
  }
}

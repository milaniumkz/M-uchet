import '/utils/inventory_costing_method.dart';

double saleItemCogsNum(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
}

class SaleItemCogsReportRow {
  const SaleItemCogsReportRow({
    required this.saleId,
    required this.saleItemId,
    required this.productId,
    required this.productName,
    required this.warehouseName,
    required this.costingMethod,
    required this.quantity,
    required this.unitCostApplied,
    required this.totalCost,
    required this.batchBreakdown,
  });

  final String saleId;
  final String saleItemId;
  final String productId;
  final String productName;
  final String warehouseName;
  final String costingMethod;
  final double quantity;
  final double unitCostApplied;
  final double totalCost;
  final List<String> batchBreakdown;
}

List<Map<String, dynamic>> resolveSalesCogsItems({
  required Iterable<Map<String, dynamic>> cogsEntries,
  required Iterable<Map<String, dynamic>> legacyCogsItems,
}) {
  final normalizedEntries = cogsEntries
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
  if (normalizedEntries.isNotEmpty) {
    return normalizedEntries;
  }
  return legacyCogsItems
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

List<SaleItemCogsReportRow> buildSaleItemCogsReportRows({
  required List<Map<String, dynamic>> cogsItems,
}) {
  final grouped = <String, Map<String, dynamic>>{};

  for (final item in cogsItems) {
    final saleItemId = (item['sale_item_id'] ?? '').toString().trim();
    if (saleItemId.isEmpty) continue;
    final row = grouped.putIfAbsent(
      saleItemId,
      () => <String, dynamic>{
        'saleId': (item['sale_id'] ?? '').toString().trim(),
        'saleItemId': saleItemId,
        'productId': (item['product_id'] ?? '').toString().trim(),
        'productName': (item['product_name'] ?? '').toString().trim(),
        'warehouseName': (item['warehouse_name'] ?? '').toString().trim(),
        'costingMethod': inventoryCostingMethodFromValue(
          item['costing_method'],
        ).storageValue,
        'quantity': 0.0,
        'unitCostApplied': saleItemCogsNum(
          item['unit_cost_applied'] ?? item['cost_basis_unit_cost'],
        ),
        'totalCost': 0.0,
        'batchBreakdown': <String>[],
      },
    );

    final qty = saleItemCogsNum(item['qty']);
    final totalCost = saleItemCogsNum(item['total_cost']);
    row['quantity'] = (row['quantity'] as double) + qty;
    row['totalCost'] = (row['totalCost'] as double) + totalCost;

    final batchId = (item['batch_id'] ?? '').toString().trim();
    final unitCost = saleItemCogsNum(item['unit_cost']);
    final method = (row['costingMethod'] ?? 'FIFO').toString();
    if (batchId.isNotEmpty) {
      (row['batchBreakdown'] as List<String>).add(
        '$batchId: ${qty.toStringAsFixed(2)} x ${unitCost.toStringAsFixed(2)}',
      );
    } else if (method == InventoryCostingMethod.weightedAverage.storageValue) {
      (row['batchBreakdown'] as List<String>).add(
        'AVG: ${qty.toStringAsFixed(2)} x ${unitCost.toStringAsFixed(2)}',
      );
    }
  }

  final rows = grouped.values.map((row) {
    return SaleItemCogsReportRow(
      saleId: (row['saleId'] ?? '').toString(),
      saleItemId: (row['saleItemId'] ?? '').toString(),
      productId: (row['productId'] ?? '').toString(),
      productName: (row['productName'] ?? '').toString(),
      warehouseName: (row['warehouseName'] ?? '').toString(),
      costingMethod: (row['costingMethod'] ?? 'FIFO').toString(),
      quantity: row['quantity'] as double? ?? 0.0,
      unitCostApplied: row['unitCostApplied'] as double? ?? 0.0,
      totalCost: row['totalCost'] as double? ?? 0.0,
      batchBreakdown:
          List<String>.from(row['batchBreakdown'] as List? ?? const []),
    );
  }).toList()
    ..sort((a, b) => b.saleId.compareTo(a.saleId));

  return rows;
}

List<SaleItemCogsReportRow> buildSaleItemCogsReportRowsForSaleIds({
  required List<Map<String, dynamic>> cogsItems,
  required Set<String> saleIds,
}) {
  if (saleIds.isEmpty) return const [];
  final filtered = cogsItems.where((item) {
    final saleId = (item['sale_id'] ?? '').toString().trim();
    return saleId.isNotEmpty && saleIds.contains(saleId);
  }).toList();
  return buildSaleItemCogsReportRows(cogsItems: filtered);
}

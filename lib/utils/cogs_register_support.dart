import '/utils/sale_item_cogs_report_support.dart';

double cogsRegisterNum(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
}

String cogsSalesItemJoinKey(Map<String, dynamic> data) {
  final saleItemId =
      (data['sale_item_id'] ?? data['id'] ?? '').toString().trim();
  if (saleItemId.isNotEmpty) return 'sale_item:$saleItemId';
  final saleId = (data['sale_id'] ?? '').toString().trim();
  final productId = (data['product_id'] ?? data['id'] ?? '').toString().trim();
  if (saleId.isNotEmpty && productId.isNotEmpty) {
    return 'sale_product:$saleId:$productId';
  }
  final productName =
      (data['product_name'] ?? data['name'] ?? '').toString().trim().toLowerCase();
  if (saleId.isNotEmpty && productName.isNotEmpty) {
    return 'sale_name:$saleId:$productName';
  }
  return '';
}

Map<String, double> buildCogsBySalesItemKey({
  required List<Map<String, dynamic>> cogsEntries,
  required List<Map<String, dynamic>> legacyCogsItems,
}) {
  final resolved = resolveSalesCogsItems(
    cogsEntries: cogsEntries,
    legacyCogsItems: legacyCogsItems,
  );
  final cogsByKey = <String, double>{};
  for (final item in resolved) {
    final key = cogsSalesItemJoinKey(item);
    if (key.isEmpty) continue;
    final cost = cogsRegisterNum(
      item['total_cost'] ?? item['cogs_amount'] ?? item['cost_amount'],
    );
    cogsByKey[key] = (cogsByKey[key] ?? 0) + cost;
  }
  return cogsByKey;
}

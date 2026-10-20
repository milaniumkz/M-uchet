import '/utils/cogs_register_support.dart';
import '/utils/inventory_costing_method.dart';
import '/utils/ledger_scope.dart';

class CogsIntegritySummary {
  const CogsIntegritySummary({
    required this.salesItemsChecked,
    required this.missingCogsCount,
    required this.fifoMissingBatchCount,
    required this.ledgerMismatchCount,
  });

  final int salesItemsChecked;
  final int missingCogsCount;
  final int fifoMissingBatchCount;
  final int ledgerMismatchCount;

  int get totalIssues =>
      missingCogsCount + fifoMissingBatchCount + ledgerMismatchCount;
}

List<List<String>> buildCogsIntegrityExportRows({
  required CogsIntegritySummary summary,
}) {
  return <List<String>>[
    <String>['COGS Audit'],
    <String>[],
    <String>['Проверено sale items', summary.salesItemsChecked.toString()],
    <String>['Нет COGS', summary.missingCogsCount.toString()],
    <String>['FIFO без batch', summary.fifoMissingBatchCount.toString()],
    <String>['Ledger mismatch', summary.ledgerMismatchCount.toString()],
    <String>['Всего проблем', summary.totalIssues.toString()],
  ];
}

CogsIntegritySummary computeCogsIntegritySummary({
  required List<Map<String, dynamic>> salesItems,
  required List<Map<String, dynamic>> cogsEntries,
  required List<Map<String, dynamic>> legacyCogsItems,
  required List<Map<String, dynamic>> batchConsumptions,
}) {
  final cogsByKey = buildCogsBySalesItemKey(
    cogsEntries: cogsEntries,
    legacyCogsItems: legacyCogsItems,
  );
  final batchCountsBySaleItemId = <String, int>{};
  for (final item in batchConsumptions) {
    final saleItemId = (item['sale_item_id'] ?? '').toString().trim();
    if (saleItemId.isEmpty) continue;
    batchCountsBySaleItemId[saleItemId] =
        (batchCountsBySaleItemId[saleItemId] ?? 0) + 1;
  }

  var missingCogsCount = 0;
  var fifoMissingBatchCount = 0;
  var ledgerMismatchCount = 0;

  for (final item in salesItems) {
    final itemKey = cogsSalesItemJoinKey(item);
    final saleItemId = (item['id'] ?? item['sale_item_id'] ?? '').toString().trim();
    final itemKind = (item['item_kind'] ?? 'product').toString().trim().toLowerCase();
    final itemLedgerScope = ledgerScopeFromData(item);
    final costingMethod = inventoryCostingMethodFromValue(
      item['costing_method'] ?? item['inventory_costing_method'],
    );

    final hasCogs = itemKey.isNotEmpty && (cogsByKey[itemKey] ?? 0) > 0;
    if (!hasCogs) {
      missingCogsCount += 1;
      continue;
    }

    if (itemKind == 'product' &&
        costingMethod == InventoryCostingMethod.fifo &&
        saleItemId.isNotEmpty &&
        (batchCountsBySaleItemId[saleItemId] ?? 0) == 0) {
      fifoMissingBatchCount += 1;
    }

    final matchingEntries = cogsEntries.where((entry) {
      final entryKey = cogsSalesItemJoinKey(entry);
      return entryKey.isNotEmpty && entryKey == itemKey;
    }).toList();
    if (matchingEntries.isEmpty) continue;
    final hasMismatch = matchingEntries.any(
      (entry) => !ledgerScopeFromData(entry).matches(itemLedgerScope),
    );
    if (hasMismatch) {
      ledgerMismatchCount += 1;
    }
  }

  return CogsIntegritySummary(
    salesItemsChecked: salesItems.length,
    missingCogsCount: missingCogsCount,
    fifoMissingBatchCount: fifoMissingBatchCount,
    ledgerMismatchCount: ledgerMismatchCount,
  );
}

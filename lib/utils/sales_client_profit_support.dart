import '/utils/product_sales_metrics_support.dart';
import '/utils/sales_profit_breakdown_support.dart';

class SalesClientProfitRow {
  const SalesClientProfitRow({
    required this.key,
    required this.clientName,
    required this.orders,
    required this.revenue,
    required this.cogs,
    required this.grossProfit,
    this.lastPurchaseAt,
  });

  final String key;
  final String clientName;
  final int orders;
  final double revenue;
  final double cogs;
  final double grossProfit;
  final DateTime? lastPurchaseAt;
}

List<SalesClientProfitRow> buildSalesClientProfitRows({
  required List<Map<String, dynamic>> salesLedger,
  List<Map<String, dynamic>> salesItems = const [],
  List<Map<String, dynamic>> cogsEntries = const [],
  List<Map<String, dynamic>> legacyCogsItems = const [],
}) {
  final cogsBySaleId = buildSaleCogsBySaleId(
    salesItems: salesItems,
    cogsEntries: cogsEntries,
    legacyCogsItems: legacyCogsItems,
  );
  final rows = <String, Map<String, dynamic>>{};

  for (final sale in salesLedger) {
    final key = salesProfitBreakdownKey(
      sale,
      idField: 'client_id',
      nameField: 'client_name',
    );
    if (key.isEmpty) continue;
    final row = rows.putIfAbsent(
      key,
      () => <String, dynamic>{
        'clientName': ((sale['client_name'] ?? '').toString().trim().isEmpty)
            ? key
            : (sale['client_name'] ?? '').toString().trim(),
        'orders': 0,
        'revenue': 0.0,
        'cogs': 0.0,
        'grossProfit': 0.0,
        'lastPurchaseAt': null,
      },
    );
    final saleId = (sale['sale_id'] ?? sale['id'] ?? '').toString().trim();
    final revenue = productSalesNum(sale['amount']);
    final cogs = cogsBySaleId[saleId] ?? 0;
    final createdAt = sale['created_at'] is DateTime ? sale['created_at'] as DateTime : null;
    row['orders'] = (row['orders'] as int) + 1;
    row['revenue'] = (row['revenue'] as double) + revenue;
    row['cogs'] = (row['cogs'] as double) + cogs;
    row['grossProfit'] = (row['grossProfit'] as double) + (revenue - cogs);
    final lastPurchaseAt = row['lastPurchaseAt'] as DateTime?;
    if (createdAt != null &&
        (lastPurchaseAt == null || createdAt.isAfter(lastPurchaseAt))) {
      row['lastPurchaseAt'] = createdAt;
    }
  }

  final result = rows.entries.map((entry) {
    final row = entry.value;
    return SalesClientProfitRow(
      key: entry.key,
      clientName: (row['clientName'] ?? '').toString(),
      orders: (row['orders'] as int?) ?? 0,
      revenue: (row['revenue'] as double?) ?? 0,
      cogs: (row['cogs'] as double?) ?? 0,
      grossProfit: (row['grossProfit'] as double?) ?? 0,
      lastPurchaseAt: row['lastPurchaseAt'] as DateTime?,
    );
  }).toList()
    ..sort((a, b) => b.grossProfit.compareTo(a.grossProfit));

  return result;
}

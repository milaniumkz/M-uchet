import '/utils/product_sales_metrics_support.dart';
import '/utils/sale_item_cogs_report_support.dart';
import '/utils/shop_finance_ledger_support.dart';

String salesProfitBreakdownKey(
  Map<String, dynamic> data, {
  required String idField,
  required String nameField,
}) {
  final id = (data[idField] ?? '').toString().trim();
  if (id.isNotEmpty) return 'id:$id';
  final name = (data[nameField] ?? '').toString().trim();
  if (name.isNotEmpty) return 'name:${name.toLowerCase()}';
  return '';
}

Map<String, double> buildSaleCogsBySaleId({
  List<Map<String, dynamic>> salesItems = const [],
  List<Map<String, dynamic>> cogsEntries = const [],
  List<Map<String, dynamic>> legacyCogsItems = const [],
}) {
  final resolvedCogsItems = salesItems.isNotEmpty
      ? salesItems
      : resolveSalesCogsItems(
          cogsEntries: cogsEntries,
          legacyCogsItems: legacyCogsItems,
        );
  final cogsBySaleId = <String, double>{};
  for (final item in resolvedCogsItems) {
    final saleId = (item['sale_id'] ?? '').toString().trim();
    if (saleId.isEmpty) continue;
    cogsBySaleId[saleId] =
        (cogsBySaleId[saleId] ?? 0) + saleItemCogsNum(
          item['total_cost'] ?? item['cogs_amount'] ?? item['cost_amount'],
        );
  }
  return cogsBySaleId;
}

List<Map<String, dynamic>> buildCashierProfitRows({
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
      idField: 'cashier_id',
      nameField: 'cashier_name',
    );
    if (key.isEmpty) continue;
    final row = rows.putIfAbsent(
      key,
      () => <String, dynamic>{
        'cashier_name': ((sale['cashier_name'] ?? '').toString().trim().isEmpty)
            ? key
            : (sale['cashier_name'] ?? '').toString().trim(),
        'orders': 0,
        'revenue': 0.0,
        'cogs': 0.0,
        'gross_profit': 0.0,
      },
    );
    final saleId = (sale['sale_id'] ?? sale['id'] ?? '').toString().trim();
    final revenue = productSalesNum(sale['amount']);
    final cogs = cogsBySaleId[saleId] ?? 0;
    row['orders'] = (row['orders'] as int) + 1;
    row['revenue'] = (row['revenue'] as double) + revenue;
    row['cogs'] = (row['cogs'] as double) + cogs;
    row['gross_profit'] = (row['gross_profit'] as double) + (revenue - cogs);
  }

  final list = rows.values.toList()
    ..sort((a, b) => productSalesNum(b['gross_profit'])
        .compareTo(productSalesNum(a['gross_profit'])));
  return list;
}

List<Map<String, dynamic>> buildCashRegisterProfitRows({
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
      idField: 'cash_register_id',
      nameField: 'cash_register_name',
    );
    if (key.isEmpty) continue;
    final row = rows.putIfAbsent(
      key,
      () => <String, dynamic>{
        'cash_register_id':
            (sale['cash_register_id'] ?? '').toString().trim(),
        'register_name':
            ((sale['cash_register_name'] ?? '').toString().trim().isEmpty)
                ? key
                : (sale['cash_register_name'] ?? '').toString().trim(),
        'transactions': 0,
        'revenue': 0.0,
        'cogs': 0.0,
        'gross_profit': 0.0,
      },
    );
    final saleId = (sale['sale_id'] ?? sale['id'] ?? '').toString().trim();
    final revenue = productSalesNum(sale['amount']);
    final cogs = cogsBySaleId[saleId] ?? 0;
    row['transactions'] = (row['transactions'] as int) + 1;
    row['revenue'] = (row['revenue'] as double) + revenue;
    row['cogs'] = (row['cogs'] as double) + cogs;
    row['gross_profit'] = (row['gross_profit'] as double) + (revenue - cogs);
  }

  final list = rows.values.toList()
    ..sort((a, b) => productSalesNum(b['gross_profit'])
        .compareTo(productSalesNum(a['gross_profit'])));
  return list;
}

Map<String, dynamic> buildShopCogsSummary({
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
  final cogsByShopKey = <String, double>{};

  for (final sale in salesLedger) {
    final shopKey = shopFinanceKey(sale);
    if (shopKey.isEmpty) continue;
    final saleId = (sale['sale_id'] ?? sale['id'] ?? '').toString().trim();
    cogsByShopKey[shopKey] =
        (cogsByShopKey[shopKey] ?? 0) + (cogsBySaleId[saleId] ?? 0);
  }

  return <String, dynamic>{'cogsByShopKey': cogsByShopKey};
}

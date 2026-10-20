import '/utils/sales_ledger_support.dart';
import '/utils/sales_profit_breakdown_support.dart';

double shopFinanceNum(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
}

String shopFinanceKey(
  Map<String, dynamic> data, {
  String idField = 'shop_id',
  String nameField = 'shop_name',
}) {
  final id = (data[idField] ?? data['id'] ?? '').toString().trim();
  if (id.isNotEmpty) return 'id:$id';
  final name = (data[nameField] ?? data['name'] ?? '').toString().trim();
  if (name.isNotEmpty) return 'name:${name.toLowerCase()}';
  return '';
}

Map<String, dynamic> buildShopFinanceLedger({
  required List<Map<String, dynamic>> shops,
  required List<Map<String, dynamic>> salesLedger,
  List<Map<String, dynamic>> salesItems = const [],
  List<Map<String, dynamic>> cogsEntries = const [],
  List<Map<String, dynamic>> legacyCogsItems = const [],
  required List<Map<String, dynamic>> shopExpenses,
  required List<Map<String, dynamic>> cashRegisters,
  required List<Map<String, dynamic>> cashRegisterIncassations,
}) {
  final rows = <String, _ShopFinanceRow>{};
  final cogsByShopKey = Map<String, double>.from(
    buildShopCogsSummary(
          salesLedger: salesLedger,
          salesItems: salesItems,
          cogsEntries: cogsEntries,
          legacyCogsItems: legacyCogsItems,
        )['cogsByShopKey'] as Map? ??
        const <String, double>{},
  );

  void ensureShop(Map<String, dynamic> item) {
    final key = shopFinanceKey(item);
    if (key.isEmpty) return;
    rows.putIfAbsent(
      key,
      () => _ShopFinanceRow(
        key: key,
        shopId: (item['shop_id'] ?? item['id'] ?? '').toString().trim(),
        shopName: (item['shop_name'] ?? item['name'] ?? '').toString().trim(),
      ),
    );
  }

  for (final shop in shops) {
    ensureShop(shop);
  }

  for (final sale in salesLedger) {
    final key = shopFinanceKey(sale);
    if (key.isEmpty) continue;
    ensureShop(sale);
    rows[key]!.revenue += salesLedgerNum(sale['amount']);
    rows[key]!.salesCount += 1;
  }

  for (final entry in cogsByShopKey.entries) {
    if (!rows.containsKey(entry.key)) continue;
    rows[entry.key]!.cogs += entry.value;
  }

  for (final expense in shopExpenses) {
    final key = shopFinanceKey(expense);
    if (key.isEmpty) continue;
    ensureShop(expense);
    rows[key]!.expenses += shopFinanceNum(expense['amount']);
    rows[key]!.expenseCount += 1;
  }

  final registerByShiftId = <String, Map<String, dynamic>>{};
  for (final register in cashRegisters) {
    final registerId = (register['id'] ?? '').toString().trim();
    if (registerId.isNotEmpty) {
      registerByShiftId[registerId] = register;
    }
    final key = shopFinanceKey(register);
    if (key.isEmpty) continue;
    ensureShop(register);
    rows[key]!.cashTurnover += shopFinanceNum(register['cash_sales']) +
        shopFinanceNum(register['card_sales']);
    rows[key]!.endingCash += shopFinanceNum(register['ending_cash']);
    rows[key]!.recordedIncassations +=
        shopFinanceNum(register['incassation_total']);
    rows[key]!.registerCount += 1;
  }

  for (final incassation in cashRegisterIncassations) {
    final shiftId =
        (incassation['cash_register_shift_id'] ?? '').toString().trim();
    final register = shiftId.isEmpty ? null : registerByShiftId[shiftId];
    final source = register ?? incassation;
    final key = shopFinanceKey(source);
    if (key.isEmpty) continue;
    ensureShop(source);
    rows[key]!.incassations += shopFinanceNum(incassation['amount']);
    rows[key]!.incassationCount += 1;
  }

  final list = rows.values.map((row) => row.toMap()).toList()
    ..sort((a, b) =>
        shopFinanceNum(b['profit']).compareTo(shopFinanceNum(a['profit'])));

  final summary = <String, dynamic>{
    'revenue': list.fold<double>(
      0,
      (sum, row) => sum + shopFinanceNum(row['revenue']),
    ),
    'cogs': list.fold<double>(
      0,
      (sum, row) => sum + shopFinanceNum(row['cogs']),
    ),
    'gross_profit': list.fold<double>(
      0,
      (sum, row) => sum + shopFinanceNum(row['gross_profit']),
    ),
    'expenses': list.fold<double>(
      0,
      (sum, row) => sum + shopFinanceNum(row['expenses']),
    ),
    'profit': list.fold<double>(
      0,
      (sum, row) => sum + shopFinanceNum(row['profit']),
    ),
    'cash_turnover': list.fold<double>(
      0,
      (sum, row) => sum + shopFinanceNum(row['cash_turnover']),
    ),
    'incassations': list.fold<double>(
      0,
      (sum, row) => sum + shopFinanceNum(row['incassations']),
    ),
    'reconciliation_gap': list.fold<double>(
      0,
      (sum, row) => sum + shopFinanceNum(row['reconciliation_gap']),
    ),
  };

  return <String, dynamic>{
    'rows': list,
    'summary': summary,
  };
}

class _ShopFinanceRow {
  _ShopFinanceRow({
    required this.key,
    required this.shopId,
    required this.shopName,
  });

  final String key;
  final String shopId;
  final String shopName;

  double revenue = 0;
  double cogs = 0;
  double expenses = 0;
  double cashTurnover = 0;
  double endingCash = 0;
  double incassations = 0;
  double recordedIncassations = 0;
  int salesCount = 0;
  int expenseCount = 0;
  int registerCount = 0;
  int incassationCount = 0;

  Map<String, dynamic> toMap() {
    final grossProfit = revenue - cogs;
    final profit = grossProfit - expenses;
    final reconciliationGap = revenue - cashTurnover;
    return <String, dynamic>{
      'key': key,
      'shop_id': shopId,
      'shop_name': shopName.isEmpty ? shopId : shopName,
      'revenue': revenue,
      'cogs': cogs,
      'gross_profit': grossProfit,
      'expenses': expenses,
      'profit': profit,
      'cash_turnover': cashTurnover,
      'ending_cash': endingCash,
      'incassations': incassations,
      'recorded_incassations': recordedIncassations,
      'reconciliation_gap': reconciliationGap,
      'sales_count': salesCount,
      'expense_count': expenseCount,
      'register_count': registerCount,
      'incassation_count': incassationCount,
    };
  }
}

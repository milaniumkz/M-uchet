import '/utils/sale_item_cogs_report_support.dart';

double salesGrossProfitNum(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
}

DateTime? salesGrossProfitDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value.runtimeType.toString() == 'Timestamp') {
    return value.toDate() as DateTime;
  }
  return DateTime.tryParse(value.toString());
}

class SalesGrossProfitSnapshot {
  const SalesGrossProfitSnapshot({
    required this.revenue,
    required this.cogs,
    required this.grossProfit,
    required this.marginPercent,
  });

  final double revenue;
  final double cogs;
  final double grossProfit;
  final double marginPercent;
}

class SalesGrossProfitMonthRow {
  const SalesGrossProfitMonthRow({
    required this.monthKey,
    required this.revenue,
    required this.cogs,
    required this.grossProfit,
    required this.marginPercent,
  });

  final String monthKey;
  final double revenue;
  final double cogs;
  final double grossProfit;
  final double marginPercent;
}

SalesGrossProfitSnapshot computeSalesGrossProfitSnapshot({
  required List<Map<String, dynamic>> sales,
  List<Map<String, dynamic>> cogsItems = const [],
  List<Map<String, dynamic>> cogsEntries = const [],
  List<Map<String, dynamic>> legacyCogsItems = const [],
}) {
  final resolvedCogsItems = cogsItems.isNotEmpty
      ? cogsItems
      : resolveSalesCogsItems(
          cogsEntries: cogsEntries,
          legacyCogsItems: legacyCogsItems,
        );
  final revenue = sales.fold<double>(
    0,
    (sum, item) => sum + salesGrossProfitNum(item['amount']),
  );
  final cogs = resolvedCogsItems.fold<double>(
    0,
    (sum, item) => sum + salesGrossProfitNum(item['total_cost']),
  );
  final grossProfit = revenue - cogs;
  final marginPercent =
      revenue <= 0 ? 0.0 : ((grossProfit / revenue) * 100).toDouble();
  return SalesGrossProfitSnapshot(
    revenue: revenue,
    cogs: cogs,
    grossProfit: grossProfit,
    marginPercent: marginPercent,
  );
}

List<SalesGrossProfitMonthRow> buildSalesGrossProfitMonthRows({
  required List<Map<String, dynamic>> sales,
  List<Map<String, dynamic>> cogsItems = const [],
  List<Map<String, dynamic>> cogsEntries = const [],
  List<Map<String, dynamic>> legacyCogsItems = const [],
}) {
  final resolvedCogsItems = cogsItems.isNotEmpty
      ? cogsItems
      : resolveSalesCogsItems(
          cogsEntries: cogsEntries,
          legacyCogsItems: legacyCogsItems,
        );
  final rows = <String, Map<String, double>>{};

  for (final sale in sales) {
    final dt = salesGrossProfitDate(
      sale['created_at'] ?? sale['date'] ?? sale['updated_at'],
    );
    if (dt == null) continue;
    final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
    final row = rows.putIfAbsent(
      key,
      () => <String, double>{'revenue': 0, 'cogs': 0},
    );
    row['revenue'] =
        (row['revenue'] ?? 0) + salesGrossProfitNum(sale['amount']);
  }

  for (final cogs in resolvedCogsItems) {
    final dt = salesGrossProfitDate(
      cogs['created_at'] ?? cogs['date'] ?? cogs['updated_at'],
    );
    if (dt == null) continue;
    final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
    final row = rows.putIfAbsent(
      key,
      () => <String, double>{'revenue': 0, 'cogs': 0},
    );
    row['cogs'] = (row['cogs'] ?? 0) + salesGrossProfitNum(cogs['total_cost']);
  }

  final result = rows.entries.map((entry) {
    final revenue = entry.value['revenue'] ?? 0;
    final cogs = entry.value['cogs'] ?? 0;
    final grossProfit = revenue - cogs;
    final marginPercent =
        revenue <= 0 ? 0.0 : ((grossProfit / revenue) * 100).toDouble();
    return SalesGrossProfitMonthRow(
      monthKey: entry.key,
      revenue: revenue,
      cogs: cogs,
      grossProfit: grossProfit,
      marginPercent: marginPercent,
    );
  }).toList()
    ..sort((a, b) => b.monthKey.compareTo(a.monthKey));

  return result;
}

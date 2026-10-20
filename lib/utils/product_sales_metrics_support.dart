import 'package:cloud_firestore/cloud_firestore.dart';

import '/utils/cogs_register_support.dart';
import '/utils/inventory_costing_method.dart';

double productSalesNum(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
}

DateTime? productSalesDate(dynamic raw) {
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw);
  return null;
}

double productSalesCost(Map<String, dynamic> data) {
  final explicitCogs = productSalesNum(data['cogs_amount']);
  if (explicitCogs > 0) return explicitCogs;
  final registerCost = productSalesNum(
    data['total_cost'] ?? data['cost_amount'],
  );
  if (registerCost > 0) return registerCost;
  return productSalesNum(data['cost']);
}

String productMetricKey(Map<String, dynamic> data) {
  final id = (data['product_id'] ?? data['id'] ?? '').toString().trim();
  if (id.isNotEmpty) return 'id:$id';
  final name = (data['product_name'] ?? data['name'] ?? '').toString().trim();
  if (name.isNotEmpty) return 'name:${name.toLowerCase()}';
  return '';
}

Map<String, dynamic> enrichProductsWithSalesMetrics({
  required List<Map<String, dynamic>> products,
  required List<Map<String, dynamic>> salesItems,
  List<Map<String, dynamic>> cogsEntries = const [],
  List<Map<String, dynamic>> legacyCogsItems = const [],
}) {
  final metrics = buildProductSalesMetricsRows(
    salesItems: salesItems,
    cogsEntries: cogsEntries,
    legacyCogsItems: legacyCogsItems,
  );
  final metricByKey = <String, Map<String, dynamic>>{
    for (final metric in metrics)
      (metric['metric_key'] ?? '').toString(): metric,
  };

  final enriched = <Map<String, dynamic>>[];
  for (final product in products) {
    final key = productMetricKey(product);
    final metric = metricByKey[key] ?? const <String, dynamic>{};
    final revenue = productSalesNum(metric['revenue']);
    final profit = productSalesNum(metric['profit']);
    final margin = productSalesNum(metric['margin']);
    final lastSaleAt = metric['last_sale_at'];
    enriched.add({
      ...product,
      'salesCount': productSalesNum(metric['salesCount']),
      'revenue': revenue,
      'profit': profit,
      'margin': margin,
      'abc': (metric['abc'] ?? product['abc'] ?? 'C').toString(),
      if (lastSaleAt != null) 'last_sale_at': lastSaleAt,
    });
  }

  return <String, dynamic>{'items': enriched};
}

List<Map<String, dynamic>> buildProductSalesMetricsRows({
  required List<Map<String, dynamic>> salesItems,
  List<Map<String, dynamic>> cogsEntries = const [],
  List<Map<String, dynamic>> legacyCogsItems = const [],
}) {
  final cogsByItemKey = buildCogsBySalesItemKey(
    cogsEntries: cogsEntries,
    legacyCogsItems: legacyCogsItems,
  );
  final metrics = <String, _ProductMetric>{};

  for (final item in salesItems) {
    final key = productMetricKey(item);
    if (key.isEmpty) continue;
    final metric = metrics.putIfAbsent(key, _ProductMetric.new);
    metric.productId =
        (item['product_id'] ?? item['id'] ?? '').toString().trim();
    metric.productName =
        (item['product_name'] ?? item['name'] ?? '').toString().trim();
    metric.qty += productSalesNum(item['qty']);
    metric.revenue += productSalesNum(item['amount']);
    final itemKey = cogsSalesItemJoinKey(item);
    metric.cost += cogsByItemKey[itemKey] ?? productSalesCost(item);
    final dt = productSalesDate(item['created_at']) ??
        productSalesDate(item['date']) ??
        productSalesDate(item['updated_at']);
    if (dt != null &&
        (metric.lastSaleAt == null || dt.isAfter(metric.lastSaleAt!))) {
      metric.lastSaleAt = dt;
    }
  }

  final rows = metrics.entries.map((entry) {
    final metric = entry.value;
    final profit = metric.revenue - metric.cost;
    final margin =
        metric.revenue <= 0 ? 0.0 : (profit / metric.revenue) * 100.0;
    return <String, dynamic>{
      'metric_key': entry.key,
      'product_id': metric.productId,
      'product_name': metric.productName,
      'salesCount': metric.qty,
      'revenue': metric.revenue,
      'cost': metric.cost,
      'profit': profit,
      'margin': margin,
      if (metric.lastSaleAt != null) 'last_sale_at': metric.lastSaleAt,
    };
  }).toList();

  _applyAbcCategories(rows);
  return rows;
}

List<Map<String, dynamic>> buildMonthlyMarginMetrics({
  required List<Map<String, dynamic>> salesItems,
  List<Map<String, dynamic>> cogsEntries = const [],
  List<Map<String, dynamic>> legacyCogsItems = const [],
}) {
  final cogsByItemKey = buildCogsBySalesItemKey(
    cogsEntries: cogsEntries,
    legacyCogsItems: legacyCogsItems,
  );
  final rows = <String, _MonthlyMarginMetric>{};

  for (final item in salesItems) {
    final dt = productSalesDate(item['date']) ??
        productSalesDate(item['created_at']) ??
        productSalesDate(item['updated_at']);
    if (dt == null) continue;
    final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
    final row = rows.putIfAbsent(
      key,
      () => _MonthlyMarginMetric(
          monthKey: key, date: DateTime(dt.year, dt.month)),
    );
    row.revenue += productSalesNum(item['amount']);
    final itemKey = cogsSalesItemJoinKey(item);
    row.cost += cogsByItemKey[itemKey] ?? productSalesCost(item);
  }

  final list = rows.values.map((row) => row.toMap()).toList()
    ..sort((a, b) => (b['monthKey'] ?? '')
        .toString()
        .compareTo((a['monthKey'] ?? '').toString()));
  return list;
}

List<Map<String, dynamic>> buildCostingMethodMarginMetrics({
  required List<Map<String, dynamic>> salesItems,
  required List<Map<String, dynamic>> products,
  List<Map<String, dynamic>> cogsEntries = const [],
  List<Map<String, dynamic>> legacyCogsItems = const [],
}) {
  final cogsByItemKey = buildCogsBySalesItemKey(
    cogsEntries: cogsEntries,
    legacyCogsItems: legacyCogsItems,
  );
  final productByKey = <String, Map<String, dynamic>>{};
  for (final product in products) {
    final key = productMetricKey(product);
    if (key.isNotEmpty) productByKey[key] = product;
  }

  final rows = <String, Map<String, dynamic>>{};
  for (final item in salesItems) {
    final product = productByKey[productMetricKey(item)] ?? const <String, dynamic>{};
    final method = resolveInventoryCostingMethod(
      explicitValue: item['costing_method'] ?? item['inventory_costing_method'],
      productData: product,
    );
    final storageValue = method.storageValue;
    final row = rows.putIfAbsent(
      storageValue,
      () => <String, dynamic>{
        'method': storageValue,
        'method_label': inventoryCostingMethodLabel(method),
        'revenue': 0.0,
        'cost': 0.0,
        'profit': 0.0,
        'sales_count': 0.0,
      },
    );
    final revenue = productSalesNum(item['amount']);
    final itemKey = cogsSalesItemJoinKey(item);
    final cost = cogsByItemKey[itemKey] ?? productSalesCost(item);
    row['revenue'] = (row['revenue'] as double) + revenue;
    row['cost'] = (row['cost'] as double) + cost;
    row['profit'] = (row['profit'] as double) + (revenue - cost);
    row['sales_count'] =
        (row['sales_count'] as double) + productSalesNum(item['qty']);
  }

  final list = rows.values.toList()
    ..sort((a, b) => productSalesNum(b['profit'])
        .compareTo(productSalesNum(a['profit'])));
  for (final row in list) {
    final revenue = productSalesNum(row['revenue']);
    final profit = productSalesNum(row['profit']);
    row['margin'] = revenue <= 0 ? 0.0 : (profit / revenue) * 100.0;
  }
  return list;
}


void _applyAbcCategories(List<Map<String, dynamic>> items) {
  final sorted = List<Map<String, dynamic>>.from(items)
    ..sort((a, b) =>
        productSalesNum(b['revenue']).compareTo(productSalesNum(a['revenue'])));
  final totalRevenue = sorted.fold<double>(
    0.0,
    (total, item) => total + productSalesNum(item['revenue']),
  );
  double cumulative = 0.0;
  for (final item in sorted) {
    final revenue = productSalesNum(item['revenue']);
    cumulative += revenue;
    final share = totalRevenue <= 0 ? 0.0 : (cumulative / totalRevenue) * 100.0;
    if (share <= 80) {
      item['abc'] = 'A';
    } else if (share <= 95) {
      item['abc'] = 'B';
    } else {
      item['abc'] = 'C';
    }
  }
}

class _ProductMetric {
  _ProductMetric();

  String productId = '';
  String productName = '';
  double qty = 0;
  double revenue = 0;
  double cost = 0;
  DateTime? lastSaleAt;
}

class _MonthlyMarginMetric {
  _MonthlyMarginMetric({
    required this.monthKey,
    required this.date,
  });

  final String monthKey;
  final DateTime date;
  double revenue = 0;
  double cost = 0;

  Map<String, dynamic> toMap() {
    final profit = revenue - cost;
    final margin = revenue <= 0 ? 0.0 : (profit / revenue) * 100.0;
    return <String, dynamic>{
      'monthKey': monthKey,
      'date': date,
      'revenue': revenue,
      'cost': cost,
      'profit': profit,
      'margin': margin,
    };
  }
}

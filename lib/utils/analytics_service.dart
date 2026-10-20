import 'package:cloud_firestore/cloud_firestore.dart';

import '/utils/business_event_support.dart';
import '/utils/ledger_scope.dart';

class AnalyticsSnapshot {
  const AnalyticsSnapshot({
    required this.revenue,
    required this.cost,
    required this.margin,
    required this.eventCount,
  });

  final double revenue;
  final double cost;
  final double margin;
  final int eventCount;
}

class AnalyticsMonthRow {
  const AnalyticsMonthRow({
    required this.monthKey,
    required this.revenue,
    required this.cost,
    required this.margin,
    required this.eventCount,
  });

  final String monthKey;
  final double revenue;
  final double cost;
  final double margin;
  final int eventCount;
}

AnalyticsSnapshot computeEventAnalyticsSnapshot({
  required Iterable<Map<String, dynamic>> events,
  LedgerScope ledgerScope = LedgerScope.both,
  String? warehouseId,
  bool Function(DateTime? date)? inPeriod,
}) {
  var revenue = 0.0;
  var cost = 0.0;
  var eventCount = 0;
  for (final event in events) {
    final eventScope = ledgerScopeFromLegacyValue(
      (event['ledger_scope'] ?? event['ledgerScope'])?.toString(),
    );
    if (!ledgerScope.matches(eventScope)) continue;
    if (warehouseId != null &&
        warehouseId.isNotEmpty &&
        (event['warehouse_id'] ?? '').toString() != warehouseId) {
      continue;
    }
    final occurredAt = _date(event['occurred_at']);
    if (inPeriod != null && !inPeriod(occurredAt)) {
      continue;
    }
    final type = businessEventTypeFromValue(
      (event['event_type'] ?? event['eventType'])?.toString(),
    );
    switch (type) {
      case BusinessEventType.saleCreated:
      case BusinessEventType.servicePerformed:
        revenue += _num(event['revenue']);
        cost += _num(event['cost']);
        eventCount += 1;
        break;
      case BusinessEventType.paymentReceived:
        eventCount += 1;
        break;
      case BusinessEventType.inventoryMoved:
      case BusinessEventType.expenseRecorded:
        cost += _num(event['cost']);
        eventCount += 1;
        break;
    }
  }
  return AnalyticsSnapshot(
    revenue: revenue,
    cost: cost,
    margin: revenue - cost,
    eventCount: eventCount,
  );
}

List<AnalyticsMonthRow> buildEventAnalyticsMonthRows({
  required Iterable<Map<String, dynamic>> events,
  LedgerScope ledgerScope = LedgerScope.both,
  String? warehouseId,
}) {
  final rows = <String, Map<String, dynamic>>{};
  for (final event in events) {
    final eventScope = ledgerScopeFromLegacyValue(
      (event['ledger_scope'] ?? event['ledgerScope'])?.toString(),
    );
    if (!ledgerScope.matches(eventScope)) continue;
    if (warehouseId != null &&
        warehouseId.isNotEmpty &&
        (event['warehouse_id'] ?? '').toString() != warehouseId) {
      continue;
    }
    final date = _date(event['occurred_at']);
    if (date == null) continue;
    final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
    final row = rows.putIfAbsent(
      monthKey,
      () => <String, dynamic>{
        'revenue': 0.0,
        'cost': 0.0,
        'eventCount': 0,
      },
    );
    final type = businessEventTypeFromValue(
      (event['event_type'] ?? event['eventType'])?.toString(),
    );
    switch (type) {
      case BusinessEventType.saleCreated:
      case BusinessEventType.servicePerformed:
        row['revenue'] = (row['revenue'] as double) + _num(event['revenue']);
        row['cost'] = (row['cost'] as double) + _num(event['cost']);
        row['eventCount'] = (row['eventCount'] as int) + 1;
        break;
      case BusinessEventType.paymentReceived:
        row['eventCount'] = (row['eventCount'] as int) + 1;
        break;
      case BusinessEventType.inventoryMoved:
      case BusinessEventType.expenseRecorded:
        row['cost'] = (row['cost'] as double) + _num(event['cost']);
        row['eventCount'] = (row['eventCount'] as int) + 1;
        break;
    }
  }
  final result = rows.entries.map((entry) {
    final revenue = entry.value['revenue'] as double? ?? 0.0;
    final cost = entry.value['cost'] as double? ?? 0.0;
    return AnalyticsMonthRow(
      monthKey: entry.key,
      revenue: revenue,
      cost: cost,
      margin: revenue - cost,
      eventCount: entry.value['eventCount'] as int? ?? 0,
    );
  }).toList(growable: false)
    ..sort((a, b) => a.monthKey.compareTo(b.monthKey));
  return result;
}

double _num(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
}

DateTime? _date(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

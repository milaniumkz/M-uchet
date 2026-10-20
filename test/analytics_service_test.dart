import 'package:flutter_test/flutter_test.dart';

import 'package:uchet_s_d/utils/analytics_service.dart';
import 'package:uchet_s_d/utils/business_event_support.dart';
import 'package:uchet_s_d/utils/ledger_scope.dart';

void main() {
  test('event analytics aggregates revenue cost and margin', () {
    final events = <Map<String, dynamic>>[
      buildBusinessEventPayload(
        companyId: 'c1',
        type: BusinessEventType.saleCreated,
        ledgerScope: LedgerScope.accounting,
        revenue: 1000,
        cost: 600,
        warehouseId: 'w1',
        occurredAt: DateTime(2025, 1, 10),
      ),
      buildBusinessEventPayload(
        companyId: 'c1',
        type: BusinessEventType.paymentReceived,
        ledgerScope: LedgerScope.accounting,
        revenue: 0,
        cost: 0,
        warehouseId: 'w1',
        occurredAt: DateTime(2025, 1, 11),
      ),
      buildBusinessEventPayload(
        companyId: 'c1',
        type: BusinessEventType.inventoryMoved,
        ledgerScope: LedgerScope.management,
        revenue: 0,
        cost: 50,
        warehouseId: 'w2',
        occurredAt: DateTime(2025, 2, 1),
      ),
    ];

    final snapshot = computeEventAnalyticsSnapshot(
      events: events,
      ledgerScope: LedgerScope.accounting,
    );

    expect(snapshot.revenue, 1000);
    expect(snapshot.cost, 600);
    expect(snapshot.margin, 400);
  });

  test('event month rows respect warehouse and ledger filters', () {
    final events = <Map<String, dynamic>>[
      buildBusinessEventPayload(
        companyId: 'c1',
        type: BusinessEventType.saleCreated,
        ledgerScope: LedgerScope.accounting,
        revenue: 100,
        cost: 50,
        warehouseId: 'w1',
        occurredAt: DateTime(2025, 1, 1),
      ),
      buildBusinessEventPayload(
        companyId: 'c1',
        type: BusinessEventType.saleCreated,
        ledgerScope: LedgerScope.accounting,
        revenue: 200,
        cost: 120,
        warehouseId: 'w2',
        occurredAt: DateTime(2025, 1, 5),
      ),
    ];

    final rows = buildEventAnalyticsMonthRows(
      events: events,
      ledgerScope: LedgerScope.accounting,
      warehouseId: 'w1',
    );

    expect(rows, hasLength(1));
    expect(rows.first.revenue, 100);
    expect(rows.first.margin, 50);
  });

  test('expense event increases cost without revenue', () {
    final snapshot = computeEventAnalyticsSnapshot(
      events: [
        buildBusinessEventPayload(
          companyId: 'c1',
          type: BusinessEventType.expenseRecorded,
          ledgerScope: LedgerScope.accounting,
          cost: 75,
          occurredAt: DateTime(2025, 2, 2),
        ),
      ],
      ledgerScope: LedgerScope.accounting,
    );

    expect(snapshot.revenue, 0);
    expect(snapshot.cost, 75);
    expect(snapshot.margin, -75);
  });

  test('payment received does not double count revenue', () {
    final snapshot = computeEventAnalyticsSnapshot(
      events: [
        buildBusinessEventPayload(
          companyId: 'c1',
          type: BusinessEventType.saleCreated,
          ledgerScope: LedgerScope.accounting,
          revenue: 200,
          cost: 80,
          occurredAt: DateTime(2025, 2, 1),
        ),
        buildBusinessEventPayload(
          companyId: 'c1',
          type: BusinessEventType.paymentReceived,
          ledgerScope: LedgerScope.accounting,
          revenue: 200,
          cost: 0,
          occurredAt: DateTime(2025, 2, 2),
        ),
      ],
      ledgerScope: LedgerScope.accounting,
    );

    expect(snapshot.revenue, 200);
    expect(snapshot.cost, 80);
    expect(snapshot.margin, 120);
    expect(snapshot.eventCount, 2);
  });

  test('sales analytics can ignore non-sales business events', () {
    final snapshot = computeEventAnalyticsSnapshot(
      events: [
        buildBusinessEventPayload(
          companyId: 'c1',
          type: BusinessEventType.saleCreated,
          ledgerScope: LedgerScope.accounting,
          revenue: 300,
          cost: 120,
          occurredAt: DateTime(2025, 2, 1),
        ),
        buildBusinessEventPayload(
          companyId: 'c1',
          type: BusinessEventType.inventoryMoved,
          ledgerScope: LedgerScope.accounting,
          cost: 999,
          occurredAt: DateTime(2025, 2, 2),
        ),
      ].where((event) {
        final type = businessEventTypeFromValue(
          (event['event_type'] ?? '').toString(),
        );
        return type == BusinessEventType.saleCreated ||
            type == BusinessEventType.servicePerformed;
      }).toList(),
      ledgerScope: LedgerScope.accounting,
    );

    expect(snapshot.revenue, 300);
    expect(snapshot.cost, 120);
    expect(snapshot.margin, 180);
  });
}

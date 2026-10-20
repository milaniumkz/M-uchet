import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/ledger_scope.dart';
import 'package:uchet_s_d/utils/service_accounting_support.dart';

void main() {
  test('calculates fixed service cost', () {
    const model = ServiceCostModelView(
      serviceId: 's1',
      costingType: ServiceCostingType.fixed,
      fixedCost: 100,
      variableCost: 0,
      defaultUnitCost: 80,
      currency: 'KZT',
      ledgerScope: LedgerScope.accounting,
      notes: '',
    );
    final result = calculateServiceExecution(
      costModel: model,
      quantity: 2,
      unitPrice: 250,
    );
    expect(result.costAmount, 200);
    expect(result.marginAmount, 300);
  });

  test('calculates manual and mixed service cost', () {
    const manualModel = ServiceCostModelView(
      serviceId: 's1',
      costingType: ServiceCostingType.manual,
      fixedCost: 0,
      variableCost: 0,
      defaultUnitCost: 70,
      currency: 'KZT',
      ledgerScope: LedgerScope.accounting,
      notes: '',
    );
    final manual = calculateServiceExecution(
      costModel: manualModel,
      quantity: 3,
      unitPrice: 200,
      manualUnitCost: 90,
    );
    expect(manual.costAmount, 270);

    const mixedModel = ServiceCostModelView(
      serviceId: 's2',
      costingType: ServiceCostingType.mixed,
      fixedCost: 20,
      variableCost: 30,
      defaultUnitCost: 0,
      currency: 'KZT',
      ledgerScope: LedgerScope.management,
      notes: '',
    );
    final mixed = calculateServiceExecution(
      costModel: mixedModel,
      quantity: 2,
      unitPrice: 150,
    );
    expect(mixed.costAmount, 100);
    expect(mixed.unitCost, 50);
  });

  test('aggregates service report rows', () {
    final rows = buildServiceReportRows(
      executionDocs: [
        {
          'service_id': 's1',
          'service_name': 'Audit',
          'service_category': 'Finance',
          'quantity': 2,
          'revenue_amount': 500,
          'cost_amount': 200,
          'margin_amount': 300,
          'ledger_scope': 'ACCOUNTING',
        },
        {
          'service_id': 's1',
          'service_name': 'Audit',
          'service_category': 'Finance',
          'quantity': 1,
          'revenue_amount': 250,
          'cost_amount': 120,
          'margin_amount': 130,
          'ledger_scope': 'ACCOUNTING',
        },
      ],
      breakdown: 'service',
    );
    expect(rows, hasLength(1));
    expect(rows.first.revenue, 750);
    expect(rows.first.cost, 320);
    expect(rows.first.margin, 430);
  });

  test('aggregates service report rows from business events', () {
    final rows = buildServiceReportRowsFromEvents(
      eventDocs: [
        {
          'event_type': 'SERVICE_PERFORMED',
          'service_id': 's1',
          'service_name': 'Audit',
          'service_category': 'Finance',
          'quantity': 2,
          'revenue': 500,
          'cost': 200,
          'ledger_scope': 'ACCOUNTING',
          'occurred_at': DateTime(2025, 8, 10),
        },
        {
          'event_type': 'SERVICE_PERFORMED',
          'service_id': 's1',
          'service_name': 'Audit',
          'service_category': 'Finance',
          'quantity': 1,
          'revenue': 250,
          'cost': 120,
          'ledger_scope': 'ACCOUNTING',
          'occurred_at': DateTime(2025, 8, 11),
        },
      ],
      breakdown: 'service',
    );

    expect(rows, hasLength(1));
    expect(rows.first.revenue, 750);
    expect(rows.first.cost, 320);
    expect(rows.first.margin, 430);
  });
}

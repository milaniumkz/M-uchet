import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/sales_profit_breakdown_support.dart';

void main() {
  test('buildSaleCogsBySaleId sums cogs per sale', () {
    final result = buildSaleCogsBySaleId(
      salesItems: const [
        {'sale_id': 's1', 'cogs_amount': 100},
        {'sale_id': 's1', 'cogs_amount': 50},
        {'sale_id': 's2', 'cogs_amount': 80},
      ],
    );

    expect(result['s1'], 150);
    expect(result['s2'], 80);
  });

  test('buildCashierProfitRows computes gross profit per cashier', () {
    final rows = buildCashierProfitRows(
      salesLedger: const [
        {
          'sale_id': 's1',
          'cashier_id': 'c1',
          'cashier_name': 'Кассир 1',
          'amount': 500,
        },
        {
          'sale_id': 's2',
          'cashier_id': 'c1',
          'cashier_name': 'Кассир 1',
          'amount': 300,
        },
      ],
      salesItems: const [
        {'sale_id': 's1', 'cogs_amount': 200},
        {'sale_id': 's2', 'cogs_amount': 90},
      ],
    );

    expect(rows.single['cashier_name'], 'Кассир 1');
    expect(rows.single['revenue'], 800);
    expect(rows.single['cogs'], 290);
    expect(rows.single['gross_profit'], 510);
  });

  test('buildCashRegisterProfitRows computes gross profit per register', () {
    final rows = buildCashRegisterProfitRows(
      salesLedger: const [
        {
          'sale_id': 's1',
          'cash_register_id': 'r1',
          'cash_register_name': 'Касса 1',
          'amount': 500,
        },
        {
          'sale_id': 's2',
          'cash_register_id': 'r1',
          'cash_register_name': 'Касса 1',
          'amount': 250,
        },
      ],
      salesItems: const [
        {'sale_id': 's1', 'cogs_amount': 200},
        {'sale_id': 's2', 'cogs_amount': 100},
      ],
    );

    expect(rows.single['register_name'], 'Касса 1');
    expect(rows.single['transactions'], 2);
    expect(rows.single['revenue'], 750);
    expect(rows.single['cogs'], 300);
    expect(rows.single['gross_profit'], 450);
  });

  test('buildSaleCogsBySaleId prefers cogs register rows over legacy sales_items', () {
    final result = buildSaleCogsBySaleId(
      cogsEntries: const [
        {'sale_id': 's1', 'total_cost': 120},
      ],
      legacyCogsItems: const [
        {'sale_id': 's1', 'cogs_amount': 400},
      ],
    );

    expect(result['s1'], 120);
  });
}

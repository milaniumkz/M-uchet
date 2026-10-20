import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/shop_finance_ledger_support.dart';

void main() {
  group('buildShopFinanceLedger', () {
    test('combines revenue, expenses, registers and incassations by shop', () {
      final result = buildShopFinanceLedger(
        shops: [
          {'id': 's1', 'name': 'Магазин 1'},
        ],
        salesLedger: [
          {
            'sale_id': 'sale-1',
            'shop_id': 's1',
            'shop_name': 'Магазин 1',
            'amount': 1000,
          },
        ],
        salesItems: [
          {'sale_id': 'sale-1', 'cogs_amount': 300},
        ],
        shopExpenses: [
          {'shop_id': 's1', 'shop_name': 'Магазин 1', 'amount': 250},
        ],
        cashRegisters: [
          {
            'id': 'shift1',
            'shop_id': 's1',
            'shop_name': 'Магазин 1',
            'cash_sales': 600,
            'card_sales': 350,
            'ending_cash': 200,
            'incassation_total': 300,
          },
        ],
        cashRegisterIncassations: [
          {
            'cash_register_shift_id': 'shift1',
            'amount': 300,
          },
        ],
      );

      final rows = List<Map<String, dynamic>>.from(result['rows'] as List);
      final row = rows.single;

      expect(row['shop_id'], 's1');
      expect(row['revenue'], 1000);
      expect(row['cogs'], 300);
      expect(row['gross_profit'], 700);
      expect(row['expenses'], 250);
      expect(row['profit'], 450);
      expect(row['cash_turnover'], 950);
      expect(row['incassations'], 300);
      expect(row['reconciliation_gap'], 50);
    });
  });

  test('prefers cogs register rows when provided', () {
    final result = buildShopFinanceLedger(
      shops: [
        {'id': 's1', 'name': 'Магазин 1'},
      ],
      salesLedger: [
        {
          'sale_id': 'sale-1',
          'shop_id': 's1',
          'shop_name': 'Магазин 1',
          'amount': 1000,
        },
      ],
      cogsEntries: [
        {'sale_id': 'sale-1', 'total_cost': 250},
      ],
      legacyCogsItems: [
        {'sale_id': 'sale-1', 'cogs_amount': 600},
      ],
      shopExpenses: const [],
      cashRegisters: const [],
      cashRegisterIncassations: const [],
    );

    final summary = Map<String, dynamic>.from(result['summary'] as Map);
    expect(summary['cogs'], 250);
    expect(summary['gross_profit'], 750);
  });
}

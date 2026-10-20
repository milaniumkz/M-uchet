import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/sales_gross_profit_support.dart';

void main() {
  test('computes revenue cogs and gross profit snapshot', () {
    final snapshot = computeSalesGrossProfitSnapshot(
      sales: const [
        {'amount': 1000},
        {'amount': 500},
      ],
      cogsItems: const [
        {'total_cost': 400},
        {'total_cost': 200},
      ],
    );

    expect(snapshot.revenue, 1500);
    expect(snapshot.cogs, 600);
    expect(snapshot.grossProfit, 900);
    expect(snapshot.marginPercent, closeTo(60, 0.001));
  });

  test('builds monthly rows from sales and cogs dates', () {
    final rows = buildSalesGrossProfitMonthRows(
      sales: [
        {'amount': 1000, 'created_at': DateTime(2025, 1, 10)},
        {'amount': 500, 'created_at': DateTime(2025, 1, 20)},
        {'amount': 700, 'created_at': DateTime(2025, 2, 5)},
      ],
      cogsItems: [
        {'total_cost': 600, 'created_at': DateTime(2025, 1, 20)},
        {'total_cost': 280, 'created_at': DateTime(2025, 2, 5)},
      ],
    );

    expect(rows, hasLength(2));
    expect(rows.first.monthKey, '2025-02');
    expect(rows.first.revenue, 700);
    expect(rows.first.cogs, 280);
    expect(rows.first.grossProfit, 420);
    expect(rows.last.monthKey, '2025-01');
    expect(rows.last.revenue, 1500);
    expect(rows.last.cogs, 600);
    expect(rows.last.marginPercent, closeTo(60, 0.001));
  });

  test('prefers cogs register rows over legacy cogs rows', () {
    final snapshot = computeSalesGrossProfitSnapshot(
      sales: const [
        {'amount': 1000},
      ],
      cogsEntries: const [
        {'total_cost': 300},
      ],
      legacyCogsItems: const [
        {'cogs_amount': 500},
      ],
    );

    expect(snapshot.cogs, 300);
    expect(snapshot.grossProfit, 700);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/sales_client_profit_support.dart';

void main() {
  test('buildSalesClientProfitRows computes revenue cogs and gross profit', () {
    final rows = buildSalesClientProfitRows(
      salesLedger: [
        {
          'sale_id': 'sale-1',
          'client_id': 'client-1',
          'client_name': 'Клиент 1',
          'amount': 1000,
          'created_at': DateTime(2025, 1, 10),
        },
        {
          'sale_id': 'sale-2',
          'client_id': 'client-1',
          'client_name': 'Клиент 1',
          'amount': 500,
          'created_at': DateTime(2025, 1, 12),
        },
      ],
      salesItems: const [
        {'sale_id': 'sale-1', 'cogs_amount': 400},
        {'sale_id': 'sale-2', 'cogs_amount': 150},
      ],
    );

    expect(rows, hasLength(1));
    expect(rows.single.clientName, 'Клиент 1');
    expect(rows.single.orders, 2);
    expect(rows.single.revenue, 1500);
    expect(rows.single.cogs, 550);
    expect(rows.single.grossProfit, 950);
    expect(rows.single.lastPurchaseAt, DateTime(2025, 1, 12));
  });
}

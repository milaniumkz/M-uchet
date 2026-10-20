import 'package:flutter_test/flutter_test.dart';

import 'package:uchet_s_d/utils/cogs_register_support.dart';

void main() {
  test('buildCogsBySalesItemKey prefers cogs register rows over legacy rows', () {
    final result = buildCogsBySalesItemKey(
      cogsEntries: const [
        {
          'sale_item_id': 'si-1',
          'sale_id': 'sale-1',
          'product_id': 'p1',
          'total_cost': 220,
        },
      ],
      legacyCogsItems: const [
        {
          'sale_item_id': 'si-1',
          'sale_id': 'sale-1',
          'product_id': 'p1',
          'cogs_amount': 500,
        },
      ],
    );

    expect(result['sale_item:si-1'], 220);
  });

  test('buildCogsBySalesItemKey falls back to sale and product key', () {
    final result = buildCogsBySalesItemKey(
      cogsEntries: const [
        {
          'sale_id': 'sale-1',
          'product_id': 'p1',
          'total_cost': 180,
        },
      ],
      legacyCogsItems: const [],
    );

    expect(result['sale_product:sale-1:p1'], 180);
  });
}

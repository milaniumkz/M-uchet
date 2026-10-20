import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/sale_item_cogs_report_support.dart';

void main() {
  test('resolveSalesCogsItems prefers cogs register rows over legacy rows', () {
    final items = resolveSalesCogsItems(
      cogsEntries: [
        {
          'sale_id': 's1',
          'sale_item_id': 'si1',
          'total_cost': 320.0,
        },
      ],
      legacyCogsItems: [
        {
          'sale_id': 's1',
          'sale_item_id': 'si1',
          'total_cost': 999.0,
        },
      ],
    );

    expect(items, hasLength(1));
    expect(items.single['total_cost'], 320.0);
  });

  test('resolveSalesCogsItems falls back to legacy rows when register is empty', () {
    final items = resolveSalesCogsItems(
      cogsEntries: const [],
      legacyCogsItems: [
        {
          'sale_id': 's1',
          'sale_item_id': 'si1',
          'total_cost': 150.0,
        },
      ],
    );

    expect(items, hasLength(1));
    expect(items.single['total_cost'], 150.0);
  });

  test('buildSaleItemCogsReportRows groups FIFO consumptions by sale item', () {
    final rows = buildSaleItemCogsReportRows(
      cogsItems: [
        {
          'sale_id': 's1',
          'sale_item_id': 'si1',
          'product_id': 'p1',
          'product_name': 'Item',
          'warehouse_name': 'Main',
          'costing_method': 'FIFO',
          'qty': 2,
          'unit_cost': 100,
          'unit_cost_applied': 120,
          'total_cost': 200,
          'batch_id': 'b1',
        },
        {
          'sale_id': 's1',
          'sale_item_id': 'si1',
          'product_id': 'p1',
          'product_name': 'Item',
          'warehouse_name': 'Main',
          'costing_method': 'FIFO',
          'qty': 1,
          'unit_cost': 150,
          'unit_cost_applied': 120,
          'total_cost': 150,
          'batch_id': 'b2',
        },
      ],
    );

    expect(rows, hasLength(1));
    expect(rows.single.quantity, 3);
    expect(rows.single.totalCost, 350);
    expect(rows.single.batchBreakdown, hasLength(2));
  });

  test('buildSaleItemCogsReportRows keeps weighted average as AVG basis', () {
    final rows = buildSaleItemCogsReportRows(
      cogsItems: [
        {
          'sale_id': 's2',
          'sale_item_id': 'si2',
          'product_id': 'p2',
          'product_name': 'Item 2',
          'warehouse_name': 'Main',
          'costing_method': 'WEIGHTED_AVERAGE',
          'qty': 2,
          'unit_cost': 160,
          'unit_cost_applied': 160,
          'total_cost': 320,
          'batch_id': '',
        },
      ],
    );

    expect(rows.single.costingMethod, 'WEIGHTED_AVERAGE');
    expect(rows.single.batchBreakdown.single, contains('AVG'));
  });

  test('buildSaleItemCogsReportRowsForSaleIds filters by sale ids', () {
    final rows = buildSaleItemCogsReportRowsForSaleIds(
      cogsItems: [
        {
          'sale_id': 's1',
          'sale_item_id': 'si1',
          'product_id': 'p1',
          'product_name': 'Item 1',
          'warehouse_name': 'Main',
          'costing_method': 'FIFO',
          'qty': 1,
          'unit_cost': 10,
          'unit_cost_applied': 10,
          'total_cost': 10,
          'batch_id': 'b1',
        },
        {
          'sale_id': 's2',
          'sale_item_id': 'si2',
          'product_id': 'p2',
          'product_name': 'Item 2',
          'warehouse_name': 'Main',
          'costing_method': 'FIFO',
          'qty': 2,
          'unit_cost': 20,
          'unit_cost_applied': 20,
          'total_cost': 40,
          'batch_id': 'b2',
        },
      ],
      saleIds: {'s2'},
    );

    expect(rows, hasLength(1));
    expect(rows.single.saleId, 's2');
    expect(rows.single.totalCost, 40);
  });
}

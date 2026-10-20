import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/product_sales_metrics_support.dart';

void main() {
  group('enrichProductsWithSalesMetrics', () {
    test('overlays live sales item aggregates onto products', () {
      final result = enrichProductsWithSalesMetrics(
        products: [
          {
            'id': 'p1',
            'name': 'Товар 1',
            'stock': 10,
            'revenue': 1,
            'profit': 1,
          },
          {
            'id': 'p2',
            'name': 'Товар 2',
            'stock': 5,
          },
        ],
        salesItems: [
          {
            'product_id': 'p1',
            'product_name': 'Товар 1',
            'qty': 3,
            'amount': 900,
            'cost': 600,
            'created_at': Timestamp.fromDate(DateTime(2025, 3, 1)),
          },
          {
            'product_id': 'p2',
            'product_name': 'Товар 2',
            'qty': 1,
            'amount': 200,
            'cost': 50,
            'created_at': Timestamp.fromDate(DateTime(2025, 3, 2)),
          },
        ],
      );

      final items = List<Map<String, dynamic>>.from(result['items'] as List);
      final p1 = items.firstWhere((item) => item['id'] == 'p1');
      final p2 = items.firstWhere((item) => item['id'] == 'p2');

      expect(p1['salesCount'], 3);
      expect(p1['revenue'], 900);
      expect(p1['profit'], 300);
      expect(p1['margin'], closeTo(33.333, 0.01));
      expect(p1['last_sale_at'], DateTime(2025, 3, 1));

      expect(p2['salesCount'], 1);
      expect(p2['revenue'], 200);
      expect(p2['profit'], 150);
      expect(p2['abc'], anyOf('A', 'B', 'C'));
    });

    test('matches by product name when product id is missing', () {
      final result = enrichProductsWithSalesMetrics(
        products: [
          {'name': 'Услуга 1'},
        ],
        salesItems: [
          {
            'product_name': 'Услуга 1',
            'qty': 2,
            'amount': 500,
            'cost': 100,
          },
        ],
      );

      final item = (result['items'] as List).cast<Map<String, dynamic>>().first;
      expect(item['salesCount'], 2);
      expect(item['revenue'], 500);
      expect(item['profit'], 400);
    });
  });

  group('buildProductSalesMetricsRows', () {
    test('aggregates rows and assigns abc categories', () {
      final rows = buildProductSalesMetricsRows(
        salesItems: [
          {
            'product_id': 'p1',
            'product_name': 'A',
            'qty': 2,
            'amount': 1000,
            'cost': 700,
          },
          {
            'product_id': 'p2',
            'product_name': 'B',
            'qty': 1,
            'amount': 200,
            'cost': 50,
          },
        ],
      );

      final p1 = rows.firstWhere((row) => row['product_id'] == 'p1');
      expect(p1['salesCount'], 2);
      expect(p1['profit'], 300);
      expect(p1['margin'], closeTo(30, 0.01));
      expect(['A', 'B', 'C'], contains(p1['abc']));
    });

    test('prefers cogs_amount over legacy cost field', () {
      final rows = buildProductSalesMetricsRows(
        salesItems: [
          {
            'product_id': 'p1',
            'product_name': 'A',
            'qty': 2,
            'amount': 1000,
            'cost': 700,
            'cogs_amount': 550,
          },
        ],
      );

      final p1 = rows.firstWhere((row) => row['product_id'] == 'p1');
      expect(p1['cost'], 550);
      expect(p1['profit'], 450);
    });

    test('prefers cogs register rows when provided', () {
      final rows = buildProductSalesMetricsRows(
        salesItems: [
          {
            'id': 'si-1',
            'sale_id': 'sale-1',
            'product_id': 'p1',
            'product_name': 'A',
            'qty': 2,
            'amount': 1000,
            'cogs_amount': 700,
          },
        ],
        cogsEntries: const [
          {
            'sale_item_id': 'si-1',
            'sale_id': 'sale-1',
            'product_id': 'p1',
            'total_cost': 480,
          },
        ],
      );

      final p1 = rows.firstWhere((row) => row['product_id'] == 'p1');
      expect(p1['cost'], 480);
      expect(p1['profit'], 520);
    });
  });

  group('buildMonthlyMarginMetrics', () {
    test('groups sales items by month', () {
      final rows = buildMonthlyMarginMetrics(
        salesItems: [
          {
            'amount': 500,
            'cost': 300,
            'created_at': Timestamp.fromDate(DateTime(2025, 3, 5)),
          },
          {
            'amount': 100,
            'cost': 20,
            'created_at': Timestamp.fromDate(DateTime(2025, 3, 20)),
          },
        ],
      );

      expect(rows, hasLength(1));
      expect(rows.first['monthKey'], '2025-03');
      expect(rows.first['revenue'], 600);
      expect(rows.first['cost'], 320);
      expect(rows.first['profit'], 280);
    });

    test('uses cogs_amount in monthly margin rows', () {
      final rows = buildMonthlyMarginMetrics(
        salesItems: [
          {
            'amount': 500,
            'cost': 300,
            'cogs_amount': 250,
            'created_at': Timestamp.fromDate(DateTime(2025, 3, 5)),
          },
        ],
      );

      expect(rows.first['cost'], 250);
      expect(rows.first['profit'], 250);
    });

    test('uses cogs register rows in monthly margin rows when provided', () {
      final rows = buildMonthlyMarginMetrics(
        salesItems: [
          {
            'id': 'si-1',
            'sale_id': 'sale-1',
            'product_id': 'p1',
            'amount': 500,
            'cost': 300,
            'created_at': Timestamp.fromDate(DateTime(2025, 3, 5)),
          },
        ],
        cogsEntries: const [
          {
            'sale_item_id': 'si-1',
            'sale_id': 'sale-1',
            'product_id': 'p1',
            'total_cost': 220,
          },
        ],
      );

      expect(rows.first['cost'], 220);
      expect(rows.first['profit'], 280);
    });
  });

  group('buildCostingMethodMarginMetrics', () {
    test('groups sales by fifo and weighted average methods', () {
      final rows = buildCostingMethodMarginMetrics(
        products: const [
          {
            'id': 'p1',
            'inventory_costing_method': 'FIFO',
          },
          {
            'id': 'p2',
            'inventory_costing_method': 'WEIGHTED_AVERAGE',
          },
        ],
        salesItems: const [
          {
            'product_id': 'p1',
            'amount': 500,
            'cogs_amount': 300,
            'qty': 2,
          },
          {
            'product_id': 'p2',
            'amount': 400,
            'cogs_amount': 250,
            'qty': 1,
          },
        ],
      );

      final fifo = rows.firstWhere((row) => row['method'] == 'FIFO');
      final avg = rows.firstWhere(
        (row) => row['method'] == 'WEIGHTED_AVERAGE',
      );

      expect(fifo['revenue'], 500);
      expect(fifo['cost'], 300);
      expect(fifo['profit'], 200);
      expect(fifo['method_label'], 'FIFO');

      expect(avg['revenue'], 400);
      expect(avg['cost'], 250);
      expect(avg['profit'], 150);
      expect(avg['method_label'], 'Средневзвешенная');
    });

    test('uses cogs register rows in costing method margin metrics', () {
      final rows = buildCostingMethodMarginMetrics(
        products: const [
          {
            'id': 'p1',
            'inventory_costing_method': 'FIFO',
          },
        ],
        salesItems: const [
          {
            'id': 'si-1',
            'sale_id': 'sale-1',
            'product_id': 'p1',
            'amount': 500,
            'cogs_amount': 300,
            'qty': 2,
          },
        ],
        cogsEntries: const [
          {
            'sale_item_id': 'si-1',
            'sale_id': 'sale-1',
            'product_id': 'p1',
            'total_cost': 210,
          },
        ],
      );

      final fifo = rows.firstWhere((row) => row['method'] == 'FIFO');
      expect(fifo['cost'], 210);
      expect(fifo['profit'], 290);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/cogs_backfill_support.dart';

void main() {
  group('cogs backfill support', () {
    test('builds cogs entry payload from legacy sale item cogs', () {
      final payload = buildBackfillCogsEntryPayloadFromLegacy(
        legacyDocId: 'legacy-1',
        legacyData: <String, dynamic>{
          'idCompany': 'company-1',
          'sale_id': 'sale-1',
          'sale_item_id': 'item-1',
          'product_id': 'product-1',
          'product_name': 'Product',
          'warehouse_id': 'warehouse-1',
          'warehouse_name': 'Warehouse',
          'ledger_scope': 'MANAGEMENT',
          'costing_method': 'FIFO',
          'qty': 2,
          'unit_cost_applied': 7,
          'total_cost': 14,
          'batch_id': 'batch-1',
        },
      );

      expect(payload, isNotNull);
      expect(payload!['legacy_source_id'], 'legacy-1');
      expect(payload['sale_item_id'], 'item-1');
      expect(payload['ledger_scope'], 'MANAGEMENT');
      expect(payload['costing_method'], 'FIFO');
      expect(payload['unit_cost'], 7);
      expect(payload['total_cost'], 14);
      expect(payload['source_batch_id'], 'batch-1');
    });

    test('builds batch consumption only when batch exists', () {
      final payload = buildBackfillBatchConsumptionPayloadFromLegacy(
        legacyDocId: 'legacy-2',
        legacyData: <String, dynamic>{
          'idCompany': 'company-1',
          'sale_id': 'sale-2',
          'sale_item_id': 'item-2',
          'ledger_scope': 'ACCOUNTING',
          'qty': 3,
          'unit_cost': 5,
          'total_cost': 15,
          'batch_id': 'batch-2',
        },
      );

      expect(payload, isNotNull);
      expect(payload!['batch_id'], 'batch-2');
      expect(payload['unit_cost'], 5);
      expect(payload['total_cost'], 15);
    });

    test('skips batch consumption without batch id', () {
      final payload = buildBackfillBatchConsumptionPayloadFromLegacy(
        legacyDocId: 'legacy-3',
        legacyData: <String, dynamic>{
          'idCompany': 'company-1',
          'sale_id': 'sale-3',
          'sale_item_id': 'item-3',
          'qty': 1,
          'unit_cost': 4,
          'total_cost': 4,
        },
      );

      expect(payload, isNull);
    });

    test('builds deterministic backfill doc ids', () {
      expect(
        legacyCogsBackfillDocId(legacyDocId: 'abc', prefix: 'cogs'),
        'cogs_abc',
      );
    });
  });
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/sales_ledger_support.dart';

void main() {
  group('buildSalesLedger', () {
    test('prefers linked transaction amount and keeps sale metadata', () {
      final ledger = buildSalesLedger(
        sales: [
          {
            'id': 'sale-1',
            'idCompany': 'company-1',
            'amount': 1000,
            'transaction_id': 'tx-1',
            'shop_id': 'shop-1',
            'shop_name': 'Main Shop',
            'cashier_id': 'cashier-1',
            'cashier_name': 'Anna',
            'client_id': 'client-1',
            'client_name': 'Client A',
            'discount': 50,
            'created_at': Timestamp.fromDate(DateTime(2025, 1, 1)),
          },
        ],
        transactions: [
          {
            'id': 'tx-1',
            'sale_id': 'sale-1',
            'idCompany': 'company-1',
            'type': 'income',
            'summa': 1200,
            'typeUchet': 'Up1',
            'source': 'sales.cash_mode',
            'created_at': Timestamp.fromDate(DateTime(2025, 1, 2)),
          },
        ],
      );

      expect(ledger, hasLength(1));
      expect(ledger.first['amount'], 1200);
      expect(ledger.first['transaction_id'], 'tx-1');
      expect(ledger.first['sale_id'], 'sale-1');
      expect(ledger.first['shop_name'], 'Main Shop');
      expect(ledger.first['cashier_name'], 'Anna');
      expect(ledger.first['client_name'], 'Client A');
      expect(ledger.first['created_at'], DateTime(2025, 1, 2));
    });

    test('adds orphan sale transactions missing sales document', () {
      final ledger = buildSalesLedger(
        sales: const [],
        transactions: [
          {
            'id': 'tx-2',
            'sale_id': 'sale-2',
            'idCompany': 'company-1',
            'type': 'income',
            'summa': 3000,
            'source': 'sales.cash_mode',
            'shop_name': 'Branch',
            'created_at': Timestamp.fromDate(DateTime(2025, 2, 1)),
          },
        ],
      );

      expect(ledger, hasLength(1));
      expect(ledger.first['orphan_transaction'], isTrue);
      expect(ledger.first['amount'], 3000);
      expect(ledger.first['sale_id'], 'sale-2');
      expect(ledger.first['transaction_id'], 'tx-2');
      expect(ledger.first['shop_name'], 'Branch');
    });

    test('ignores unrelated transactions', () {
      final ledger = buildSalesLedger(
        sales: const [],
        transactions: [
          {
            'id': 'tx-3',
            'idCompany': 'company-1',
            'type': 'decome',
            'summa': 100,
            'source': 'manual',
          },
          {
            'id': 'tx-4',
            'idCompany': 'company-1',
            'type': 'income',
            'summa': 200,
            'source': 'manual',
          },
        ],
      );

      expect(ledger, isEmpty);
    });
  });
}

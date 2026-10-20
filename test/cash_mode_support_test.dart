import 'package:flutter_test/flutter_test.dart';

import 'package:uchet_s_d/utils/cash_mode_support.dart';
import 'package:uchet_s_d/utils/domain_entry_adapters.dart';
import 'package:uchet_s_d/utils/ledger_scope.dart';

void main() {
  final officialProduct = CatalogEntryView(
    id: 'p1',
    companyId: 'c1',
    name: 'Official',
    code: 'P1',
    barcode: '',
    itemKind: 'product',
    stock: 5,
    salePrice: 1000,
    basePrice: 900,
    warehouseType: WarehouseType.official,
    ledgerScope: LedgerScope.accounting,
  );

  final unofficialCartItem = CartEntryView(
    id: 'p2',
    name: 'Unofficial',
    itemKind: 'product',
    qty: 1,
    stock: 2,
    salePrice: 800,
    basePrice: 700,
    warehouseType: WarehouseType.unofficial,
    ledgerScope: LedgerScope.management,
  );

  test('cartAccountingModeFromEntries resolves legacy mode', () {
    expect(cartAccountingModeFromEntries([unofficialCartItem]), 'Up1');
  });

  test('productCompatibleWithCart rejects mixed official/unofficial cart', () {
    expect(
      productCompatibleWithCart(officialProduct, [unofficialCartItem]),
      isFalse,
    );
  });

  test('buildLocalShiftSalesPatch updates hot path counters', () {
    final patch = buildLocalShiftSalesPatch(
      shiftDoc: const {'id': 'shift-1', 'cash_sales': 0},
      cashSales: 5000,
      cardSales: 2000,
      transactions: 3,
    );

    expect(patch['id'], 'shift-1');
    expect(patch['cash_sales'], 5000);
    expect(patch['card_sales'], 2000);
    expect(patch['transactions'], 3);
  });

  test('applySoldItemsToProductDocs updates stock and stock value', () {
    final updated = applySoldItemsToProductDocs(
      productDocs: const [
        {
          'id': 'p1',
          'stock': 10,
          'purchase_price': 500,
        }
      ],
      soldCartDocs: const [
        {
          'id': 'p1',
          'item_kind': 'product',
          'qty': 3,
        }
      ],
    );

    expect(updated.single['stock'], 7);
    expect(updated.single['stock_value'], 3500);
  });

  test('buildCashSaleUiStatePatch updates products, shift and invalidations',
      () {
    final patch = buildCashSaleUiStatePatch(
      productDocs: const [
        {'id': 'p1', 'stock': 4, 'purchase_price': 100}
      ],
      soldCartDocs: const [
        {'id': 'p1', 'item_kind': 'product', 'qty': 1}
      ],
      shiftDoc: const {'id': 'shift-1'},
      cashSales: 1000,
      cardSales: 500,
      transactions: 2,
    );

    expect(patch.productDocs.single['stock'], 3);
    expect(patch.shiftDoc['cash_sales'], 1000);
    expect(patch.shiftDoc['card_sales'], 500);
    expect(patch.collectionsToInvalidate, contains('sales_items'));
    expect(patch.collectionsToInvalidate, contains('cogs_register'));
    expect(patch.collectionsToInvalidate, contains('batch_consumptions'));
    expect(patch.collectionsToInvalidate, contains('nomenklatura'));
  });
}

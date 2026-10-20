import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:uchet_s_d/utils/domain_entry_adapters.dart';
import 'package:uchet_s_d/utils/ledger_scope.dart';

void main() {
  test('SaleEntryView maps ledger scope and names', () {
    final view = SaleEntryView.fromMap({
      'id': 'sale-1',
      'idCompany': 'c1',
      'amount': 1200,
      'created_at': Timestamp.fromDate(DateTime(2025, 1, 2)),
      'shop_name': 'Shop',
      'client_name': 'Client',
      'cashier_name': 'Cashier',
      'discount': 25,
      'payment_method': 'cash',
      'ledger_scope': 'ACCOUNTING',
      'typeUchet': 'Bu',
      'source': 'sales.cash_mode',
    });

    expect(view.amount, 1200);
    expect(view.shopName, 'Shop');
    expect(view.ledgerScope, LedgerScope.accounting);
    expect(view.typeUchet, 'Bu');
  });

  test('ExpenseEntryView maps management scope from legacy type', () {
    final view = ExpenseEntryView.fromMap({
      'id': 'exp-1',
      'idCompany': 'c1',
      'amount': '900',
      'created_at': Timestamp.fromDate(DateTime(2025, 2, 1)),
      'shop_name': 'Store',
      'category': 'Fuel',
      'typeUchet': 'Up1',
    });

    expect(view.amount, 900);
    expect(view.category, 'Fuel');
    expect(view.ledgerScope, LedgerScope.management);
  });

  test('ServiceEntryView maps service fields', () {
    final view = ServiceEntryView.fromMap({
      'id': 'service-1',
      'idCompany': 'c1',
      'name': 'Repair',
      'code': 'SRV1',
      'description': 'Repair service',
      'category': 'Auto',
      'price': 2500,
      'vat': 12,
    });

    expect(view.name, 'Repair');
    expect(view.category, 'Auto');
    expect(view.price, 2500);
    expect(view.vat, 12);
  });

  test('SupplierEntryView maps supplier fields', () {
    final view = SupplierEntryView.fromMap({
      'id': 'supplier-1',
      'idCompany': 'c1',
      'name': 'Mega Trade',
      'legal_name': 'Mega Trade LLP',
      'bin': '123456',
      'category': 'Food',
      'contact': 'Ali',
      'status': 'Активный',
      'turnover': 12000,
      'orders': 5,
    });

    expect(view.name, 'Mega Trade');
    expect(view.legalName, 'Mega Trade LLP');
    expect(view.isActive, isTrue);
    expect(view.turnover, 12000);
    expect(view.orders, 5);
  });

  test('InventoryEntryView resolves warehouse type and abc', () {
    final view = InventoryEntryView.fromMap({
      'id': 'n1',
      'idCompany': 'c1',
      'name': 'Item',
      'category': 'Main',
      'category_before_discount': 'Old',
      'category_at_discount': 'Promo',
      'warehouse': 'Официальные товары',
      'stock': 5,
      'revenue': 1000,
      'profit': 200,
      'abc': 'a',
      'discount_percent': 10,
      'sales_with_discount_count': 2,
      'sales_with_discount_sum': 300,
    });

    expect(view.isOfficial, true);
    expect(view.warehouseType, WarehouseType.official);
    expect(view.abc, 'A');
    expect(view.discountPercent, 10);
    expect(view.categoryBeforeDiscount, 'Old');
    expect(view.discountSalesCount, 2);
  });

  test('InvestmentEntryView maps amounts and period', () {
    final view = InvestmentEntryView.fromMap({
      'id': 'inv-1',
      'idCompany': 'c1',
      'amount': 5000,
      'return_amount': 6500,
      'period': 'Январь 2025',
      'name': 'Expansion',
    });

    expect(view.amount, 5000);
    expect(view.returnAmount, 6500);
    expect(view.period, 'Январь 2025');
    expect(view.name, 'Expansion');
  });

  test('ShopEntryView maps core shop fields', () {
    final view = ShopEntryView.fromMap({
      'id': 'shop-1',
      'idCompany': 'c1',
      'name': 'Store',
      'address': 'Addr',
      'manager': 'Boss',
      'phone': '+123',
      'workingHours': '9-18',
      'warehouseName': 'WH',
      'status': 'active',
    });

    expect(view.name, 'Store');
    expect(view.isActive, isTrue);
    expect(view.warehouseName, 'WH');
  });

  test('WarehouseMovementEntryView maps movement row', () {
    final view = WarehouseMovementEntryView.fromMap({
      'id': 'move-1',
      'idCompany': 'c1',
      'product_name': 'Item',
      'product_code': 'X1',
      'from_warehouse': 'A',
      'to_warehouse': 'B',
      'qty': 4,
      'user_name': 'U',
      'created_at': Timestamp.fromDate(DateTime(2025, 3, 4)),
    }, kind: 'move');

    expect(view.kind, 'move');
    expect(view.productTitle, 'Item (X1)');
    expect(view.qty, 4);
    expect(view.userName, 'U');
  });

  test('ClientEntryView builds display label', () {
    final view = ClientEntryView.fromMap({
      'id': 'client-1',
      'idCompany': 'c1',
      'name': 'Mega Optica',
      'client_type': 'legal',
    });

    expect(view.displayType, 'Юр.лицо');
    expect(view.displayLabel, 'Mega Optica • Юр.лицо');
  });

  test('CashierEntryView maps permissions and pin state', () {
    final view = CashierEntryView.fromMap({
      'id': 'cashier-1',
      'idCompany': 'c1',
      'name': 'Aruzhan',
      'shop_id': 'shop-1',
      'shop_name': 'Store',
      'salary': 120000,
      'commissionPercent': 7,
      'status': 'active',
      'pin_hash': 'hash',
      'permissions': {
        'canDiscount': true,
        'maxDiscount': 15,
      },
    });

    expect(view.isActive, isTrue);
    expect(view.hasPin, isTrue);
    expect(view.canDiscount, isTrue);
    expect(view.maxDiscount, 15);
    expect(view.shopName, 'Store');
  });

  test('CashRegisterShiftEntryView maps turnover and average check', () {
    final view = CashRegisterShiftEntryView.fromMap({
      'id': 'shift-1',
      'idCompany': 'c1',
      'cash_register_name': 'Касса 1',
      'cashier_id': 'cashier-1',
      'cashier_name': 'Aruzhan',
      'status': 'open',
      'cash_sales': 20000,
      'card_sales': 5000,
      'transactions': 5,
      'starting_cash': 3000,
      'incassation_total': 7000,
      'typeUchet': 'Up1',
    });

    expect(view.isOpen, isTrue);
    expect(view.turnover, 25000);
    expect(view.averageCheck, 5000);
    expect(view.ledgerScope, LedgerScope.management);
  });

  test('CatalogEntryView maps effective price and kind', () {
    final view = CatalogEntryView.fromMap({
      'id': 'prod-1',
      'idCompany': 'c1',
      'name': 'Product',
      'code': 'P1',
      'barcode': '123',
      'item_kind': 'product',
      'stock': 7,
      'sale_price': 1500,
      'price': 1200,
      'warehouse': 'Официальные товары',
    });

    expect(view.isProduct, isTrue);
    expect(view.effectivePrice, 1500);
    expect(view.isOfficial, isTrue);
  });

  test('CartEntryView maps qty and base price fallback', () {
    final view = CartEntryView.fromMap({
      'id': 'srv-1',
      'name': 'Service',
      'item_kind': 'service',
      'qty': 2,
      'price': 3000,
    });

    expect(view.isProduct, isFalse);
    expect(view.qty, 2);
    expect(view.effectivePrice, 3000);
  });
}

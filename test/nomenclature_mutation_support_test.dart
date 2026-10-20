import 'package:flutter_test/flutter_test.dart';

import 'package:uchet_s_d/utils/inventory_costing_method.dart';
import 'package:uchet_s_d/utils/ledger_scope.dart';
import 'package:uchet_s_d/utils/nomenclature_mutation_support.dart';

void main() {
  test('buildNomenclatureProductPayload writes ledger scope and warehouse type',
      () {
    final payload = buildNomenclatureProductPayload(
      companyId: 'c1',
      userId: 'u1',
      name: 'Item',
      code: 'I1',
      type: 'Товар',
      category: 'Товары',
      sku: 'SKU1',
      barcode: '123',
      warehouse: 'Официальные товары',
      purchaseText: '100',
      saleText: '150',
      stockText: '3',
      minStockText: '1',
      sourceType: 'manual',
      accountingMode: 'Bu',
      isCreate: true,
    );

    expect(payload['ledger_scope'], LedgerScope.accounting.storageValue);
    expect(payload['warehouse_type'], WarehouseType.official.storageValue);
    expect(payload['stock_value'], 300);
    expect(payload['inventory_costing_method'], 'FIFO');
    expect(payload.containsKey('created_at'), isTrue);
  });

  test('buildNomenclatureProductPayload writes selected costing method', () {
    final payload = buildNomenclatureProductPayload(
      companyId: 'c1',
      userId: 'u1',
      name: 'Item',
      code: 'I1',
      type: 'Товар',
      category: 'Товары',
      sku: 'SKU1',
      barcode: '123',
      warehouse: 'Официальные товары',
      purchaseText: '100',
      saleText: '150',
      stockText: '3',
      minStockText: '1',
      sourceType: 'manual',
      accountingMode: 'Bu',
      costingMethod: InventoryCostingMethod.weightedAverage,
      isCreate: true,
    );

    expect(payload['inventory_costing_method'], 'WEIGHTED_AVERAGE');
    expect(payload['costing_method'], 'WEIGHTED_AVERAGE');
  });

  test('buildWarehouseMovementPayload builds typed movement payload', () {
    final payload = buildWarehouseMovementPayload(
      companyId: 'c1',
      userId: 'u1',
      userName: 'User',
      productId: 'p1',
      productName: 'Item',
      productCode: 'I1',
      fromWarehouse: 'A',
      toWarehouse: 'B',
      qty: 2,
      extra: const {'kind': 'move'},
    );

    expect(payload['idCompany'], 'c1');
    expect(payload['product_id'], 'p1');
    expect(payload['qty'], 2);
    expect(payload['kind'], 'move');
  });

  test('buildPurchaseBatchHeaderPayload writes workflow metadata', () {
    final payload = buildPurchaseBatchHeaderPayload(
      companyId: 'c1',
      userId: 'u1',
      deliveryType: 'car',
      vehicleNumber: '123',
      driverName: 'Ali',
      driverPhone: '777',
      supplierName: 'Mega',
      invoiceNumber: 'INV-1',
      invoiceDate: '2025-01-01',
      gtdNumber: 'GTD',
      deliveryNote: 'note',
      accountingMode: 'Bu',
    );

    expect(payload['idCompany'], 'c1');
    expect(payload['workflow_stage'], 'purchase');
    expect(payload['ledger_scope'], LedgerScope.accounting.storageValue);
  });

  test('buildInventoryCostingMethodPatch writes selected method', () {
    final payload = buildInventoryCostingMethodPatch(
      costingMethod: InventoryCostingMethod.weightedAverage,
    );

    expect(payload['inventory_costing_method'], 'WEIGHTED_AVERAGE');
    expect(payload['costing_method'], 'WEIGHTED_AVERAGE');
    expect(payload.containsKey('updated_at'), isTrue);
  });
}

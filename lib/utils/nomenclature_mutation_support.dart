import '/backend/backend.dart';
import '/utils/accounting_workflow.dart';
import '/utils/inventory_costing_method.dart';
import '/utils/ledger_scope.dart';
import '/utils/money_amount.dart';
import '/utils/product_catalog_support.dart' as product_catalog;

Map<String, dynamic> buildNomenclatureProductPayload({
  required String companyId,
  required String userId,
  required String name,
  required String code,
  required String type,
  required String category,
  required String sku,
  required String barcode,
  required String warehouse,
  required String purchaseText,
  required String saleText,
  required String stockText,
  required String minStockText,
  required String sourceType,
  required String accountingMode,
  InventoryCostingMethod costingMethod = InventoryCostingMethod.fifo,
  Map<String, dynamic> extra = const <String, dynamic>{},
  required bool isCreate,
}) {
  final purchase = product_catalog.toNumFlexible(purchaseText);
  final sale = product_catalog.toNumFlexible(saleText);
  final stock = product_catalog.toNumFlexible(stockText);
  final minStock = product_catalog.toNumFlexible(minStockText);
  final inventoryWarehouseType =
      warehouseTypeFromLegacy(warehouse: warehouse.trim());
  return {
    'name': name.trim(),
    'code': code.trim(),
    'type': type.trim(),
    'category': category.trim(),
    'sku': sku.trim(),
    'barcode': barcode.trim(),
    'warehouse': warehouse.trim(),
    ...warehouseTypeFields(inventoryWarehouseType),
    'purchase_price': purchase,
    'sale_price': sale,
    'markup_ratio': product_catalog.markupCoeffFromPrices(
      purchaseText,
      saleText,
      warehouse: warehouse,
    ),
    'stock': stock,
    'min_stock': minStock,
    'stock_value': stock * purchase,
    ...inventoryCostingMethodFields(costingMethod),
    ...product_catalog.sourceMeta(sourceType),
    'user_id': userId,
    'idCompany': companyId.trim(),
    'accounting_mode': accountingMode,
    'ledger_scope': ledgerScopeFromLegacyValue(accountingMode).storageValue,
    ...extra,
    'updated_at': FieldValue.serverTimestamp(),
    if (isCreate) 'created_at': FieldValue.serverTimestamp(),
  };
}

Map<String, dynamic> buildWarehouseMovementPayload({
  required String companyId,
  required String userId,
  required String userName,
  required String productId,
  required String productName,
  required String productCode,
  required String fromWarehouse,
  required String toWarehouse,
  required double qty,
  Map<String, dynamic> extra = const <String, dynamic>{},
}) {
  return {
    'idCompany': companyId,
    'user_id': userId,
    'user_name': userName,
    'product_id': productId,
    'product_name': productName,
    'product_code': productCode,
    'from_warehouse': fromWarehouse,
    'to_warehouse': toWarehouse,
    'qty': qty,
    'created_at': FieldValue.serverTimestamp(),
    ...extra,
  };
}

Map<String, dynamic> buildPurchaseBatchHeaderPayload({
  required String companyId,
  required String userId,
  required String deliveryType,
  required String vehicleNumber,
  required String driverName,
  required String driverPhone,
  required String supplierName,
  required String invoiceNumber,
  required String invoiceDate,
  required String gtdNumber,
  required String deliveryNote,
  required String accountingMode,
  Map<String, dynamic> extra = const {},
}) {
  return {
    'user_id': userId,
    'idCompany': companyId,
    'delivery_type': deliveryType.trim(),
    'vehicle_number': vehicleNumber.trim(),
    'driver_name': driverName.trim(),
    'driver_phone': driverPhone.trim(),
    'supplier_name': supplierName.trim(),
    'invoice_number': invoiceNumber.trim(),
    'invoice_date': invoiceDate.trim(),
    'gtd_number': gtdNumber.trim(),
    'delivery_note': deliveryNote.trim(),
    'created_at': FieldValue.serverTimestamp(),
    'doc_date': FieldValue.serverTimestamp(),
    ...workflowMeta(
      stage: AccountingWorkflowStage.purchase,
      accountingMode: accountingMode,
      status: AccountingWorkflowStatus.posted,
    ),
    ...extra,
  };
}

Map<String, dynamic> buildPurchaseBatchItemPayload({
  required String article,
  required String name,
  required double price,
  required double qty,
}) {
  return {
    'article': article.trim(),
    'name': name.trim(),
    'price': price,
    'qty': qty,
    'total': qty * price,
  };
}

Map<String, dynamic> buildPurchaseTransactionPayload({
  required String companyId,
  required String accountingMode,
  required double totalCost,
  required DocumentReference schetRef,
  required String schetTitle,
  Map<String, dynamic>? schetData,
  double? exchangeRateToCompany,
  DateTime? exchangeRateDate,
  String exchangeRateSource = 'manual_purchase',
}) {
  return {
    ...createTranzactionRecordData(
      type: 'decome',
      typeUchet: accountingMode,
      ledgerScope: ledgerScopeFromLegacyValue(accountingMode).storageValue,
      kat: 'Закупка',
      text: 'Закупка партии',
      summa: totalCost,
      nds: false,
      summaNds: 0,
      idCompany: companyId,
      schetId: schetRef,
      schetTitle: schetTitle,
    ),
    ...mapToFirestore(
      transactionMoneyFieldsForAccountData(
        amountOriginal: totalCost,
        accountData: schetData,
        exchangeRateToCompany: exchangeRateToCompany,
        exchangeRateDate: exchangeRateDate,
        exchangeRateSource: exchangeRateSource,
      ),
    ),
    ...mapToFirestore({'date': FieldValue.serverTimestamp()}),
    ...workflowMeta(
      stage: AccountingWorkflowStage.purchase,
      accountingMode: accountingMode,
      status: AccountingWorkflowStatus.posted,
    ),
  };
}

Map<String, dynamic> buildInventoryCostingMethodPatch({
  required InventoryCostingMethod costingMethod,
}) {
  return {
    ...inventoryCostingMethodFields(costingMethod),
    'updated_at': FieldValue.serverTimestamp(),
  };
}

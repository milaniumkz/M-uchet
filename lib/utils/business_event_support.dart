import '/utils/ledger_scope.dart';

enum BusinessEventType {
  saleCreated,
  servicePerformed,
  inventoryMoved,
  paymentReceived,
  expenseRecorded,
}

extension BusinessEventTypeX on BusinessEventType {
  String get storageValue {
    switch (this) {
      case BusinessEventType.saleCreated:
        return 'SALE_CREATED';
      case BusinessEventType.servicePerformed:
        return 'SERVICE_PERFORMED';
      case BusinessEventType.inventoryMoved:
        return 'INVENTORY_MOVED';
      case BusinessEventType.paymentReceived:
        return 'PAYMENT_RECEIVED';
      case BusinessEventType.expenseRecorded:
        return 'EXPENSE_RECORDED';
    }
  }
}

BusinessEventType businessEventTypeFromValue(String? raw) {
  switch ((raw ?? '').trim().toUpperCase()) {
    case 'SERVICE_PERFORMED':
      return BusinessEventType.servicePerformed;
    case 'INVENTORY_MOVED':
      return BusinessEventType.inventoryMoved;
    case 'PAYMENT_RECEIVED':
      return BusinessEventType.paymentReceived;
    case 'EXPENSE_RECORDED':
      return BusinessEventType.expenseRecorded;
    default:
      return BusinessEventType.saleCreated;
  }
}

Map<String, dynamic> buildBusinessEventPayload({
  required String companyId,
  required BusinessEventType type,
  required LedgerScope ledgerScope,
  String? aggregateId,
  String? saleId,
  String? saleItemId,
  String? productId,
  String? serviceId,
  String? serviceName,
  String? serviceCategory,
  String? warehouseId,
  String? warehouseName,
  String? transactionId,
  String? categoryName,
  double revenue = 0,
  double cost = 0,
  double quantity = 0,
  String? paymentMethod,
  String? notes,
  DateTime? occurredAt,
}) {
  return <String, dynamic>{
    'idCompany': companyId,
    'event_type': type.storageValue,
    'ledger_scope': ledgerScope.storageValue,
    'aggregate_id': aggregateId,
    'sale_id': saleId,
    'sale_item_id': saleItemId,
    'product_id': productId,
    'service_id': serviceId,
    'service_name': serviceName,
    'service_category': serviceCategory,
    'warehouse_id': warehouseId,
    'warehouse_name': warehouseName,
    'transaction_id': transactionId,
    'category_name': categoryName,
    'revenue': revenue,
    'cost': cost,
    'margin': revenue - cost,
    'quantity': quantity,
    'payment_method': paymentMethod,
    'notes': notes,
    'occurred_at': occurredAt ?? DateTime.now(),
    'created_at': DateTime.now(),
  }..removeWhere((key, value) => value == null || value == '');
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/utils/ledger_scope.dart';

class InventoryReservationRecord extends FirestoreRecord {
  InventoryReservationRecord._(super.reference, super.data) {
    _initializeFields();
  }

  String? _orderId;
  String get orderId => _orderId ?? '';

  String? _orderItemId;
  String get orderItemId => _orderItemId ?? '';

  String? _productId;
  String get productId => _productId ?? '';

  String? _warehouseId;
  String get warehouseId => _warehouseId ?? '';

  String? _batchId;
  String get batchId => _batchId ?? '';

  double? _quantityReserved;
  double get quantityReserved => _quantityReserved ?? 0;

  double? _quantityReleased;
  double get quantityReleased => _quantityReleased ?? 0;

  double? _quantityConsumed;
  double get quantityConsumed => _quantityConsumed ?? 0;

  String? _status;
  String get status => _status ?? '';

  String? _ledgerScope;
  String get ledgerScope => _ledgerScope ?? '';
  LedgerScope get ledgerScopeEnum => ledgerScopeFromLegacyValue(_ledgerScope);

  void _initializeFields() {
    _orderId = snapshotData['order_id'] as String?;
    _orderItemId = snapshotData['order_item_id'] as String?;
    _productId = snapshotData['product_id'] as String?;
    _warehouseId = snapshotData['warehouse_id'] as String?;
    _batchId = snapshotData['batch_id'] as String?;
    _quantityReserved = castToType<double>(snapshotData['quantity_reserved']);
    _quantityReleased = castToType<double>(snapshotData['quantity_released']);
    _quantityConsumed = castToType<double>(snapshotData['quantity_consumed']);
    _status = snapshotData['status'] as String?;
    _ledgerScope = (snapshotData['ledger_scope'] ?? snapshotData['ledgerScope'])
        as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('inventory_reservations');

  static InventoryReservationRecord fromSnapshot(DocumentSnapshot snapshot) =>
      InventoryReservationRecord._(
        snapshot.reference,
        mapFromFirestore(Map<String, dynamic>.from(snapshot.data() as Map)),
      );
}

Map<String, dynamic> createInventoryReservationRecordData({
  String? orderId,
  String? orderItemId,
  String? productId,
  String? warehouseId,
  String? batchId,
  double? quantityReserved,
  double? quantityReleased,
  double? quantityConsumed,
  String? status,
  String? ledgerScope,
  String? idCompany,
}) {
  return mapToFirestore(
    <String, dynamic>{
      'order_id': orderId,
      'order_item_id': orderItemId,
      'product_id': productId,
      'warehouse_id': warehouseId,
      'batch_id': batchId,
      'quantity_reserved': quantityReserved,
      'quantity_released': quantityReleased,
      'quantity_consumed': quantityConsumed,
      'status': status,
      'ledger_scope': ledgerScope,
      'idCompany': idCompany,
    }.withoutNulls,
  );
}

class InventoryReservationRecordDocumentEquality
    implements Equality<InventoryReservationRecord> {
  const InventoryReservationRecordDocumentEquality();

  @override
  bool equals(
    InventoryReservationRecord? e1,
    InventoryReservationRecord? e2,
  ) =>
      e1?.orderId == e2?.orderId &&
      e1?.orderItemId == e2?.orderItemId &&
      e1?.batchId == e2?.batchId &&
      e1?.quantityReserved == e2?.quantityReserved &&
      e1?.status == e2?.status;

  @override
  int hash(InventoryReservationRecord? e) => const ListEquality().hash([
        e?.orderId,
        e?.orderItemId,
        e?.batchId,
        e?.quantityReserved,
        e?.status,
      ]);

  @override
  bool isValidKey(Object? o) => o is InventoryReservationRecord;
}

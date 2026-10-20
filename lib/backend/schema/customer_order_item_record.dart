import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/flutter_flow/flutter_flow_util.dart';

class CustomerOrderItemRecord extends FirestoreRecord {
  CustomerOrderItemRecord._(super.reference, super.data) {
    _initializeFields();
  }

  String? _orderId;
  String get orderId => _orderId ?? '';

  String? _productId;
  String get productId => _productId ?? '';

  double? _quantityOrdered;
  double get quantityOrdered => _quantityOrdered ?? 0;

  double? _quantityReserved;
  double get quantityReserved => _quantityReserved ?? 0;

  double? _quantityShipped;
  double get quantityShipped => _quantityShipped ?? 0;

  void _initializeFields() {
    _orderId = snapshotData['order_id'] as String?;
    _productId = snapshotData['product_id'] as String?;
    _quantityOrdered = castToType<double>(snapshotData['quantity_ordered']);
    _quantityReserved = castToType<double>(snapshotData['quantity_reserved']);
    _quantityShipped = castToType<double>(snapshotData['quantity_shipped']);
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('customer_order_items');

  static CustomerOrderItemRecord fromSnapshot(DocumentSnapshot snapshot) =>
      CustomerOrderItemRecord._(
        snapshot.reference,
        mapFromFirestore(Map<String, dynamic>.from(snapshot.data() as Map)),
      );
}

Map<String, dynamic> createCustomerOrderItemRecordData({
  String? orderId,
  String? productId,
  double? quantityOrdered,
  double? quantityReserved,
  double? quantityShipped,
  String? idCompany,
}) {
  return mapToFirestore(
    <String, dynamic>{
      'order_id': orderId,
      'product_id': productId,
      'quantity_ordered': quantityOrdered,
      'quantity_reserved': quantityReserved,
      'quantity_shipped': quantityShipped,
      'idCompany': idCompany,
    }.withoutNulls,
  );
}

class CustomerOrderItemRecordDocumentEquality
    implements Equality<CustomerOrderItemRecord> {
  const CustomerOrderItemRecordDocumentEquality();

  @override
  bool equals(CustomerOrderItemRecord? e1, CustomerOrderItemRecord? e2) =>
      e1?.orderId == e2?.orderId &&
      e1?.productId == e2?.productId &&
      e1?.quantityOrdered == e2?.quantityOrdered &&
      e1?.quantityReserved == e2?.quantityReserved &&
      e1?.quantityShipped == e2?.quantityShipped;

  @override
  int hash(CustomerOrderItemRecord? e) => const ListEquality().hash([
        e?.orderId,
        e?.productId,
        e?.quantityOrdered,
        e?.quantityReserved,
        e?.quantityShipped,
      ]);

  @override
  bool isValidKey(Object? o) => o is CustomerOrderItemRecord;
}

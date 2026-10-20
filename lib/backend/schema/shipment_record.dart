import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/utils/ledger_scope.dart';

class ShipmentRecord extends FirestoreRecord {
  ShipmentRecord._(super.reference, super.data) {
    _initializeFields();
  }

  String? _orderId;
  String get orderId => _orderId ?? '';

  String? _saleId;
  String get saleId => _saleId ?? '';

  String? _status;
  String get status => _status ?? '';

  double? _totalAmount;
  double get totalAmount => _totalAmount ?? 0;

  String? _ledgerScope;
  String get ledgerScope => _ledgerScope ?? '';
  LedgerScope get ledgerScopeEnum => ledgerScopeFromLegacyValue(_ledgerScope);

  void _initializeFields() {
    _orderId = snapshotData['order_id'] as String?;
    _saleId = snapshotData['sale_id'] as String?;
    _status = snapshotData['status'] as String?;
    _totalAmount = castToType<double>(snapshotData['total_amount']);
    _ledgerScope = (snapshotData['ledger_scope'] ?? snapshotData['ledgerScope'])
        as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('shipments');

  static ShipmentRecord fromSnapshot(DocumentSnapshot snapshot) =>
      ShipmentRecord._(
        snapshot.reference,
        mapFromFirestore(Map<String, dynamic>.from(snapshot.data() as Map)),
      );
}

Map<String, dynamic> createShipmentRecordData({
  String? orderId,
  String? saleId,
  String? status,
  double? totalAmount,
  String? ledgerScope,
  String? idCompany,
}) {
  return mapToFirestore(
    <String, dynamic>{
      'order_id': orderId,
      'sale_id': saleId,
      'status': status,
      'total_amount': totalAmount,
      'ledger_scope': ledgerScope,
      'idCompany': idCompany,
    }.withoutNulls,
  );
}

class ShipmentRecordDocumentEquality implements Equality<ShipmentRecord> {
  const ShipmentRecordDocumentEquality();

  @override
  bool equals(ShipmentRecord? e1, ShipmentRecord? e2) =>
      e1?.orderId == e2?.orderId &&
      e1?.saleId == e2?.saleId &&
      e1?.status == e2?.status &&
      e1?.totalAmount == e2?.totalAmount;

  @override
  int hash(ShipmentRecord? e) => const ListEquality().hash([
        e?.orderId,
        e?.saleId,
        e?.status,
        e?.totalAmount,
      ]);

  @override
  bool isValidKey(Object? o) => o is ShipmentRecord;
}

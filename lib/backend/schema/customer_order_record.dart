import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/utils/ledger_scope.dart';

class CustomerOrderRecord extends FirestoreRecord {
  CustomerOrderRecord._(super.reference, super.data) {
    _initializeFields();
  }

  String? _orderNumber;
  String get orderNumber => _orderNumber ?? '';

  String? _customerId;
  String get customerId => _customerId ?? '';

  String? _customerName;
  String get customerName => _customerName ?? '';

  String? _warehouseId;
  String get warehouseId => _warehouseId ?? '';

  String? _status;
  String get status => _status ?? '';

  double? _totalAmount;
  double get totalAmount => _totalAmount ?? 0;

  String? _currency;
  String get currency => _currency ?? 'KZT';

  String? _ledgerScope;
  String get ledgerScope => _ledgerScope ?? '';
  LedgerScope get ledgerScopeEnum => ledgerScopeFromLegacyValue(_ledgerScope);

  void _initializeFields() {
    _orderNumber = snapshotData['order_number'] as String?;
    _customerId = snapshotData['customer_id'] as String?;
    _customerName = snapshotData['customer_name'] as String?;
    _warehouseId = snapshotData['warehouse_id'] as String?;
    _status = snapshotData['status'] as String?;
    _totalAmount = castToType<double>(snapshotData['total_amount']);
    _currency = snapshotData['currency'] as String?;
    _ledgerScope = (snapshotData['ledger_scope'] ?? snapshotData['ledgerScope'])
        as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('customer_orders');

  static CustomerOrderRecord fromSnapshot(DocumentSnapshot snapshot) =>
      CustomerOrderRecord._(
        snapshot.reference,
        mapFromFirestore(Map<String, dynamic>.from(snapshot.data() as Map)),
      );
}

Map<String, dynamic> createCustomerOrderRecordData({
  String? orderNumber,
  String? customerId,
  String? customerName,
  String? warehouseId,
  String? status,
  double? totalAmount,
  String? currency,
  String? ledgerScope,
  String? idCompany,
}) {
  return mapToFirestore(
    <String, dynamic>{
      'order_number': orderNumber,
      'customer_id': customerId,
      'customer_name': customerName,
      'warehouse_id': warehouseId,
      'status': status,
      'total_amount': totalAmount,
      'currency': currency,
      'ledger_scope': ledgerScope,
      'idCompany': idCompany,
    }.withoutNulls,
  );
}

class CustomerOrderRecordDocumentEquality
    implements Equality<CustomerOrderRecord> {
  const CustomerOrderRecordDocumentEquality();

  @override
  bool equals(CustomerOrderRecord? e1, CustomerOrderRecord? e2) =>
      e1?.orderNumber == e2?.orderNumber &&
      e1?.customerId == e2?.customerId &&
      e1?.status == e2?.status &&
      e1?.totalAmount == e2?.totalAmount;

  @override
  int hash(CustomerOrderRecord? e) => const ListEquality().hash([
        e?.orderNumber,
        e?.customerId,
        e?.status,
        e?.totalAmount,
      ]);

  @override
  bool isValidKey(Object? o) => o is CustomerOrderRecord;
}

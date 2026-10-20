import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/utils/ledger_scope.dart';

class OrderPaymentRecord extends FirestoreRecord {
  OrderPaymentRecord._(super.reference, super.data) {
    _initializeFields();
  }

  String? _orderId;
  String get orderId => _orderId ?? '';

  String? _transactionId;
  String get transactionId => _transactionId ?? '';

  double? _amount;
  double get amount => _amount ?? 0;

  String? _paymentMethod;
  String get paymentMethod => _paymentMethod ?? '';

  String? _status;
  String get status => _status ?? '';

  String? _ledgerScope;
  String get ledgerScope => _ledgerScope ?? '';
  LedgerScope get ledgerScopeEnum => ledgerScopeFromLegacyValue(_ledgerScope);

  void _initializeFields() {
    _orderId = snapshotData['order_id'] as String?;
    _transactionId = snapshotData['transaction_id'] as String?;
    _amount = castToType<double>(snapshotData['amount']);
    _paymentMethod = snapshotData['payment_method'] as String?;
    _status = snapshotData['status'] as String?;
    _ledgerScope = (snapshotData['ledger_scope'] ?? snapshotData['ledgerScope'])
        as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('order_payments');

  static OrderPaymentRecord fromSnapshot(DocumentSnapshot snapshot) =>
      OrderPaymentRecord._(
        snapshot.reference,
        mapFromFirestore(Map<String, dynamic>.from(snapshot.data() as Map)),
      );
}

Map<String, dynamic> createOrderPaymentRecordData({
  String? orderId,
  String? transactionId,
  double? amount,
  String? paymentMethod,
  String? status,
  String? ledgerScope,
  String? idCompany,
}) {
  return mapToFirestore(
    <String, dynamic>{
      'order_id': orderId,
      'transaction_id': transactionId,
      'amount': amount,
      'payment_method': paymentMethod,
      'status': status,
      'ledger_scope': ledgerScope,
      'idCompany': idCompany,
    }.withoutNulls,
  );
}

class OrderPaymentRecordDocumentEquality
    implements Equality<OrderPaymentRecord> {
  const OrderPaymentRecordDocumentEquality();

  @override
  bool equals(OrderPaymentRecord? e1, OrderPaymentRecord? e2) =>
      e1?.orderId == e2?.orderId &&
      e1?.transactionId == e2?.transactionId &&
      e1?.amount == e2?.amount &&
      e1?.paymentMethod == e2?.paymentMethod &&
      e1?.status == e2?.status;

  @override
  int hash(OrderPaymentRecord? e) => const ListEquality().hash([
        e?.orderId,
        e?.transactionId,
        e?.amount,
        e?.paymentMethod,
        e?.status,
      ]);

  @override
  bool isValidKey(Object? o) => o is OrderPaymentRecord;
}

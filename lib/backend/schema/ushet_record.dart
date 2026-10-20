import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class UshetRecord extends FirestoreRecord {
  UshetRecord._(
    super.reference,
    super.data,
  ) {
    _initializeFields();
  }

  // "doxodUp" field.
  double? _doxodUp;
  double get doxodUp => _doxodUp ?? 0.0;
  bool hasDoxodUp() => _doxodUp != null;

  // "doxodBu" field.
  double? _doxodBu;
  double get doxodBu => _doxodBu ?? 0.0;
  bool hasDoxodBu() => _doxodBu != null;

  // "doxodUp1" field.
  double? _doxodUp1;
  double get doxodUp1 => _doxodUp1 ?? 0.0;
  bool hasDoxodUp1() => _doxodUp1 != null;

  // "rashodUp" field.
  double? _rashodUp;
  double get rashodUp => _rashodUp ?? 0.0;
  bool hasRashodUp() => _rashodUp != null;

  // "rashodBu" field.
  double? _rashodBu;
  double get rashodBu => _rashodBu ?? 0.0;
  bool hasRashodBu() => _rashodBu != null;

  // "rashodUp1" field.
  double? _rashodUp1;
  double get rashodUp1 => _rashodUp1 ?? 0.0;
  bool hasRashodUp1() => _rashodUp1 != null;

  // "nds" field.
  double? _nds;
  double get nds => _nds ?? 0.0;
  bool hasNds() => _nds != null;

  // "ndsPay" field.
  double? _ndsPay;
  double get ndsPay => _ndsPay ?? 0.0;
  bool hasNdsPay() => _ndsPay != null;

  // "kpn" field.
  double? _kpn;
  double get kpn => _kpn ?? 0.0;
  bool hasKpn() => _kpn != null;

  // "idCompany" field.
  String? _idCompany;
  String get idCompany => _idCompany ?? '';
  bool hasIdCompany() => _idCompany != null;

  // "pribilUp" field.
  double? _pribilUp;
  double get pribilUp => _pribilUp ?? 0.0;
  bool hasPribilUp() => _pribilUp != null;

  // "pribilBu" field.
  double? _pribilBu;
  double get pribilBu => _pribilBu ?? 0.0;
  bool hasPribilBu() => _pribilBu != null;

  // "pribilUp1" field.
  double? _pribilUp1;
  double get pribilUp1 => _pribilUp1 ?? 0.0;
  bool hasPribilUp1() => _pribilUp1 != null;

  // "balanceUp" field.
  double? _balanceUp;
  double get balanceUp => _balanceUp ?? 0.0;
  bool hasBalanceUp() => _balanceUp != null;

  // "balanceUp1" field.
  double? _balanceUp1;
  double get balanceUp1 => _balanceUp1 ?? 0.0;
  bool hasBalanceUp1() => _balanceUp1 != null;

  // "BalanceBu" field.
  double? _balanceBu;
  double get balanceBu => _balanceBu ?? 0.0;
  bool hasBalanceBu() => _balanceBu != null;

  // "kpnPay" field.
  double? _kpnPay;
  double get kpnPay => _kpnPay ?? 0.0;
  bool hasKpnPay() => _kpnPay != null;

  // "cogsUp" field.
  double? _cogsUp;
  double get cogsUp => _cogsUp ?? 0.0;
  bool hasCogsUp() => _cogsUp != null;

  // "cogsBu" field.
  double? _cogsBu;
  double get cogsBu => _cogsBu ?? 0.0;
  bool hasCogsBu() => _cogsBu != null;

  // "cogsUp1" field.
  double? _cogsUp1;
  double get cogsUp1 => _cogsUp1 ?? 0.0;
  bool hasCogsUp1() => _cogsUp1 != null;

  // "grossProfitUp" field.
  double? _grossProfitUp;
  double get grossProfitUp => _grossProfitUp ?? 0.0;
  bool hasGrossProfitUp() => _grossProfitUp != null;

  // "grossProfitBu" field.
  double? _grossProfitBu;
  double get grossProfitBu => _grossProfitBu ?? 0.0;
  bool hasGrossProfitBu() => _grossProfitBu != null;

  // "grossProfitUp1" field.
  double? _grossProfitUp1;
  double get grossProfitUp1 => _grossProfitUp1 ?? 0.0;
  bool hasGrossProfitUp1() => _grossProfitUp1 != null;

  void _initializeFields() {
    _doxodUp = castToType<double>(snapshotData['doxodUp']);
    _doxodBu = castToType<double>(snapshotData['doxodBu']);
    _doxodUp1 = castToType<double>(snapshotData['doxodUp1']);
    _rashodUp = castToType<double>(snapshotData['rashodUp']);
    _rashodBu = castToType<double>(snapshotData['rashodBu']);
    _rashodUp1 = castToType<double>(snapshotData['rashodUp1']);
    _nds = castToType<double>(snapshotData['nds']);
    _ndsPay = castToType<double>(snapshotData['ndsPay']);
    _kpn = castToType<double>(snapshotData['kpn']);
    _idCompany = snapshotData['idCompany'] as String?;
    _pribilUp = castToType<double>(snapshotData['pribilUp']);
    _pribilBu = castToType<double>(snapshotData['pribilBu']);
    _pribilUp1 = castToType<double>(snapshotData['pribilUp1']);
    _balanceUp = castToType<double>(snapshotData['balanceUp']);
    _balanceBu = castToType<double>(snapshotData['BalanceBu']);
    _balanceUp1 = castToType<double>(snapshotData['balanceUp1']);
    _kpnPay = castToType<double>(snapshotData['kpnPay']);
    _cogsUp = castToType<double>(snapshotData['cogsUp']);
    _cogsBu = castToType<double>(snapshotData['cogsBu']);
    _cogsUp1 = castToType<double>(snapshotData['cogsUp1']);
    _grossProfitUp = castToType<double>(snapshotData['grossProfitUp']);
    _grossProfitBu = castToType<double>(snapshotData['grossProfitBu']);
    _grossProfitUp1 = castToType<double>(snapshotData['grossProfitUp1']);
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('ushet');

  static Stream<UshetRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => UshetRecord.fromSnapshot(s));

  static Future<UshetRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => UshetRecord.fromSnapshot(s));

  static UshetRecord fromSnapshot(DocumentSnapshot snapshot) => UshetRecord._(
        snapshot.reference,
        mapFromFirestore(Map<String, dynamic>.from(snapshot.data() as Map)),
      );

  static UshetRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      UshetRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'UshetRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is UshetRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createUshetRecordData({
  double? doxodUp,
  double? doxodBu,
  double? doxodUp1,
  double? rashodUp,
  double? rashodBu,
  double? rashodUp1,
  double? nds,
  double? ndsPay,
  double? kpn,
  String? idCompany,
  double? pribilUp,
  double? pribilBu,
  double? pribilUp1,
  double? balanceUp,
  double? balanceBu,
  double? balanceUp1,
  double? kpnPay,
  double? cogsUp,
  double? cogsBu,
  double? cogsUp1,
  double? grossProfitUp,
  double? grossProfitBu,
  double? grossProfitUp1,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'doxodUp': doxodUp,
      'doxodBu': doxodBu,
      'doxodUp1': doxodUp1,
      'rashodUp': rashodUp,
      'rashodBu': rashodBu,
      'rashodUp1': rashodUp1,
      'nds': nds,
      'ndsPay': ndsPay,
      'kpn': kpn,
      'idCompany': idCompany,
      'pribilUp': pribilUp,
      'pribilBu': pribilBu,
      'pribilUp1': pribilUp1,
      'balanceUp': balanceUp,
      'BalanceBu': balanceBu,
      'balanceUp1': balanceUp1,
      'kpnPay': kpnPay,
      'cogsUp': cogsUp,
      'cogsBu': cogsBu,
      'cogsUp1': cogsUp1,
      'grossProfitUp': grossProfitUp,
      'grossProfitBu': grossProfitBu,
      'grossProfitUp1': grossProfitUp1,
    }.withoutNulls,
  );

  return firestoreData;
}

class UshetRecordDocumentEquality implements Equality<UshetRecord> {
  const UshetRecordDocumentEquality();

  @override
  bool equals(UshetRecord? e1, UshetRecord? e2) {
    return e1?.doxodUp == e2?.doxodUp &&
        e1?.doxodBu == e2?.doxodBu &&
        e1?.doxodUp1 == e2?.doxodUp1 &&
        e1?.rashodUp == e2?.rashodUp &&
        e1?.rashodBu == e2?.rashodBu &&
        e1?.rashodUp1 == e2?.rashodUp1 &&
        e1?.nds == e2?.nds &&
        e1?.ndsPay == e2?.ndsPay &&
        e1?.kpn == e2?.kpn &&
        e1?.idCompany == e2?.idCompany &&
        e1?.pribilUp == e2?.pribilUp &&
        e1?.pribilBu == e2?.pribilBu &&
        e1?.pribilUp1 == e2?.pribilUp1 &&
        e1?.balanceUp == e2?.balanceUp &&
        e1?.balanceBu == e2?.balanceBu &&
        e1?.balanceUp1 == e2?.balanceUp1 &&
        e1?.kpnPay == e2?.kpnPay &&
        e1?.cogsUp == e2?.cogsUp &&
        e1?.cogsBu == e2?.cogsBu &&
        e1?.cogsUp1 == e2?.cogsUp1 &&
        e1?.grossProfitUp == e2?.grossProfitUp &&
        e1?.grossProfitBu == e2?.grossProfitBu &&
        e1?.grossProfitUp1 == e2?.grossProfitUp1;
  }

  @override
  int hash(UshetRecord? e) => const ListEquality().hash([
        e?.doxodUp,
        e?.doxodBu,
        e?.doxodUp1,
        e?.rashodUp,
        e?.rashodBu,
        e?.rashodUp1,
        e?.nds,
        e?.ndsPay,
        e?.kpn,
        e?.idCompany,
        e?.pribilUp,
        e?.pribilBu,
        e?.pribilUp1,
        e?.balanceUp,
        e?.balanceBu,
        e?.balanceUp1,
        e?.kpnPay,
        e?.cogsUp,
        e?.cogsBu,
        e?.cogsUp1,
        e?.grossProfitUp,
        e?.grossProfitBu,
        e?.grossProfitUp1,
      ]);

  @override
  bool isValidKey(Object? o) => o is UshetRecord;
}

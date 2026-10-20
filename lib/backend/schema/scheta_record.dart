import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class SchetaRecord extends FirestoreRecord {
  SchetaRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "nal" field.
  double? _nal;
  double get nal => _nal ?? 0.0;
  bool hasNal() => _nal != null;

  // "bank" field.
  double? _bank;
  double get bank => _bank ?? 0.0;
  bool hasBank() => _bank != null;

  // "myMoney" field.
  double? _myMoney;
  double get myMoney => _myMoney ?? 0.0;
  bool hasMyMoney() => _myMoney != null;

  DocumentReference get parentReference => reference.parent.parent!;

  void _initializeFields() {
    _nal = castToType<double>(snapshotData['nal']);
    _bank = castToType<double>(snapshotData['bank']);
    _myMoney = castToType<double>(snapshotData['myMoney']);
  }

  static Query<Map<String, dynamic>> collection([DocumentReference? parent]) =>
      parent != null
          ? parent.collection('scheta')
          : FirebaseFirestore.instance.collectionGroup('scheta');

  static DocumentReference createDoc(DocumentReference parent, {String? id}) =>
      parent.collection('scheta').doc(id);

  static Stream<SchetaRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => SchetaRecord.fromSnapshot(s));

  static Future<SchetaRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => SchetaRecord.fromSnapshot(s));

  static SchetaRecord fromSnapshot(DocumentSnapshot snapshot) => SchetaRecord._(
        snapshot.reference,
        mapFromFirestore(Map<String, dynamic>.from(snapshot.data() as Map)),
      );

  static SchetaRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      SchetaRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'SchetaRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is SchetaRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createSchetaRecordData({
  double? nal,
  double? bank,
  double? myMoney,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'nal': nal,
      'bank': bank,
      'myMoney': myMoney,
    }.withoutNulls,
  );

  return firestoreData;
}

class SchetaRecordDocumentEquality implements Equality<SchetaRecord> {
  const SchetaRecordDocumentEquality();

  @override
  bool equals(SchetaRecord? e1, SchetaRecord? e2) {
    return e1?.nal == e2?.nal &&
        e1?.bank == e2?.bank &&
        e1?.myMoney == e2?.myMoney;
  }

  @override
  int hash(SchetaRecord? e) =>
      const ListEquality().hash([e?.nal, e?.bank, e?.myMoney]);

  @override
  bool isValidKey(Object? o) => o is SchetaRecord;
}

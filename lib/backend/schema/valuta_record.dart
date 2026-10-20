import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class ValutaRecord extends FirestoreRecord {
  ValutaRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "kod" field.
  String? _kod;
  String get kod => _kod ?? '';
  bool hasKod() => _kod != null;

  // "title" field.
  String? _title;
  String get title => _title ?? '';
  bool hasTitle() => _title != null;

  // "simvol" field.
  String? _simvol;
  String get simvol => _simvol ?? '';
  bool hasSimvol() => _simvol != null;

  // "country_code" field.
  String? _countryCode;
  String get countryCode => _countryCode ?? '';
  bool hasCountryCode() => _countryCode != null;

  void _initializeFields() {
    _kod = snapshotData['kod'] as String?;
    _title = snapshotData['title'] as String?;
    _simvol = snapshotData['simvol'] as String?;
    _countryCode = (snapshotData['country_code'] ?? snapshotData['countryCode'])
        as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('valuta');

  static Stream<ValutaRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => ValutaRecord.fromSnapshot(s));

  static Future<ValutaRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => ValutaRecord.fromSnapshot(s));

  static ValutaRecord fromSnapshot(DocumentSnapshot snapshot) => ValutaRecord._(
        snapshot.reference,
        mapFromFirestore(Map<String, dynamic>.from(snapshot.data() as Map)),
      );

  static ValutaRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      ValutaRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'ValutaRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is ValutaRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createValutaRecordData({
  String? kod,
  String? title,
  String? simvol,
  String? countryCode,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'kod': kod,
      'title': title,
      'simvol': simvol,
      'country_code': countryCode,
      'countryCode': countryCode,
    }.withoutNulls,
  );

  return firestoreData;
}

class ValutaRecordDocumentEquality implements Equality<ValutaRecord> {
  const ValutaRecordDocumentEquality();

  @override
  bool equals(ValutaRecord? e1, ValutaRecord? e2) {
    return e1?.kod == e2?.kod &&
        e1?.title == e2?.title &&
        e1?.simvol == e2?.simvol &&
        e1?.countryCode == e2?.countryCode;
  }

  @override
  int hash(ValutaRecord? e) =>
      const ListEquality().hash([e?.kod, e?.title, e?.simvol, e?.countryCode]);

  @override
  bool isValidKey(Object? o) => o is ValutaRecord;
}

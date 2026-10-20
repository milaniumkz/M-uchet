import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class CountryRecord extends FirestoreRecord {
  CountryRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "title" field.
  String? _title;
  String get title => _title ?? '';
  bool hasTitle() => _title != null;

  // "valuta" field.
  String? _valuta;
  String get valuta => _valuta ?? '';
  bool hasValuta() => _valuta != null;

  // "znak" field.
  String? _znak;
  String get znak => _znak ?? '';
  bool hasZnak() => _znak != null;

  // "country_code" field.
  String? _countryCode;
  String get countryCode => _countryCode ?? '';
  bool hasCountryCode() => _countryCode != null;

  void _initializeFields() {
    _title = snapshotData['title'] as String?;
    _valuta = snapshotData['valuta'] as String?;
    _znak = snapshotData['znak'] as String?;
    _countryCode = (snapshotData['country_code'] ?? snapshotData['countryCode'])
        as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('country');

  static Stream<CountryRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => CountryRecord.fromSnapshot(s));

  static Future<CountryRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => CountryRecord.fromSnapshot(s));

  static CountryRecord fromSnapshot(DocumentSnapshot snapshot) =>
      CountryRecord._(
        snapshot.reference,
        mapFromFirestore(Map<String, dynamic>.from(snapshot.data() as Map)),
      );

  static CountryRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      CountryRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'CountryRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is CountryRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createCountryRecordData({
  String? title,
  String? valuta,
  String? znak,
  String? countryCode,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'title': title,
      'valuta': valuta,
      'znak': znak,
      'country_code': countryCode,
      'countryCode': countryCode,
    }.withoutNulls,
  );

  return firestoreData;
}

class CountryRecordDocumentEquality implements Equality<CountryRecord> {
  const CountryRecordDocumentEquality();

  @override
  bool equals(CountryRecord? e1, CountryRecord? e2) {
    return e1?.title == e2?.title &&
        e1?.valuta == e2?.valuta &&
        e1?.znak == e2?.znak &&
        e1?.countryCode == e2?.countryCode;
  }

  @override
  int hash(CountryRecord? e) =>
      const ListEquality().hash([e?.title, e?.valuta, e?.znak, e?.countryCode]);

  @override
  bool isValidKey(Object? o) => o is CountryRecord;
}

import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class OtrasliRecord extends FirestoreRecord {
  OtrasliRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "title" field.
  String? _title;
  String get title => _title ?? '';
  bool hasTitle() => _title != null;

  // "oced" field.
  List<String>? _oced;
  List<String> get oced => _oced ?? const [];
  bool hasOced() => _oced != null;

  // "country" field.
  String? _country;
  String get country => _country ?? '';
  bool hasCountry() => _country != null;

  // "country_code" field.
  String? _countryCode;
  String get countryCode => _countryCode ?? '';
  bool hasCountryCode() => _countryCode != null;

  void _initializeFields() {
    _title = snapshotData['title'] as String?;
    _oced = getDataList(snapshotData['oced']);
    _country = snapshotData['country'] as String?;
    _countryCode = (snapshotData['country_code'] ?? snapshotData['countryCode'])
        as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('otrasli');

  static Stream<OtrasliRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => OtrasliRecord.fromSnapshot(s));

  static Future<OtrasliRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => OtrasliRecord.fromSnapshot(s));

  static OtrasliRecord fromSnapshot(DocumentSnapshot snapshot) =>
      OtrasliRecord._(
        snapshot.reference,
        mapFromFirestore(Map<String, dynamic>.from(snapshot.data() as Map)),
      );

  static OtrasliRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      OtrasliRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'OtrasliRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is OtrasliRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createOtrasliRecordData({
  String? title,
  String? country,
  String? countryCode,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'title': title,
      'country': country,
      'country_code': countryCode,
      'countryCode': countryCode,
    }.withoutNulls,
  );

  return firestoreData;
}

class OtrasliRecordDocumentEquality implements Equality<OtrasliRecord> {
  const OtrasliRecordDocumentEquality();

  @override
  bool equals(OtrasliRecord? e1, OtrasliRecord? e2) {
    const listEquality = ListEquality();
    return e1?.title == e2?.title &&
        listEquality.equals(e1?.oced, e2?.oced) &&
        e1?.country == e2?.country &&
        e1?.countryCode == e2?.countryCode;
  }

  @override
  int hash(OtrasliRecord? e) => const ListEquality()
      .hash([e?.title, e?.oced, e?.country, e?.countryCode]);

  @override
  bool isValidKey(Object? o) => o is OtrasliRecord;
}

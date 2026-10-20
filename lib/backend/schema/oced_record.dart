import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class OcedRecord extends FirestoreRecord {
  OcedRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "title" field.
  String? _title;
  String get title => _title ?? '';
  bool hasTitle() => _title != null;

  // "kod" field.
  String? _kod;
  String get kod => _kod ?? '';
  bool hasKod() => _kod != null;

  // "section" field.
  String? _section;
  String get section => _section ?? '';
  bool hasSection() => _section != null;

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
    _kod = snapshotData['kod'] as String?;
    _section = snapshotData['section'] as String?;
    _country = snapshotData['country'] as String?;
    _countryCode = (snapshotData['country_code'] ?? snapshotData['countryCode'])
        as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('oced');

  static Stream<OcedRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => OcedRecord.fromSnapshot(s));

  static Future<OcedRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => OcedRecord.fromSnapshot(s));

  static OcedRecord fromSnapshot(DocumentSnapshot snapshot) => OcedRecord._(
        snapshot.reference,
        mapFromFirestore(Map<String, dynamic>.from(snapshot.data() as Map)),
      );

  static OcedRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      OcedRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'OcedRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is OcedRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createOcedRecordData({
  String? title,
  String? kod,
  String? section,
  String? country,
  String? countryCode,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'title': title,
      'kod': kod,
      'section': section,
      'country': country,
      'country_code': countryCode,
      'countryCode': countryCode,
    }.withoutNulls,
  );

  return firestoreData;
}

class OcedRecordDocumentEquality implements Equality<OcedRecord> {
  const OcedRecordDocumentEquality();

  @override
  bool equals(OcedRecord? e1, OcedRecord? e2) {
    return e1?.title == e2?.title &&
        e1?.kod == e2?.kod &&
        e1?.section == e2?.section &&
        e1?.country == e2?.country &&
        e1?.countryCode == e2?.countryCode;
  }

  @override
  int hash(OcedRecord? e) => const ListEquality()
      .hash([e?.title, e?.kod, e?.section, e?.country, e?.countryCode]);

  @override
  bool isValidKey(Object? o) => o is OcedRecord;
}

import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class FormaRecord extends FirestoreRecord {
  FormaRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "title" field.
  String? _title;
  String get title => _title ?? '';
  bool hasTitle() => _title != null;

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
    _country = snapshotData['country'] as String?;
    _countryCode = (snapshotData['country_code'] ?? snapshotData['countryCode'])
        as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('forma');

  static Stream<FormaRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => FormaRecord.fromSnapshot(s));

  static Future<FormaRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => FormaRecord.fromSnapshot(s));

  static FormaRecord fromSnapshot(DocumentSnapshot snapshot) => FormaRecord._(
        snapshot.reference,
        mapFromFirestore(Map<String, dynamic>.from(snapshot.data() as Map)),
      );

  static FormaRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      FormaRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'FormaRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is FormaRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createFormaRecordData({
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

class FormaRecordDocumentEquality implements Equality<FormaRecord> {
  const FormaRecordDocumentEquality();

  @override
  bool equals(FormaRecord? e1, FormaRecord? e2) {
    return e1?.title == e2?.title &&
        e1?.country == e2?.country &&
        e1?.countryCode == e2?.countryCode;
  }

  @override
  int hash(FormaRecord? e) =>
      const ListEquality().hash([e?.title, e?.country, e?.countryCode]);

  @override
  bool isValidKey(Object? o) => o is FormaRecord;
}

import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class NalogiRecord extends FirestoreRecord {
  NalogiRecord._(
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

  // "country" field.
  String? _country;
  String get country => _country ?? '';
  bool hasCountry() => _country != null;

  // "procent" field.
  String? _procent;
  String get procent => _procent ?? '';
  bool hasProcent() => _procent != null;

  // "country_code" field.
  String? _countryCode;
  String get countryCode => _countryCode ?? '';
  bool hasCountryCode() => _countryCode != null;

  void _initializeFields() {
    _title = snapshotData['title'] as String?;
    _kod = snapshotData['kod'] as String?;
    _country = snapshotData['country'] as String?;
    _procent = snapshotData['procent'] as String?;
    _countryCode = (snapshotData['country_code'] ?? snapshotData['countryCode'])
        as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('nalogi');

  static Stream<NalogiRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => NalogiRecord.fromSnapshot(s));

  static Future<NalogiRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => NalogiRecord.fromSnapshot(s));

  static NalogiRecord fromSnapshot(DocumentSnapshot snapshot) => NalogiRecord._(
        snapshot.reference,
        mapFromFirestore(Map<String, dynamic>.from(snapshot.data() as Map)),
      );

  static NalogiRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      NalogiRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'NalogiRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is NalogiRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createNalogiRecordData({
  String? title,
  String? kod,
  String? country,
  String? procent,
  String? countryCode,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'title': title,
      'kod': kod,
      'country': country,
      'procent': procent,
      'country_code': countryCode,
      'countryCode': countryCode,
    }.withoutNulls,
  );

  return firestoreData;
}

class NalogiRecordDocumentEquality implements Equality<NalogiRecord> {
  const NalogiRecordDocumentEquality();

  @override
  bool equals(NalogiRecord? e1, NalogiRecord? e2) {
    return e1?.title == e2?.title &&
        e1?.kod == e2?.kod &&
        e1?.country == e2?.country &&
        e1?.procent == e2?.procent &&
        e1?.countryCode == e2?.countryCode;
  }

  @override
  int hash(NalogiRecord? e) => const ListEquality()
      .hash([e?.title, e?.kod, e?.country, e?.procent, e?.countryCode]);

  @override
  bool isValidKey(Object? o) => o is NalogiRecord;
}

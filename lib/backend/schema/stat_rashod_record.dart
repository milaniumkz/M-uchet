import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class StatRashodRecord extends FirestoreRecord {
  StatRashodRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "title" field.
  String? _title;
  String get title => _title ?? '';
  bool hasTitle() => _title != null;

  // "type" field.
  String? _type;
  String get type => _type ?? '';
  bool hasType() => _type != null;

  // "text" field.
  String? _text;
  String get text => _text ?? '';
  bool hasText() => _text != null;

  // "summa" field.
  double? _summa;
  double get summa => _summa ?? 0.0;
  bool hasSumma() => _summa != null;

  // "color" field.
  Color? _color;
  Color? get color => _color;
  bool hasColor() => _color != null;

  // "idCompany" field.
  String? _idCompany;
  String get idCompany => _idCompany ?? '';
  bool hasIdCompany() => _idCompany != null;

  void _initializeFields() {
    _title = snapshotData['title'] as String?;
    _type = snapshotData['type'] as String?;
    _text = snapshotData['text'] as String?;
    _summa = castToType<double>(snapshotData['summa']);
    _color = getSchemaColor(snapshotData['color']);
    _idCompany = snapshotData['idCompany'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('statRashod');

  static Stream<StatRashodRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => StatRashodRecord.fromSnapshot(s));

  static Future<StatRashodRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => StatRashodRecord.fromSnapshot(s));

  static StatRashodRecord fromSnapshot(DocumentSnapshot snapshot) =>
      StatRashodRecord._(
        snapshot.reference,
        mapFromFirestore(Map<String, dynamic>.from(snapshot.data() as Map)),
      );

  static StatRashodRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      StatRashodRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'StatRashodRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is StatRashodRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createStatRashodRecordData({
  String? title,
  String? type,
  String? text,
  double? summa,
  Color? color,
  String? idCompany,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'title': title,
      'type': type,
      'text': text,
      'summa': summa,
      'color': color,
      'idCompany': idCompany,
    }.withoutNulls,
  );

  return firestoreData;
}

class StatRashodRecordDocumentEquality implements Equality<StatRashodRecord> {
  const StatRashodRecordDocumentEquality();

  @override
  bool equals(StatRashodRecord? e1, StatRashodRecord? e2) {
    return e1?.title == e2?.title &&
        e1?.type == e2?.type &&
        e1?.text == e2?.text &&
        e1?.summa == e2?.summa &&
        e1?.color == e2?.color &&
        e1?.idCompany == e2?.idCompany;
  }

  @override
  int hash(StatRashodRecord? e) => const ListEquality()
      .hash([e?.title, e?.type, e?.text, e?.summa, e?.color, e?.idCompany]);

  @override
  bool isValidKey(Object? o) => o is StatRashodRecord;
}

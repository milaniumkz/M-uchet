import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class UsersRecord extends FirestoreRecord {
  UsersRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "email" field.
  String? _email;
  String get email => _email ?? '';
  bool hasEmail() => _email != null;

  // "display_name" field.
  String? _displayName;
  String get displayName => _displayName ?? '';
  bool hasDisplayName() => _displayName != null;

  // "photo_url" field.
  String? _photoUrl;
  String get photoUrl => _photoUrl ?? '';
  bool hasPhotoUrl() => _photoUrl != null;

  // "uid" field.
  String? _uid;
  String get uid => _uid ?? '';
  bool hasUid() => _uid != null;

  // "created_time" field.
  DateTime? _createdTime;
  DateTime? get createdTime => _createdTime;
  bool hasCreatedTime() => _createdTime != null;

  // "phone_number" field.
  String? _phoneNumber;
  String get phoneNumber => _phoneNumber ?? '';
  bool hasPhoneNumber() => _phoneNumber != null;

  // "password" field.
  String? _password;
  String get password => _password ?? '';
  bool hasPassword() => _password != null;

  // "role" field.
  String? _role;
  String get role => _role ?? '';
  bool hasRole() => _role != null;

  // "country" field.
  String? _country;
  String get country => _country ?? '';
  bool hasCountry() => _country != null;

  // "otrasl" field.
  String? _otrasl;
  String get otrasl => _otrasl ?? '';
  bool hasOtrasl() => _otrasl != null;

  // "tip" field.
  String? _tip;
  String get tip => _tip ?? '';
  bool hasTip() => _tip != null;

  // "nalog" field.
  String? _nalog;
  String get nalog => _nalog ?? '';
  bool hasNalog() => _nalog != null;

  // "buh" field.
  bool? _buh;
  bool get buh => _buh ?? false;
  bool hasBuh() => _buh != null;

  // "bloc" field.
  bool? _bloc;
  bool get bloc => _bloc ?? false;
  bool hasBloc() => _bloc != null;

  // "name_Company" field.
  String? _nameCompany;
  String get nameCompany => _nameCompany ?? '';
  bool hasNameCompany() => _nameCompany != null;

  // "bin" field.
  String? _bin;
  String get bin => _bin ?? '';
  bool hasBin() => _bin != null;

  // "adres" field.
  String? _adres;
  String get adres => _adres ?? '';
  bool hasAdres() => _adres != null;

  // "aced" field.
  List<String>? _aced;
  List<String> get aced => _aced ?? const [];
  bool hasAced() => _aced != null;

  // "nds" field.
  bool? _nds;
  bool get nds => _nds ?? false;
  bool hasNds() => _nds != null;

  // "pin" field.
  String? _pin;
  String get pin => _pin ?? '';
  bool hasPin() => _pin != null;

  // "idCompany" field.
  String? _idCompany;
  String get idCompany => _idCompany ?? '';
  bool hasIdCompany() => _idCompany != null;

  // "activeCompanyId" field.
  String? _activeCompanyId;
  String get activeCompanyId => _activeCompanyId ?? '';
  bool hasActiveCompanyId() => _activeCompanyId != null;

  // "companyIds" field.
  List<String>? _companyIds;
  List<String> get companyIds => _companyIds ?? const [];
  bool hasCompanyIds() => _companyIds != null;

  void _initializeFields() {
    _email = snapshotData['email'] as String?;
    _displayName = snapshotData['display_name'] as String?;
    _photoUrl = snapshotData['photo_url'] as String?;
    _uid = snapshotData['uid'] as String?;
    _createdTime = snapshotData['created_time'] as DateTime?;
    _phoneNumber = snapshotData['phone_number'] as String?;
    _password = snapshotData['password'] as String?;
    _role = snapshotData['role'] as String?;
    _country = snapshotData['country'] as String?;
    _otrasl = snapshotData['otrasl'] as String?;
    _tip = snapshotData['tip'] as String?;
    _nalog = snapshotData['nalog'] as String?;
    _buh = snapshotData['buh'] as bool?;
    _bloc = snapshotData['bloc'] as bool?;
    _nameCompany = snapshotData['name_Company'] as String?;
    _bin = snapshotData['bin'] as String?;
    _adres = snapshotData['adres'] as String?;
    _aced = getDataList(snapshotData['aced']);
    _nds = snapshotData['nds'] as bool?;
    _pin = snapshotData['pin'] as String?;
    _idCompany = snapshotData['idCompany'] as String?;
    _activeCompanyId = snapshotData['activeCompanyId'] as String?;
    _companyIds = getDataList(snapshotData['companyIds']);
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('users');

  static Stream<UsersRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => UsersRecord.fromSnapshot(s));

  static Future<UsersRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => UsersRecord.fromSnapshot(s));

  static UsersRecord fromSnapshot(DocumentSnapshot snapshot) => UsersRecord._(
        snapshot.reference,
        mapFromFirestore(Map<String, dynamic>.from(snapshot.data() as Map)),
      );

  static UsersRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      UsersRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'UsersRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is UsersRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createUsersRecordData({
  String? email,
  String? displayName,
  String? photoUrl,
  String? uid,
  DateTime? createdTime,
  String? phoneNumber,
  String? password,
  String? role,
  String? country,
  String? otrasl,
  String? tip,
  String? nalog,
  bool? buh,
  bool? bloc,
  String? nameCompany,
  String? bin,
  String? adres,
  bool? nds,
  String? pin,
  String? idCompany,
  String? activeCompanyId,
  List<String>? companyIds,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'email': email,
      'display_name': displayName,
      'photo_url': photoUrl,
      'uid': uid,
      'created_time': createdTime,
      'phone_number': phoneNumber,
      'password': password,
      'role': role,
      'country': country,
      'otrasl': otrasl,
      'tip': tip,
      'nalog': nalog,
      'buh': buh,
      'bloc': bloc,
      'name_Company': nameCompany,
      'bin': bin,
      'adres': adres,
      'nds': nds,
      'pin': pin,
      'idCompany': idCompany,
      'activeCompanyId': activeCompanyId,
      'companyIds': companyIds,
    }.withoutNulls,
  );

  return firestoreData;
}

class UsersRecordDocumentEquality implements Equality<UsersRecord> {
  const UsersRecordDocumentEquality();

  @override
  bool equals(UsersRecord? e1, UsersRecord? e2) {
    const listEquality = ListEquality();
    return e1?.email == e2?.email &&
        e1?.displayName == e2?.displayName &&
        e1?.photoUrl == e2?.photoUrl &&
        e1?.uid == e2?.uid &&
        e1?.createdTime == e2?.createdTime &&
        e1?.phoneNumber == e2?.phoneNumber &&
        e1?.password == e2?.password &&
        e1?.role == e2?.role &&
        e1?.country == e2?.country &&
        e1?.otrasl == e2?.otrasl &&
        e1?.tip == e2?.tip &&
        e1?.nalog == e2?.nalog &&
        e1?.buh == e2?.buh &&
        e1?.bloc == e2?.bloc &&
        e1?.nameCompany == e2?.nameCompany &&
        e1?.bin == e2?.bin &&
        e1?.adres == e2?.adres &&
        listEquality.equals(e1?.aced, e2?.aced) &&
        e1?.nds == e2?.nds &&
        e1?.pin == e2?.pin &&
        e1?.idCompany == e2?.idCompany &&
        e1?.activeCompanyId == e2?.activeCompanyId &&
        listEquality.equals(e1?.companyIds, e2?.companyIds);
  }

  @override
  int hash(UsersRecord? e) => const ListEquality().hash([
        e?.email,
        e?.displayName,
        e?.photoUrl,
        e?.uid,
        e?.createdTime,
        e?.phoneNumber,
        e?.password,
        e?.role,
        e?.country,
        e?.otrasl,
        e?.tip,
        e?.nalog,
        e?.buh,
        e?.bloc,
        e?.nameCompany,
        e?.bin,
        e?.adres,
        e?.aced,
        e?.nds,
        e?.pin,
        e?.idCompany,
        e?.activeCompanyId,
        e?.companyIds
      ]);

  @override
  bool isValidKey(Object? o) => o is UsersRecord;
}

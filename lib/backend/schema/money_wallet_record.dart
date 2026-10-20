import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/utils/ledger_scope.dart';
import '/utils/money_wallet_types.dart';

class MoneyWalletRecord extends FirestoreRecord {
  MoneyWalletRecord._(
    super.reference,
    super.data,
  ) {
    _initializeFields();
  }

  String? _name;
  String get name => _name ?? '';
  bool hasName() => _name != null;

  String? _type;
  String get type => _type ?? '';
  bool hasType() => _type != null;
  WalletType get walletType => walletTypeFromValue(_type);

  String? _ledgerScope;
  String get ledgerScope => _ledgerScope ?? '';
  bool hasLedgerScope() => _ledgerScope != null;
  LedgerScope get ledgerScopeEnum => ledgerScopeFromLegacyValue(_ledgerScope);

  String? _currency;
  String get currency => _currency ?? 'KZT';
  bool hasCurrency() => _currency != null;

  bool? _isActive;
  bool get isActive => _isActive ?? true;
  bool hasIsActive() => _isActive != null;

  double? _openingBalance;
  double get openingBalance => _openingBalance ?? 0.0;
  bool hasOpeningBalance() => _openingBalance != null;

  double? _currentBalance;
  double get currentBalance => _currentBalance ?? 0.0;
  bool hasCurrentBalance() => _currentBalance != null;

  String? _ownerType;
  String get ownerType => _ownerType ?? '';
  bool hasOwnerType() => _ownerType != null;

  String? _ownerId;
  String get ownerId => _ownerId ?? '';
  bool hasOwnerId() => _ownerId != null;

  String? _linkedLegacyAccountId;
  String get linkedLegacyAccountId => _linkedLegacyAccountId ?? '';
  bool hasLinkedLegacyAccountId() => _linkedLegacyAccountId != null;

  String? _linkedLegacyCashboxId;
  String get linkedLegacyCashboxId => _linkedLegacyCashboxId ?? '';
  bool hasLinkedLegacyCashboxId() => _linkedLegacyCashboxId != null;

  String? _linkedLegacyCardId;
  String get linkedLegacyCardId => _linkedLegacyCardId ?? '';
  bool hasLinkedLegacyCardId() => _linkedLegacyCardId != null;

  String? _legacySourceKey;
  String get legacySourceKey => _legacySourceKey ?? '';
  bool hasLegacySourceKey() => _legacySourceKey != null;

  String? _description;
  String get description => _description ?? '';
  bool hasDescription() => _description != null;

  String? _idCompany;
  String get idCompany => _idCompany ?? '';
  bool hasIdCompany() => _idCompany != null;

  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  DateTime? _updatedAt;
  DateTime? get updatedAt => _updatedAt;
  bool hasUpdatedAt() => _updatedAt != null;

  void _initializeFields() {
    _name = _asString(snapshotData['name']);
    _type = _asString(snapshotData['type']);
    _ledgerScope = _asString(
      snapshotData['ledger_scope'] ?? snapshotData['ledgerScope'],
    );
    _currency = _asString(snapshotData['currency']);
    _isActive = _asBool(
      snapshotData['is_active'] ?? snapshotData['isActive'],
    );
    _openingBalance = _asDouble(
      snapshotData['opening_balance'] ?? snapshotData['openingBalance'],
    );
    _currentBalance = _asDouble(
      snapshotData['current_balance'] ?? snapshotData['currentBalance'],
    );
    _ownerType =
        _asString(snapshotData['owner_type'] ?? snapshotData['ownerType']);
    _ownerId = _asString(snapshotData['owner_id'] ?? snapshotData['ownerId']);
    _linkedLegacyAccountId = _asString(
      snapshotData['linked_legacy_account_id'] ??
          snapshotData['linkedLegacyAccountId'],
    );
    _linkedLegacyCashboxId = _asString(
      snapshotData['linked_legacy_cashbox_id'] ??
          snapshotData['linkedLegacyCashboxId'],
    );
    _linkedLegacyCardId = _asString(
      snapshotData['linked_legacy_card_id'] ??
          snapshotData['linkedLegacyCardId'],
    );
    _legacySourceKey = _asString(
      snapshotData['legacy_source_key'] ?? snapshotData['legacySourceKey'],
    );
    _description =
        _asString(snapshotData['description'] ?? snapshotData['notes']);
    _idCompany = _asString(snapshotData['idCompany']);
    _createdAt = _asDateTime(snapshotData['created_at']);
    _updatedAt = _asDateTime(snapshotData['updated_at']);
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('money_wallets');

  static String? _asString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  static bool? _asBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final raw = value.toString().trim().toLowerCase();
    if (raw == 'true' || raw == '1' || raw == 'yes') return true;
    if (raw == 'false' || raw == '0' || raw == 'no') return false;
    return null;
  }

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      final normalized = value.trim().replaceAll(' ', '').replaceAll(',', '.');
      return double.tryParse(normalized);
    }
    return null;
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static Stream<MoneyWalletRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => MoneyWalletRecord.fromSnapshot(s));

  static Future<MoneyWalletRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => MoneyWalletRecord.fromSnapshot(s));

  static MoneyWalletRecord fromSnapshot(DocumentSnapshot snapshot) =>
      MoneyWalletRecord._(
        snapshot.reference,
        mapFromFirestore(Map<String, dynamic>.from(snapshot.data() as Map)),
      );

  static MoneyWalletRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      MoneyWalletRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'MoneyWalletRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is MoneyWalletRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createMoneyWalletRecordData({
  String? name,
  String? type,
  String? ledgerScope,
  String? currency,
  bool? isActive,
  double? openingBalance,
  double? currentBalance,
  String? ownerType,
  String? ownerId,
  String? linkedLegacyAccountId,
  String? linkedLegacyCashboxId,
  String? linkedLegacyCardId,
  String? legacySourceKey,
  String? description,
  String? idCompany,
  dynamic createdAt,
  dynamic updatedAt,
}) {
  return mapToFirestore(
    <String, dynamic>{
      'name': name,
      'type': type,
      'ledger_scope': ledgerScope,
      'ledgerScope': ledgerScope,
      'currency': currency,
      'is_active': isActive,
      'isActive': isActive,
      'opening_balance': openingBalance,
      'openingBalance': openingBalance,
      'current_balance': currentBalance,
      'currentBalance': currentBalance,
      'owner_type': ownerType,
      'ownerType': ownerType,
      'owner_id': ownerId,
      'ownerId': ownerId,
      'linked_legacy_account_id': linkedLegacyAccountId,
      'linkedLegacyAccountId': linkedLegacyAccountId,
      'linked_legacy_cashbox_id': linkedLegacyCashboxId,
      'linkedLegacyCashboxId': linkedLegacyCashboxId,
      'linked_legacy_card_id': linkedLegacyCardId,
      'linkedLegacyCardId': linkedLegacyCardId,
      'legacy_source_key': legacySourceKey,
      'legacySourceKey': legacySourceKey,
      'description': description,
      'notes': description,
      'idCompany': idCompany,
      'created_at': createdAt,
      'updated_at': updatedAt,
    }.withoutNulls,
  );
}

class MoneyWalletRecordDocumentEquality implements Equality<MoneyWalletRecord> {
  const MoneyWalletRecordDocumentEquality();

  @override
  bool equals(MoneyWalletRecord? e1, MoneyWalletRecord? e2) {
    return e1?.name == e2?.name &&
        e1?.type == e2?.type &&
        e1?.ledgerScope == e2?.ledgerScope &&
        e1?.currency == e2?.currency &&
        e1?.isActive == e2?.isActive &&
        e1?.openingBalance == e2?.openingBalance &&
        e1?.currentBalance == e2?.currentBalance &&
        e1?.ownerType == e2?.ownerType &&
        e1?.ownerId == e2?.ownerId &&
        e1?.linkedLegacyAccountId == e2?.linkedLegacyAccountId &&
        e1?.linkedLegacyCashboxId == e2?.linkedLegacyCashboxId &&
        e1?.linkedLegacyCardId == e2?.linkedLegacyCardId &&
        e1?.legacySourceKey == e2?.legacySourceKey &&
        e1?.description == e2?.description &&
        e1?.idCompany == e2?.idCompany;
  }

  @override
  int hash(MoneyWalletRecord? e) => const ListEquality().hash([
        e?.name,
        e?.type,
        e?.ledgerScope,
        e?.currency,
        e?.isActive,
        e?.openingBalance,
        e?.currentBalance,
        e?.ownerType,
        e?.ownerId,
        e?.linkedLegacyAccountId,
        e?.linkedLegacyCashboxId,
        e?.linkedLegacyCardId,
        e?.legacySourceKey,
        e?.description,
        e?.idCompany,
      ]);

  @override
  bool isValidKey(Object? o) => o is MoneyWalletRecord;
}

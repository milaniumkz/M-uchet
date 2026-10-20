import 'dart:math';

import '/backend/firestore_cache.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ledger_scope.dart';

const defaultNomenclatureCategories = ['Товары', 'Материалы'];
const officialVatRate = 0.16;

const sourceTypeManual = 'manual';
const sourceTypeOneC = '1c';
const sourceTypeExcel = 'excel';

const _articleCharset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
const _articleLength = 8;
final _articleRandom = Random();

String randomArticleCode() {
  return List.generate(
    _articleLength,
    (_) => _articleCharset[_articleRandom.nextInt(_articleCharset.length)],
  ).join();
}

Future<bool> articleExistsForCompany(
  FirebaseFirestore firestore,
  String companyId,
  String article, {
  required String warehouse,
}) async {
  final trimmed = article.trim();
  if (trimmed.isEmpty || companyId.trim().isEmpty) return false;
  final snap = await firestore
      .collection('nomenklatura')
      .where('idCompany', isEqualTo: companyId.trim())
      .where('sku', isEqualTo: trimmed)
      .get();
  if (snap.docs.isEmpty) return false;
  final targetType = warehouseTypeFromLegacy(warehouse: warehouse);
  for (final doc in snap.docs) {
    final data = doc.data();
    final docType = warehouseTypeFromData(data);
    if (docType == targetType) {
      return true;
    }
  }
  return false;
}

Future<DocumentSnapshot<Object?>?> findProductByArticleForCompany(
  FirebaseFirestore firestore,
  String companyId,
  String article, {
  String? warehouse,
}) async {
  final trimmed = article.trim();
  if (companyId.trim().isEmpty || trimmed.isEmpty) return null;
  final snap = await firestore
      .collection('nomenklatura')
      .where('idCompany', isEqualTo: companyId)
      .where('sku', isEqualTo: trimmed)
      .getCached();
  return pickByWarehouseContour(snap, warehouse ?? '');
}

Future<String?> generateUniqueArticleCode(
  FirebaseFirestore firestore,
  String companyId, {
  required String warehouse,
}) async {
  const attempts = 6;
  for (var i = 0; i < attempts; i++) {
    final candidate = randomArticleCode();
    if (!await articleExistsForCompany(
      firestore,
      companyId,
      candidate,
      warehouse: warehouse,
    )) {
      return candidate;
    }
  }
  return null;
}

Future<String?> warehouseParentByName(
  FirebaseFirestore firestore,
  String companyId,
  String warehouseName,
) async {
  final trimmedCompany = companyId.trim();
  final trimmedName = warehouseName.trim();
  if (trimmedCompany.isEmpty || trimmedName.isEmpty) return null;
  final snap = await firestore
      .collection('warehouses')
      .where('idCompany', isEqualTo: trimmedCompany)
      .where('name', isEqualTo: trimmedName)
      .limit(1)
      .get();
  if (snap.docs.isEmpty) return null;
  final data = snap.docs.first.data();
  final parent = (data['parentWarehouse'] ?? data['parent'] ?? '').toString();
  final trimmedParent = parent.trim();
  return trimmedParent.isEmpty ? null : trimmedParent;
}

double toNumFlexible(String value) {
  return double.tryParse(value.replaceAll(',', '.').trim()) ?? 0;
}

bool isOfficialWarehouseLabel(String value) {
  return warehouseTypeFromLegacy(warehouse: value).isOfficial;
}

String warehouseByAccountingMode(String typeUchet) {
  final scope = ledgerScopeFromLegacyValue(typeUchet);
  return scope == LedgerScope.accounting
      ? WarehouseType.official.bucketLabel
      : WarehouseType.unofficial.bucketLabel;
}

DocumentSnapshot<Object?>? pickByWarehouseContour(
  QuerySnapshot<Object?> snap,
  String warehouse,
) {
  if (snap.docs.isEmpty) return null;
  final targetType = warehouseTypeFromLegacy(warehouse: warehouse);
  for (final doc in snap.docs) {
    final raw = doc.data();
    final data = raw is Map<String, dynamic>
        ? raw
        : Map<String, dynamic>.from(raw as Map);
    final docType = warehouseTypeFromData(data);
    if (docType == targetType) {
      return doc;
    }
  }
  return null;
}

Map<String, dynamic> sourceMeta(String sourceType) {
  final normalized = sourceType.trim().toLowerCase();
  if (normalized == sourceTypeOneC) {
    return {
      'source_type': sourceTypeOneC,
      'source_label': 'Импорт из 1С',
      'source_mark': 'Импорт из 1С',
    };
  }
  if (normalized == sourceTypeExcel) {
    return {
      'source_type': sourceTypeExcel,
      'source_label': 'Импорт Excel',
      'source_mark': 'Импорт Excel',
    };
  }
  return {
    'source_type': sourceTypeManual,
    'source_label': 'Ручной ввод',
    'source_mark': '*',
  };
}

String productSourceShort(Map<String, dynamic> item) {
  final sourceType = (item['source_type'] ?? '').toString().toLowerCase();
  final sourceLabel = (item['source_label'] ?? '').toString().toLowerCase();
  final sourceMark = (item['source_mark'] ?? '').toString().toLowerCase();

  if (sourceType == sourceTypeOneC ||
      sourceType.contains('1c') ||
      sourceType.contains('1с') ||
      sourceLabel.contains('1с') ||
      sourceMark.contains('1с')) {
    return 'Импорт из 1С';
  }
  if (sourceType == sourceTypeExcel ||
      sourceType.contains('excel') ||
      sourceType.contains('csv') ||
      sourceType.contains('file') ||
      sourceLabel.contains('excel') ||
      sourceLabel.contains('csv') ||
      sourceMark.contains('excel')) {
    return 'Импорт Excel';
  }
  if (sourceType == sourceTypeManual ||
      sourceLabel.contains('ручной') ||
      sourceMark == '*') {
    return '*';
  }
  return '-';
}

String productSourceFull(Map<String, dynamic> item) {
  final short = productSourceShort(item);
  if (short == 'Импорт из 1С' || short == 'Импорт Excel') return short;
  if (short == '*') return '* Ручной ввод';
  return '-';
}

double markupCoeffFromPrices(
  String purchase,
  String sale, {
  String warehouse = '',
}) {
  final p = toNumFlexible(purchase);
  var s = toNumFlexible(sale);
  if (p <= 0 || s <= 0) return 0;
  if (isOfficialWarehouseLabel(warehouse)) {
    s = s / (1 + officialVatRate);
  }
  if (s <= 0) return 0;
  return s / p;
}

import '/backend/backend.dart';

bool isExcludedCompanyIncome(dynamic value) {
  final map = _map(value);
  if (_boolValue(
      value, ['exclude_from_company_income', 'excludeFromCompanyIncome'])) {
    return true;
  }
  final values = <String>[
    if (value is TranzactionRecord) value.kat else _str(map['kat']),
    if (value is TranzactionRecord) value.text else _str(map['text']),
    _str(map['category']),
    _str(map['category_title']),
    _str(map['category_name']),
    if (value is AccountingEntryRecord)
      '${value.description} ${value.creditAccountTitle}'
    else
      '${_str(map['description'])} ${_str(map['credit_account_title'])} ${_str(map['creditAccountTitle'])}',
  ];
  return values.any(looksLikeTaxRefund);
}

bool looksLikeTaxRefund(String value) {
  final normalized = value.trim().toLowerCase().replaceAll('ё', 'е');
  return normalized.contains('возврат налога') ||
      normalized.contains('возврат налогов');
}

bool isTaxRefundAccountId(String accountId) {
  return accountId.trim().startsWith('virtual:tax_refund:');
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is TranzactionRecord || value is AccountingEntryRecord) {
    return value.snapshotData;
  }
  return const <String, dynamic>{};
}

bool _boolValue(dynamic value, List<String> keys) {
  final map = _map(value);
  for (final key in keys) {
    final raw = map[key];
    if (raw is bool) return raw;
    final normalized = raw?.toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
  }
  return false;
}

String _str(dynamic value) => value?.toString().trim() ?? '';

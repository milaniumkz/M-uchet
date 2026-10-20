const String personalMoneySection = 'personal_money';
const String personalManualSource = 'manual';

String _stringValue(Map<String, dynamic> entry, String key) =>
    (entry[key] ?? '').toString().trim();

bool isPersonalMoneyEntry(Map<String, dynamic> entry) {
  final source = _stringValue(entry, 'source').toLowerCase();
  final scope = _stringValue(entry, 'scope').toLowerCase();
  final section = _stringValue(entry, 'section').toLowerCase();
  final entryScope = _stringValue(entry, 'entry_scope').toLowerCase();

  final isManualPersonal =
      source == personalManualSource && scope == 'personal';
  final isMarkedPersonalMoney =
      section == personalMoneySection || entryScope == personalMoneySection;
  if (!isManualPersonal && !isMarkedPersonalMoney) {
    return false;
  }

  final linkedCompanyFields = <String>[
    'tranzaction_id',
    'transaction_id',
    'source_transaction_id',
    'source_id',
    'schet_id',
    'schetId',
    'account_id',
    'accountId',
  ];
  return linkedCompanyFields.every((key) => _stringValue(entry, key).isEmpty);
}

List<Map<String, dynamic>> filterPersonalMoneyEntries(
  Iterable<Map<String, dynamic>> entries,
) =>
    entries.where(isPersonalMoneyEntry).toList();

import '/backend/backend.dart';
import '/utils/accounting_accounts.dart';
import '/utils/income_exclusion_support.dart';
import '/utils/ledger_scope.dart';
import '/utils/money_amount.dart';

class AccountingTaxSnapshot {
  const AccountingTaxSnapshot({
    required this.ndsAccrued,
    required this.ndsPayable,
    required this.kpnAccrued,
    required this.kpnPayable,
  });

  final double ndsAccrued;
  final double ndsPayable;
  final double kpnAccrued;
  final double kpnPayable;
}

AccountingTaxSnapshot computeTaxSnapshot({
  required Iterable<dynamic> sources,
  required String ledgerFilter,
  required double income,
  required double expense,
  required double ndsRate,
  required double kpnRate,
  bool Function(DateTime? date)? inPeriod,
}) {
  return computeTaxSnapshotForScope(
    sources: sources,
    ledgerScope: ledgerScopeFromLegacyValue(ledgerFilter),
    income: income,
    expense: expense,
    ndsRate: ndsRate,
    kpnRate: kpnRate,
    inPeriod: inPeriod,
  );
}

AccountingTaxSnapshot computeTaxSnapshotForScope({
  required Iterable<dynamic> sources,
  required LedgerScope ledgerScope,
  required double income,
  required double expense,
  required double ndsRate,
  required double kpnRate,
  bool Function(DateTime? date)? inPeriod,
}) {
  final normalizedNdsRate = _normalizedRate(ndsRate);
  final normalizedKpnRate = _normalizedRate(kpnRate);
  var outputVat = 0.0;
  var inputVat = 0.0;
  var taxableIncome = 0.0;
  var deductibleExpense = 0.0;
  var hasTaxBaseFlags = false;

  for (final item in sources) {
    if (!ledgerScope.matches(ledgerScopeFromLegacyValue(_ledgerScope(item)))) {
      continue;
    }
    if (inPeriod != null && !inPeriod(_date(item))) continue;
    final isIncome = _isIncomeSource(item);
    final isExpense = _isExpenseSource(item);
    final taxable = !isExcludedCompanyIncome(item) &&
        _isTaxableIncome(item, isIncome: isIncome);
    final deductible = _isDeductibleExpense(item, isExpense: isExpense);
    final vatTaxable = _isVatTaxableIncome(item);
    final vatDeductible = _isVatDeductibleExpense(item);
    hasTaxBaseFlags = hasTaxBaseFlags || _hasTaxBaseFlag(item);

    if (isIncome && taxable) {
      taxableIncome += _amount(item);
    }
    if (isExpense && deductible) {
      deductibleExpense += _amount(item);
    }

    if (!vatTaxable && !vatDeductible) continue;
    final taxAmount = _taxAmount(item, normalizedNdsRate);
    if (taxAmount <= 0) continue;
    final taxKind = _taxKind(item);
    final type = _type(item).toLowerCase().trim();
    if (vatTaxable &&
        (taxKind == 'vat_output' ||
            type == 'income' ||
            type == 'доход' ||
            type == 'doxod' ||
            isIncome)) {
      outputVat += taxAmount;
    } else if (vatDeductible &&
        (taxKind == 'vat_input' ||
            type == 'decome' ||
            type == 'expense' ||
            type == 'расход' ||
            type == 'rashod' ||
            isExpense)) {
      inputVat += taxAmount;
    }
  }

  final ndsPayable =
      (outputVat - inputVat).clamp(0, double.infinity).toDouble();
  final profitGross =
      hasTaxBaseFlags ? taxableIncome - deductibleExpense : income - expense;
  final kpnAccrued = (profitGross > 0 ? profitGross : 0) * normalizedKpnRate;

  return AccountingTaxSnapshot(
    ndsAccrued: outputVat,
    ndsPayable: ndsPayable,
    kpnAccrued: kpnAccrued,
    kpnPayable: kpnAccrued,
  );
}

double _normalizedRate(double rate) {
  if (rate <= 0) return 0;
  return rate > 1 ? rate / 100 : rate;
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

String _ledgerScope(dynamic tx) {
  if (tx is AccountingEntryRecord) return tx.ledgerScope;
  if (tx is TranzactionRecord) {
    return tx.ledgerScope.isNotEmpty ? tx.ledgerScope : tx.typeUchet;
  }
  final map = _map(tx);
  return (map['ledger_scope'] ?? map['ledgerScope'] ?? map['typeUchet'] ?? '')
      .toString();
}

DateTime? _date(dynamic tx) {
  if (tx is AccountingEntryRecord) return tx.entryDate;
  if (tx is TranzactionRecord) return tx.date;
  final map = _map(tx);
  final raw = map['entry_date'] ??
      map['date'] ??
      map['created_at'] ??
      map['updated_at'];
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw);
  return null;
}

bool _taxEnabled(dynamic tx) {
  if (tx is AccountingEntryRecord) {
    return tx.taxKind.trim().isNotEmpty || tx.taxAmount > 0;
  }
  if (tx is TranzactionRecord) return tx.nds;
  final map = _map(tx);
  return (map['tax_kind']?.toString().isNotEmpty == true) ||
      (map['tax_amount'] is num && (map['tax_amount'] as num).toDouble() > 0) ||
      map['nds'] == true;
}

bool _hasTaxBaseFlag(dynamic tx) {
  if (tx is AccountingEntryRecord) {
    return tx.snapshotData.containsKey('taxable') ||
        tx.snapshotData.containsKey('taxable_income') ||
        tx.snapshotData.containsKey('deductible') ||
        tx.snapshotData.containsKey('tax_deductible');
  }
  if (tx is TranzactionRecord) return tx.hasTaxable() || tx.hasDeductible();
  final map = _map(tx);
  return map.containsKey('taxable') ||
      map.containsKey('taxable_income') ||
      map.containsKey('deductible') ||
      map.containsKey('tax_deductible');
}

bool _isTaxableIncome(dynamic tx, {required bool isIncome}) {
  final explicit = _boolValue(tx, ['taxable', 'taxable_income']);
  if (explicit != null) return explicit;
  return isIncome;
}

bool _isDeductibleExpense(dynamic tx, {required bool isExpense}) {
  final explicit = _boolValue(tx, ['deductible', 'tax_deductible']);
  if (explicit != null) return explicit;
  return isExpense;
}

bool _isVatTaxableIncome(dynamic tx) {
  final explicit = _boolValue(tx, ['nds', 'vat_taxable', 'vatTaxable']);
  if (explicit != null) return explicit;
  return _taxEnabled(tx);
}

bool _isVatDeductibleExpense(dynamic tx) {
  final explicit = _boolValue(tx, [
    'vat_deductible',
    'vatDeductible',
    'nds_deductible',
    'ndsDeductible',
  ]);
  if (explicit != null) return explicit;
  if (tx is AccountingEntryRecord) {
    return tx.taxKind == 'vat_input' || tx.taxAmount > 0;
  }
  if (tx is Map<String, dynamic>) {
    final taxKind = (tx['tax_kind'] ?? tx['taxKind'] ?? '').toString().trim();
    if (taxKind == 'vat_input') return true;
  }
  return false;
}

bool? _boolValue(dynamic tx, List<String> keys) {
  dynamic value;
  if (tx is AccountingEntryRecord) {
    for (final key in keys) {
      if (tx.snapshotData.containsKey(key)) {
        value = tx.snapshotData[key];
        break;
      }
    }
  } else if (tx is TranzactionRecord) {
    for (final key in keys) {
      if (tx.snapshotData.containsKey(key)) {
        value = tx.snapshotData[key];
        break;
      }
    }
  } else {
    final map = _map(tx);
    for (final key in keys) {
      if (map.containsKey(key)) {
        value = map[key];
        break;
      }
    }
  }
  if (value == null) return null;
  if (value is bool) return value;
  final normalized = value.toString().trim().toLowerCase();
  if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
    return true;
  }
  if (normalized == 'false' || normalized == '0' || normalized == 'no') {
    return false;
  }
  return null;
}

bool _isIncomeSource(dynamic tx) {
  if (tx is AccountingEntryRecord) {
    return accountNatureForId(tx.creditAccountId) == AccountNature.income ||
        tx.taxKind == 'vat_output';
  }
  if (tx is TranzactionRecord) {
    final type = tx.type.toLowerCase().trim();
    return type == 'income' || type == 'доход' || type == 'doxod';
  }
  final map = _map(tx);
  final type = (map['type'] ?? '').toString().toLowerCase().trim();
  final creditId =
      (map['credit_account_id'] ?? map['creditAccountId'] ?? '').toString();
  return type == 'income' ||
      type == 'доход' ||
      type == 'doxod' ||
      accountNatureForId(creditId) == AccountNature.income ||
      (map['tax_kind'] ?? '').toString() == 'vat_output';
}

bool _isExpenseSource(dynamic tx) {
  if (tx is AccountingEntryRecord) {
    return accountNatureForId(tx.debitAccountId) == AccountNature.expense ||
        tx.taxKind == 'vat_input';
  }
  if (tx is TranzactionRecord) {
    final type = tx.type.toLowerCase().trim();
    return type == 'decome' ||
        type == 'expense' ||
        type == 'расход' ||
        type == 'rashod';
  }
  final map = _map(tx);
  final type = (map['type'] ?? '').toString().toLowerCase().trim();
  final debitId =
      (map['debit_account_id'] ?? map['debitAccountId'] ?? '').toString();
  return type == 'decome' ||
      type == 'expense' ||
      type == 'расход' ||
      type == 'rashod' ||
      accountNatureForId(debitId) == AccountNature.expense ||
      (map['tax_kind'] ?? '').toString() == 'vat_input';
}

String _type(dynamic tx) {
  if (tx is AccountingEntryRecord) return tx.sourceType;
  if (tx is TranzactionRecord) return tx.type;
  return (_map(tx)['type'] ?? '').toString();
}

double _summa(dynamic tx) {
  if (tx is AccountingEntryRecord) return tx.amount;
  if (tx is TranzactionRecord) return tx.amountCompany;
  final map = _map(tx);
  final value = map['amount_company'] ?? map['amountCompany'] ?? map['summa'];
  return value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
}

double _amount(dynamic tx) {
  if (tx is AccountingEntryRecord) return tx.amount;
  if (tx is TranzactionRecord) return tx.amountCompany;
  final map = _map(tx);
  return companyAmountFromData(map);
}

String _taxKind(dynamic tx) {
  if (tx is AccountingEntryRecord) return tx.taxKind;
  final map = _map(tx);
  if ((map['tax_kind'] ?? '').toString().isNotEmpty) {
    return (map['tax_kind'] ?? '').toString();
  }
  final type = (map['type'] ?? '').toString().toLowerCase().trim();
  if (type == 'income' || type == 'доход' || type == 'doxod') {
    return 'vat_output';
  }
  return 'vat_input';
}

double _taxAmount(dynamic tx, double fallbackRate) {
  if (tx is AccountingEntryRecord) {
    if (tx.taxAmount > 0) return tx.taxAmount;
    return tx.amount * (tx.taxRate > 0 ? tx.taxRate : fallbackRate);
  }
  if (tx is TranzactionRecord) {
    if (tx.summaNds > 0) return tx.summaNds;
    return tx.amountCompany * (tx.taxRate > 0 ? tx.taxRate : fallbackRate);
  }
  final map = _map(tx);
  final explicit = map['tax_amount'];
  if (explicit is num && explicit.toDouble() > 0) return explicit.toDouble();
  final old = map['summaNds'];
  if (old is num && old.toDouble() > 0) return old.toDouble();
  final rawRate = map['tax_rate'] ?? map['taxRate'];
  final rate = rawRate is num
      ? rawRate.toDouble()
      : double.tryParse(rawRate?.toString().replaceAll(',', '.') ?? '');
  return _summa(map) *
      ((rate ?? fallbackRate) > 1
          ? (rate ?? fallbackRate) / 100
          : (rate ?? fallbackRate));
}

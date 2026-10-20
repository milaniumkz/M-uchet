enum MoneyFlowType {
  operating,
  investing,
  financing,
  transfer,
}

const Set<String> _financingKeywords = {
  'owner',
  'withdrawal',
  'contribution',
  'capital',
  'loan',
  'credit',
  'borrow',
  'владел',
  'собствен',
  'вклад',
  'капитал',
  'займ',
  'кредит',
  'изъят',
};

const Set<String> _investingKeywords = {
  'equipment',
  'asset',
  'invest',
  'capex',
  'основ',
  'оборуд',
  'инвест',
  'станок',
  'авто',
  'техника',
};

extension MoneyFlowTypeX on MoneyFlowType {
  String get storageValue {
    switch (this) {
      case MoneyFlowType.operating:
        return 'OPERATING';
      case MoneyFlowType.investing:
        return 'INVESTING';
      case MoneyFlowType.financing:
        return 'FINANCING';
      case MoneyFlowType.transfer:
        return 'TRANSFER';
    }
  }

  String get label {
    switch (this) {
      case MoneyFlowType.operating:
        return 'Операционный';
      case MoneyFlowType.investing:
        return 'Инвестиционный';
      case MoneyFlowType.financing:
        return 'Финансовый';
      case MoneyFlowType.transfer:
        return 'Перевод';
    }
  }
}

MoneyFlowType moneyFlowTypeFromValue(String? raw) {
  final normalized = (raw ?? '').trim().toLowerCase();
  switch (normalized) {
    case 'investing':
      return MoneyFlowType.investing;
    case 'financing':
      return MoneyFlowType.financing;
    case 'transfer':
      return MoneyFlowType.transfer;
    case 'operating':
    default:
      return MoneyFlowType.operating;
  }
}

String _normalizeMoneyFlowText(String? raw) {
  return (raw ?? '').trim().toLowerCase();
}

bool _containsFlowKeyword(String source, Set<String> keywords) {
  if (source.isEmpty) return false;
  return keywords.any(source.contains);
}

MoneyFlowType inferMoneyFlowType({
  String? explicitValue,
  String? transactionType,
  String? category,
  String? description,
  String? obligationId,
}) {
  final explicit = _normalizeMoneyFlowText(explicitValue);
  if (explicit.isNotEmpty) {
    return moneyFlowTypeFromValue(explicit);
  }

  final type = _normalizeMoneyFlowText(transactionType);
  if (type == 'transfer') return MoneyFlowType.transfer;

  final combined = [
    _normalizeMoneyFlowText(category),
    _normalizeMoneyFlowText(description),
  ].where((part) => part.isNotEmpty).join(' ');

  if (_containsFlowKeyword(combined, _financingKeywords)) {
    return MoneyFlowType.financing;
  }
  if (_containsFlowKeyword(combined, _investingKeywords)) {
    return MoneyFlowType.investing;
  }
  return MoneyFlowType.operating;
}

Map<String, dynamic> moneyFlowTypeFields(MoneyFlowType flowType) {
  return <String, dynamic>{
    'money_flow_type': flowType.storageValue,
    'moneyFlowType': flowType.storageValue,
  };
}

enum AccountNature {
  asset,
  liability,
  equity,
  income,
  expense,
}

String accountNatureStorageValue(AccountNature nature) {
  switch (nature) {
    case AccountNature.asset:
      return 'asset';
    case AccountNature.liability:
      return 'liability';
    case AccountNature.equity:
      return 'equity';
    case AccountNature.income:
      return 'income';
    case AccountNature.expense:
      return 'expense';
  }
}

AccountNature accountNatureFromValue(
  dynamic raw, {
  String? tip,
}) {
  final normalized = raw?.toString().trim().toLowerCase() ?? '';
  switch (normalized) {
    case 'asset':
      return AccountNature.asset;
    case 'liability':
      return AccountNature.liability;
    case 'equity':
      return AccountNature.equity;
    case 'income':
      return AccountNature.income;
    case 'expense':
      return AccountNature.expense;
  }

  final normalizedTip = tip?.trim().toLowerCase() ?? '';
  switch (normalizedTip) {
    case 'my':
      return AccountNature.equity;
    case 'bank':
    case 'nal':
    default:
      return AccountNature.asset;
  }
}

double closingBalanceForNature({
  required AccountNature nature,
  required double openingBalance,
  required double debitTurnover,
  required double creditTurnover,
}) {
  switch (nature) {
    case AccountNature.asset:
    case AccountNature.expense:
      return openingBalance + debitTurnover - creditTurnover;
    case AccountNature.liability:
    case AccountNature.equity:
    case AccountNature.income:
      return openingBalance - debitTurnover + creditTurnover;
  }
}

bool isVirtualAccountId(String accountId) {
  return accountId.trim().startsWith('virtual:');
}

AccountNature accountNatureForId(String accountId) {
  if (accountId.startsWith('virtual:income:')) return AccountNature.income;
  if (accountId.startsWith('virtual:expense:')) return AccountNature.expense;
  if (accountId.startsWith('virtual:equity:')) return AccountNature.equity;
  if (accountId.startsWith('virtual:liability:')) return AccountNature.liability;
  if (accountId.startsWith('virtual:asset:')) return AccountNature.asset;
  return AccountNature.asset;
}

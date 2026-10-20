import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/account_balance_service.dart';
import 'package:uchet_s_d/utils/accounting_accounts.dart';

void main() {
  test(
      'single account balance includes all movements when opening date is empty',
      () {
    final result = computeSingleAccountBalance(
      accountId: 'bank-1',
      nature: AccountNature.asset,
      openingBalance: 519818,
      entryPayloads: [
        {
          'debit_account_id': 'bank-1',
          'amount': 1000000,
          'entry_date': DateTime(2026, 5, 25),
        },
        {
          'credit_account_id': 'bank-1',
          'amount': 300000,
          'entry_date': DateTime(2026, 5, 25),
        },
      ],
    );

    expect(result.debitTurnover, 1000000);
    expect(result.creditTurnover, 300000);
    expect(result.closingBalance, 1219818);
  });

  test('single account balance ignores movements before opening date', () {
    final result = computeSingleAccountBalance(
      accountId: 'bank-1',
      nature: AccountNature.asset,
      openingBalance: 519818,
      openingBalanceDate: DateTime(2026, 7, 24),
      entryPayloads: [
        {
          'debit_account_id': 'bank-1',
          'amount': 1000000,
          'entry_date': DateTime(2026, 5, 25),
        },
        {
          'debit_account_id': 'bank-1',
          'amount': 100,
          'entry_date': DateTime(2026, 7, 24),
        },
      ],
    );

    expect(result.debitTurnover, 100);
    expect(result.creditTurnover, 0);
    expect(result.closingBalance, 519918);
  });
}

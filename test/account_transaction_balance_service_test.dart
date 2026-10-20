import 'package:flutter_test/flutter_test.dart';
import 'package:uchet_s_d/utils/account_transaction_balance_service.dart';

void main() {
  test('account card includes posted payments before opening balance date', () {
    final summary = computeAccountTransactionMovementSummary(
      accountId: 'forte-bank',
      storedBalance: 519818,
      openingBalance: 519818,
      hasOpeningBalance: true,
      transactionPayloads: [
        {
          'type': 'income',
          'status': 'Проведена',
          'summa': 1000000,
          'schetId': 'forte-bank',
          'date': DateTime(2026, 5, 25),
        },
        {
          'type': 'decome',
          'status': 'Проведена',
          'summa': 1300000,
          'schetId': 'forte-bank',
          'date': DateTime(2026, 5, 25),
        },
        {
          'type': 'income',
          'status': 'Проведена',
          'summa': 52562,
          'schetId': 'other-bank',
          'date': DateTime(2026, 5, 25),
        },
      ],
    );

    expect(summary.incomeCount, 1);
    expect(summary.expenseCount, 1);
    expect(summary.income, 1000000);
    expect(summary.expense, 1300000);
    expect(summary.closingBalance, 219818);
  });

  test('empty status is treated as posted for old payments', () {
    final summary = computeAccountTransactionMovementSummary(
      accountId: 'kaspi',
      storedBalance: 0,
      openingBalance: 0,
      hasOpeningBalance: true,
      transactionPayloads: [
        {
          'type': 'доход',
          'summa': 1200,
          'schet_id': 'sheta/kaspi',
        },
      ],
    );

    expect(summary.income, 1200);
    expect(summary.closingBalance, 1200);
  });

  test('account movement uses original currency amount when present', () {
    final summary = computeAccountTransactionMovementSummary(
      accountId: 'usd-account',
      storedBalance: 0,
      openingBalance: 0,
      hasOpeningBalance: true,
      transactionPayloads: [
        {
          'type': 'income',
          'status': 'Проведена',
          'amount_original': 100,
          'amount_company': 1050,
          'currency_original': 'USD',
          'company_currency': 'TJS',
          'schetId': 'usd-account',
        },
      ],
    );

    expect(summary.income, 100);
    expect(summary.closingBalance, 100);
  });

  test('transfer counts as income for target and expense for source account',
      () {
    final sourceSummary = computeAccountTransactionMovementSummary(
      accountId: 'kaspi',
      storedBalance: 0,
      openingBalance: 1000,
      hasOpeningBalance: true,
      transactionPayloads: [
        {
          'type': 'transfer',
          'status': 'Проведена',
          'summa': 300,
          'sourceSchetId': 'kaspi',
          'targetSchetId': 'forte',
        },
      ],
    );
    final targetSummary = computeAccountTransactionMovementSummary(
      accountId: 'forte',
      storedBalance: 0,
      openingBalance: 2000,
      hasOpeningBalance: true,
      transactionPayloads: [
        {
          'type': 'transfer',
          'status': 'Проведена',
          'summa': 300,
          'sourceSchetId': 'kaspi',
          'targetSchetId': 'forte',
        },
      ],
    );

    expect(sourceSummary.incomeCount, 0);
    expect(sourceSummary.expenseCount, 1);
    expect(sourceSummary.expense, 300);
    expect(sourceSummary.closingBalance, 700);

    expect(targetSummary.incomeCount, 1);
    expect(targetSummary.expenseCount, 0);
    expect(targetSummary.income, 300);
    expect(targetSummary.closingBalance, 2300);
  });

  test('legacy posting status is treated as posted', () {
    final summary = computeAccountTransactionMovementSummary(
      accountId: 'forte',
      storedBalance: 0,
      openingBalance: 0,
      hasOpeningBalance: true,
      transactionPayloads: [
        {
          'type': 'income',
          'status': 'Проводка',
          'summa': 500,
          'schetId': 'forte',
        },
      ],
    );

    expect(summary.incomeCount, 1);
    expect(summary.income, 500);
    expect(summary.closingBalance, 500);
  });

  test('wallet-only transaction linked to legacy account is counted', () {
    final summary = computeAccountTransactionMovementSummary(
      accountId: 'forte',
      storedBalance: 0,
      openingBalance: 1000,
      hasOpeningBalance: true,
      transactionPayloads: [
        {
          'type': 'decome',
          'status': 'Проведена',
          'summa': 250,
          'wallet_id': 'account_forte',
        },
      ],
    );

    expect(summary.expenseCount, 1);
    expect(summary.expense, 250);
    expect(summary.closingBalance, 750);
  });

  test('wallet-only transfer is counted for source and target legacy accounts',
      () {
    final sourceSummary = computeAccountTransactionMovementSummary(
      accountId: 'cash',
      storedBalance: 0,
      openingBalance: 1000,
      hasOpeningBalance: true,
      transactionPayloads: [
        {
          'type': 'transfer',
          'status': 'Проведена',
          'summa': 400,
          'from_wallet_id': 'account_cash',
          'to_wallet_id': 'account_forte',
        },
      ],
    );
    final targetSummary = computeAccountTransactionMovementSummary(
      accountId: 'forte',
      storedBalance: 0,
      openingBalance: 100,
      hasOpeningBalance: true,
      transactionPayloads: [
        {
          'type': 'transfer',
          'status': 'Проведена',
          'summa': 400,
          'from_wallet_id': 'account_cash',
          'to_wallet_id': 'account_forte',
        },
      ],
    );

    expect(sourceSummary.expense, 400);
    expect(sourceSummary.closingBalance, 600);
    expect(targetSummary.income, 400);
    expect(targetSummary.closingBalance, 500);
  });
}
